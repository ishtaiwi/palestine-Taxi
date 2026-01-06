import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Vehicle from '../models/Vehicle.js';
import DriverQueue from '../models/DriverQueue.js';
import { markNoShowForTrip } from './noShowService.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import { getUtcNow, parseUtcDate } from '../utils/timeUtils.js';

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

    // Get vehicle details
    const vehicle = await Vehicle.findById(trip.vehicleid);
    if (!vehicle) {
      return false;
    }

    // Get reservations for this trip
    const reservations = await Reservation.findByTripId(trip.tripid);
    const confirmedReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );

    // Get broken seats count (for logging only, not used in calculation)
    const brokenSeats = (vehicle.broken_seats || []).length;

    // Available passenger seats = (total seats - 1 driver seat) - reserved
    // Note: broken seats are NOT subtracted - they are handled in seat selection UI
    const availableSeats = calculateAvailablePassengerSeats(
      vehicle.seatnum,
      confirmedReservations.length,
      0
    );

    // Should depart if vehicle is full (no available seats for passengers)
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

    // Should depart if scheduled time has arrived (UTC comparison)
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

    // Get trip details
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }

    // Allow scheduled, open, or delayed trips to depart
    if (trip.status !== 'scheduled' && trip.status !== 'open' && trip.status !== 'delayed') {
      console.log(`[DepartureService] ⚠️ Trip ${tripid} is not in scheduled/open/delayed status: ${trip.status}`);
      return {
        success: false,
        message: 'Trip is not in scheduled/open/delayed status',
      };
    }

    // Update trip status to in_progress
    const updatedTrip = await Trip.update(tripid, {
      status: 'in_progress',
      deptime: getUtcNow().toISOString(), // Update actual departure time (UTC)
    });

    // Remove driver from queue if assigned
    if (trip.assigned_driverid) {
      try {
        await DriverQueue.removeDriverFromQueue(trip.assigned_driverid);
        console.log(`[DepartureService] ✅ Removed driver ${trip.assigned_driverid} from queue`);
      } catch (error) {
        console.error(`[DepartureService] ⚠️ Error removing driver from queue:`, error);
        // Don't fail the departure if queue removal fails
      }
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
 * Check and depart trips that should depart
 * @returns {Promise<object>} - Departure results
 */
export const checkAndDepartTrips = async () => {
  try {
    console.log(`[DepartureService] 🔍 Checking trips that should depart`);

    // Find trips that need departure
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

    // Check each trip
    for (const trip of tripsNeedingDeparture) {
      try {
        let shouldDepart = false;
        let reason = '';

        // Rule 1: Early Departure (vehicle is full)
        if (await shouldDepartEarly(trip)) {
          shouldDepart = true;
          reason = 'early_departure_full';
        }
        // Rule 2: Scheduled Departure (time has arrived)
        else if (await shouldDepartScheduled(trip)) {
          // Rule 3: Future Booking Rule (must have at least one future booking)
          const hasFuture = await hasFutureBooking(trip);
          if (hasFuture) {
            shouldDepart = true;
            reason = 'scheduled_departure_with_future_booking';
          } else {
            // Check if trip has any bookings at all
            const reservations = await Reservation.findByTripId(trip.tripid);
            if (reservations.length > 0) {
              shouldDepart = true;
              reason = 'scheduled_departure_with_bookings';
            } else {
              console.log(`[DepartureService] ⚠️ Trip ${trip.tripid} scheduled time arrived but no bookings`);
            }
          }
        }

        if (shouldDepart) {
          const result = await departTrip(trip.tripid);

          // Mark No-Show reservations when trip departs
          try {
            await markNoShowForTrip(trip.tripid);
            console.log(`[DepartureService] ✅ Checked No-Show for trip ${trip.tripid}`);
          } catch (error) {
            console.error(`[DepartureService] ⚠️ Error checking No-Show for trip ${trip.tripid}:`, error);
            // Don't fail departure if No-Show check fails
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

