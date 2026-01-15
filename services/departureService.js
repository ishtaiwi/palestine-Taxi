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
              const reservations = await Reservation.findByTripId(trip.tripid);
              if (reservations.length > 0) {
                shouldDepart = true;
                reason = 'scheduled_departure_with_bookings';
              } else {
                console.log(`[DepartureService] ⚠️ Trip ${trip.tripid} scheduled time arrived but no bookings`);
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

