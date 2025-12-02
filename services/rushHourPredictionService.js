import { addDays, startOfDay } from 'date-fns';
import { mean, standardDeviation } from 'simple-statistics';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import PredictionModel from '../models/PredictionModel.js';
import logger from '../utils/logger.js';

const DEFAULT_LOOKBACK_DAYS = Number(process.env.PREDICTION_LOOKBACK_DAYS || 90);
const DEFAULT_FORWARD_DAYS = Number(process.env.PREDICTION_FORWARD_DAYS || 7);
const RUSH_THRESHOLD_MULTIPLIER = Number(process.env.RUSH_HOUR_THRESHOLD || 0.7);

const modelState = {
    lastTrainedAt: null,
    lastBulkTrainingRange: null,
    lines: new Map(), // lineid -> { buckets: Map, stats: {...} }
};

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

    const historicalBuckets = await Reservation.getHistoricalBookingsByTimeRange(start, end, filters);

    const trainedLines = new Set();
    let sampleCount = 0;

    for (const bucket of historicalBuckets) {
        if (!bucket.lineid) continue;
        trainedLines.add(bucket.lineid);
        sampleCount += bucket.totalBookings;

        const lineModel = getOrCreateLineModel(bucket.lineid);
        mergeBucket(lineModel, bucket);
    }

    for (const lineid of trainedLines) {
        recomputeStats(modelState.lines.get(lineid));
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

    return {
        trainedLines: Array.from(trainedLines),
        samplesProcessed: sampleCount,
        lookbackWindow: {
            start: start.toISOString(),
            end: end.toISOString(),
        },
    };
}

export async function updateModelIncremental(events = []) {
    let updatedLines = new Set();

    for (const event of events) {
        if (!event?.lineid || !event.eventTime) {
            continue;
        }

        const lineModel = getOrCreateLineModel(event.lineid);
        const date = new Date(event.eventTime);
        if (Number.isNaN(date.getTime())) continue;

        const dayOfWeek = date.getUTCDay();
        const hour = date.getUTCHours();
        const key = `${dayOfWeek}|${hour}`;

        if (!lineModel.buckets.has(key)) {
            lineModel.buckets.set(key, {
                lineid: event.lineid,
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

        updatedLines.add(event.lineid);
    }

    updatedLines = Array.from(updatedLines);
    updatedLines.forEach((lineid) => recomputeStats(modelState.lines.get(lineid)));

    // Debounced save - only save if we processed significant updates
    if (updatedLines.length > 0 && events.length >= 5) {
        try {
            await saveModelToDatabase();
        } catch (saveError) {
            logger.warn('Failed to save model to database after incremental update', {
                error: saveError.message,
            });
        }
    }

    return {
        updatedLines,
        eventsProcessed: events.length,
        lastIncrementalUpdate: new Date().toISOString(),
    };
}

export async function getRushHourPredictions(options = {}) {
    const lineid = options.lineid;
    const daysAhead = options.daysAhead || DEFAULT_FORWARD_DAYS;

    if (!lineid) {
        throw new Error('lineid is required for getRushHourPredictions');
    }

    if (!modelState.lines.has(lineid)) {
        await trainModelBulk({ lineid });
    }

    const lineModel = modelState.lines.get(lineid);
    if (!lineModel || lineModel.buckets.size === 0) {
        return {
            lineid,
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
        trainedLines: modelState.lines.size,
        lastTrainedAt: modelState.lastTrainedAt,
        lastBulkTrainingRange: modelState.lastBulkTrainingRange,
    };
}

export function getTrackedLines() {
    return Array.from(modelState.lines.keys());
}

function getOrCreateLineModel(lineid) {
    if (!modelState.lines.has(lineid)) {
        modelState.lines.set(lineid, {
            lineid,
            buckets: new Map(),
            stats: {
                mean: 0,
                stdDev: 0,
                lastUpdatedAt: null,
            },
        });
    }
    return modelState.lines.get(lineid);
}

function mergeBucket(lineModel, bucket) {
    const key = `${bucket.dayOfWeek}|${bucket.hour}`;

    if (!lineModel.buckets.has(key)) {
        lineModel.buckets.set(key, {
            lineid: bucket.lineid,
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
        };
    }

    return {
        buckets: lineModel.buckets.size,
        updatedAt: lineModel.stats.lastUpdatedAt,
        mean: lineModel.stats.mean,
        stdDev: lineModel.stats.stdDev,
    };
}

function serializeModelState() {
    const serialized = {
        lastTrainedAt: modelState.lastTrainedAt,
        lastBulkTrainingRange: modelState.lastBulkTrainingRange,
        lines: {},
    };

    // Convert Map to serializable format
    modelState.lines.forEach((lineModel, lineid) => {
        const bucketsArray = [];
        lineModel.buckets.forEach((bucket, key) => {
            bucketsArray.push({
                key,
                value: bucket,
            });
        });

        serialized.lines[lineid] = {
            lineid,
            buckets: bucketsArray,
            stats: lineModel.stats,
        };
    });

    return serialized;
}

function deserializeModelState(serializedData) {
    if (!serializedData || !serializedData.lines) {
        return;
    }

    modelState.lastTrainedAt = serializedData.lastTrainedAt || null;
    modelState.lastBulkTrainingRange = serializedData.lastBulkTrainingRange || null;
    modelState.lines.clear();

    // Reconstruct Maps from serialized data
    Object.entries(serializedData.lines || {}).forEach(([lineid, lineData]) => {
        const buckets = new Map();
        if (Array.isArray(lineData.buckets)) {
            lineData.buckets.forEach(({ key, value }) => {
                buckets.set(key, value);
            });
        }

        modelState.lines.set(lineid, {
            lineid,
            buckets,
            stats: lineData.stats || {
                mean: 0,
                stdDev: 0,
                lastUpdatedAt: null,
            },
        });
    });
}

export async function saveModelToDatabase() {
    const serialized = serializeModelState();
    const savedLines = [];

    for (const [lineid, lineData] of modelState.lines.entries()) {
        try {
            const bucketsArray = [];
            lineData.buckets.forEach((bucket, key) => {
                bucketsArray.push({ key, value: bucket });
            });

            await PredictionModel.upsert(lineid, {
                model_data: {
                    buckets: bucketsArray,
                    stats: lineData.stats,
                },
                last_trained_at: modelState.lastTrainedAt,
                training_range_start: modelState.lastBulkTrainingRange?.start || null,
                training_range_end: modelState.lastBulkTrainingRange?.end || null,
            });

            savedLines.push(lineid);
        } catch (error) {
            logger.error('Failed to save model for line', {
                lineid,
                error: error.message,
            });
        }
    }

    logger.info('Model saved to database', {
        linesSaved: savedLines.length,
        totalLines: modelState.lines.size,
    });

    return {
        savedLines,
        totalLines: modelState.lines.size,
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

                modelState.lines.set(savedModel.lineid, {
                    lineid: savedModel.lineid,
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
                logger.error('Failed to load model for line', {
                    lineid: savedModel.lineid,
                    error: error.message,
                });
            }
        }

        logger.info('Model loaded from database', {
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
    saveModelToDatabase,
    loadModelFromDatabase,
    initializeModel,
};

