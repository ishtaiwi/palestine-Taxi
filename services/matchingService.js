import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import Driver from '../models/Driver.js';
import { BOOKING_TYPE } from '../utils/constants.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import { parseUtcDate } from '../utils/timeUtils.js';
import logger from '../utils/logger.js';
import { assignVehicleFromQueue } from './tripOpeningService.js';

/**
 * Get the next driver from the queue for a specific line and direction
 * @param {string} lineid - The line ID
 * @param {string} direction - The direction ('going' or 'returning')
 * @returns {Promise<object|null>} - The next driver in queue or null
 */
export const getNextDriverFromQueue = async (lineid, direction = null) => {
  try {
    const queue = await DriverQueue.getActiveByLine(lineid, direction);
    if (!queue || queue.length === 0) {
      return null;
    }

    return queue[0];
  } catch (error) {
    logger.error('[MatchingService] Error getting next driver from queue:', error);
    throw error;
  }
};

/**
 * Find all trips at the same deptime for a line (trip group)
 * @param {string} deptime - The departure time
 * @param {string} lineid - The line ID
 * @returns {Promise<Array>} - Array of trips at the same deptime
 */
export const findTripsAtSameTime = async (deptime, lineid) => {
  try {

    const deptimeDate = parseUtcDate(deptime);
    if (!deptimeDate) return [];

    const timeWindowStart = new Date(deptimeDate.getTime() - 60 * 1000);
    const timeWindowEnd = new Date(deptimeDate.getTime() + 60 * 1000);

    const allTrips = await Trip.findAll({ lineid });
    const tripsAtSameTime = allTrips.filter(trip => {
      if (!trip.deptime) return false;
      const tripDeptime = parseUtcDate(trip.deptime);
      if (!tripDeptime) return false;
      return tripDeptime >= timeWindowStart && tripDeptime <= timeWindowEnd;
    });

    return tripsAtSameTime;
  } catch (error) {
    logger.error('[MatchingService] Error finding trips at same time:', error);
    return [];
  }
};

/**
 * Check if a trip needs additional drivers and assign them from queue
 * This handles multi-driver assignment when bookings exceed the first driver's capacity
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - Result with assigned drivers count
 */
export const checkAndAssignAdditionalDrivers = async (tripid) => {
  try {
    const trip = await Trip.findById(tripid);
    if (!trip || !trip.deptime || !trip.lineid) {
      return { success: false, assigned: 0, message: 'Trip not found or invalid' };
    }


    const tripsAtSameTime = await findTripsAtSameTime(trip.deptime, trip.lineid);


    let totalAvailableSeats = 0;
    const assignedTrips = [];
    for (const t of tripsAtSameTime) {
      if (t.vehicleid && t.assigned_driverid) {
        assignedTrips.push(t);
        const vehicle = await Vehicle.findById(t.vehicleid);
        if (vehicle) {
          const availableSeats = await getAvailableSeats(vehicle, t.tripid);
          totalAvailableSeats += availableSeats;
        }
      }
    }


    let totalBookings = 0;
    let bookingsOnFullTrips = 0;
    for (const t of tripsAtSameTime) {
      if (t.tripid) {
        const reservations = await Reservation.findByTripId(t.tripid);
        const activeReservations = reservations.filter(
          r => r.status === 'confirmed' || r.status === 'checked_in'
        );
        totalBookings += activeReservations.length;


        if (t.vehicleid && t.assigned_driverid) {
          const vehicle = await Vehicle.findById(t.vehicleid);
          if (vehicle) {
            const maxPassengerSeats = vehicle.seatnum - 1;
            if (activeReservations.length > maxPassengerSeats) {

              bookingsOnFullTrips += (activeReservations.length - maxPassengerSeats);
            }
          }
        }
      }
    }


    const futureBookings = await Reservation.findFutureBookingsForTrip(trip.deptime, { lineid: trip.lineid });
    const unassignedFutureBookings = futureBookings.filter(b => !b.tripid);
    totalBookings += unassignedFutureBookings.length;


    if (totalBookings === 0) {
      logger.info(`[MatchingService] Trip ${tripid} has no bookings - no need for additional drivers`);
      return { success: true, assigned: 0, message: 'No bookings - no additional drivers needed' };
    }


    if (totalAvailableSeats >= totalBookings) {
      logger.info(`[MatchingService] Trip ${tripid} has enough capacity (${totalAvailableSeats} seats >= ${totalBookings} bookings) - no need for additional drivers`);
      return { success: true, assigned: 0, message: 'Enough capacity available' };
    }


    const additionalSeatsNeeded = totalBookings - totalAvailableSeats;
    logger.info(`[MatchingService] 🔍 Trip ${tripid} needs additional capacity: ${additionalSeatsNeeded} seats (total bookings: ${totalBookings}, available: ${totalAvailableSeats})`);


    const unassignedTrips = tripsAtSameTime.filter(t => (!t.assigned_driverid || !t.vehicleid) && t.status !== 'completed' && t.status !== 'cancelled');
    let assignedCount = 0;


    for (const unassignedTrip of unassignedTrips) {
      if (assignedCount >= Math.ceil(additionalSeatsNeeded / 4)) break;


      const reservations = await Reservation.findByTripId(unassignedTrip.tripid);
      const activeReservations = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      );

      if (activeReservations.length === 0) {
        logger.info(`[MatchingService] ⚠️ Trip ${unassignedTrip.tripid} has no reservations - skipping driver assignment`);
        continue;
      }

      const assignmentResult = await assignVehicleFromQueue(unassignedTrip.tripid, trip.lineid);
      if (assignmentResult && assignmentResult.success) {
        assignedCount++;
        logger.info(`[MatchingService] ✅ Assigned additional driver ${assignmentResult.driverid} to existing trip ${unassignedTrip.tripid} (has ${activeReservations.length} reservation(s))`);
      }
    }




    const remainingSeatsNeeded = additionalSeatsNeeded - (assignedCount * 4);
    if (remainingSeatsNeeded > 0) {


      const unassignedBookingsCount = unassignedFutureBookings.length;


      const allInstantBookings = await Reservation.findByBookingType(BOOKING_TYPE.INSTANT, {
        status: 'confirmed',
      });
      const unassignedInstantBookings = allInstantBookings.filter(b => {
        if (b.tripid) return false;
        if (!b.scheduled_trip_time) return false;
        const bookingTime = parseUtcDate(b.scheduled_trip_time);
        const tripTime = parseUtcDate(trip.deptime);
        if (!bookingTime || !tripTime) return false;
        const timeDiff = Math.abs(bookingTime.getTime() - tripTime.getTime());
        return timeDiff <= 60000;
      });

      const totalUnassignedBookings = unassignedBookingsCount + unassignedInstantBookings.length;






      if (totalUnassignedBookings === 0 && bookingsOnFullTrips === 0) {
        logger.info(`[MatchingService] ⚠️ No unassigned bookings and no bookings exceeding capacity - will not create new trips unnecessarily`);
        return {
          success: true,
          assigned: assignedCount,
          message: 'No bookings needing reassignment - no need to create additional trips'
        };
      }

      logger.info(`[MatchingService] Found ${totalUnassignedBookings} unassigned bookings and ${bookingsOnFullTrips} bookings exceeding capacity - will create trips for them`);

      const queue = await DriverQueue.getActiveByLine(trip.lineid);
      if (!queue || queue.length === 0) {
        logger.info(`[MatchingService] ⚠️ No drivers available in queue - cannot create additional trips`);
        return {
          success: false,
          assigned: assignedCount,
          message: 'No drivers available in queue to assign'
        };
      }



      const estimatedDriversNeeded = Math.min(
        Math.ceil(remainingSeatsNeeded / 4),
        Math.ceil(totalUnassignedBookings / 4)
      );
      const driversToAssign = queue.slice(0, estimatedDriversNeeded);

      for (const driverQueueEntry of driversToAssign) {
        const driverid = driverQueueEntry.driverid;


        const driverTrips = await Trip.findAssignedTrips(driverid, { fromNow: false });
        const tripDeptime = parseUtcDate(trip.deptime);
        const hasTripAtThisTime = driverTrips.some(dt => {
          if (dt.status === 'completed' || dt.status === 'cancelled') return false;
          const dtDeptime = parseUtcDate(dt.deptime);
          if (!dtDeptime || !tripDeptime) return false;
          const timeDiff = Math.abs(dtDeptime.getTime() - tripDeptime.getTime());
          return timeDiff <= 60000;
        });

        if (hasTripAtThisTime) {
          logger.info(`[MatchingService] Driver ${driverid} already has trip at this time, skipping`);
          continue;
        }


        const vehicles = await Vehicle.findByDriverId(driverid);
        if (!vehicles || vehicles.length === 0) {
          logger.warn(`[MatchingService] ⚠️ Driver ${driverid} has no vehicle, removing from queue`);
          await DriverQueue.removeDriverFromQueue(driverid);
          continue;
        }


        // Get direction from trip
        const tripDirection = trip.direction || 'going';
        const newTrip = await findOrAssignExistingTrip(driverid, trip.lineid, trip.deptime, true, tripDirection);

        if (newTrip) {

          await DriverQueue.removeDriverFromQueue(driverid);
          logger.info(`[MatchingService] ✅ Created/assigned additional trip ${newTrip.tripid} with driver ${driverid} for same deptime (removed from queue)`);


          await syncTripStats(newTrip.tripid);

          assignedCount++;
        } else {
          logger.warn(`[MatchingService] ⚠️ Failed to create/assign trip for driver ${driverid}`);
        }
      }
    }

    return {
      success: true,
      assigned: assignedCount,
      message: `Assigned ${assignedCount} additional drivers`
    };
  } catch (error) {
    logger.error(`[MatchingService] Error checking and assigning additional drivers for trip ${tripid}:`, error);
    return { success: false, assigned: 0, error: error.message };
  }
};

/**
 * Recalculate and sync trip stats (availableseats, totalbookings) based on actual reservations
 * This ensures the trip table is always in sync with actual reservation data
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - Updated trip stats
 */
export const syncTripStats = async (tripid) => {
  try {
    const trip = await Trip.findById(tripid);
    if (!trip) {
      logger.error(`[MatchingService] Trip ${tripid} not found for stats sync`);
      return null;
    }


    const reservations = await Reservation.findByTripId(tripid);
    const activeReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );
    const actualBookings = activeReservations.length;


    let maxPassengerSeats = 4;
    if (trip.vehicleid) {
      const vehicle = await Vehicle.findById(trip.vehicleid);
      if (vehicle) {
        maxPassengerSeats = vehicle.seatnum - 1;
      }
    }


    const calculatedAvailableSeats = Math.max(0, maxPassengerSeats - actualBookings);


    if (trip.availableseats !== calculatedAvailableSeats || trip.totalbookings !== actualBookings) {
      await Trip.update(tripid, {
        availableseats: calculatedAvailableSeats,
        totalbookings: actualBookings,
      });
      logger.info(`[MatchingService] 🔄 Synced trip ${tripid} stats: availableseats=${calculatedAvailableSeats}, totalbookings=${actualBookings}`);
    }

    return {
      tripid,
      availableseats: calculatedAvailableSeats,
      totalbookings: actualBookings,
    };
  } catch (error) {
    logger.error(`[MatchingService] Error syncing trip stats for ${tripid}:`, error);
    return null;
  }
};

/**
 * Immediately create a new trip with next driver from queue for a booking on a full trip
 * This is used when a booking comes in for a full trip and we need to immediately assign it to a new driver
 * @param {string} fullTripId - The trip ID that is full
 * @param {string} bookingId - The booking ID that needs to be assigned to a new trip
 * @returns {Promise<object|null>} - The new trip object or null if no driver available
 */
export const createNewTripForFullTripBooking = async (fullTripId, bookingId) => {
  try {
    logger.info(`[MatchingService] 🚨 Creating new trip for booking ${bookingId} on full trip ${fullTripId}`);


    const fullTrip = await Trip.findById(fullTripId);
    if (!fullTrip || !fullTrip.deptime || !fullTrip.lineid) {
      logger.error(`[MatchingService] Full trip ${fullTripId} not found or invalid`);
      return null;
    }

    logger.info(`[MatchingService] Full trip details: lineid=${fullTrip.lineid}, deptime=${fullTrip.deptime}, vehicleid=${fullTrip.vehicleid}, driverid=${fullTrip.assigned_driverid}`);


    const queue = await DriverQueue.getActiveByLine(fullTrip.lineid);
    if (!queue || queue.length === 0) {
      logger.warn(`[MatchingService] ⚠️ No drivers available in queue for line ${fullTrip.lineid}`);
      return null;
    }

    logger.info(`[MatchingService] Found ${queue.length} driver(s) in queue for line ${fullTrip.lineid}`);

    const tripDeptime = parseUtcDate(fullTrip.deptime);
    if (!tripDeptime) {
      logger.error(`[MatchingService] Invalid deptime for trip ${fullTripId}`);
      return null;
    }


    let selectedDriver = null;
    let selectedVehicle = null;

    for (const driverQueueEntry of queue) {
      const driverid = driverQueueEntry.driverid;


      const driverTrips = await Trip.findAssignedTrips(driverid, { fromNow: false });
      const hasTripAtSameTime = driverTrips.some(t => {
        if (t.status === 'completed' || t.status === 'cancelled') return false;
        if (t.deptime) {
          const tDeptime = parseUtcDate(t.deptime);
          if (tDeptime) {
            const timeDiff = Math.abs(tDeptime.getTime() - tripDeptime.getTime());
            return timeDiff <= 60000;
          }
        }
        return false;
      });

      if (hasTripAtSameTime) {
        logger.info(`[MatchingService] Driver ${driverid} already has trip at this time, skipping`);
        continue;
      }


      const vehicles = await Vehicle.findByDriverId(driverid);
      if (!vehicles || vehicles.length === 0) {
        logger.warn(`[MatchingService] ⚠️ Driver ${driverid} has no vehicle, removing from queue`);
        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }


      selectedDriver = driverQueueEntry;
      selectedVehicle = vehicles[0];
      logger.info(`[MatchingService] ✅ Selected driver ${driverid} from queue for new trip`);
      break;
    }

    if (!selectedDriver || !selectedVehicle) {
      logger.warn(`[MatchingService] ⚠️ No available driver found in queue`);
      return null;
    }

    const driverid = selectedDriver.driverid;
    const vehicle = selectedVehicle;


    const { v4: uuidv4 } = await import('uuid');
    const { calculateAvailablePassengerSeats } = await import('../utils/seatCalculation.js');


    const openingTime = new Date(tripDeptime.getTime() - 45 * 60 * 1000);
    const maxPassengerSeats = calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0);

    logger.info(`[MatchingService] Creating new trip: driver=${driverid}, vehicle=${vehicle.vehicleid}, deptime=${fullTrip.deptime}, maxSeats=${maxPassengerSeats}`);

    const newTripData = {
      tripid: uuidv4(),
      lineid: fullTrip.lineid,
      vehicleid: vehicle.vehicleid,
      deptime: fullTrip.deptime,
      status: 'scheduled',
      availableseats: maxPassengerSeats,
      totalbookings: 0,
      trip_opening_time: openingTime.toISOString(),
      auto_departure_enabled: true,
      early_departure_allowed: true,
      scheduled_departure_enforced: true,
    };

    const newTrip = await Trip.create(newTripData);
    logger.info(`[MatchingService] ✅ Created trip ${newTrip.tripid}`);

    await Trip.assignDriver(newTrip.tripid, driverid);
    logger.info(`[MatchingService] ✅ Assigned driver ${driverid} to trip ${newTrip.tripid}`);

    // Transfer payments for this trip to the driver
    try {
      const { transferPaymentsForTrip } = await import('./paymentService.js');
      const transferResult = await transferPaymentsForTrip(newTrip.tripid, driverid);
      if (transferResult.success) {
        logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${newTrip.tripid}`);
      }
    } catch (paymentError) {
      logger.warn(`[MatchingService] ⚠️ Error transferring payments for trip ${newTrip.tripid}:`, paymentError);
    }

    await DriverQueue.removeDriverFromQueue(driverid);
    logger.info(`[MatchingService] ✅ Removed driver ${driverid} from queue after creating trip ${newTrip.tripid}`);


    await Reservation.update(bookingId, {
      tripid: newTrip.tripid,
    });
    logger.info(`[MatchingService] ✅ Assigned booking ${bookingId} to new trip ${newTrip.tripid}`);


    await syncTripStats(newTrip.tripid);
    logger.info(`[MatchingService] ✅ Synced trip stats for ${newTrip.tripid}`);

    const finalTrip = await Trip.findById(newTrip.tripid);
    logger.info(`[MatchingService] ✅ Created new trip ${newTrip.tripid} with driver ${driverid} for booking ${bookingId}`);

    // Send notifications
    try {
      const { sendNotification, NOTIFICATION_TYPES } = await import('./notificationService.js');
      const Driver = (await import('../models/Driver.js')).default;
      const Line = (await import('../models/Line.js')).default;
      const Passenger = (await import('../models/Passenger.js')).default;
      
      // Get driver, line, and passenger info
      const driver = await Driver.findById(driverid);
      const line = await Line.findById(finalTrip.lineid);
      const reservation = await Reservation.findById(bookingId);
      const passenger = reservation ? await Passenger.findById(reservation.passengerid) : null;
      
      const driverName = driver?.user?.fullname || 'Driver';
      const vehicle = await Vehicle.findById(vehicle.vehicleid);
      const plateNumber = vehicle?.plateno || 'N/A';
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');

      // Notify driver
      if (driver?.userid) {
        const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid);
        const { DateTime } = await import('luxon');
        const deptime = DateTime.fromISO(new Date(finalTrip.deptime).toISOString())
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
            tripid: finalTrip.tripid,
          },
          driverLanguage,
          { line, trip: finalTrip } // Pass raw data for separate Arabic/English formatting
        );
      }

      // Notify passenger
      if (passenger?.userid) {
        const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, passenger.userid);
        const { DateTime } = await import('luxon');
        const deptime = DateTime.fromISO(new Date(finalTrip.deptime).toISOString())
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
          { line, trip: finalTrip } // Pass raw data for separate Arabic/English formatting
        );
      }
    } catch (notifError) {
      logger.warn(`[MatchingService] Failed to send notifications for new trip ${newTrip.tripid}:`, notifError);
    }

    return finalTrip;
  } catch (error) {
    logger.error(`[MatchingService] ❌ Error creating new trip for full trip booking:`, error);
    logger.error(`[MatchingService] Error stack:`, error.stack);
    return null;
  }
};

/**
 * Get available seats for a vehicle (excluding broken seats and existing reservations)
 * @param {object} vehicle - The vehicle object
 * @param {string} tripid - The trip ID (optional, for checking existing reservations)
 * @returns {Promise<number>} - Number of available seats
 */
export const getAvailableSeats = async (vehicle, tripid = null) => {
  try {
    let reservedSeats = 0;


    if (tripid) {
      const reservations = await Reservation.findByTripId(tripid);
      reservedSeats = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      ).length;
    }


    const brokenSeats = (vehicle.broken_seats || []).length;



    const availableSeats = calculateAvailablePassengerSeats(
      vehicle.seatnum,
      reservedSeats,
      0
    );

    return availableSeats;
  } catch (error) {
    logger.error('[MatchingService] Error calculating available seats:', error);
    throw error;
  }
};

/**
 * Find existing scheduled trip OR assign driver to an existing unassigned trip at a specific time
 * This should NOT create new trips - instead it assigns drivers to existing scheduled trips
 * @param {string} driverid - The driver ID
 * @param {string} lineid - The line ID
 * @param {string} deptime - The departure time
 * @param {boolean} hasBookingsWaiting - Whether there are bookings waiting to be assigned (required to create new trip)
 * @param {string} direction - The trip direction ('going' or 'return')
 * @returns {Promise<object|null>} - The trip object or null if no suitable trip found
 */
const findOrAssignExistingTrip = async (driverid, lineid, deptime, hasBookingsWaiting = false, direction = 'going') => {
  try {

    const vehicles = await Vehicle.findByDriverId(driverid);
    if (vehicles.length === 0) {
      throw new Error(`Driver ${driverid} has no vehicle`);
    }

    const vehicle = vehicles[0];
    const deptimeUtc = parseUtcDate(deptime);


    const existingDriverTrips = await Trip.findAssignedTrips(driverid, {
      fromNow: false,
    });

    const alreadyAssignedTrip = existingDriverTrips.find(t => {
      const tripDeptime = parseUtcDate(t.deptime);
      return tripDeptime && deptimeUtc && tripDeptime.getTime() === deptimeUtc.getTime();
    });

    if (alreadyAssignedTrip) {
      logger.info(`[MatchingService] ✅ Driver ${driverid} already assigned to trip ${alreadyAssignedTrip.tripid}`);
      return alreadyAssignedTrip;
    }


    const allTrips = await Trip.findAll({ lineid, status: 'scheduled', direction });
    const openTrips = await Trip.findAll({ lineid, status: 'open', direction });
    const candidateTrips = [...allTrips, ...openTrips];

    const unassignedTripAtTime = candidateTrips.find(t => {
      const tripDeptime = parseUtcDate(t.deptime);
      const timeMatches = tripDeptime && deptimeUtc && tripDeptime.getTime() === deptimeUtc.getTime();
      const noDriver = !t.vehicleid || !t.assigned_driverid;
      const directionMatches = !t.direction || t.direction === direction;
      return timeMatches && noDriver && directionMatches;
    });

    if (unassignedTripAtTime) {

      const reservations = await Reservation.findByTripId(unassignedTripAtTime.tripid);
      const activeReservations = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      );

      if (activeReservations.length === 0) {
        logger.info(`[MatchingService] ⚠️ Trip ${unassignedTripAtTime.tripid} has no reservations - driver will not be assigned`);
        return null;
      }


      const vehicleType = vehicle.seatnum === 5 ? '4+1' : vehicle.seatnum === 8 ? '7+1' : `${vehicle.seatnum} seats`;
      logger.info(`[MatchingService] 🔗 Assigning driver ${driverid} with ${vehicleType} vehicle to existing trip ${unassignedTripAtTime.tripid} (has ${activeReservations.length} reservation(s))`);

      await Trip.update(unassignedTripAtTime.tripid, {
        vehicleid: vehicle.vehicleid,
      });
      await Trip.assignDriver(unassignedTripAtTime.tripid, driverid);

      // Transfer payments for this trip to the driver
      try {
        const { transferPaymentsForTrip } = await import('./paymentService.js');
        const transferResult = await transferPaymentsForTrip(unassignedTripAtTime.tripid, driverid);
        if (transferResult.success) {
          logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${unassignedTripAtTime.tripid}`);
        }
      } catch (paymentError) {
        logger.warn(`[MatchingService] ⚠️ Error transferring payments for trip ${unassignedTripAtTime.tripid}:`, paymentError);
      }

      await syncTripStats(unassignedTripAtTime.tripid);


      return await Trip.findById(unassignedTripAtTime.tripid);
    }



    if (!hasBookingsWaiting) {

      const futureBookings = await Reservation.findFutureBookingsForTrip(deptime, { lineid });
      const unassignedFutureBookings = futureBookings.filter(b => !b.tripid);


      const allInstantBookings = await Reservation.findByBookingType(BOOKING_TYPE.INSTANT, {
        status: 'confirmed',
      });
      const unassignedInstantBookings = allInstantBookings.filter(b => {
        if (b.tripid) return false;
        if (!b.scheduled_trip_time) return false;
        const bookingTime = parseUtcDate(b.scheduled_trip_time);
        if (!bookingTime || !deptimeUtc) return false;
        const timeDiff = Math.abs(bookingTime.getTime() - deptimeUtc.getTime());
        return timeDiff <= 60000;
      });

      const totalUnassignedBookings = unassignedFutureBookings.length + unassignedInstantBookings.length;

      if (totalUnassignedBookings === 0) {
        logger.info(`[MatchingService] ⚠️ No bookings waiting for time ${deptime} - will not create new trip for driver ${driverid}`);
        return null;
      }

      logger.info(`[MatchingService] Found ${totalUnassignedBookings} unassigned bookings for time ${deptime} - will create new trip`);
    }


    logger.info(`[MatchingService] 🆕 Creating new trip for driver ${driverid} at ${deptime} for line ${lineid}`);

    const { v4: uuidv4 } = await import('uuid');
    const { calculateAvailablePassengerSeats } = await import('../utils/seatCalculation.js');


    const openingTime = new Date(deptimeUtc.getTime() - 45 * 60 * 1000);
    const maxPassengerSeats = calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0);

    // Get line to determine origin_stationid
    const Line = (await import('../models/Line.js')).default;
    const line = await Line.findById(lineid);
    
    // Set origin_stationid based on direction
    let origin_stationid = null;
    if (direction === 'going') {
      origin_stationid = line?.main_stationid || null;
    } else if (direction === 'return') {
      origin_stationid = line?.return_stationid || null;
    }

    const newTripData = {
      tripid: uuidv4(),
      lineid,
      vehicleid: vehicle.vehicleid,
      deptime: deptime,
      status: 'scheduled',
      availableseats: maxPassengerSeats,
      totalbookings: 0,
      trip_opening_time: openingTime.toISOString(),
      auto_departure_enabled: true,
      early_departure_allowed: true,
      scheduled_departure_enforced: true,
      direction: direction,
      origin_stationid: origin_stationid,
    };

    const newTrip = await Trip.create(newTripData);
    await Trip.assignDriver(newTrip.tripid, driverid);

    // Transfer payments for this trip to the driver
    try {
      const { transferPaymentsForTrip } = await import('./paymentService.js');
      const transferResult = await transferPaymentsForTrip(newTrip.tripid, driverid);
      if (transferResult.success) {
        logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${newTrip.tripid}`);
      }
    } catch (paymentError) {
      logger.warn(`[MatchingService] ⚠️ Error transferring payments for trip ${newTrip.tripid}:`, paymentError);
    }

    await syncTripStats(newTrip.tripid);

    logger.info(`[MatchingService] ✅ Created new trip ${newTrip.tripid} for driver ${driverid} at ${deptime}`);

    return await Trip.findById(newTrip.tripid);
  } catch (error) {
    logger.error('[MatchingService] Error finding/assigning trip:', error);
    throw error;
  }
};

/**
 * Transfer payments for a trip to the driver's wallet
 * @param {string} tripid - The trip ID
 * @returns {Promise<void>}
 */
const transferPaymentsToDriver = async (tripid) => {
  try {
    const trip = await Trip.findById(tripid);
    if (!trip || !trip.assigned_driverid) {
      console.log(`[MatchingService] ⚠️ Trip ${tripid} has no assigned driver, skipping payment transfer`);
      return;
    }

    // Get driver's userid - try from trip object first, then fetch driver directly
    let driverUserid = trip.vehicle?.driver?.userid || trip.vehicle?.driver?.user?.userid;

    if (!driverUserid) {
      // Fallback: fetch driver directly
      try {
        const driver = await Driver.findById(trip.assigned_driverid);
        driverUserid = driver?.userid;
      } catch (error) {
        console.error(`[MatchingService] Error fetching driver ${trip.assigned_driverid}:`, error);
      }
    }

    if (!driverUserid) {
      console.log(`[MatchingService] ⚠️ Could not find driver userid for trip ${tripid}, skipping payment transfer`);
      return;
    }

    // Get driver's wallet
    const driverWallets = await Wallet.findByUserId(driverUserid, 'main');
    const driverWallet = driverWallets?.[0];
    if (!driverWallet) {
      console.log(`[MatchingService] ⚠️ Driver wallet not found for user ${driverUserid}, skipping payment transfer`);
      return;
    }

    // Get all reservations for this trip
    const reservations = await Reservation.findByTripId(tripid);

    // Process payments for each reservation
    for (const reservation of reservations) {
      if (!reservation.paymentid) {
        continue;
      }

      try {
        const payment = await Payment.findById(reservation.paymentid);
        if (!payment || payment.status !== 'completed') {
          continue;
        }

        // Skip if payment already has towalletid set
        if (payment.towalletid) {
          continue;
        }

        // Update payment tripid if it was null, and set towalletid
        const paymentUpdates = {
          tripid: tripid,
          towalletid: driverWallet.walletid,
        };

        await Payment.update(payment.paymentid, paymentUpdates);

        // Add payment amount to driver wallet
        await Wallet.updateBalance(driverWallet.walletid, payment.amount, 'add');

        console.log(`[MatchingService] ✅ Transferred payment ${payment.paymentid} (${payment.amount}) to driver wallet for trip ${tripid}`);
      } catch (error) {
        console.error(`[MatchingService] Error transferring payment for reservation ${reservation.bookingid}:`, error);
        // Continue with other payments even if one fails
      }
    }
  } catch (error) {
    console.error(`[MatchingService] Error in transferPaymentsToDriver for trip ${tripid}:`, error);
    // Don't throw - allow the distribution to continue
  }
};

/**
 * Distribute future bookings to drivers
 * @param {string} scheduledTripTime - The scheduled trip departure time
 * @param {string} lineid - The line ID
 * @param {string} tripid - Optional trip ID to assign bookings to (if provided, uses this trip instead of creating new ones)
 * @returns {Promise<object>} - Distribution result
 */
export const distributeFutureBookings = async (scheduledTripTime, lineid, tripid = null) => {
  try {
    logger.info(`[MatchingService] 🚀 Starting distribution of future bookings for time ${scheduledTripTime} on line ${lineid}`);


    const futureBookings = await Reservation.findFutureBookingsForTrip(scheduledTripTime, { lineid });


    const unassignedBookings = futureBookings.filter(b => !b.tripid);

    if (unassignedBookings.length === 0) {
      logger.info(`[MatchingService] No unassigned future bookings found for time ${scheduledTripTime}`);
      return {
        success: true,
        distributed: 0,
        remaining: 0,
        driversUsed: [],
      };
    }

    logger.info(`[MatchingService] Found ${unassignedBookings.length} unassigned future bookings`);

    let distributedCount = 0;
    let remainingBookings = [...unassignedBookings];
    const driversUsed = [];


    let targetTrip = null;
    if (tripid) {
      targetTrip = await Trip.findById(tripid);
      if (!targetTrip) {
        logger.warn(`[MatchingService] ⚠️ Trip ${tripid} not found, cannot distribute bookings`);
        return {
          success: false,
          distributed: 0,
          remaining: unassignedBookings.length,
          driversUsed: [],
        };
      }
      logger.info(`[MatchingService] Using existing trip ${tripid} for distribution`);
    }


    while (remainingBookings.length > 0) {

      if (targetTrip) {
        // If trip has a vehicle, check capacity; otherwise assign all bookings (capacity will be checked later)
        let bookingsToAssign = [];

        if (targetTrip.vehicleid) {
          const driverVehicle = await Vehicle.findById(targetTrip.vehicleid);
          let availableSeats = await getAvailableSeats(driverVehicle, targetTrip.tripid);

          if (availableSeats > 0) {
            bookingsToAssign = remainingBookings.slice(0, availableSeats);
          } else {
            // Trip is full, break to look for other trips
            break;
          }
        } else {
          // Trip has no vehicle yet - assign all bookings to this trip
          // Capacity will be checked when vehicle is assigned
          bookingsToAssign = [...remainingBookings];
        }

        if (bookingsToAssign.length > 0) {
          for (const booking of bookingsToAssign) {
            await Reservation.update(booking.bookingid, {
              tripid: targetTrip.tripid,
            });

            // Update payment.tripid for this booking
            if (booking.paymentid) {
              try {
                const Payment = (await import('../models/Payment.js')).default;
                await Payment.update(booking.paymentid, { tripid: targetTrip.tripid });
              } catch (error) {
                logger.warn(`[MatchingService] ⚠️ Failed to update payment.tripid for booking ${booking.bookingid}:`, error);
              }
            }

            distributedCount++;
          }

          if (bookingsToAssign.length > 0) {
            await syncTripStats(targetTrip.tripid);

            // Transfer payments for this trip to the driver (only if driver is assigned)
            if (targetTrip.assigned_driverid) {
              try {
                const { transferPaymentsForTrip } = await import('./paymentService.js');
                const transferResult = await transferPaymentsForTrip(targetTrip.tripid, targetTrip.assigned_driverid);
                if (transferResult.success) {
                  logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${targetTrip.assigned_driverid} for trip ${targetTrip.tripid}`);
                }
              } catch (paymentError) {
                logger.warn(`[MatchingService] ⚠️ Error transferring payments for trip ${targetTrip.tripid}:`, paymentError);
              }
            }
          }

          remainingBookings = remainingBookings.slice(bookingsToAssign.length);

          const vehicleInfo = targetTrip.vehicleid ? await Vehicle.findById(targetTrip.vehicleid) : null;
          driversUsed.push({
            driverid: targetTrip.assigned_driverid || null,
            tripid: targetTrip.tripid,
            bookingsAssigned: bookingsToAssign.length,
            vehicle: vehicleInfo,
          });

          logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} future bookings to trip ${targetTrip.tripid}${!targetTrip.vehicleid ? ' (no vehicle yet)' : ''}`);
        }

        // If tripid was provided, only assign to that specific trip (don't look for other trips)
        // Exit the while loop and return
        break;
      }

      // Code below only executes when tripid is null (no specific trip provided)
      if (remainingBookings.length > 0) {
        const tripsAtSameTime = await findTripsAtSameTime(scheduledTripTime, lineid);
        const otherTrips = tripsAtSameTime.filter(t =>
          t.tripid !== targetTrip.tripid &&
          t.vehicleid &&
          t.assigned_driverid &&
          (t.status === 'scheduled' || t.status === 'open' || t.status === 'delayed')
        );


        for (const otherTrip of otherTrips) {
          if (remainingBookings.length === 0) break;

          const otherVehicle = await Vehicle.findById(otherTrip.vehicleid);
          const otherAvailableSeats = await getAvailableSeats(otherVehicle, otherTrip.tripid);

          if (otherAvailableSeats > 0) {
            const bookingsToAssign = remainingBookings.slice(0, otherAvailableSeats);

            for (const booking of bookingsToAssign) {
              await Reservation.update(booking.bookingid, {
                tripid: otherTrip.tripid,
              });
              distributedCount++;
            }

            if (bookingsToAssign.length > 0) {
              await syncTripStats(otherTrip.tripid);
            }

            remainingBookings = remainingBookings.slice(bookingsToAssign.length);

            driversUsed.push({
              driverid: otherTrip.assigned_driverid,
              tripid: otherTrip.tripid,
              bookingsAssigned: bookingsToAssign.length,
              vehicle: otherVehicle,
            });

            logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} future bookings to additional trip ${otherTrip.tripid} at same time`);
          }
        }


        if (remainingBookings.length > 0) {
          targetTrip = null;
        } else {
          break;
        }
      } else {
        break;
      }
    }

    // Code below only executes when tripid is null (no specific trip provided)
    // It creates new trips with drivers from the queue
    if (tripid) {
      // If tripid was provided, we've already assigned bookings to that trip, so return
      return {
        success: true,
        distributed: distributedCount,
        remaining: remainingBookings.length,
        driversUsed,
      };
    }

    // Continue with creating new trips for remaining bookings
    while (remainingBookings.length > 0) {
      // For future bookings, we need to determine direction from bookings or use default 'going'
      // For now, we'll get drivers from 'going' queue by default
      // TODO: Determine direction from booking context if needed
      const queueDirection = 'going'; // Default for future bookings
      const driverQueueEntry = await getNextDriverFromQueue(lineid, queueDirection);

      if (!driverQueueEntry) {
        logger.warn(`[MatchingService] ⚠️ No more drivers available in ${queueDirection} queue`);
        break;
      }

      const driverid = driverQueueEntry.driverid;
      const queueEntryDirection = driverQueueEntry.direction || queueDirection;
      
      // Map queue direction to trip direction
      const { mapQueueDirectionToTripDirection } = await import('../utils/tripDirectionUtils.js');
      const tripDirection = mapQueueDirectionToTripDirection(queueEntryDirection);

      const driverTrip = await findOrAssignExistingTrip(driverid, lineid, scheduledTripTime, true, tripDirection);

      if (!driverTrip) {
        logger.warn(`[MatchingService] ⚠️ Failed to find or create trip for driver ${driverid} at ${scheduledTripTime}`);

        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }


      const driverVehicle = await Vehicle.findById(driverTrip.vehicleid);


      const vehicleType = driverVehicle.seatnum === 5 ? '4+1' : driverVehicle.seatnum === 8 ? '7+1' : `${driverVehicle.seatnum} seats`;
      const maxPassengerSeats = driverVehicle.seatnum - 1;
      logger.info(`[MatchingService] 📦 Driver ${driverid} has ${vehicleType} vehicle (${driverVehicle.seatnum} total, ${maxPassengerSeats} passenger seats)`);


      const availableSeats = await getAvailableSeats(driverVehicle, driverTrip.tripid);

      if (availableSeats <= 0) {
        logger.warn(`[MatchingService] ⚠️ Driver ${driverid} vehicle (${vehicleType}) is full, moving to next driver`);

        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }


      const bookingsToAssign = remainingBookings.slice(0, availableSeats);


      for (const booking of bookingsToAssign) {
        await Reservation.update(booking.bookingid, {
          tripid: driverTrip.tripid,
        });

        distributedCount++;
      }


      if (bookingsToAssign.length > 0) {
        await syncTripStats(driverTrip.tripid);

        // Update payment.tripid for all assigned bookings and transfer payments
        try {
          const Payment = (await import('../models/Payment.js')).default;
          for (const booking of bookingsToAssign) {
            if (booking.paymentid) {
              try {
                await Payment.update(booking.paymentid, { tripid: driverTrip.tripid });
              } catch (error) {
                logger.warn(`[MatchingService] ⚠️ Failed to update payment.tripid for booking ${booking.bookingid}:`, error);
              }
            }
          }

          // Transfer payments for this trip to the driver
          const { transferPaymentsForTrip } = await import('./paymentService.js');
          const transferResult = await transferPaymentsForTrip(driverTrip.tripid, driverid);
          if (transferResult.success) {
            logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${driverTrip.tripid}`);
          }
        } catch (paymentError) {
          logger.warn(`[MatchingService] ⚠️ Error updating payments for trip ${driverTrip.tripid}:`, paymentError);
        }
      }


      remainingBookings = remainingBookings.slice(bookingsToAssign.length);

      // Transfer payments to driver wallet after assigning reservations
      await transferPaymentsToDriver(driverTrip.tripid);

      driversUsed.push({
        driverid,
        tripid: driverTrip.tripid,
        bookingsAssigned: bookingsToAssign.length,
        vehicle: driverVehicle,
      });

      logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} future bookings to driver ${driverid} (${vehicleType} vehicle, trip ${driverTrip.tripid})`);


      if (availableSeats === bookingsToAssign.length) {
        logger.info(`[MatchingService] 🚗 Driver ${driverid} vehicle (${vehicleType}) is now full, removing from queue`);
        await DriverQueue.removeDriverFromQueue(driverid);
      }
    }

    return {
      success: true,
      distributed: distributedCount,
      remaining: remainingBookings.length,
      driversUsed,
    };
  } catch (error) {
    logger.error('[MatchingService] Error distributing future bookings:', error);
    throw error;
  }
};

/**
 * Distribute instant bookings to drivers for the next available trip
 * @param {string} lineid - The line ID
 * @param {string} nextTripTime - The next trip departure time (optional)
 * @param {string} tripid - Optional trip ID to assign bookings to (if provided, uses this trip instead of finding next)
 * @returns {Promise<object>} - Distribution result
 */
export const distributeInstantBookings = async (lineid, nextTripTime = null, tripid = null) => {
  try {
    logger.info(`[MatchingService] 🚀 Starting distribution of instant bookings for line ${lineid}`);



    let targetTripTime = nextTripTime;

    if (!targetTripTime) {

      const scheduledTrips = await Trip.findUpcoming({ lineid, status: 'scheduled' });
      const openTrips = await Trip.findUpcoming({ lineid, status: 'open' });
      const upcomingTrips = [...scheduledTrips, ...openTrips].sort((a, b) => {
        const aDeptime = parseUtcDate(a.deptime);
        const bDeptime = parseUtcDate(b.deptime);
        if (!aDeptime || !bDeptime) return 0;
        return aDeptime.getTime() - bDeptime.getTime();
      });
      if (upcomingTrips.length > 0) {
        targetTripTime = upcomingTrips[0].deptime;
      } else {
        logger.warn(`[MatchingService] ⚠️ No upcoming trips found for line ${lineid}`);
        return {
          success: true,
          distributed: 0,
          remaining: 0,
          driversUsed: [],
        };
      }
    }


    const allInstantBookings = await Reservation.findByBookingType(BOOKING_TYPE.INSTANT, {
      status: 'confirmed',
    });



    const unassignedBookings = allInstantBookings
      .filter(b => !b.tripid)
      .sort((a, b) => {
        const aBookedAt = parseUtcDate(a.bookedat);
        const bBookedAt = parseUtcDate(b.bookedat);
        if (!aBookedAt || !bBookedAt) return 0;
        return aBookedAt.getTime() - bBookedAt.getTime();
      });

    if (unassignedBookings.length === 0) {
      logger.info(`[MatchingService] No unassigned instant bookings found`);
      return {
        success: true,
        distributed: 0,
        remaining: 0,
        driversUsed: [],
      };
    }

    logger.info(`[MatchingService] Found ${unassignedBookings.length} unassigned instant bookings (ordered by timestamp)`);

    let distributedCount = 0;
    let remainingBookings = [...unassignedBookings];
    const driversUsed = [];


    let targetTrip = null;
    if (tripid) {
      targetTrip = await Trip.findById(tripid);
      if (!targetTrip || !targetTrip.vehicleid) {
        logger.warn(`[MatchingService] ⚠️ Trip ${tripid} not found or has no vehicle, cannot distribute bookings`);
        return {
          success: false,
          distributed: 0,
          remaining: unassignedBookings.length,
          driversUsed: [],
        };
      }
      logger.info(`[MatchingService] Using existing trip ${tripid} for instant booking distribution`);
    }



    while (remainingBookings.length > 0) {

      if (targetTrip) {
        const driverVehicle = await Vehicle.findById(targetTrip.vehicleid);
        let availableSeats = await getAvailableSeats(driverVehicle, targetTrip.tripid);

        if (availableSeats > 0) {

          const bookingsToAssign = remainingBookings.slice(0, availableSeats);

          for (const booking of bookingsToAssign) {
            await Reservation.update(booking.bookingid, {
              tripid: targetTrip.tripid,
            });
            distributedCount++;
          }


          if (bookingsToAssign.length > 0) {
            await syncTripStats(targetTrip.tripid);
          }

          remainingBookings = remainingBookings.slice(bookingsToAssign.length);

          driversUsed.push({
            driverid: targetTrip.assigned_driverid,
            tripid: targetTrip.tripid,
            bookingsAssigned: bookingsToAssign.length,
            vehicle: driverVehicle,
          });

          logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} instant bookings to trip ${targetTrip.tripid}`);
        }


        if (remainingBookings.length > 0) {
          const tripsAtSameTime = await findTripsAtSameTime(targetTripTime, lineid);
          const otherTrips = tripsAtSameTime.filter(t =>
            t.tripid !== targetTrip.tripid &&
            t.vehicleid &&
            t.assigned_driverid &&
            (t.status === 'scheduled' || t.status === 'open' || t.status === 'delayed')
          );


          for (const otherTrip of otherTrips) {
            if (remainingBookings.length === 0) break;

            const otherVehicle = await Vehicle.findById(otherTrip.vehicleid);
            const otherAvailableSeats = await getAvailableSeats(otherVehicle, otherTrip.tripid);

            if (otherAvailableSeats > 0) {
              const bookingsToAssign = remainingBookings.slice(0, otherAvailableSeats);

              for (const booking of bookingsToAssign) {
                await Reservation.update(booking.bookingid, {
                  tripid: otherTrip.tripid,
                });
                distributedCount++;
              }

              if (bookingsToAssign.length > 0) {
                await syncTripStats(otherTrip.tripid);
              }

              remainingBookings = remainingBookings.slice(bookingsToAssign.length);

              driversUsed.push({
                driverid: otherTrip.assigned_driverid,
                tripid: otherTrip.tripid,
                bookingsAssigned: bookingsToAssign.length,
                vehicle: otherVehicle,
              });

              logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} instant bookings to additional trip ${otherTrip.tripid} at same time`);
            }
          }


          if (remainingBookings.length > 0) {
            targetTrip = null;
          } else {
            break;
          }
        } else {
          break;
        }
      }


      // For instant bookings, get drivers from 'going' queue by default
      // TODO: Determine direction from booking context if needed
      const queueDirection = 'going'; // Default for instant bookings
      const driverQueueEntry = await getNextDriverFromQueue(lineid, queueDirection);

      if (!driverQueueEntry) {
        logger.warn(`[MatchingService] ⚠️ No more drivers available in ${queueDirection} queue`);
        break;
      }

      const driverid = driverQueueEntry.driverid;
      const queueEntryDirection = driverQueueEntry.direction || queueDirection;
      
      // Map queue direction to trip direction
      const { mapQueueDirectionToTripDirection } = await import('../utils/tripDirectionUtils.js');
      const tripDirection = mapQueueDirectionToTripDirection(queueEntryDirection);

      const driverTrip = await findOrAssignExistingTrip(driverid, lineid, targetTripTime, true, tripDirection);

      if (!driverTrip) {
        logger.warn(`[MatchingService] ⚠️ Failed to find or create trip for driver ${driverid} at ${targetTripTime}`);

        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }


      const driverVehicle = await Vehicle.findById(driverTrip.vehicleid);


      const vehicleType = driverVehicle.seatnum === 5 ? '4+1' : driverVehicle.seatnum === 8 ? '7+1' : `${driverVehicle.seatnum} seats`;
      const maxPassengerSeats = driverVehicle.seatnum - 1;
      logger.info(`[MatchingService] 📦 Driver ${driverid} has ${vehicleType} vehicle (${driverVehicle.seatnum} total, ${maxPassengerSeats} passenger seats)`);


      const availableSeats = await getAvailableSeats(driverVehicle, driverTrip.tripid);

      if (availableSeats <= 0) {
        logger.warn(`[MatchingService] ⚠️ Driver ${driverid} vehicle (${vehicleType}) is full, moving to next driver`);

        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }


      const bookingsToAssign = remainingBookings.slice(0, availableSeats);


      for (const booking of bookingsToAssign) {
        await Reservation.update(booking.bookingid, {
          tripid: driverTrip.tripid,
        });

        distributedCount++;
      }


      if (bookingsToAssign.length > 0) {
        await syncTripStats(driverTrip.tripid);

        // Update payment.tripid for all assigned bookings and transfer payments
        try {
          const Payment = (await import('../models/Payment.js')).default;
          for (const booking of bookingsToAssign) {
            if (booking.paymentid) {
              try {
                await Payment.update(booking.paymentid, { tripid: driverTrip.tripid });
              } catch (error) {
                logger.warn(`[MatchingService] ⚠️ Failed to update payment.tripid for booking ${booking.bookingid}:`, error);
              }
            }
          }

          // Transfer payments for this trip to the driver
          const { transferPaymentsForTrip } = await import('./paymentService.js');
          const transferResult = await transferPaymentsForTrip(driverTrip.tripid, driverid);
          if (transferResult.success) {
            logger.info(`[MatchingService] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${driverTrip.tripid}`);
          }
        } catch (paymentError) {
          logger.warn(`[MatchingService] ⚠️ Error updating payments for trip ${driverTrip.tripid}:`, paymentError);
        }
      }


      remainingBookings = remainingBookings.slice(bookingsToAssign.length);

      driversUsed.push({
        driverid,
        tripid: driverTrip.tripid,
        bookingsAssigned: bookingsToAssign.length,
        vehicle: driverVehicle,
      });

      logger.info(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} instant bookings to driver ${driverid} (${vehicleType} vehicle, trip ${driverTrip.tripid})`);


      if (availableSeats === bookingsToAssign.length) {
        logger.info(`[MatchingService] 🚗 Driver ${driverid} vehicle (${vehicleType}) is now full, removing from queue`);
        await DriverQueue.removeDriverFromQueue(driverid);
      }
    }

    return {
      success: true,
      distributed: distributedCount,
      remaining: remainingBookings.length,
      driversUsed,
    };
  } catch (error) {
    logger.error('[MatchingService] Error distributing instant bookings:', error);
    throw error;
  }
};

/**
 * Distribute all bookings for a trip opening (Future first, then Instant)
 * Also handles multi-driver assignment when bookings exceed capacity
 * @param {string} tripid - The trip ID that just opened
 * @returns {Promise<object>} - Distribution result
 */
export const distributeAllBookings = async (tripid) => {
  try {
    logger.info(`[MatchingService] 🚀 Starting distribution for opened trip ${tripid}`);


    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }


    if (!trip.vehicleid) {
      logger.warn(`[MatchingService] ⚠️ Trip ${tripid} has no vehicle assigned, skipping booking distribution`);
      return {
        success: false,
        message: 'Trip has no vehicle assigned',
        future: { distributed: 0, remaining: 0, driversUsed: [] },
        instant: { distributed: 0, remaining: 0, driversUsed: [] },
        totalDistributed: 0,
        totalRemaining: 0,
      };
    }

    const scheduledTripTime = trip.deptime;
    const lineid = trip.lineid;


    logger.info(`[MatchingService] 📅 Step 1: Distributing Future Bookings`);
    const futureResult = await distributeFutureBookings(scheduledTripTime, lineid, tripid);


    logger.info(`[MatchingService] ⚡ Step 2: Distributing Instant Bookings`);
    const instantResult = await distributeInstantBookings(lineid, scheduledTripTime, tripid);



    logger.info(`[MatchingService] 🚐 Step 3: Checking for additional driver needs`);
    const additionalDriversResult = await checkAndAssignAdditionalDrivers(tripid);

    if (additionalDriversResult.assigned > 0) {
      logger.info(`[MatchingService] ✅ Assigned ${additionalDriversResult.assigned} additional drivers, redistributing bookings`);



      const tripsAtSameTime = await findTripsAtSameTime(scheduledTripTime, lineid);
      const assignedTrips = tripsAtSameTime.filter(t => t.vehicleid && t.assigned_driverid);

      if (assignedTrips.length > 1) {

        logger.info(`[MatchingService] 🔄 Redistributing across ${assignedTrips.length} trips at same time`);


        const redistFutureResult = await distributeFutureBookings(scheduledTripTime, lineid, null);
        const redistInstantResult = await distributeInstantBookings(lineid, scheduledTripTime, null);

        return {
          success: true,
          future: redistFutureResult,
          instant: redistInstantResult,
          totalDistributed: redistFutureResult.distributed + redistInstantResult.distributed,
          totalRemaining: redistFutureResult.remaining + redistInstantResult.remaining,
          additionalDriversAssigned: additionalDriversResult.assigned,
        };
      }
    }

    return {
      success: true,
      future: futureResult,
      instant: instantResult,
      totalDistributed: futureResult.distributed + instantResult.distributed,
      totalRemaining: futureResult.remaining + instantResult.remaining,
      additionalDriversAssigned: additionalDriversResult.assigned || 0,
    };
  } catch (error) {
    logger.error('[MatchingService] Error distributing all bookings:', error);
    throw error;
  }
};

/**
 * Adjust future reservations when schedule interval changes
 * Moves reservations to the next available trip time based on new schedule
 */
export const adjustReservationsForScheduleChange = async (
  lineid,
  oldInterval,
  newInterval,
  startHour,
  endHour
) => {
  try {
    logger.info(`[MatchingService] 🔄 Adjusting reservations for schedule change: line=${lineid}, oldInterval=${oldInterval}, newInterval=${newInterval}`);

    // Get all future reservations for this line
    const Reservation = (await import('../models/Reservation.js')).default;
    const futureReservations = await Reservation.findByBookingType('future', {
      status: 'confirmed',
    });

    const lineReservations = futureReservations.filter(r => r.lineid === lineid);

    if (lineReservations.length === 0) {
      logger.info(`[MatchingService] No future reservations found for line ${lineid}`);
      return { adjusted: 0, errors: [] };
    }

    logger.info(`[MatchingService] Found ${lineReservations.length} future reservation(s) to adjust`);

    const adjusted = [];
    const errors = [];
    const timezoneOffset = await getServerTimezoneOffset();

    for (const reservation of lineReservations) {
      try {
        if (!reservation.scheduled_trip_time) {
          logger.warn(`[MatchingService] Reservation ${reservation.bookingid} has no scheduled_trip_time, skipping`);
          continue;
        }

        const oldScheduledTime = parseUtcDate(reservation.scheduled_trip_time);
        if (!oldScheduledTime) {
          logger.warn(`[MatchingService] Invalid scheduled_trip_time for reservation ${reservation.bookingid}`);
          continue;
        }

        // Generate new trip times based on new schedule
        const year = oldScheduledTime.getFullYear();
        const month = String(oldScheduledTime.getMonth() + 1).padStart(2, '0');
        const day = String(oldScheduledTime.getDate()).padStart(2, '0');
        const offsetSign = timezoneOffset >= 0 ? '+' : '-';
        const offsetHours = String(Math.abs(timezoneOffset)).padStart(2, '0');

        // Generate all possible trip times for the day with new interval
        const newTripTimes = [];
        let currentMinutes = startHour * 60;
        const endMinutes = endHour * 60;

        while (currentMinutes <= endMinutes) {
          const hours = Math.floor(currentMinutes / 60);
          const mins = currentMinutes % 60;
          const localTimeString = `${year}-${month}-${day}T${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00${offsetSign}${offsetHours}:00`;
          const utcTime = parseUtcDate(localTimeString);
          if (utcTime) {
            newTripTimes.push(utcTime);
          }
          currentMinutes += newInterval;
        }

        // Find the next available trip time (equal or after the old scheduled time)
        const nextAvailableTime = newTripTimes.find(time => 
          time.getTime() >= oldScheduledTime.getTime()
        ) || newTripTimes[newTripTimes.length - 1]; // If no time found, use the last one

        if (!nextAvailableTime) {
          logger.warn(`[MatchingService] No available trip time found for reservation ${reservation.bookingid}`);
          errors.push(`No available time for reservation ${reservation.bookingid}`);
          continue;
        }

        // Update the reservation's scheduled_trip_time
        const newScheduledTime = nextAvailableTime.toISOString();
        await Reservation.update(reservation.bookingid, {
          scheduled_trip_time: newScheduledTime,
          tripid: null, // Clear tripid so it gets reassigned to the new trip
        });

        // Update payment if exists
        if (reservation.paymentid) {
          try {
            const Payment = (await import('../models/Payment.js')).default;
            await Payment.update(reservation.paymentid, {
              tripid: null, // Clear tripid
            });
          } catch (error) {
            logger.warn(`[MatchingService] ⚠️ Failed to update payment.tripid for reservation ${reservation.bookingid}:`, error);
          }
        }

        adjusted.push({
          bookingid: reservation.bookingid,
          oldTime: oldScheduledTime.toISOString(),
          newTime: newScheduledTime,
        });

        logger.info(`[MatchingService] ✅ Adjusted reservation ${reservation.bookingid} from ${oldScheduledTime.toISOString()} to ${newScheduledTime}`);
      } catch (error) {
        logger.error(`[MatchingService] ❌ Error adjusting reservation ${reservation.bookingid}:`, error);
        errors.push(`Error adjusting reservation ${reservation.bookingid}: ${error.message}`);
      }
    }

    logger.info(`[MatchingService] ✅ Adjusted ${adjusted.length} reservation(s), ${errors.length} error(s)`);

    return {
      adjusted: adjusted.length,
      errors,
      details: adjusted,
    };
  } catch (error) {
    logger.error('[MatchingService] Error adjusting reservations for schedule change:', error);
    throw error;
  }
};
