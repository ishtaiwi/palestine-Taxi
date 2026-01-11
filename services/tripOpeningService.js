import Trip from '../models/Trip.js';
import Vehicle from '../models/Vehicle.js';
import DriverQueue from '../models/DriverQueue.js';
import Reservation from '../models/Reservation.js';
import { distributeAllBookings, syncTripStats } from './matchingService.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import logger from '../utils/logger.js';
import { getUtcNow, parseUtcDate } from '../utils/timeUtils.js';

/**
 * Assign a vehicle to a trip from the driver queue
 * IMPORTANT: Only assigns driver if trip has reservations (bookings)
 * @param {string} tripid - The trip ID
 * @param {string} lineid - The line ID
 * @returns {Promise<object|null>} - Assignment result or null if no driver available or no reservations
 */
export const assignVehicleFromQueue = async (tripid, lineid) => {
  try {
    logger.info(`[TripOpeningService] 🔍 Attempting to assign vehicle from queue for trip ${tripid}`);

    
    const currentTrip = await Trip.findById(tripid);
    if (currentTrip && currentTrip.assigned_driverid && currentTrip.vehicleid) {
      logger.info(`[TripOpeningService] ✅ Trip ${tripid} already has driver ${currentTrip.assigned_driverid} assigned`);
      return {
        success: true,
        vehicle: { vehicleid: currentTrip.vehicleid },
        driverid: currentTrip.assigned_driverid,
        trip: currentTrip,
        alreadyAssigned: true,
      };
    }

    
    const reservations = await Reservation.findByTripId(tripid);
    const activeReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );
    
    if (activeReservations.length === 0) {
      logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} has no reservations - driver will not be assigned until bookings exist`);
      return null;
    }

    logger.info(`[TripOpeningService] ✅ Trip ${tripid} has ${activeReservations.length} reservation(s) - proceeding with driver assignment`);

    
    const queue = await DriverQueue.getActiveByLine(lineid);
    if (!queue || queue.length === 0) {
      logger.info(`[TripOpeningService] ⚠️ No drivers available in queue for line ${lineid}`);
      return null;
    }

    logger.info(`[TripOpeningService] 📋 Found ${queue.length} driver(s) in queue: ${queue.map((d, i) => `[${i+1}] driver ${d.driverid}`).join(', ')}`);

    
    const tripDeptime = parseUtcDate(currentTrip.deptime);
    
    
    let selectedDriver = null;
    let selectedVehicle = null;

    for (const driverQueueEntry of queue) {
      const driverid = driverQueueEntry.driverid;

      
      const driverTrips = await Trip.findAssignedTrips(driverid, { fromNow: false });
      const hasTripAtSameTime = driverTrips.some(t => {
        
        if (t.status === 'completed' || t.status === 'cancelled') return false;
        
        
        if (tripDeptime && t.deptime) {
          const tDeptime = parseUtcDate(t.deptime);
          if (tDeptime) {
            const timeDiff = Math.abs(tDeptime.getTime() - tripDeptime.getTime());
            return timeDiff <= 60000; 
          }
        }
        return false;
      });

      if (hasTripAtSameTime) {
        logger.info(`[TripOpeningService] ⚠️ Driver ${driverid} already assigned to a trip at this time, skipping`);
        
        continue;
      }

      
      const vehicles = await Vehicle.findByDriverId(driverid);
      if (!vehicles || vehicles.length === 0) {
        logger.warn(`[TripOpeningService] ⚠️ Driver ${driverid} has no vehicle assigned - removing from queue`);
        
        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }

      
      selectedDriver = driverQueueEntry;
      selectedVehicle = vehicles[0];
      logger.info(`[TripOpeningService] ✅ Selected driver ${driverid} from queue (position ${queue.indexOf(driverQueueEntry) + 1})`);
      break; 
    }

    if (!selectedDriver || !selectedVehicle) {
      logger.info(`[TripOpeningService] ⚠️ No available driver found in queue for line ${lineid}`);
      return null;
    }

    const driverid = selectedDriver.driverid;
    const vehicle = selectedVehicle;

    
    await Trip.update(tripid, {
      vehicleid: vehicle.vehicleid,
    });

    
    await Trip.assignDriver(tripid, driverid);

    
    await syncTripStats(tripid);

    
    await DriverQueue.removeDriverFromQueue(driverid);

    // Record earnings for all existing reservations now that driver is assigned
    try {
      const { checkAndRecordReservationEarnings } = await import('./driverEarningsService.js');
      const allReservations = await Reservation.findByTripId(tripid);
      const activeReservations = allReservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      );
      
      logger.info(`[TripOpeningService] 📝 Recording earnings for ${activeReservations.length} existing reservation(s) on trip ${tripid}`);
      
      for (const reservation of activeReservations) {
        try {
          await checkAndRecordReservationEarnings(reservation.bookingid, tripid);
        } catch (earningsError) {
          logger.warn(`[TripOpeningService] ⚠️ Error recording earnings for reservation ${reservation.bookingid}:`, earningsError);
          // Continue with other reservations even if one fails
        }
      }
      
      logger.info(`[TripOpeningService] ✅ Earnings recording completed for trip ${tripid}`);
    } catch (earningsError) {
      logger.error(`[TripOpeningService] ⚠️ Error recording earnings for trip ${tripid}:`, earningsError);
      // Don't fail driver assignment if earnings recording fails
    }

    
    const updatedTrip = await Trip.findById(tripid);

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

    
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }

    
    if (trip.status !== 'scheduled' && trip.status !== 'delayed') {
      logger.warn(`[TripOpeningService] ⚠️ Trip ${tripid} is not in scheduled/delayed status: ${trip.status}`);
      return {
        success: false,
        message: 'Trip is not in scheduled/delayed status',
      };
    }

    
    if (!trip.trip_opening_time) {
      const openingTime = getUtcNow().toISOString();
      await Trip.update(tripid, {
        trip_opening_time: openingTime,
        status: 'open',
      });
      logger.info(`[TripOpeningService] ✅ Set trip_opening_time and status='open' for trip ${tripid}`);
    } else if (trip.status === 'scheduled') {
      
      await Trip.update(tripid, { status: 'open' });
      logger.info(`[TripOpeningService] ✅ Updated status to 'open' for trip ${tripid}`);
    }

    
    const reservations = await Reservation.findByTripId(tripid);
    const activeReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );

    
    let vehicleAssigned = false;
    if (!trip.vehicleid) {
      
      if (activeReservations.length === 0) {
        logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} opened but has no reservations - driver will not be assigned until bookings exist`);
        return {
          success: true,
          trip,
          vehicleAssigned: false,
          message: 'Trip opened but no reservations - driver will be assigned when bookings are made',
        };
      }

      logger.info(`[TripOpeningService] 🔍 Trip ${tripid} has ${activeReservations.length} reservation(s) and no vehicle, attempting assignment from queue`);
      const assignmentResult = await assignVehicleFromQueue(tripid, trip.lineid);

      if (assignmentResult) {
        vehicleAssigned = true;
        
        if (trip.status === 'delayed') {
          await Trip.update(tripid, { status: 'open' });
          logger.info(`[TripOpeningService] ✅ Trip ${tripid} status changed from delayed to open`);
        }
        
        const updatedTrip = await Trip.findById(tripid);
        trip.vehicleid = updatedTrip.vehicleid;
        trip.availableseats = updatedTrip.availableseats;
      } else {
        logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} opened but no vehicle assigned - waiting for driver`);
        
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

    
    
    
    
    
    const waitingTrips = [];
    let skippedCount = { hasVehicle: 0, noDeptime: 0, timeNotPassed: 0, noReservations: 0 };

    for (const trip of allTrips) {
      if (trip.vehicleid) {
        skippedCount.hasVehicle++;
        continue; 
      }

      const openingTime = trip.trip_opening_time ? parseUtcDate(trip.trip_opening_time) : null;
      const deptime = trip.deptime ? parseUtcDate(trip.deptime) : null;

      if (!deptime) {
        skippedCount.noDeptime++;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} has no deptime, skipping`);
        continue; 
      }

      const openingTimePassed = openingTime ? openingTime.getTime() <= now.getTime() : false;
      const departureTimePassed = deptime.getTime() <= now.getTime();

      
      
      let hasReservations = false;
      try {
        const reservations = await Reservation.findByTripId(trip.tripid);
        hasReservations = reservations && reservations.length > 0;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} reservations check: found ${reservations?.length || 0} reservations, totalbookings: ${trip.totalbookings || 0}`);
      } catch (error) {
        logger.error(`[TripOpeningService] Error checking reservations for trip ${trip.tripid}:`, error);
        continue; 
      }

      
      if (departureTimePassed && !hasReservations) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) passed departure time but has no reservations (totalbookings: ${trip.totalbookings || 0}), skipping assignment`);
        continue; 
      }

      
      if (openingTimePassed && !departureTimePassed && !hasReservations) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) opening time passed but has no reservations, skipping assignment - driver should wait in queue`);
        continue; 
      }

      
      if (!openingTimePassed && !departureTimePassed) {
        skippedCount.timeNotPassed++;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} (line: ${trip.lineid}) time not passed yet - opening: ${openingTime ? openingTime.toISOString() : 'N/A'}, deptime: ${deptime.toISOString()}, now: ${now.toISOString()}`);
        continue;
      }

      
      
      
      if (hasReservations && (openingTimePassed || departureTimePassed)) {
        waitingTrips.push(trip);
        logger.debug(`[TripOpeningService] ✅ Trip ${trip.tripid} (line: ${trip.lineid}) added to waiting list - openingTimePassed: ${openingTimePassed}, departureTimePassed: ${departureTimePassed}, hasReservations: ${hasReservations}`);
      }
    }

    logger.info(`[TripOpeningService] Filtered ${allTrips.length} trips: ${waitingTrips.length} waiting, ${skippedCount.hasVehicle} have vehicles, ${skippedCount.noDeptime} no deptime, ${skippedCount.timeNotPassed} time not passed, ${skippedCount.noReservations} no reservations`);

    
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

    
    for (const trip of waitingTrips) {
      try {
        const assignmentResult = await assignVehicleFromQueue(trip.tripid, lineid);

        if (assignmentResult) {
          assignedCount++;
          
          if (trip.status === 'delayed') {
            await Trip.update(trip.tripid, { status: 'open' });
          }

          
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
    const oneMinuteBefore = new Date(now.getTime() + 60 * 1000); 

    
    
    const scheduledTrips = await Trip.findAll({ status: 'scheduled' });
    const openTrips = await Trip.findAll({ status: 'open' });
    const delayedTrips = await Trip.findAll({ status: 'delayed' });
    const allTrips = [...scheduledTrips, ...openTrips, ...delayedTrips];

    const tripsToDelay = [];

    for (const trip of allTrips) {
      
      if (trip.status === 'in_progress' || trip.status === 'completed' || trip.status === 'cancelled') {
        continue;
      }

      const deptime = parseUtcDate(trip.deptime);
      if (!deptime) continue;

      const departureTimePassed = deptime.getTime() <= now.getTime();
      const oneMinuteBeforeDeparture = deptime.getTime() >= now.getTime() && deptime.getTime() <= oneMinuteBefore.getTime();

      
      if (!trip.vehicleid && oneMinuteBeforeDeparture) {
        tripsToDelay.push(trip);
        continue;
      }

      
      if (departureTimePassed) {
        try {
          
          const hasBookings = (trip.totalbookings && trip.totalbookings > 0) || false;

          let hasReservations = false;
          if (hasBookings) {
            
            const reservations = await Reservation.findByTripId(trip.tripid);
            hasReservations = reservations && reservations.length > 0;
          }

          
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
 * Open all scheduled trips that need to be opened
 * Opening time is based on trip interval: 30 min intervals = 20 min before, 60 min intervals = 45 min before
 * @param {number} openingWindowMinutes - Maximum minutes before departure for initial filter (default: 45)
 * @returns {Promise<object>} - Opening results
 */
export const openScheduledTrips = async (openingWindowMinutes = 45) => {
  try {
    logger.info(`[TripOpeningService] 🔍 Finding trips that need to be opened (using ${openingWindowMinutes} min window for initial filter)`);

    
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

