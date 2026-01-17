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
 * IMPORTANT: Only assigns driver if trip has reservations (bookings) or future bookings matching the trip's deptime and lineid
 * @param {string} tripid - The trip ID
 * @param {string} lineid - The line ID
 * @returns {Promise<object|null>} - Assignment result or null if no driver available or no reservations/future bookings
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

    // ALSO check for future bookings that match this trip's deptime and lineid
    // This handles the case where future bookings exist but trip hasn't been created yet
    let futureBookingsCount = 0;
    if (currentTrip && currentTrip.deptime) {
      try {
        const futureBookings = await Reservation.findFutureBookingsForTrip(
          currentTrip.deptime,
          { lineid: lineid }
        );
        // Count unassigned future bookings (those without tripid or with matching tripid)
        futureBookingsCount = futureBookings.filter(b =>
          (!b.tripid || b.tripid === tripid) &&
          (b.status === 'confirmed' || b.status === 'checked_in')
        ).length;

        if (futureBookingsCount > 0) {
          logger.info(`[TripOpeningService] 📅 Found ${futureBookingsCount} future booking(s) for trip ${tripid} at ${currentTrip.deptime}`);
        }
      } catch (error) {
        logger.warn(`[TripOpeningService] ⚠️ Error checking future bookings:`, error);
      }
    }

    const totalBookings = activeReservations.length + futureBookingsCount;

    if (totalBookings === 0) {
      logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} has no reservations or future bookings - driver will not be assigned until bookings exist`);
      return null;
    }

    logger.info(`[TripOpeningService] ✅ Trip ${tripid} has ${activeReservations.length} reservation(s) and ${futureBookingsCount} future booking(s) - proceeding with driver assignment`);

    // Get trip direction to filter queue
    const tripDirection = currentTrip?.direction || 'going';
    
    // Map trip direction to queue direction
    const { mapTripDirectionToQueueDirection } = await import('../utils/tripDirectionUtils.js');
    const queueDirection = mapTripDirectionToQueueDirection(tripDirection);

    const queue = await DriverQueue.getActiveByLine(lineid, queueDirection);
    if (!queue || queue.length === 0) {
      logger.info(`[TripOpeningService] ⚠️ No drivers available in ${queueDirection} queue for line ${lineid}`);
      return null;
    }

    logger.info(`[TripOpeningService] 📋 Found ${queue.length} driver(s) in ${queueDirection} queue: ${queue.map((d, i) => `[${i + 1}] driver ${d.driverid}`).join(', ')}`);


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

    // Transfer payments for this trip to the driver
    try {
      const { transferPaymentsForTrip } = await import('./paymentService.js');
      const transferResult = await transferPaymentsForTrip(tripid, driverid);
      if (transferResult.success) {
        logger.info(`[TripOpeningService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${tripid}`);
      } else {
        logger.warn(`[TripOpeningService] ⚠️ Payment transfer failed for trip ${tripid}: ${transferResult.error}`);
      }
    } catch (paymentError) {
      logger.error(`[TripOpeningService] ❌ Error transferring payments for trip ${tripid}:`, paymentError);
      // Don't fail driver assignment if payment transfer fails
    }

    const updatedTrip = await Trip.findById(tripid);

    logger.info(`[TripOpeningService] ✅ Vehicle ${vehicle.vehicleid} and driver ${driverid} assigned to trip ${tripid}`);

    // Send notifications
    try {
      const { sendNotification, sendBulkNotifications, NOTIFICATION_TYPES } = await import('./notificationService.js');
      const Driver = (await import('../models/Driver.js')).default;
      const Line = (await import('../models/Line.js')).default;
      
      // Get driver and line info
      const driver = await Driver.findById(driverid);
      const line = await Line.findById(updatedTrip.lineid);
      const driverName = driver?.user?.fullname || 'Driver';
      const plateNumber = vehicle.plateno || 'N/A';
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');

      // Notify driver
      if (driver?.userid) {
        const tripDirection = updatedTrip.direction || 'going';
        const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, null, null, tripDirection);
        const { DateTime } = await import('luxon');
        const deptime = DateTime.fromISO(new Date(updatedTrip.deptime).toISOString())
          .setLocale(driverLanguage === 'en' ? 'en' : 'ar')
          .toLocaleString({ 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: driverLanguage === 'en'
          });

        await sendNotification(
          driver.userid,
          NOTIFICATION_TYPES.TRIP_ASSIGNED,
          {
            from: driverFromName,
            to: driverToName,
            time: deptime,
            tripid: tripid,
          },
          driverLanguage,
          { line, trip: updatedTrip } // Pass raw data for separate Arabic/English formatting
        );
      }

      // Notify all passengers on the trip (send individually to use per-user language)
      const reservations = await Reservation.findByTripId(tripid);
      const activeReservations = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      );

      if (activeReservations.length > 0) {
        for (const reservation of activeReservations) {
          const Passenger = (await import('../models/Passenger.js')).default;
          const passenger = await Passenger.findById(reservation.passengerid);
          if (passenger?.userid) {
            try {
              const tripDirection = updatedTrip.direction || 'going';
              const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, passenger.userid, null, null, tripDirection);
              const { DateTime } = await import('luxon');
              const deptime = DateTime.fromISO(new Date(updatedTrip.deptime).toISOString())
                .setLocale(passengerLanguage === 'en' ? 'en' : 'ar')
                .toLocaleString({ 
                  year: 'numeric', 
                  month: 'long', 
                  day: 'numeric', 
                  hour: '2-digit', 
                  minute: '2-digit',
                  hour12: passengerLanguage === 'en'
                });

              await sendNotification(
                passenger.userid,
                NOTIFICATION_TYPES.DRIVER_ASSIGNED,
                {
                  driverName,
                  plateNumber,
                  from: passengerFromName,
                  to: passengerToName,
                  time: deptime,
                },
                passengerLanguage,
                { line, trip: updatedTrip } // Pass raw data for separate Arabic/English formatting
              );
            } catch (notifError) {
              logger.warn(`[TripOpeningService] Failed to send notification to passenger ${passenger.userid}:`, notifError);
            }
          }
        }
      }
    } catch (notifError) {
      logger.warn(`[TripOpeningService] Failed to send notifications for trip ${tripid}:`, notifError);
    }

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

    // ALSO check for future bookings that match this trip's deptime and lineid
    // This handles the case where future bookings exist but haven't been assigned to trip yet
    let futureBookingsCount = 0;
    if (trip.deptime) {
      try {
        const futureBookings = await Reservation.findFutureBookingsForTrip(
          trip.deptime,
          { lineid: trip.lineid }
        );
        // Count unassigned future bookings (those without tripid or with matching tripid)
        futureBookingsCount = futureBookings.filter(b =>
          (!b.tripid || b.tripid === tripid) &&
          (b.status === 'confirmed' || b.status === 'checked_in')
        ).length;

        if (futureBookingsCount > 0) {
          logger.info(`[TripOpeningService] 📅 Found ${futureBookingsCount} future booking(s) for trip ${tripid} at ${trip.deptime}`);
        }
      } catch (error) {
        logger.warn(`[TripOpeningService] ⚠️ Error checking future bookings:`, error);
      }
    }

    const totalBookings = activeReservations.length + futureBookingsCount;

    let vehicleAssigned = false;
    if (!trip.vehicleid) {

      if (totalBookings === 0) {
        logger.info(`[TripOpeningService] ⚠️ Trip ${tripid} opened but has no reservations or future bookings - driver will not be assigned until bookings exist`);
        return {
          success: true,
          trip,
          vehicleAssigned: false,
          message: 'Trip opened but no reservations or future bookings - driver will be assigned when bookings are made',
        };
      }

      logger.info(`[TripOpeningService] 🔍 Trip ${tripid} has ${activeReservations.length} reservation(s) and ${futureBookingsCount} future booking(s) and no vehicle, attempting assignment from queue`);
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

    // Always try to distribute bookings, even if no vehicle yet
    // This ensures future bookings get assigned to the trip
    let distributionResult = null;
    try {
      logger.info(`[TripOpeningService] 📋 Distributing bookings for trip ${tripid}`);

      // First, assign any unassigned future bookings to this trip
      if (trip.deptime) {
        const { distributeFutureBookings } = await import('./matchingService.js');
        const futureResult = await distributeFutureBookings(trip.deptime, trip.lineid, tripid);
        if (futureResult.distributed > 0) {
          logger.info(`[TripOpeningService] ✅ Assigned ${futureResult.distributed} future booking(s) to trip ${tripid}`);
        }
      }

      // Then distribute all bookings if vehicle is assigned
      if (vehicleAssigned) {
        distributionResult = await distributeAllBookings(tripid);
      }
    } catch (distError) {
      logger.warn(`[TripOpeningService] ⚠️ Error distributing bookings:`, distError);
      // Don't fail trip opening if distribution fails
    }

    // Send trip opening notifications (already handled in openScheduledTrip, but ensure it's called)
    const updatedTrip = await Trip.findById(tripid);

    return {
      success: true,
      trip: updatedTrip || trip,
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
      let hasFutureBookings = false;
      try {
        const reservations = await Reservation.findByTripId(trip.tripid);
        hasReservations = reservations && reservations.length > 0;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} reservations check: found ${reservations?.length || 0} reservations, totalbookings: ${trip.totalbookings || 0}`);

        // Also check for future bookings matching this trip's deptime and lineid
        if (trip.deptime && trip.lineid) {
          try {
            const futureBookings = await Reservation.findFutureBookingsForTrip(
              trip.deptime,
              { lineid: trip.lineid }
            );
            hasFutureBookings = futureBookings && futureBookings.some(b =>
              (!b.tripid || b.tripid === trip.tripid) &&
              (b.status === 'confirmed' || b.status === 'checked_in')
            );
            if (hasFutureBookings) {
              logger.debug(`[TripOpeningService] Trip ${trip.tripid} has future bookings matching deptime ${trip.deptime}`);
            }
          } catch (fbError) {
            logger.warn(`[TripOpeningService] Error checking future bookings for trip ${trip.tripid}:`, fbError);
          }
        }
      } catch (error) {
        logger.error(`[TripOpeningService] Error checking reservations for trip ${trip.tripid}:`, error);
        continue;
      }

      const hasAnyBookings = hasReservations || hasFutureBookings;

      if (departureTimePassed && !hasAnyBookings) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) passed departure time but has no reservations or future bookings (totalbookings: ${trip.totalbookings || 0}), skipping assignment`);
        continue;
      }


      if (openingTimePassed && !departureTimePassed && !hasAnyBookings) {
        skippedCount.noReservations++;
        logger.info(`[TripOpeningService] ⚠️ Trip ${trip.tripid} (line: ${trip.lineid}) opening time passed but has no reservations or future bookings, skipping assignment - driver should wait in queue`);
        continue;
      }


      if (!openingTimePassed && !departureTimePassed) {
        skippedCount.timeNotPassed++;
        logger.debug(`[TripOpeningService] Trip ${trip.tripid} (line: ${trip.lineid}) time not passed yet - opening: ${openingTime ? openingTime.toISOString() : 'N/A'}, deptime: ${deptime.toISOString()}, now: ${now.toISOString()}`);
        continue;
      }




      if (hasAnyBookings && (openingTimePassed || departureTimePassed)) {
        waitingTrips.push(trip);
        logger.debug(`[TripOpeningService] ✅ Trip ${trip.tripid} (line: ${trip.lineid}) added to waiting list - openingTimePassed: ${openingTimePassed}, departureTimePassed: ${departureTimePassed}, hasReservations: ${hasReservations}, hasFutureBookings: ${hasFutureBookings}`);
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

