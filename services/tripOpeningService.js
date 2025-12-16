import Trip from '../models/Trip.js';
import Vehicle from '../models/Vehicle.js';
import DriverQueue from '../models/DriverQueue.js';
import { distributeAllBookings } from './matchingService.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import logger from '../utils/logger.js';

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
    
    // Update trip_opening_time if not already set
    if (!trip.trip_opening_time) {
      const openingTime = new Date().toISOString();
      await Trip.update(tripid, {
        trip_opening_time: openingTime,
      });
      logger.info(`[TripOpeningService] ✅ Set trip_opening_time for trip ${tripid}`);
    }
    
    // Check if trip has vehicle assigned
    let vehicleAssigned = false;
    if (!trip.vehicleid) {
      logger.info(`[TripOpeningService] 🔍 Trip ${tripid} has no vehicle, attempting assignment from queue`);
      const assignmentResult = await assignVehicleFromQueue(tripid, trip.lineid);
      
      if (assignmentResult) {
        vehicleAssigned = true;
        // Update trip status back to scheduled if it was delayed
        if (trip.status === 'delayed') {
          await Trip.update(tripid, { status: 'scheduled' });
          logger.info(`[TripOpeningService] ✅ Trip ${tripid} status changed from delayed to scheduled`);
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
    const now = new Date().toISOString();
    
    // Get all scheduled and delayed trips (filtered by lineid if provided)
    // We need to check both statuses since delayed trips also need vehicles
    let allTrips = [];
    if (lineid) {
      const scheduledTrips = await Trip.findAll({ status: 'scheduled', lineid });
      const delayedTrips = await Trip.findAll({ status: 'delayed', lineid });
      allTrips = [...scheduledTrips, ...delayedTrips];
    } else {
      const scheduledTrips = await Trip.findAll({ status: 'scheduled' });
      const delayedTrips = await Trip.findAll({ status: 'delayed' });
      allTrips = [...scheduledTrips, ...delayedTrips];
    }
    
    // Filter trips that have trip_opening_time set but no vehicleid
    // and the opening time has passed (trip is opened)
    const waitingTrips = allTrips.filter(trip => 
      trip.trip_opening_time && 
      !trip.vehicleid &&
      new Date(trip.trip_opening_time) <= new Date(now) &&
      new Date(trip.deptime) >= new Date(now) // Only future trips
    );
    
    // Sort by deptime (earliest first)
    waitingTrips.sort((a, b) => new Date(a.deptime) - new Date(b.deptime));
    
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
          // Update trip status back to scheduled if it was delayed
          if (trip.status === 'delayed') {
            await Trip.update(trip.tripid, { status: 'scheduled' });
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
 * Mark trips as delayed if they have no vehicle 1 minute before scheduled departure
 * @returns {Promise<object>} - Results of delayed marking
 */
export const markTripsAsDelayed = async () => {
  try {
    const now = new Date();
    const oneMinuteBefore = new Date(now.getTime() + 60 * 1000); // 1 minute from now
    
    // Find trips that need to be marked as delayed
    // Status is scheduled, vehicleid is NULL, and deptime is 1 minute away
    const allTrips = await Trip.findAll({ status: 'scheduled' });
    
    const tripsToDelay = allTrips.filter(trip => {
      if (trip.vehicleid) return false; // Has vehicle, skip
      
      const deptime = new Date(trip.deptime);
      // Check if deptime is within 1 minute from now (but not in the past)
      return deptime >= now && deptime <= oneMinuteBefore;
    });
    
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

