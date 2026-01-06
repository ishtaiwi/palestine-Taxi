import Trip from '../models/Trip.js';
import Vehicle from '../models/Vehicle.js';
import DriverQueue from '../models/DriverQueue.js';
import Reservation from '../models/Reservation.js';
import { distributeAllBookings } from './matchingService.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import logger from '../utils/logger.js';
import { getUtcNow, parseUtcDate } from '../utils/timeUtils.js';

/**
 * Assign a vehicle to a trip from the driver queue
 * @param {string} tripid - The trip ID
 * @param {string} lineid - The line ID
 * @returns {Promise<object|null>} - Assignment result or null if no driver available
 */
export const assignVehicleFromQueue = async (tripid, lineid) => {
  try {
    logger.info(`[TripOpeningService] 🔍 Attempting to assign vehicle from queue for trip ${tripid}`);

    // Get next driver from queue
    const queue = await DriverQueue.getActiveByLine(lineid);
    if (!queue || queue.length === 0) {
      logger.info(`[TripOpeningService] ⚠️ No drivers available in queue for line ${lineid}`);
      return null;
    }

    // Get the first driver in queue (FIFO)
    const driverQueueEntry = queue[0];
    const driverid = driverQueueEntry.driverid;

    // Get driver's vehicle (one-to-one relationship)
    const vehicles = await Vehicle.findByDriverId(driverid);
    if (!vehicles || vehicles.length === 0) {
      logger.warn(`[TripOpeningService] ⚠️ Driver ${driverid} has no vehicle assigned`);
      // Remove driver from queue since they don't have a vehicle
      await DriverQueue.removeDriverFromQueue(driverid);
      return null;
    }

    const vehicle = vehicles[0];

    // Update trip with vehicle and driver assignment
    const updatedTrip = await Trip.update(tripid, {
      vehicleid: vehicle.vehicleid,
      availableseats: calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0),
    });

    // Assign driver to trip
    await Trip.assignDriver(tripid, driverid);

    // Remove driver from queue after successful assignment
    await DriverQueue.removeDriverFromQueue(driverid);

    logger.info(`[TripOpeningService] ✅ Vehicle ${vehicle.vehicleid} and driver ${driverid} assigned to trip ${tripid}`);

    return {
      success: true,
      vehicle,
      driverid,
      trip: updatedTrip,
    };
  } catch (error) {
    logger.error(`[TripOpeningService] ❌ Error assigning vehicle from queue for trip ${tripid}:`, error);
    throw error;
  }
};

/**
 * Open a scheduled trip (make it available for bookings)
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - Opening result
 */
export const openScheduledTrip = async (tripid) => {
  try {
    logger.info(`[TripOpeningService] 🚀 Opening trip ${tripid}`);

    // Get trip details
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }

    // Allow opening trips in 'scheduled' or 'delayed' status
    if (trip.status !== 'scheduled' && trip.status !== 'delayed') {
      logger.warn(`[TripOpeningService] ⚠️ Trip ${tripid} is not in scheduled/delayed status: ${trip.status}`);
      return {
        success: false,
        message: 'Trip is not in scheduled/delayed status',
      };
    }

    // Update trip_opening_time and status to 'open' if not already set
    if (!trip.trip_opening_time) {
      const openingTime = getUtcNow().toISOString();
      await Trip.update(tripid, {
        trip_opening_time: openingTime,
        status: 'open',
      });
      logger.info(`[TripOpeningService] ✅ Set trip_opening_time and status='open' for trip ${tripid}`);
    } else if (trip.status === 'scheduled') {
      // Trip already has opening time but status not updated yet
      await Trip.update(tripid, { status: 'open' });
      logger.info(`[TripOpeningService] ✅ Updated status to 'open' for trip ${tripid}`);
    }

    // Check if trip has vehicle assigned
    let vehicleAssigned = false;
    if (!trip.vehicleid) {
      logger.info(`[TripOpeningService] 🔍 Trip ${tripid} has no vehicle, attempting assignment from queue`);
      const assignmentResult = await assignVehicleFromQueue(tripid, trip.lineid);

      if (assignmentResult) {
        vehicleAssigned = true;
        // Update trip status to open if it was delayed
        if (trip.status === 'delayed') {
          await Trip.update(tripid, { status: 'open' });
          logger.info(`[TripOpeningService] ✅ Trip ${tripid} status changed from delayed to open`);
        }
        // Refresh trip data after assignment
        const updatedTrip = await Trip.findById(tripid);
        trip.vehicleid = updatedTrip.vehicleid;
        trip.availableseats = updatedTrip.availableseats;
      } else {
        logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} opened but no vehicle assigned - waiting for driver`);
        // Trip opened but no vehicle available - will be assigned when driver joins queue
        return {
          success: true,
          trip,
          vehicleAssigned: false,
          message: 'Trip opened but no driver available in queue',
        };
      }
    } else {
      vehicleAssigned = true;
    }

    // Only distribute bookings if vehicle is assigned
    let distributionResult = null;
    if (vehicleAssigned) {
      logger.info(`[TripOpeningService] 📋 Distributing bookings for trip ${tripid}`);
      distributionResult = await distributeAllBookings(tripid);
    }

    return {
      success: true,
      trip,
      vehicleAssigned,
      distribution: distributionResult,
    };
  } catch (error) {
    logger.error(`[TripOpeningService] ❌ Error opening trip ${tripid}:`, error);
    throw error;
  }
};

/**
 * Find trips waiting for vehicle assignment
 * @param {string} lineid - The line ID (optional, if not provided checks all lines)
 * @returns {Promise<Array>} - Array of waiting trips
 */
export const findWaitingTrips = async (lineid = null) => {
  try {
    const now = getUtcNow();
    logger.info(`[TripOpeningService] 🔍 Finding waiting trips${lineid ? ` for line ${lineid}` : ' (all lines)'}`);

    // Get all scheduled, open, and delayed trips (filtered by lineid if provided)
    // We need to check all these statuses since they may need vehicles
    let allTrips = [];
    if (lineid) {
      const scheduledTrips = await Trip.findAll({ status: 'scheduled', lineid });
      const openTrips = await Trip.findAll({ status: 'open', lineid });
      const delayedTrips = await Trip.findAll({ status: 'delayed', lineid });
      allTrips = [...scheduledTrips, ...openTrips, ...delayedTrips];
      logger.info(`[TripOpeningService] Found ${allTrips.length} trips (scheduled: ${scheduledTrips.length}, open: ${openTrips.length}, delayed: ${delayedTrips.length}) for line ${lineid}`);
    } else {
      const scheduledTrips = await Trip.findAll({ status: 'scheduled' });
      const openTrips = await Trip.findAll({ status: 'open' });
      const delayedTrips = await Trip.findAll({ status: 'delayed' });
      allTrips = [...scheduledTrips, ...openTrips, ...delayedTrips];
      logger.info(`[TripOpeningService] Found ${allTrips.length} trips (scheduled: ${scheduledTrips.length}, open: ${openTrips.length}, delayed: ${delayedTrips.length}) for all lines`);
    }

    // Filter trips that need vehicle assignment:
    // 1. No vehicle assigned (!trip.vehicleid)
    // 2. Trip opening time has passed (if set) OR departure time has passed
    // 3. If departure time has passed, trip must have reservations
    // 4. Trip is in a status that allows assignment (scheduled, open, delayed)
    const waitingTrips = [];
    let skippedCount = { hasVehicle: 0, noDeptime: 0, timeNotPassed: 0, noReservations: 0 };

    for (const trip of allTrips) {
      if (trip.vehicleid) {
        skippedCount.hasVehicle++;
        continue; // Already has vehicle
      }

      const openingTime = trip.trip_opening_time ? parseUtcDate(trip.trip_opening_time) : null;
      const deptime = trip.deptime ? parseUtcDate(trip.deptime) : null;

      if (!deptime) {
        skippedCount.noDeptime++;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} has no deptime, skipping`);
        continue; // Must have departure time
      }

      const openingTimePassed = openingTime ? openingTime.getTime() <= now.getTime() : false;
      const departureTimePassed = deptime.getTime() <= now.getTime();

      // Check for reservations - trips without reservations should not be assigned vehicles
      // Drivers should stay in queue waiting for trips with actual bookings
      let hasReservations = false;
      try {
        const reservations = await Reservation.findByTripId(trip.tripid);
        hasReservations = reservations && reservations.length > 0;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} reservations check: found ${reservations?.length || 0} reservations, totalbookings: ${trip.totalbookings || 0}`);
      } catch (error) {
        logger.error(`[TripOpeningService] Error checking reservations for trip ${trip.tripid}:`, error);
        continue; // Skip on error
      }

      // If departure time has passed, ONLY include if trip has reservations
      if (departureTimePassed && !hasReservations) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) passed departure time but has no reservations (totalbookings: ${trip.totalbookings || 0}), skipping assignment`);
        continue; // Skip trips without reservations that have passed departure
      }

      // If opening time passed but departure hasn't, ONLY include if trip has reservations
      if (openingTimePassed && !departureTimePassed && !hasReservations) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) opening time passed but has no reservations, skipping assignment - driver should wait in queue`);
        continue; // Skip trips without reservations even if opening time passed
      }

      // Check if time conditions are met
      if (!openingTimePassed && !departureTimePassed) {
        skippedCount.timeNotPassed++;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} (line: ${trip.lineid}) time not passed yet - opening: ${openingTime ? openingTime.toISOString() : 'N/A'}, deptime: ${deptime.toISOString()}, now: ${now.toISOString()}`);
        continue;
      }

      // Include if:
      // 1. Opening time passed AND has reservations, OR
      // 2. Departure time passed AND has reservations
      if (hasReservations && (openingTimePassed || departureTimePassed)) {
        waitingTrips.push(trip);
        logger.debug(`[TripOpeningService] ✅ Trip ${trip.tripid} (line: ${trip.lineid}) added to waiting list - openingTimePassed: ${openingTimePassed}, departureTimePassed: ${departureTimePassed}, hasReservations: ${hasReservations}`);
      }
    }

    logger.info(`[TripOpeningService] Filtered ${allTrips.length} trips: ${waitingTrips.length} waiting, ${skippedCount.hasVehicle} have vehicles, ${skippedCount.noDeptime} no deptime, ${skippedCount.timeNotPassed} time not passed, ${skippedCount.noReservations} no reservations`);

    // Sort by deptime (earliest first)
    waitingTrips.sort((a, b) => {
      const aDeptime = parseUtcDate(a.deptime);
      const bDeptime = parseUtcDate(b.deptime);
      if (!aDeptime || !bDeptime) return 0;
      return aDeptime.getTime() - bDeptime.getTime();
    });

    return waitingTrips;
  } catch (error) {
    logger.error('[TripOpeningService] Error finding waiting trips:', error);
    throw error;
  }
};

/**
 * Check and assign waiting trips when a driver joins the queue
 * @param {string} lineid - The line ID
 * @returns {Promise<object>} - Assignment results
 */
export const checkAndAssignWaitingTrips = async (lineid) => {
  try {
    logger.info(`[TripOpeningService] 🔍 Checking for waiting trips on line ${lineid}`);

    // Find waiting trips for this line
    const waitingTrips = await findWaitingTrips(lineid);

    if (waitingTrips.length === 0) {
      logger.info(`[TripOpeningService] ✅ No waiting trips found for line ${lineid}`);
      return {
        success: true,
        assigned: 0,
        trips: [],
      };
    }

    logger.info(`[TripOpeningService] 📅 Found ${waitingTrips.length} waiting trips for line ${lineid}`);

    const results = [];
    let assignedCount = 0;

    // Try to assign vehicles to waiting trips (in order of departure time)
    for (const trip of waitingTrips) {
      try {
        const assignmentResult = await assignVehicleFromQueue(trip.tripid, lineid);

        if (assignmentResult) {
          assignedCount++;
          // Update trip status to open if it was delayed
          if (trip.status === 'delayed') {
            await Trip.update(trip.tripid, { status: 'open' });
          }

          // Distribute bookings for this trip now that vehicle is assigned
          try {
            await distributeAllBookings(trip.tripid);
          } catch (distError) {
            logger.warn(`[TripOpeningService] ⚠️ Error distributing bookings for trip ${trip.tripid}:`, distError);
          }

          results.push({
            tripid: trip.tripid,
            success: true,
            vehicleAssigned: true,
          });

          logger.info(`[TripOpeningService] ✅ Waiting trip ${trip.tripid} assigned vehicle`);
        } else {
          // No driver available for this trip
          results.push({
            tripid: trip.tripid,
            success: false,
            vehicleAssigned: false,
            message: 'No driver available',
          });
        }
      } catch (error) {
        logger.error(`[TripOpeningService] ❌ Error assigning vehicle to waiting trip ${trip.tripid}:`, error);
        results.push({
          tripid: trip.tripid,
          success: false,
          error: error.message,
        });
      }
    }

    return {
      success: true,
      assigned: assignedCount,
      total: waitingTrips.length,
      trips: results,
    };
  } catch (error) {
    logger.error(`[TripOpeningService] ❌ Error checking and assigning waiting trips for line ${lineid}:`, error);
    throw error;
  }
};

/**
 * Mark trips as delayed if:
 * 1. They have no vehicle 1 minute before scheduled departure, OR
 * 2. They have reservations, departure time has passed, and haven't departed yet
 * @returns {Promise<object>} - Results of delayed marking
 */
export const markTripsAsDelayed = async () => {
  try {
    const now = getUtcNow();
    const oneMinuteBefore = new Date(now.getTime() + 60 * 1000); // 1 minute from now

    // Find trips that need to be marked as delayed
    // Status is scheduled, open, or delayed (to re-check), and haven't departed
    const scheduledTrips = await Trip.findAll({ status: 'scheduled' });
    const openTrips = await Trip.findAll({ status: 'open' });
    const delayedTrips = await Trip.findAll({ status: 'delayed' });
    const allTrips = [...scheduledTrips, ...openTrips, ...delayedTrips];

    const tripsToDelay = [];

    for (const trip of allTrips) {
      // Skip trips that are already in_progress or completed
      if (trip.status === 'in_progress' || trip.status === 'completed' || trip.status === 'cancelled') {
        continue;
      }

      const deptime = parseUtcDate(trip.deptime);
      if (!deptime) continue;

      const departureTimePassed = deptime.getTime() <= now.getTime();
      const oneMinuteBeforeDeparture = deptime.getTime() >= now.getTime() && deptime.getTime() <= oneMinuteBefore.getTime();

      // Case 1: No vehicle and 1 minute before departure
      if (!trip.vehicleid && oneMinuteBeforeDeparture) {
        tripsToDelay.push(trip);
        continue;
      }

      // Case 2: Has reservations, departure time passed, and hasn't departed
      if (departureTimePassed) {
        try {
          // Check both totalbookings (quick check) and actual reservations (more accurate)
          const hasBookings = (trip.totalbookings && trip.totalbookings > 0) || false;

          let hasReservations = false;
          if (hasBookings) {
            // If totalbookings > 0, verify with actual reservation query
            const reservations = await Reservation.findByTripId(trip.tripid);
            hasReservations = reservations && reservations.length > 0;
          }

          // Mark as delayed if has reservations (checked via query) OR has bookings count
          if ((hasReservations || hasBookings) && trip.status !== 'delayed') {
            tripsToDelay.push(trip);
            logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (status: ${trip.status}, totalbookings: ${trip.totalbookings || 0}) has reservations and departure time passed, marking as delayed`);
          }
        } catch (error) {
          logger.error(`[TripOpeningService] Error checking reservations for trip ${trip.tripid}:`, error);
        }
      }
    }

    if (tripsToDelay.length === 0) {
      return {
        success: true,
        marked: 0,
        trips: [],
      };
    }

    logger.info(`[TripOpeningService] ⚠️ Marking ${tripsToDelay.length} trips as delayed`);

    const results = [];
    for (const trip of tripsToDelay) {
      try {
        await Trip.update(trip.tripid, { status: 'delayed' });
        results.push({
          tripid: trip.tripid,
          success: true,
        });
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} marked as delayed`);
      } catch (error) {
        logger.error(`[TripOpeningService] ❌ Error marking trip ${trip.tripid} as delayed:`, error);
        results.push({
          tripid: trip.tripid,
          success: false,
          error: error.message,
        });
      }
    }

    return {
      success: true,
      marked: results.filter(r => r.success).length,
      total: tripsToDelay.length,
      trips: results,
    };
  } catch (error) {
    logger.error('[TripOpeningService] ❌ Error marking trips as delayed:', error);
    throw error;
  }
};

/**
 * Open all scheduled trips that need to be opened (45 minutes before departure)
 * @param {number} openingWindowMinutes - Minutes before departure to open trip (default: 45)
 * @returns {Promise<object>} - Opening results
 */
export const openScheduledTrips = async (openingWindowMinutes = 45) => {
  try {
    logger.info(`[TripOpeningService] 🔍 Finding trips that need to be opened (${openingWindowMinutes} minutes before departure)`);

    // Find trips that need opening
    const tripsToOpen = await Trip.findTripsNeedingOpening(openingWindowMinutes);

    if (tripsToOpen.length === 0) {
      logger.info(`[TripOpeningService] ✅ No trips need to be opened at this time`);
      return {
        success: true,
        opened: 0,
        trips: [],
      };
    }

    logger.info(`[TripOpeningService] 📅 Found ${tripsToOpen.length} trips to open`);

    const results = [];

    // Open each trip
    for (const trip of tripsToOpen) {
      try {
        const result = await openScheduledTrip(trip.tripid);
        results.push({
          tripid: trip.tripid,
          success: result.success,
          vehicleAssigned: result.vehicleAssigned || false,
          distribution: result.distribution,
        });
      } catch (error) {
        logger.error(`[TripOpeningService] ❌ Error opening trip ${trip.tripid}:`, error);
        results.push({
          tripid: trip.tripid,
          success: false,
          error: error.message,
        });
      }
    }

    // Also check for trips that need to be marked as delayed
    try {
      const delayResult = await markTripsAsDelayed();
      if (delayResult.marked > 0) {
        logger.info(`[TripOpeningService] ⚠️ Marked ${delayResult.marked} trips as delayed`);
      }
    } catch (error) {
      logger.error('[TripOpeningService] ⚠️ Error checking delayed trips:', error);
    }

    const successCount = results.filter(r => r.success).length;

    return {
      success: true,
      opened: successCount,
      total: tripsToOpen.length,
      trips: results,
    };
  } catch (error) {
    logger.error('[TripOpeningService] ❌ Error opening scheduled trips:', error);
    throw error;
  }
};

