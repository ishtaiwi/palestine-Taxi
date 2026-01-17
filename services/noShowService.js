import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { RESERVATION_STATUS } from '../utils/constants.js';

/**
 * Mark reservations as No-Show for a trip that is departing
 * @param {string} tripid - The trip ID
 * @returns {Promise<object>} - No-Show result
 */
export const markNoShowForTrip = async (tripid) => {
  try {
    console.log(`[NoShowService] 🔍 Checking No-Show for trip ${tripid}`);
    
    // Get trip details
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }
    
    // Get all reservations for this trip
    const reservations = await Reservation.findByTripId(tripid);
    
    // Filter reservations that are confirmed but not checked in
    // No-Show: confirmed reservations that haven't been checked in
    const noShowReservations = reservations.filter(
      r => {
        const isConfirmed = r.status === 'confirmed';
        const isNotCheckedIn = r.status !== 'checked_in' && r.status !== 'cancelled' && r.status !== 'no_show';
        return isConfirmed && isNotCheckedIn;
      }
    );
    
    if (noShowReservations.length === 0) {
      console.log(`[NoShowService] ✅ No No-Show reservations for trip ${tripid}`);
      return {
        success: true,
        marked: 0,
        reservations: [],
      };
    }
    
    console.log(`[NoShowService] 📋 Found ${noShowReservations.length} No-Show reservations`);
    
    const results = [];
    
    // Mark each reservation as No-Show and process refund (no refund for No-Show)
    for (const reservation of noShowReservations) {
      try {
        // Update reservation status to no_show
        await Reservation.update(reservation.bookingid, {
          status: RESERVATION_STATUS.NO_SHOW,
        });
        
        // No refund for No-Show (full charge deducted)
        // Payment is already completed, so no refund needed
        
        // Send notifications
        try {
          const { sendNotification, NOTIFICATION_TYPES } = await import('./notificationService.js');
          const Passenger = (await import('../models/Passenger.js')).default;
          const Trip = (await import('../models/Trip.js')).default;
          const Driver = (await import('../models/Driver.js')).default;
          const Line = (await import('../models/Line.js')).default;
          
          const passenger = await Passenger.findById(reservation.passengerid);
          const trip = await Trip.findById(tripid);
          const line = trip ? await Line.findById(trip.lineid) : null;
          const passengerName = passenger?.user?.fullname || 'Passenger';
          const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');

          // Notify passenger
          if (passenger?.userid) {
            const tripDirection = trip?.direction || 'going';
            const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, passenger.userid, null, null, tripDirection);
            await sendNotification(
              passenger.userid,
              NOTIFICATION_TYPES.NO_SHOW_WARNING,
              {
                from: passengerFromName,
                to: passengerToName,
              },
              passengerLanguage,
              { line, trip } // Pass raw data for separate Arabic/English formatting
            );
          }

          // Notify driver
          if (trip?.assigned_driverid) {
            const driver = await Driver.findById(trip.assigned_driverid);
            if (driver?.userid) {
              const tripDirection = trip?.direction || 'going';
              const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, null, null, tripDirection);
              await sendNotification(
                driver.userid,
                NOTIFICATION_TYPES.NO_SHOW_MARKED,
                {
                  passengerName,
                  from: driverFromName,
                  to: driverToName,
                },
                driverLanguage,
                { line, trip } // Pass raw data for separate Arabic/English formatting
              );
            }
          }
        } catch (notifError) {
          console.error(`[NoShowService] Failed to send no-show notifications for reservation ${reservation.bookingid}:`, notifError);
        }
        
        results.push({
          bookingid: reservation.bookingid,
          success: true,
          action: 'marked_no_show',
          refund: 0, // No refund for No-Show
        });
        
        console.log(`[NoShowService] ✅ Marked reservation ${reservation.bookingid} as No-Show`);
      } catch (error) {
        console.error(`[NoShowService] ❌ Error marking reservation ${reservation.bookingid} as No-Show:`, error);
        results.push({
          bookingid: reservation.bookingid,
          success: false,
          error: error.message,
        });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    
    return {
      success: true,
      marked: successCount,
      total: noShowReservations.length,
      reservations: results,
    };
  } catch (error) {
    console.error(`[NoShowService] ❌ Error marking No-Show for trip ${tripid}:`, error);
    throw error;
  }
};

/**
 * Check and mark No-Show for all departing trips
 * This is called by the background job to catch any missed No-Shows
 * @returns {Promise<object>} - No-Show results
 */
export const checkNoShowForDepartingTrips = async () => {
  try {
    console.log(`[NoShowService] 🔍 Checking No-Show for departing trips`);
    
    // Get trips that just started (in_progress) - these should have No-Show checked
    const inProgressTrips = await Trip.findAll({ status: 'in_progress' });
    
    // Also check trips that are scheduled but past departure time (should have departed)
    const tripsNeedingDeparture = await Trip.findTripsNeedingDeparture();
    
    const allTrips = [...tripsNeedingDeparture, ...inProgressTrips];
    const uniqueTrips = Array.from(new Map(allTrips.map(t => [t.tripid, t])).values());
    
    if (uniqueTrips.length === 0) {
      console.log(`[NoShowService] ✅ No trips need No-Show check at this time`);
      return {
        success: true,
        checked: 0,
        trips: [],
      };
    }
    
    console.log(`[NoShowService] 📅 Found ${uniqueTrips.length} trips to check for No-Show`);
    
    const results = [];
    
    // Check each trip
    for (const trip of uniqueTrips) {
      try {
        const result = await markNoShowForTrip(trip.tripid);
        results.push({
          tripid: trip.tripid,
          ...result,
        });
      } catch (error) {
        console.error(`[NoShowService] ❌ Error checking No-Show for trip ${trip.tripid}:`, error);
        results.push({
          tripid: trip.tripid,
          success: false,
          error: error.message,
        });
      }
    }
    
    const totalMarked = results.reduce((sum, r) => sum + (r.marked || 0), 0);
    
    return {
      success: true,
      checked: uniqueTrips.length,
      totalMarked,
      trips: results,
    };
  } catch (error) {
    console.error('[NoShowService] ❌ Error checking No-Show:', error);
    throw error;
  }
};

