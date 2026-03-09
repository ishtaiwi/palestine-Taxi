import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Vehicle from '../models/Vehicle.js';
import DriverQueue from '../models/DriverQueue.js';
import { markNoShowForTrip } from './noShowService.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import { getUtcNow, parseUtcDate } from '../utils/timeUtils.js';
import { TRIP_STATUS } from '../utils/constants.js';
import logger from '../utils/logger.js';

/**
 * Check if trip should depart early (vehicle is full)
 * @param {object} trip - The trip object
 * @returns {Promise<boolean>} - True if should depart early
 */
const shouldDepartEarly = async (trip) => {
  try {
    if (!trip.early_departure_allowed) {
      return false;
    }


    if (!trip.tripid || !trip.vehicleid) {
      return false;
    }


    const vehicle = await Vehicle.findById(trip.vehicleid);
    if (!vehicle) {
      return false;
    }


    const reservations = await Reservation.findByTripId(trip.tripid);
    const confirmedReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );


    const brokenSeats = (vehicle.broken_seats || []).length;



    const availableSeats = calculateAvailablePassengerSeats(
      vehicle.seatnum,
      confirmedReservations.length,
      0
    );


    return availableSeats <= 0;
  } catch (error) {
    console.error('[DepartureService] Error checking early departure:', error);
    return false;
  }
};

/**
 * Check if trip should depart at scheduled time
 * @param {object} trip - The trip object
 * @returns {Promise<boolean>} - True if should depart at scheduled time
 */
const shouldDepartScheduled = async (trip) => {
  try {
    if (!trip.scheduled_departure_enforced) {
      return false;
    }

    const now = getUtcNow();
    const deptime = parseUtcDate(trip.deptime);

    if (!deptime) return false;


    return deptime.getTime() <= now.getTime();
  } catch (error) {
    console.error('[DepartureService] Error checking scheduled departure:', error);
    return false;
  }
};

/**
 * Check if trip has at least one future booking (Future Booking Rule)
 * @param {object} trip - The trip object
 * @returns {Promise<boolean>} - True if has future booking
 */
const hasFutureBooking = async (trip) => {
  try {

    if (!trip.tripid) {
      return false;
    }

    const reservations = await Reservation.findByTripId(trip.tripid);
    const futureBookings = reservations.filter(
      r => r.booking_type === 'future' && (r.status === 'confirmed' || r.status === 'checked_in')
    );

    return futureBookings.length > 0;
  } catch (error) {
    console.error('[DepartureService] Error checking future bookings:', error);
    return false;
  }
};

/**
 * Depart a trip (change status to in_progress)
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - Departure result
 */
export const departTrip = async (tripid) => {
  try {
    console.log(`[DepartureService] 🚗 Departing trip ${tripid}`);


    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }


    if (trip.status !== 'scheduled' && trip.status !== 'open' && trip.status !== 'delayed') {
      console.log(`[DepartureService] ⚠️ Trip ${tripid} is not in scheduled/open/delayed status: ${trip.status}`);
      return {
        success: false,
        message: 'Trip is not in scheduled/open/delayed status',
      };
    }


    const updatedTrip = await Trip.update(tripid, {
      status: 'in_progress',
      deptime: getUtcNow().toISOString(),
    });


    if (trip.assigned_driverid) {
      try {
        await DriverQueue.removeDriverFromQueue(trip.assigned_driverid);
        console.log(`[DepartureService] ✅ Removed driver ${trip.assigned_driverid} from queue`);
      } catch (error) {
        console.error(`[DepartureService] ⚠️ Error removing driver from queue:`, error);

      }
    }

    // Send notifications to passengers and driver
    try {
      const { sendNotification, sendBulkNotifications, NOTIFICATION_TYPES } = await import('./notificationService.js');
      const Driver = (await import('../models/Driver.js')).default;
      const Line = (await import('../models/Line.js')).default;
      const Passenger = (await import('../models/Passenger.js')).default;

      const line = await Line.findById(updatedTrip.lineid);
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');

      // Notify driver
      if (updatedTrip.assigned_driverid) {
        const driver = await Driver.findById(updatedTrip.assigned_driverid);
        if (driver?.userid) {
          const tripDirection = updatedTrip.direction || 'going';
          const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, null, null, tripDirection);
          await sendNotification(
            driver.userid,
            NOTIFICATION_TYPES.TRIP_DEPARTED,
            {
              from: driverFromName,
              to: driverToName,
              tripid: tripid,
            },
            driverLanguage,
            { line, trip: updatedTrip } // Pass raw data for separate Arabic/English formatting
          );
        }
      }

      // Notify all passengers (send individually to use per-user language)
      const reservations = await Reservation.findByTripId(tripid);
      const activeReservations = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      );

      if (activeReservations.length > 0) {
        for (const reservation of activeReservations) {
          const passenger = await Passenger.findById(reservation.passengerid);
          if (passenger?.userid) {
            try {
              const tripDirection = updatedTrip.direction || 'going';
              const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, passenger.userid, null, null, tripDirection);
              await sendNotification(
                passenger.userid,
                NOTIFICATION_TYPES.TRIP_DEPARTED,
                {
                  from: passengerFromName,
                  to: passengerToName,
                  tripid: tripid,
                },
                passengerLanguage,
                { line, trip: updatedTrip } // Pass raw data for separate Arabic/English formatting
              );
            } catch (notifError) {
              logger.warn(`[DepartureService] Failed to send notification to passenger ${passenger.userid}:`, notifError);
            }
          }
        }
      }
    } catch (notifError) {
      console.error(`[DepartureService] Failed to send departure notifications for trip ${tripid}:`, notifError);
    }

    return {
      success: true,
      trip: updatedTrip,
    };
  } catch (error) {
    console.error(`[DepartureService] ❌ Error departing trip ${tripid}:`, error);
    throw error;
  }
};

/**
 * Check if a departure reminder was already sent for a trip
 * @param {string} tripid - Trip ID
 * @param {string} minutes - Minutes before departure ('15' or '5')
 * @returns {Promise<boolean>} - True if reminder was already sent
 */
const wasReminderSent = async (tripid, minutes) => {
  try {
    const Notification = (await import('../models/Notification.js')).default;
    const { NOTIFICATION_TYPES } = await import('../utils/notificationTemplates.js');

    // Check if a TRIP_DEPARTURE_SOON notification was already sent for this trip with this minutes value
    const notifications = await Notification.findByTripId(tripid, NOTIFICATION_TYPES.TRIP_DEPARTURE_SOON);
    if (!notifications || notifications.length === 0) {
      return false;
    }

    // Check if any notification matches the minutes value
    const matchingNotification = notifications.find(notif => {
      // Check if the notification data contains the minutes value
      if (notif.data) {
        let dataObj = notif.data;
        // Handle both string JSON and object
        if (typeof dataObj === 'string') {
          try {
            dataObj = JSON.parse(dataObj);
          } catch (e) {
            return false;
          }
        }
        // Check if minutes match (handle both string and number)
        const notifMinutes = dataObj.minutes;
        return notifMinutes === minutes || notifMinutes === String(minutes) || String(notifMinutes) === String(minutes);
      }
      return false;
    });

    return !!matchingNotification;
  } catch (error) {
    console.error(`[DepartureService] Error checking if reminder was sent:`, error);
    return false; // If we can't check, assume not sent to allow sending
  }
};

/**
 * Send departure reminder notifications for a specific time window
 * @param {number} minutesBefore - Minutes before departure (15 or 5)
 * @returns {Promise<object>} - Reminder results
 */
const sendDepartureReminderForMinutes = async (minutesBefore) => {
  try {
    const now = getUtcNow();

    // Find trips departing in approximately the specified minutes
    const allTrips = await Trip.findAll({ status: TRIP_STATUS.OPEN });
    const tripsNeedingReminder = allTrips.filter(trip => {
      if (!trip.deptime) return false;
      const deptime = parseUtcDate(trip.deptime);
      if (!deptime) return false;

      // Check if departure is within the time window (1 minute window)
      const diffMinutes = (deptime.getTime() - now.getTime()) / (1000 * 60);
      const lowerBound = minutesBefore - 1;
      const upperBound = minutesBefore + 1;
      return diffMinutes >= lowerBound && diffMinutes <= upperBound;
    });

    if (tripsNeedingReminder.length === 0) {
      return { success: true, reminded: 0 };
    }

    const { sendNotification, NOTIFICATION_TYPES } = await import('./notificationService.js');
    const Driver = (await import('../models/Driver.js')).default;
    const Line = (await import('../models/Line.js')).default;
    const Passenger = (await import('../models/Passenger.js')).default;
    const Reservation = (await import('../models/Reservation.js')).default;

    let remindedCount = 0;

    for (const trip of tripsNeedingReminder) {
      try {
        // Check if reminder was already sent for this trip at this time window
        const alreadySent = await wasReminderSent(trip.tripid, String(minutesBefore));
        if (alreadySent) {
          console.log(`[DepartureService] ⏭️ Skipping ${minutesBefore}-min reminder for trip ${trip.tripid} - already sent`);
          continue;
        }

        const line = await Line.findById(trip.lineid);
        const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');

        // Notify driver
        if (trip.assigned_driverid) {
          const driver = await Driver.findById(trip.assigned_driverid);
          if (driver?.userid) {
            const tripDirection = trip.direction || 'going';
            const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, null, null, tripDirection);
            await sendNotification(
              driver.userid,
              NOTIFICATION_TYPES.TRIP_DEPARTURE_SOON,
              {
                from: driverFromName,
                to: driverToName,
                minutes: String(minutesBefore),
                tripid: trip.tripid,
              },
              driverLanguage,
              { line, trip } // Pass raw data for separate Arabic/English formatting
            );
          }
        }

        // Notify passengers (send individually to use per-user language)
        const reservations = await Reservation.findByTripId(trip.tripid);
        const activeReservations = reservations.filter(
          r => r.status === 'confirmed' || r.status === 'checked_in'
        );

        if (activeReservations.length > 0) {
          for (const reservation of activeReservations) {
            const passenger = await Passenger.findById(reservation.passengerid);
            if (passenger?.userid) {
              try {
                const tripDirection = trip.direction || 'going';
                const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, passenger.userid, null, null, tripDirection);
                await sendNotification(
                  passenger.userid,
                  NOTIFICATION_TYPES.TRIP_DEPARTURE_SOON,
                  {
                    from: passengerFromName,
                    to: passengerToName,
                    minutes: String(minutesBefore),
                    tripid: trip.tripid,
                  },
                  passengerLanguage,
                  { line, trip } // Pass raw data for separate Arabic/English formatting
                );
              } catch (notifError) {
                console.error(`[DepartureService] Failed to send departure reminder to passenger ${passenger.userid}:`, notifError);
              }
            }
          }
        }

        remindedCount++;
        console.log(`[DepartureService] ✅ Sent ${minutesBefore}-min reminder for trip ${trip.tripid}`);
      } catch (error) {
        console.error(`[DepartureService] Error sending reminder for trip ${trip.tripid}:`, error);
      }
    }

    return { success: true, reminded: remindedCount };
  } catch (error) {
    console.error(`[DepartureService] Error in sendDepartureReminderForMinutes (${minutesBefore} min):`, error);
    return { success: false, error: error.message };
  }
};

/**
 * Send departure reminder notifications (15 minutes and 5 minutes before departure)
 * @returns {Promise<object>} - Reminder results
 */
export const sendDepartureReminders = async () => {
  try {
    // Send 15-minute reminders
    const result15 = await sendDepartureReminderForMinutes(15);

    // Send 5-minute reminders
    const result5 = await sendDepartureReminderForMinutes(5);

    return {
      success: true,
      reminded15: result15.reminded || 0,
      reminded5: result5.reminded || 0,
      reminded: (result15.reminded || 0) + (result5.reminded || 0),
    };
  } catch (error) {
    console.error('[DepartureService] Error in sendDepartureReminders:', error);
    return { success: false, error: error.message };
  }
};

/**
 * Check and depart trips that should depart
 * @returns {Promise<object>} - Departure results
 */
export const checkAndDepartTrips = async () => {
  try {
    console.log(`[DepartureService] 🔍 Checking trips that should depart`);


    const tripsNeedingDeparture = await Trip.findTripsNeedingDeparture();

    if (tripsNeedingDeparture.length === 0) {
      console.log(`[DepartureService] ✅ No trips need to depart at this time`);
      return {
        success: true,
        departed: 0,
        trips: [],
      };
    }

    console.log(`[DepartureService] 📅 Found ${tripsNeedingDeparture.length} trips to check`);

    const results = [];


    for (const trip of tripsNeedingDeparture) {
      try {
        let shouldDepart = false;
        let reason = '';


        if (await shouldDepartEarly(trip)) {
          shouldDepart = true;
          reason = 'early_departure_full';
        }

        else if (await shouldDepartScheduled(trip)) {

          const hasFuture = await hasFutureBooking(trip);
          if (hasFuture) {
            shouldDepart = true;
            reason = 'scheduled_departure_with_future_booking';
          } else {

            if (!trip.tripid) {
              console.log(`[DepartureService] ⚠️ Trip ${trip.tripid} scheduled time arrived but no trip ID`);
            } else {
              // Check totalbookings field directly from trip table
              const totalBookings = trip.totalbookings || 0;

              if (totalBookings > 0) {
                shouldDepart = true;
                reason = 'scheduled_departure_with_bookings';
              } else {
                // Trip has passed departure time with no bookings - cancel it
                const now = getUtcNow();
                const deptime = parseUtcDate(trip.deptime);
                if (deptime && deptime.getTime() <= now.getTime()) {
                  await Trip.update(trip.tripid, {
                    status: TRIP_STATUS.CANCELLED
                  });
                  logger.info(`[DepartureService] 🚫 Cancelled trip ${trip.tripid} - departure time passed with no bookings`);
                  results.push({
                    tripid: trip.tripid,
                    success: true,
                    reason: 'cancelled_no_reservations',
                    cancelled: true,
                  });
                  continue; // Skip to next trip
                } else {
                  console.log(`[DepartureService] ⚠️ Trip ${trip.tripid} scheduled time arrived but no bookings`);
                }
              }
            }
          }
        }

        if (shouldDepart) {
          const result = await departTrip(trip.tripid);


          try {
            await markNoShowForTrip(trip.tripid);
            console.log(`[DepartureService] ✅ Checked No-Show for trip ${trip.tripid}`);
          } catch (error) {
            console.error(`[DepartureService] ⚠️ Error checking No-Show for trip ${trip.tripid}:`, error);

          }

          results.push({
            tripid: trip.tripid,
            success: result.success,
            reason,
          });
        } else {
          results.push({
            tripid: trip.tripid,
            success: false,
            reason: 'not_ready',
          });
        }
      } catch (error) {
        console.error(`[DepartureService] ❌ Error processing trip ${trip.tripid}:`, error);
        results.push({
          tripid: trip.tripid,
          success: false,
          error: error.message,
        });
      }
    }

    const successCount = results.filter(r => r.success).length;

    return {
      success: true,
      departed: successCount,
      total: tripsNeedingDeparture.length,
      trips: results,
    };
  } catch (error) {
    console.error('[DepartureService] ❌ Error checking and departing trips:', error);
    throw error;
  }
};

