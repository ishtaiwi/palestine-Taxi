import { addDays, startOfDay } from 'date-fns';
import { mean, standardDeviation } from 'simple-statistics';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import PredictionModel from '../models/PredictionModel.js';
import logger from '../utils/logger.js';

const DEFAULT_LOOKBACK_DAYS = Number(process.env.PREDICTION_LOOKBACK_DAYS || 90);
const DEFAULT_FORWARD_DAYS = Number(process.env.PREDICTION_FORWARD_DAYS || 7);
const RUSH_THRESHOLD_MULTIPLIER = Number(process.env.RUSH_HOUR_THRESHOLD || 0.7);

// Supported directions for predictions
export const DIRECTIONS = ['going', 'return'];

const modelState = {
    lastTrainedAt: null,
    lastBulkTrainingRange: null,
    // Key format: "lineid_direction" -> { buckets: Map, stats: {...} }
    lines: new Map(),
};

/**
 * Build a model key from lineid and direction
 */
function buildModelKey(lineid, direction) {
    return `${lineid}_${direction}`;
}

/**
 * Parse a model key back to lineid and direction
 */
function parseModelKey(modelKey) {
    const parts = modelKey.split('_');
    const direction = parts.pop();
    const lineid = parts.join('_');
    return { lineid, direction };
}

export async function trainModelBulk(options = {}) {
    const now = new Date();
    const end = options.endDate ? new Date(options.endDate) : now;
    const start = options.startDate ? new Date(options.startDate) : addDays(end, -DEFAULT_LOOKBACK_DAYS);

    if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
        throw new Error('Invalid date range supplied to trainModelBulk');
    }

    const filters = {};
    if (options.lineid) {
        filters.lineid = options.lineid;
    }

    if (options.booking_type) {
        filters.booking_type = options.booking_type;
    }

    // If direction is specified, only train for that direction
    if (options.direction) {
        filters.direction = options.direction;
    }

    const historicalBuckets = await Reservation.getHistoricalBookingsByTimeRange(start, end, filters);

    const trainedModels = new Set(); // Now tracks "lineid_direction" keys
    let sampleCount = 0;

    for (const bucket of historicalBuckets) {
        if (!bucket.lineid) continue;

        // Use direction from bucket (defaults to 'going' if not present)
        const direction = bucket.direction || 'going';
        const modelKey = buildModelKey(bucket.lineid, direction);

        trainedModels.add(modelKey);
        sampleCount += bucket.totalBookings;

        const lineModel = getOrCreateLineModel(bucket.lineid, direction);
        mergeBucket(lineModel, bucket);
    }

    for (const modelKey of trainedModels) {
        recomputeStats(modelState.lines.get(modelKey));
    }

    modelState.lastTrainedAt = new Date().toISOString();
    modelState.lastBulkTrainingRange = {
        start: start.toISOString(),
        end: end.toISOString(),
    };

    // Save models to database after training
    try {
        await saveModelToDatabase();
    } catch (saveError) {
        logger.warn('Failed to save model to database after training', {
            error: saveError.message,
        });
    }

    // Parse trained models back to lineid + direction for reporting
    const trainedLineDirections = Array.from(trainedModels).map(parseModelKey);

    return {
        trainedModels: Array.from(trainedModels),
        trainedLineDirections,
        samplesProcessed: sampleCount,
        lookbackWindow: {
            start: start.toISOString(),
            end: end.toISOString(),
        },
    };
}

export async function updateModelIncremental(events = []) {
    let updatedModels = new Set();

    for (const event of events) {
        if (!event?.lineid || !event.eventTime) {
            continue;
        }

        // Use direction from event (defaults to 'going' if not present)
        const direction = event.direction || 'going';
        const modelKey = buildModelKey(event.lineid, direction);

        const lineModel = getOrCreateLineModel(event.lineid, direction);
        const date = new Date(event.eventTime);
        if (Number.isNaN(date.getTime())) continue;

        const dayOfWeek = date.getUTCDay();
        const hour = date.getUTCHours();
        const key = `${dayOfWeek}|${hour}`;

        if (!lineModel.buckets.has(key)) {
            lineModel.buckets.set(key, {
                lineid: event.lineid,
                direction,
                dayOfWeek,
                hour,
                totalBookings: 0,
                sampleCount: 0,
                statusBreakdown: {},
            });
        }

        const bucket = lineModel.buckets.get(key);
        bucket.totalBookings += 1;
        bucket.sampleCount += 1;
        bucket.statusBreakdown[event.status] = (bucket.statusBreakdown[event.status] || 0) + 1;

        updatedModels.add(modelKey);
    }

    updatedModels = Array.from(updatedModels);
    updatedModels.forEach((modelKey) => recomputeStats(modelState.lines.get(modelKey)));

    // Debounced save - only save if we processed significant updates
    if (updatedModels.length > 0 && events.length >= 5) {
        try {
            await saveModelToDatabase();
        } catch (saveError) {
            logger.warn('Failed to save model to database after incremental update', {
                error: saveError.message,
            });
        }
    }

    return {
        updatedModels,
        eventsProcessed: events.length,
        lastIncrementalUpdate: new Date().toISOString(),
    };
}

/**
 * Get rush hour predictions for a specific line and direction
 * @param {Object} options - Options
 * @param {string} options.lineid - Line ID (required)
 * @param {string} options.direction - Direction ('going' or 'return', required)
 * @param {number} options.daysAhead - Number of days to predict ahead (default 7)
 */
export async function getRushHourPredictions(options = {}) {
    const lineid = options.lineid;
    const direction = options.direction || 'going';
    const daysAhead = options.daysAhead || DEFAULT_FORWARD_DAYS;

    if (!lineid) {
        throw new Error('lineid is required for getRushHourPredictions');
    }

    if (!DIRECTIONS.includes(direction)) {
        throw new Error(`Invalid direction: ${direction}. Must be one of: ${DIRECTIONS.join(', ')}`);
    }

    const modelKey = buildModelKey(lineid, direction);

    if (!modelState.lines.has(modelKey)) {
        await trainModelBulk({ lineid, direction });
    }

    const lineModel = modelState.lines.get(modelKey);
    if (!lineModel || lineModel.buckets.size === 0) {
        return {
            lineid,
            direction,
            predictions: [],
            metadata: buildLineMetadata(lineModel),
        };
    }

    const threshold = computeRushThreshold(lineModel);
    const predictions = [];
    let currentDay = startOfDay(new Date());

    for (let i = 0; i < daysAhead; i += 1) {
        const dayOfWeek = currentDay.getUTCDay();
        for (let hour = 0; hour < 24; hour += 1) {
            const key = `${dayOfWeek}|${hour}`;
            const bucket = lineModel.buckets.get(key);
            if (!bucket) continue;

            const avgBookings = bucket.totalBookings / Math.max(bucket.sampleCount || bucket.samples?.length || 1, 1);
            if (avgBookings < threshold) continue;

            const confidence = Math.min(0.99, avgBookings / (threshold || 1));
            predictions.push({
                lineid,
                direction,
                date: currentDay.toISOString().slice(0, 10),
                hour,
                expectedBookings: avgBookings,
                confidence,
                reason: 'historical_peak',
            });
        }
        currentDay = addDays(currentDay, 1);
    }

    predictions.sort((a, b) => b.expectedBookings - a.expectedBookings);

    return {
        lineid,
        direction,
        predictions,
        metadata: {
            ...buildLineMetadata(lineModel),
            threshold,
        },
    };
}

export async function getTopDemandLines(options = {}) {
    const limit = options.limit || 5;
    const lines = Array.from(modelState.lines.keys());

    const snapshots = await Promise.all(
        lines.map(async (lineid) => {
            const buckets = await Trip.getCapacityUtilizationByLineAndTime(lineid, {
                startDate: options.startDate,
                endDate: options.endDate,
            });
            if (!buckets.length) {
                return null;
            }
            const avgUtilization =
                buckets.reduce((sum, bucket) => sum + (bucket.avgUtilization || 0), 0) / buckets.length;
            return {
                lineid,
                avgUtilization,
                buckets,
            };
        }),
    );

    return snapshots
        .filter(Boolean)
        .sort((a, b) => b.avgUtilization - a.avgUtilization)
        .slice(0, limit);
}

export async function getLineDemandSnapshot(lineid, options = {}) {
    return Trip.getCapacityUtilizationByLineAndTime(lineid, options);
}

export function getModelSummary() {
    return {
        trainedModels: modelState.lines.size,
        lastTrainedAt: modelState.lastTrainedAt,
        lastBulkTrainingRange: modelState.lastBulkTrainingRange,
    };
}

/**
 * Get all tracked model keys (lineid_direction format)
 */
export function getTrackedModels() {
    return Array.from(modelState.lines.keys());
}

/**
 * Get unique line IDs that have trained models (for backwards compatibility)
 */
export function getTrackedLines() {
    const lineIds = new Set();
    for (const modelKey of modelState.lines.keys()) {
        const { lineid } = parseModelKey(modelKey);
        lineIds.add(lineid);
    }
    return Array.from(lineIds);
}

/**
 * Get or create a line model for a specific direction
 * @param {string} lineid - Line ID
 * @param {string} direction - Direction ('going' or 'return')
 */
function getOrCreateLineModel(lineid, direction = 'going') {
    const modelKey = buildModelKey(lineid, direction);
    if (!modelState.lines.has(modelKey)) {
        modelState.lines.set(modelKey, {
            lineid,
            direction,
            buckets: new Map(),
            stats: {
                mean: 0,
                stdDev: 0,
                lastUpdatedAt: null,
            },
        });
    }
    return modelState.lines.get(modelKey);
}

function mergeBucket(lineModel, bucket) {
    const key = `${bucket.dayOfWeek}|${bucket.hour}`;

    if (!lineModel.buckets.has(key)) {
        lineModel.buckets.set(key, {
            lineid: bucket.lineid,
            direction: bucket.direction || lineModel.direction || 'going',
            dayOfWeek: bucket.dayOfWeek,
            hour: bucket.hour,
            totalBookings: 0,
            sampleCount: 0,
            statusBreakdown: {},
        });
    }

    const existing = lineModel.buckets.get(key);
    existing.totalBookings += bucket.totalBookings;
    existing.sampleCount += bucket.samples?.length || bucket.totalBookings;

    Object.entries(bucket.statusBreakdown || {}).forEach(([status, count]) => {
        existing.statusBreakdown[status] = (existing.statusBreakdown[status] || 0) + count;
    });
}

function recomputeStats(lineModel) {
    if (!lineModel) return;
    const averages = [];
    lineModel.buckets.forEach((bucket) => {
        const avg = bucket.totalBookings / Math.max(bucket.sampleCount || 1, 1);
        averages.push(avg);
    });

    lineModel.stats.mean = averages.length ? mean(averages) : 0;
    lineModel.stats.stdDev = averages.length > 1 ? standardDeviation(averages) : 0;
    lineModel.stats.lastUpdatedAt = new Date().toISOString();
}

function computeRushThreshold(lineModel) {
    if (!lineModel || !lineModel.buckets.size) return 0;

    const base = lineModel.stats.mean + lineModel.stats.stdDev * RUSH_THRESHOLD_MULTIPLIER;
    if (base > 0) return base;

    const allAverages = Array.from(lineModel.buckets.values()).map(
        (bucket) => bucket.totalBookings / Math.max(bucket.sampleCount || 1, 1),
    );
    return allAverages.length ? mean(allAverages) : 0;
}

function buildLineMetadata(lineModel) {
    if (!lineModel) {
        return {
            buckets: 0,
            updatedAt: null,
            mean: 0,
            stdDev: 0,
            direction: null,
        };
    }

    return {
        buckets: lineModel.buckets.size,
        updatedAt: lineModel.stats.lastUpdatedAt,
        mean: lineModel.stats.mean,
        stdDev: lineModel.stats.stdDev,
        direction: lineModel.direction,
    };
}

function serializeModelState() {
    const serialized = {
        lastTrainedAt: modelState.lastTrainedAt,
        lastBulkTrainingRange: modelState.lastBulkTrainingRange,
        models: {},
    };

    // Convert Map to serializable format (keyed by lineid_direction)
    modelState.lines.forEach((lineModel, modelKey) => {
        const bucketsArray = [];
        lineModel.buckets.forEach((bucket, key) => {
            bucketsArray.push({
                key,
                value: bucket,
            });
        });

        serialized.models[modelKey] = {
            lineid: lineModel.lineid,
            direction: lineModel.direction,
            buckets: bucketsArray,
            stats: lineModel.stats,
        };
    });

    return serialized;
}

function deserializeModelState(serializedData) {
    if (!serializedData) {
        return;
    }

    modelState.lastTrainedAt = serializedData.lastTrainedAt || null;
    modelState.lastBulkTrainingRange = serializedData.lastBulkTrainingRange || null;
    modelState.lines.clear();

    // Support both old format (lines) and new format (models)
    const modelsData = serializedData.models || serializedData.lines || {};

    // Reconstruct Maps from serialized data
    Object.entries(modelsData).forEach(([modelKey, modelData]) => {
        const buckets = new Map();
        if (Array.isArray(modelData.buckets)) {
            modelData.buckets.forEach(({ key, value }) => {
                buckets.set(key, value);
            });
        }

        // For old format, modelKey is just lineid, for new format it's lineid_direction
        const direction = modelData.direction || 'going';
        const lineid = modelData.lineid || modelKey;
        const actualModelKey = modelData.direction ? modelKey : buildModelKey(lineid, direction);

        modelState.lines.set(actualModelKey, {
            lineid,
            direction,
            buckets,
            stats: modelData.stats || {
                mean: 0,
                stdDev: 0,
                lastUpdatedAt: null,
            },
        });
    });
}

export async function saveModelToDatabase() {
    const savedModels = [];

    for (const [modelKey, modelData] of modelState.lines.entries()) {
        try {
            const bucketsArray = [];
            modelData.buckets.forEach((bucket, key) => {
                bucketsArray.push({ key, value: bucket });
            });

            // Use modelKey (lineid_direction) as the storage key
            await PredictionModel.upsert(modelKey, {
                model_data: {
                    lineid: modelData.lineid,
                    direction: modelData.direction,
                    buckets: bucketsArray,
                    stats: modelData.stats,
                },
                last_trained_at: modelState.lastTrainedAt,
                training_range_start: modelState.lastBulkTrainingRange?.start || null,
                training_range_end: modelState.lastBulkTrainingRange?.end || null,
            });

            savedModels.push(modelKey);
        } catch (error) {
            logger.error('Failed to save model', {
                modelKey,
                lineid: modelData.lineid,
                direction: modelData.direction,
                error: error.message,
            });
        }
    }

    logger.info('Models saved to database', {
        modelsSaved: savedModels.length,
        totalModels: modelState.lines.size,
    });

    return {
        savedModels,
        totalModels: modelState.lines.size,
    };
}

export async function loadModelFromDatabase() {
    try {
        const savedModels = await PredictionModel.findAll();

        if (savedModels.length === 0) {
            logger.info('No saved models found in database');
            return {
                loaded: 0,
                total: 0,
            };
        }

        // Clear current state
        modelState.lines.clear();
        modelState.lastTrainedAt = null;
        modelState.lastBulkTrainingRange = null;

        let loadedCount = 0;

        for (const savedModel of savedModels) {
            try {
                const modelData = savedModel.model_data;
                if (!modelData || !modelData.buckets) {
                    continue;
                }

                const buckets = new Map();
                if (Array.isArray(modelData.buckets)) {
                    modelData.buckets.forEach(({ key, value }) => {
                        buckets.set(key, value);
                    });
                }

                // Support both old format (lineid only) and new format (lineid_direction)
                const direction = modelData.direction || 'going';
                const lineid = modelData.lineid || savedModel.lineid;
                // Use the stored key as-is (it's already in lineid_direction format for new models)
                const modelKey = savedModel.lineid;

                modelState.lines.set(modelKey, {
                    lineid,
                    direction,
                    buckets,
                    stats: modelData.stats || {
                        mean: 0,
                        stdDev: 0,
                        lastUpdatedAt: savedModel.last_trained_at,
                    },
                });

                // Set global training metadata from most recent model
                if (savedModel.last_trained_at) {
                    if (!modelState.lastTrainedAt || savedModel.last_trained_at > modelState.lastTrainedAt) {
                        modelState.lastTrainedAt = savedModel.last_trained_at;
                        modelState.lastBulkTrainingRange = {
                            start: savedModel.training_range_start,
                            end: savedModel.training_range_end,
                        };
                    }
                }

                loadedCount++;
            } catch (error) {
                logger.error('Failed to load model', {
                    modelKey: savedModel.lineid,
                    error: error.message,
                });
            }
        }

        logger.info('Models loaded from database', {
            loaded: loadedCount,
            total: savedModels.length,
        });

        return {
            loaded: loadedCount,
            total: savedModels.length,
        };
    } catch (error) {
        logger.error('Failed to load models from database', {
            error: error.message,
        });
        return {
            loaded: 0,
            total: 0,
            error: error.message,
        };
    }
}

export async function initializeModel() {
    logger.info('Initializing prediction model from database...');
    const result = await loadModelFromDatabase();

    if (result.loaded > 0) {
        logger.info('✅ Prediction model initialized', {
            linesLoaded: result.loaded,
        });
    } else {
        logger.warn('⚠️ No saved models found. Model will train on first prediction request.');
    }

    return result;
}

export default {
    trainModelBulk,
    updateModelIncremental,
    getRushHourPredictions,
    getTopDemandLines,
    getLineDemandSnapshot,
    getModelSummary,
    getTrackedLines,
    getTrackedModels,
    saveModelToDatabase,
    loadModelFromDatabase,
    initializeModel,
    DIRECTIONS,
};

