import { addHours } from 'date-fns';
import ScheduleTemplate from '../models/ScheduleTemplate.js';
import Trip from '../models/Trip.js';
import Vehicle from '../models/Vehicle.js';
import { v4 as uuidv4 } from 'uuid';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import logger from '../utils/logger.js';
import {
    getRushHourPredictions,
    getTopDemandLines,
    getLineDemandSnapshot,
    getModelSummary,
    getTrackedLines,
} from './rushHourPredictionService.js';

const CAPACITY_UTILIZATION_THRESHOLD = 0.8;

export async function generateScheduleRecommendations(options = {}) {
    const lineIds = options.lineIds && options.lineIds.length ? options.lineIds : getTrackedLines();
    const daysAhead = options.daysAhead || 7;

    const recommendations = [];

    for (const lineid of lineIds) {
        const [predictionData, utilizationBuckets, templates] = await Promise.all([
            getRushHourPredictions({ lineid, daysAhead }),
            getLineDemandSnapshot(lineid, {
                startDate: options.utilizationStartDate,
                endDate: options.utilizationEndDate,
            }),
            ScheduleTemplate.findByLineId(lineid),
        ]);

        const utilizationMap = buildUtilizationMap(utilizationBuckets);
        const template = templates?.[0] || null;

        const lineRecs = await buildLineRecommendations(lineid, predictionData, utilizationMap, template);
        recommendations.push(...lineRecs);
    }

    return recommendations.sort((a, b) => b.priority - a.priority);
}

export async function getDemandInsights(options = {}) {
    const topLines = await getTopDemandLines({
        limit: options.limit || 5,
        startDate: options.utilizationStartDate,
        endDate: options.utilizationEndDate,
    });

    return {
        model: getModelSummary(),
        topLines,
    };
}

export async function applyRecommendation(recommendation) {
    if (!recommendation) {
        throw new Error('Recommendation is required');
    }

    const { actionType, actionPayload, lineid, templateId } = recommendation;

    // Handle insert_buffer_trip by creating trip directly
    if (actionType === 'insert_buffer_trip') {
        if (!actionPayload?.deptime) {
            throw new Error('insert_buffer_trip requires deptime in payload');
        }

        // Calculate trip opening time (45 minutes before departure)
        const deptime = new Date(actionPayload.deptime);
        const openingTime = new Date(deptime.getTime() - 45 * 60 * 1000);

        // Get default vehicle for seat count calculation (optional)
        // Vehicle will be assigned from driver queue at trip opening time
        const vehicles = await Vehicle.findAll({ lineid, status: 'active' });
        const defaultSeats = vehicles && vehicles.length > 0 ? vehicles[0].seatnum : 5;

        const tripData = {
            tripid: uuidv4(),
            lineid,
            vehicleid: null, // Will be assigned from driver queue at opening time
            deptime: deptime.toISOString(),
            status: 'scheduled',
            availableseats: calculateAvailablePassengerSeats(defaultSeats, 0, 0),
            totalbookings: 0,
            trip_opening_time: openingTime.toISOString(),
            auto_departure_enabled: true,
            early_departure_allowed: true,
            scheduled_departure_enforced: true,
            templateid: templateId || null,
        };

        const createdTrip = await Trip.create(tripData);

        logger.info('Buffer trip created from recommendation', {
            tripid: createdTrip.tripid,
            lineid,
            deptime: deptime.toISOString(),
        });

        return {
            trip: createdTrip,
            appliedAt: new Date().toISOString(),
        };
    }

    // Handle other action types (update template)
    if (!templateId || !actionPayload) {
        throw new Error('Recommendation is missing template context or action payload');
    }

    const updatedTemplate = await ScheduleTemplate.update(
        templateId,
        actionPayload,
    );

    return {
        updatedTemplate,
        appliedAt: new Date().toISOString(),
    };
}

async function buildLineRecommendations(lineid, predictionData, utilizationMap, template) {
    if (!predictionData?.predictions?.length) return [];

    const recommendations = [];

    for (const prediction of predictionData.predictions) {
        // Check available seats in scheduled trips for this time slot
        const totalAvailableSeats = await getTotalAvailableSeatsForTimeSlot(
            lineid,
            prediction.date,
            prediction.hour,
        );

        // Only show recommendation if expected bookings exceed available seats
        if (prediction.expectedBookings <= totalAvailableSeats) {
            continue;
        }

        const day = new Date(`${prediction.date}T00:00:00Z`).getUTCDay();
        const bucketKey = `${day}|${prediction.hour}`;
        const utilization = utilizationMap.get(bucketKey) || 0;
        const highUtilization = utilization >= CAPACITY_UTILIZATION_THRESHOLD;

        const actionPlan = await determineActionPlan({
            template,
            prediction,
            highUtilization,
            lineid,
            totalAvailableSeats,
        });

        const priority = prediction.confidence + (highUtilization ? 0.5 : 0) + utilization;

        recommendations.push({
            id: `rec_${lineid}_${prediction.date}_${prediction.hour}`,
            lineid,
            targetDate: prediction.date,
            hour: prediction.hour,
            expectedBookings: prediction.expectedBookings,
            totalAvailableSeats,
            confidence: prediction.confidence,
            utilization,
            highUtilization,
            priority,
            templateId: actionPlan.templateId,
            actionType: actionPlan.actionType,
            actionPayload: actionPlan.payload,
            summary: actionPlan.summary,
            details: actionPlan.details,
            metadata: {
                threshold: predictionData.metadata?.threshold,
                modelUpdatedAt: predictionData.metadata?.updatedAt,
            },
        });
    }

    return recommendations;
}

function buildUtilizationMap(buckets = []) {
    const map = new Map();

    buckets.forEach((bucket) => {
        const sample = bucket.samples?.[0];
        const date = sample?.deptime ? new Date(sample.deptime) : null;
        if (!date || Number.isNaN(date.getTime())) return;

        const key = `${date.getUTCDay()}|${date.getUTCHours()}`;
        map.set(key, bucket.avgUtilization || 0);
    });

    return map;
}

async function getTotalAvailableSeatsForTimeSlot(lineid, date, hour) {
    try {
        // Create date range for the specific hour
        const targetDate = new Date(`${date}T${String(hour).padStart(2, '0')}:00:00Z`);
        const startTime = new Date(targetDate);
        startTime.setMinutes(0, 0, 0);
        const endTime = new Date(targetDate);
        endTime.setMinutes(59, 59, 999);

        // Find all scheduled trips for this line in this time slot
        const trips = await Trip.findAll({
            lineid,
            date: date,
        });

        // Filter trips that match the hour and sum available seats
        let totalAvailable = 0;
        for (const trip of trips || []) {
            const tripDeptime = new Date(trip.deptime);
            if (
                tripDeptime.getUTCHours() === hour &&
                trip.status === 'scheduled' &&
                trip.availableseats > 0
            ) {
                totalAvailable += trip.availableseats || 0;
            }
        }

        return totalAvailable;
    } catch (error) {
        logger.error('Error calculating available seats for time slot', {
            lineid,
            date,
            hour,
            error: error.message,
        });
        return 0;
    }
}

async function determineActionPlan({ template, prediction, highUtilization, lineid, totalAvailableSeats }) {
    if (!template) {
        return {
            actionType: 'deploy_ad_hoc_vehicle',
            templateId: null,
            payload: null,
            summary: 'Deploy a standby vehicle for this time block',
            details: `No schedule template found. Consider adding an ad-hoc trip around ${formatHour(
                prediction.hour,
            )} UTC on ${prediction.date}.`,
        };
    }

    if (highUtilization) {
        const newInterval = Math.max(15, template.interval_minutes - 15);
        return {
            actionType: 'increase_frequency',
            templateId: template.templateid,
            payload: {
                interval_minutes: newInterval,
            },
            summary: 'Increase trip frequency during predicted rush hour',
            details: `Reduce interval from ${template.interval_minutes} to ${newInterval} minutes to handle expected demand at ${formatHour(
                prediction.hour,
            )}.`,
        };
    }

    if (prediction.hour >= template.end_hour) {
        const extendedHour = Math.min(23, prediction.hour + 1);
        return {
            actionType: 'extend_hours',
            templateId: template.templateid,
            payload: {
                end_hour: extendedHour,
            },
            summary: 'Extend operating hours to cover late rush hour',
            details: `Extend end hour from ${template.end_hour} to ${extendedHour} to cover demand peaking at ${formatHour(
                prediction.hour,
            )}.`,
        };
    }

    const additionalTripTime = new Date(`${prediction.date}T${String(prediction.hour).padStart(2, '0')}:00:00Z`);
    return {
        actionType: 'insert_buffer_trip',
        templateId: template.templateid,
        payload: {
            deptime: additionalTripTime.toISOString(),
        },
        summary: 'Insert buffer trip',
        details: `Add a buffer trip at ${formatHour(prediction.hour)} on ${prediction.date} to absorb ${prediction.expectedBookings.toFixed(
            1,
        )} projected bookings (${totalAvailableSeats} seats currently available).`,
    };
}

function formatHour(hour) {
    return `${String(hour).padStart(2, '0')}:00`;
}

export default {
    generateScheduleRecommendations,
    getDemandInsights,
    applyRecommendation,
};

