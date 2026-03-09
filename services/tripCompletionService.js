import Trip from '../models/Trip.js';
import Line from '../models/Line.js';
import LinePath from '../models/LinePath.js';
import { TRIP_STATUS, TRIP_DIRECTION } from '../utils/constants.js';
import { calculateReturnTripDeptime } from '../utils/tripDirectionUtils.js';
import { v4 as uuidv4 } from 'uuid';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import logger from '../utils/logger.js';
import { getUtcNow } from '../utils/timeUtils.js';

/**
 * Check if a going trip has completed and create returning trip if needed
 * @param {string} tripid - Trip ID
 * @returns {Promise<Object|null>} - Created returning trip or null
 */
export async function checkAndCreateReturningTrip(tripid) {
  try {
    const trip = await Trip.findById(tripid);
    
    if (!trip) {
      logger.warn(`[TripCompletionService] Trip ${tripid} not found`);
      return null;
    }

    // Only process going trips
    if (trip.direction !== TRIP_DIRECTION.GOING) {
      return null;
    }

    // Only create returning trip if going trip is completed
    if (trip.status !== TRIP_STATUS.COMPLETED) {
      return null;
    }

    // Check if returning trip already exists
    const existingReturnTrips = await Trip.findReturningTripsForGoingTrip(tripid);
    if (existingReturnTrips && existingReturnTrips.length > 0) {
      logger.info(`[TripCompletionService] Returning trip already exists for going trip ${tripid}`);
      return existingReturnTrips[0];
    }

    // Get line information
    const line = await Line.findById(trip.lineid);
    if (!line) {
      logger.warn(`[TripCompletionService] Line ${trip.lineid} not found for trip ${tripid}`);
      return null;
    }

    // Calculate return trip departure time
    const returnDeptime = calculateReturnTripDeptime(trip, 15); // 15 minute buffer

    // Get vehicle info for default seats
    let defaultSeats = 5; // Default to 4+1
    if (trip.vehicleid) {
      const Vehicle = (await import('../models/Vehicle.js')).default;
      const vehicle = await Vehicle.findById(trip.vehicleid);
      if (vehicle) {
        defaultSeats = vehicle.seatnum;
      }
    }

    // Calculate opening time (45 minutes before departure)
    const openingTime = new Date(returnDeptime.getTime() - 45 * 60 * 1000);
    const maxPassengerSeats = calculateAvailablePassengerSeats(defaultSeats, 0, 0);

    // Create returning trip
    const returnTripData = {
      tripid: uuidv4(),
      lineid: trip.lineid,
      vehicleid: null, // Will be assigned from queue
      deptime: returnDeptime.toISOString(),
      status: TRIP_STATUS.SCHEDULED,
      availableseats: maxPassengerSeats,
      totalbookings: 0,
      trip_opening_time: openingTime.toISOString(),
      auto_departure_enabled: trip.auto_departure_enabled ?? true,
      early_departure_allowed: trip.early_departure_allowed ?? true,
      scheduled_departure_enforced: trip.scheduled_departure_enforced ?? true,
      direction: TRIP_DIRECTION.RETURN,
      origin_stationid: line.return_stationid || null,
      templateid: trip.templateid || null,
    };

    const returnTrip = await Trip.create(returnTripData);

    logger.info(`[TripCompletionService] ✅ Created returning trip ${returnTrip.tripid} for going trip ${tripid}`, {
      goingTrip: tripid,
      returnTrip: returnTrip.tripid,
      returnDeptime: returnDeptime.toISOString(),
      lineid: trip.lineid,
    });

    // Try to assign any existing future bookings for this return time
    try {
      const { distributeFutureBookings } = await import('./matchingService.js');
      const futureResult = await distributeFutureBookings(
        returnDeptime.toISOString(),
        trip.lineid,
        returnTrip.tripid
      );
      if (futureResult.distributed > 0) {
        logger.info(`[TripCompletionService] Assigned ${futureResult.distributed} future bookings to returning trip ${returnTrip.tripid}`);
      }
    } catch (error) {
      logger.warn(`[TripCompletionService] Error assigning future bookings to returning trip:`, error);
      // Don't fail trip creation if booking assignment fails
    }

    return returnTrip;
  } catch (error) {
    logger.error(`[TripCompletionService] Error creating returning trip for ${tripid}:`, error);
    return null;
  }
}

/**
 * Process trip completion and create returning trip if applicable
 * This should be called when a trip status changes to completed
 * @param {string} tripid - Trip ID
 * @returns {Promise<Object|null>} - Created returning trip or null
 */
export async function processTripCompletion(tripid) {
  return await checkAndCreateReturningTrip(tripid);
}


