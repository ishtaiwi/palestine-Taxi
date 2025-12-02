import Trip from '../models/Trip.js';
import { distributeAllBookings } from './matchingService.js';

/**
 * Open a scheduled trip (make it available for bookings)
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - Opening result
 */
export const openScheduledTrip = async (tripid) => {
  try {
    console.log(`[TripOpeningService] 🚀 Opening trip ${tripid}`);
    
    // Get trip details
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }
    
    if (trip.status !== 'scheduled') {
      console.log(`[TripOpeningService] ⚠️ Trip ${tripid} is not in scheduled status`);
      return {
        success: false,
        message: 'Trip is not in scheduled status',
      };
    }
    
    // Update trip_opening_time if not already set
    if (!trip.trip_opening_time) {
      const openingTime = new Date().toISOString();
      await Trip.update(tripid, {
        trip_opening_time: openingTime,
      });
      console.log(`[TripOpeningService] ✅ Set trip_opening_time for trip ${tripid}`);
    }
    
    // Distribute bookings using Matching Engine
    console.log(`[TripOpeningService] 📋 Distributing bookings for trip ${tripid}`);
    const distributionResult = await distributeAllBookings(tripid);
    
    return {
      success: true,
      trip,
      distribution: distributionResult,
    };
  } catch (error) {
    console.error(`[TripOpeningService] ❌ Error opening trip ${tripid}:`, error);
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
    console.log(`[TripOpeningService] 🔍 Finding trips that need to be opened (${openingWindowMinutes} minutes before departure)`);
    
    // Find trips that need opening
    const tripsToOpen = await Trip.findTripsNeedingOpening(openingWindowMinutes);
    
    if (tripsToOpen.length === 0) {
      console.log(`[TripOpeningService] ✅ No trips need to be opened at this time`);
      return {
        success: true,
        opened: 0,
        trips: [],
      };
    }
    
    console.log(`[TripOpeningService] 📅 Found ${tripsToOpen.length} trips to open`);
    
    const results = [];
    
    // Open each trip
    for (const trip of tripsToOpen) {
      try {
        const result = await openScheduledTrip(trip.tripid);
        results.push({
          tripid: trip.tripid,
          success: result.success,
          distribution: result.distribution,
        });
      } catch (error) {
        console.error(`[TripOpeningService] ❌ Error opening trip ${trip.tripid}:`, error);
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
      opened: successCount,
      total: tripsToOpen.length,
      trips: results,
    };
  } catch (error) {
    console.error('[TripOpeningService] ❌ Error opening scheduled trips:', error);
    throw error;
  }
};

