import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
import { BOOKING_TYPE } from '../utils/constants.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';

/**
 * Get the next driver from the queue for a specific line
 * @param {string} lineid - The line ID
 * @returns {Promise<object|null>} - The next driver in queue or null
 */
export const getNextDriverFromQueue = async (lineid) => {
  try {
    const queue = await DriverQueue.getActiveByLine(lineid);
    if (!queue || queue.length === 0) {
      return null;
    }
    
    // Return the first driver in queue (oldest joined_at)
    return queue[0];
  } catch (error) {
    console.error('[MatchingService] Error getting next driver from queue:', error);
    throw error;
  }
};

/**
 * Assign a driver to a trip from the queue
 * @param {string} tripid - The trip ID
 * @param {string} lineid - The line ID
 * @returns {Promise<object|null>} - The assigned driver or null
 */
export const assignDriverToTrip = async (tripid, lineid) => {
  try {
    const driverQueueEntry = await getNextDriverFromQueue(lineid);
    
    if (!driverQueueEntry) {
      console.log(`[MatchingService] No drivers available in queue for line ${lineid}`);
      return null;
    }
    
    const driverid = driverQueueEntry.driverid;
    
    // Assign driver to trip
    await Trip.assignDriver(tripid, driverid);
    
    console.log(`[MatchingService] ✅ Driver ${driverid} assigned to trip ${tripid}`);
    
    return {
      driverid,
      driver: driverQueueEntry.driver,
      queueEntry: driverQueueEntry,
    };
  } catch (error) {
    console.error('[MatchingService] Error assigning driver to trip:', error);
    throw error;
  }
};

/**
 * Get available seats for a vehicle (excluding broken seats and existing reservations)
 * @param {object} vehicle - The vehicle object
 * @param {string} tripid - The trip ID (optional, for checking existing reservations)
 * @returns {Promise<number>} - Number of available seats
 */
const getAvailableSeats = async (vehicle, tripid = null) => {
  try {
    let reservedSeats = 0;
    
    // If trip ID provided, count reservations for this trip
    if (tripid) {
      const reservations = await Reservation.findByTripId(tripid);
      reservedSeats = reservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      ).length;
    }
    
    // Get broken seats count (for logging only, not used in calculation)
    const brokenSeats = (vehicle.broken_seats || []).length;
    
    // Available passenger seats = (total seats - 1 driver seat) - reserved
    // Note: broken seats are NOT subtracted - they are handled in seat selection UI
    const availableSeats = calculateAvailablePassengerSeats(
      vehicle.seatnum, 
      reservedSeats, 
      0
    );
    
    return availableSeats;
  } catch (error) {
    console.error('[MatchingService] Error calculating available seats:', error);
    throw error;
  }
};

/**
 * Find or create trip for a driver at a specific time
 * @param {string} driverid - The driver ID
 * @param {string} lineid - The line ID
 * @param {string} deptime - The departure time
 * @returns {Promise<object>} - The trip object
 */
const findOrCreateDriverTrip = async (driverid, lineid, deptime) => {
  try {
    // Get driver's vehicle
    const vehicles = await Vehicle.findByDriverId(driverid);
    if (vehicles.length === 0) {
      throw new Error(`Driver ${driverid} has no vehicle`);
    }
    
    const vehicle = vehicles[0];
    
    // Check if trip already exists for this driver at this time
    const existingTrips = await Trip.findAssignedTrips(driverid, {
      fromNow: false,
    });
    
    const tripAtTime = existingTrips.find(
      t => new Date(t.deptime).getTime() === new Date(deptime).getTime()
    );
    
    if (tripAtTime) {
      return tripAtTime;
    }
    
    // Create new trip for this driver
    // Note: broken seats are NOT subtracted - they are handled in seat selection UI
    const vehicleType = vehicle.seatnum === 5 ? '4+1' : vehicle.seatnum === 8 ? '7+1' : `${vehicle.seatnum} seats`;
    const maxPassengerSeats = calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0);
    console.log(`[MatchingService] 🚗 Creating trip for driver ${driverid} with ${vehicleType} vehicle (${vehicle.seatnum} total seats, ${maxPassengerSeats} passenger seats)`);
    
    const tripData = {
      lineid,
      vehicleid: vehicle.vehicleid,
      deptime,
      status: 'scheduled',
      availableseats: maxPassengerSeats,
      totalbookings: 0,
      assigned_driverid: driverid,
    };
    
    const trip = await Trip.create(tripData);
    await Trip.assignDriver(trip.tripid, driverid);
    
    return trip;
  } catch (error) {
    console.error('[MatchingService] Error finding/creating driver trip:', error);
    throw error;
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
    console.log(`[MatchingService] 🚀 Starting distribution of future bookings for time ${scheduledTripTime}`);
    
    // Get future bookings for this trip time (not yet assigned to any trip)
    const futureBookings = await Reservation.findFutureBookingsForTrip(scheduledTripTime, {});
    
    // Filter out bookings already assigned to trips
    const unassignedBookings = futureBookings.filter(b => !b.tripid);
    
    if (unassignedBookings.length === 0) {
      console.log(`[MatchingService] No unassigned future bookings found for time ${scheduledTripTime}`);
      return {
        success: true,
        distributed: 0,
        remaining: 0,
        driversUsed: [],
      };
    }
    
    console.log(`[MatchingService] Found ${unassignedBookings.length} unassigned future bookings`);
    
    let distributedCount = 0;
    let remainingBookings = [...unassignedBookings];
    const driversUsed = [];
    
    // If tripid is provided, use that specific trip for distribution
    let targetTrip = null;
    if (tripid) {
      targetTrip = await Trip.findById(tripid);
      if (!targetTrip || !targetTrip.vehicleid) {
        console.log(`[MatchingService] ⚠️ Trip ${tripid} not found or has no vehicle, cannot distribute bookings`);
        return {
          success: false,
          distributed: 0,
          remaining: unassignedBookings.length,
          driversUsed: [],
        };
      }
      console.log(`[MatchingService] Using existing trip ${tripid} for distribution`);
    }
    
    // Distribute future bookings to drivers in queue order (Rule 1: Future Bookings first)
    while (remainingBookings.length > 0) {
      // If using existing trip, assign all bookings to it
      if (targetTrip) {
        const driverVehicle = await Vehicle.findById(targetTrip.vehicleid);
        const availableSeats = await getAvailableSeats(driverVehicle, targetTrip.tripid);
        
        if (availableSeats <= 0) {
          console.log(`[MatchingService] ⚠️ Trip ${targetTrip.tripid} is full`);
          break;
        }
        
        const bookingsToAssign = remainingBookings.slice(0, availableSeats);
        
        for (const booking of bookingsToAssign) {
          await Reservation.update(booking.bookingid, {
            tripid: targetTrip.tripid,
          });
          distributedCount++;
        }
        
        remainingBookings = remainingBookings.slice(bookingsToAssign.length);
        
        driversUsed.push({
          driverid: targetTrip.assigned_driverid,
          tripid: targetTrip.tripid,
          bookingsAssigned: bookingsToAssign.length,
          vehicle: driverVehicle,
        });
        
        console.log(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} future bookings to trip ${targetTrip.tripid}`);
        break; // All bookings assigned to this trip
      }
      
      // Original logic: Get next driver from queue (Rule 2: First driver in queue)
      const driverQueueEntry = await getNextDriverFromQueue(lineid);
      
      if (!driverQueueEntry) {
        console.log(`[MatchingService] ⚠️ No more drivers available in queue`);
        break;
      }
      
      const driverid = driverQueueEntry.driverid;
      
      // Find or create trip for this driver at scheduled time
      const driverTrip = await findOrCreateDriverTrip(driverid, lineid, scheduledTripTime);
      
      // Get driver's vehicle
      const driverVehicle = await Vehicle.findById(driverTrip.vehicleid);
      
      // Log vehicle type for debugging
      const vehicleType = driverVehicle.seatnum === 5 ? '4+1' : driverVehicle.seatnum === 8 ? '7+1' : `${driverVehicle.seatnum} seats`;
      const maxPassengerSeats = driverVehicle.seatnum - 1; // Excluding driver
      console.log(`[MatchingService] 📦 Driver ${driverid} has ${vehicleType} vehicle (${driverVehicle.seatnum} total, ${maxPassengerSeats} passenger seats)`);
      
      // Calculate available seats for this trip
      const availableSeats = await getAvailableSeats(driverVehicle, driverTrip.tripid);
      
      if (availableSeats <= 0) {
        console.log(`[MatchingService] ⚠️ Driver ${driverid} vehicle (${vehicleType}) is full, moving to next driver`);
        // Remove driver from queue and move to next (Rule 3: Move to next driver when full)
        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }
      
      // Assign bookings to this driver (up to available seats)
      const bookingsToAssign = remainingBookings.slice(0, availableSeats);
      
      // Link bookings to this driver's trip
      for (const booking of bookingsToAssign) {
        await Reservation.update(booking.bookingid, {
          tripid: driverTrip.tripid,
        });
        
        distributedCount++;
      }
      
      // Remove assigned bookings from remaining list
      remainingBookings = remainingBookings.slice(bookingsToAssign.length);
      
      driversUsed.push({
        driverid,
        tripid: driverTrip.tripid,
        bookingsAssigned: bookingsToAssign.length,
        vehicle: driverVehicle,
      });
      
      console.log(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} future bookings to driver ${driverid} (${vehicleType} vehicle, trip ${driverTrip.tripid})`);
      
      // If vehicle is full, remove driver from queue (Rule 3: Move to next when full)
      if (availableSeats === bookingsToAssign.length) {
        console.log(`[MatchingService] 🚗 Driver ${driverid} vehicle (${vehicleType}) is now full, removing from queue`);
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
    console.error('[MatchingService] Error distributing future bookings:', error);
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
    console.log(`[MatchingService] 🚀 Starting distribution of instant bookings for line ${lineid}`);
    
    // Get instant bookings not yet assigned (ordered by bookedat timestamp - Rule 4)
    // If nextTripTime provided, use it; otherwise get the next scheduled trip time
    let targetTripTime = nextTripTime;
    
    if (!targetTripTime) {
      // Find the next scheduled trip for this line
      const upcomingTrips = await Trip.findUpcoming({ lineid, status: 'scheduled' });
      if (upcomingTrips.length > 0) {
        targetTripTime = upcomingTrips[0].deptime;
      } else {
        console.log(`[MatchingService] ⚠️ No upcoming trips found for line ${lineid}`);
        return {
          success: true,
          distributed: 0,
          remaining: 0,
          driversUsed: [],
        };
      }
    }
    
    // Get all instant bookings (ordered by bookedat timestamp - Rule 4)
    // We need to get bookings that are either unassigned or assigned to trips at the target time
    const allInstantBookings = await Reservation.findByBookingType(BOOKING_TYPE.INSTANT, {
      status: 'confirmed',
    });
    
    // Filter unassigned bookings and sort by bookedat (timestamp) - Rule 4
    // Unassigned means tripid is null or the trip is not at the target time
    const unassignedBookings = allInstantBookings
      .filter(b => {
        if (!b.tripid) return true;
        // If assigned, check if trip is at target time
        if (b.trip && b.trip.deptime) {
          return new Date(b.trip.deptime).getTime() === new Date(targetTripTime).getTime();
        }
        return false;
      })
      .sort((a, b) => new Date(a.bookedat) - new Date(b.bookedat));
    
    if (unassignedBookings.length === 0) {
      console.log(`[MatchingService] No unassigned instant bookings found`);
      return {
        success: true,
        distributed: 0,
        remaining: 0,
        driversUsed: [],
      };
    }
    
    console.log(`[MatchingService] Found ${unassignedBookings.length} unassigned instant bookings (ordered by timestamp)`);
    
    let distributedCount = 0;
    let remainingBookings = [...unassignedBookings];
    const driversUsed = [];
    
    // If tripid is provided, use that specific trip for distribution
    let targetTrip = null;
    if (tripid) {
      targetTrip = await Trip.findById(tripid);
      if (!targetTrip || !targetTrip.vehicleid) {
        console.log(`[MatchingService] ⚠️ Trip ${tripid} not found or has no vehicle, cannot distribute bookings`);
        return {
          success: false,
          distributed: 0,
          remaining: unassignedBookings.length,
          driversUsed: [],
        };
      }
      console.log(`[MatchingService] Using existing trip ${tripid} for instant booking distribution`);
    }
    
    // Distribute instant bookings to drivers in queue order (Rule 2: First driver in queue)
    while (remainingBookings.length > 0) {
      // If using existing trip, assign all bookings to it
      if (targetTrip) {
        const driverVehicle = await Vehicle.findById(targetTrip.vehicleid);
        const availableSeats = await getAvailableSeats(driverVehicle, targetTrip.tripid);
        
        if (availableSeats <= 0) {
          console.log(`[MatchingService] ⚠️ Trip ${targetTrip.tripid} is full`);
          break;
        }
        
        const bookingsToAssign = remainingBookings.slice(0, availableSeats);
        
        for (const booking of bookingsToAssign) {
          await Reservation.update(booking.bookingid, {
            tripid: targetTrip.tripid,
          });
          distributedCount++;
        }
        
        remainingBookings = remainingBookings.slice(bookingsToAssign.length);
        
        driversUsed.push({
          driverid: targetTrip.assigned_driverid,
          tripid: targetTrip.tripid,
          bookingsAssigned: bookingsToAssign.length,
          vehicle: driverVehicle,
        });
        
        console.log(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} instant bookings to trip ${targetTrip.tripid}`);
        break; // All bookings assigned to this trip
      }
      
      // Original logic: Get next driver from queue
      const driverQueueEntry = await getNextDriverFromQueue(lineid);
      
      if (!driverQueueEntry) {
        console.log(`[MatchingService] ⚠️ No more drivers available in queue`);
        break;
      }
      
      const driverid = driverQueueEntry.driverid;
      
      // Find or create trip for this driver at target time
      const driverTrip = await findOrCreateDriverTrip(driverid, lineid, targetTripTime);
      
      // Get driver's vehicle
      const driverVehicle = await Vehicle.findById(driverTrip.vehicleid);
      
      // Log vehicle type for debugging
      const vehicleType = driverVehicle.seatnum === 5 ? '4+1' : driverVehicle.seatnum === 8 ? '7+1' : `${driverVehicle.seatnum} seats`;
      const maxPassengerSeats = driverVehicle.seatnum - 1; // Excluding driver
      console.log(`[MatchingService] 📦 Driver ${driverid} has ${vehicleType} vehicle (${driverVehicle.seatnum} total, ${maxPassengerSeats} passenger seats)`);
      
      // Calculate available seats for this trip
      const availableSeats = await getAvailableSeats(driverVehicle, driverTrip.tripid);
      
      if (availableSeats <= 0) {
        console.log(`[MatchingService] ⚠️ Driver ${driverid} vehicle (${vehicleType}) is full, moving to next driver`);
        // Remove driver from queue and move to next (Rule 3: Move to next when full)
        await DriverQueue.removeDriverFromQueue(driverid);
        continue;
      }
      
      // Assign bookings to this driver (up to available seats, in timestamp order - Rule 4)
      const bookingsToAssign = remainingBookings.slice(0, availableSeats);
      
      // Link bookings to this driver's trip
      for (const booking of bookingsToAssign) {
        await Reservation.update(booking.bookingid, {
          tripid: driverTrip.tripid,
        });
        
        distributedCount++;
      }
      
      // Remove assigned bookings from remaining list
      remainingBookings = remainingBookings.slice(bookingsToAssign.length);
      
      driversUsed.push({
        driverid,
        tripid: driverTrip.tripid,
        bookingsAssigned: bookingsToAssign.length,
        vehicle: driverVehicle,
      });
      
      console.log(`[MatchingService] ✅ Assigned ${bookingsToAssign.length} instant bookings to driver ${driverid} (${vehicleType} vehicle, trip ${driverTrip.tripid})`);
      
      // If vehicle is full, remove driver from queue (Rule 3: Move to next when full)
      if (availableSeats === bookingsToAssign.length) {
        console.log(`[MatchingService] 🚗 Driver ${driverid} vehicle (${vehicleType}) is now full, removing from queue`);
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
    console.error('[MatchingService] Error distributing instant bookings:', error);
    throw error;
  }
};

/**
 * Distribute all bookings for a trip opening (Future first, then Instant)
 * @param {string} tripid - The trip ID that just opened
 * @returns {Promise<object>} - Distribution result
 */
export const distributeAllBookings = async (tripid) => {
  try {
    console.log(`[MatchingService] 🚀 Starting distribution for opened trip ${tripid}`);
    
    // Get trip details
    const trip = await Trip.findById(tripid);
    if (!trip) {
      throw new Error(`Trip ${tripid} not found`);
    }
    
    // Check if trip has vehicle assigned - cannot distribute bookings without vehicle
    if (!trip.vehicleid) {
      console.log(`[MatchingService] ⚠️ Trip ${tripid} has no vehicle assigned, skipping booking distribution`);
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
    
    // Step 1: Distribute Future Bookings first (Rule 1: Future Bookings first - highest priority)
    console.log(`[MatchingService] 📅 Step 1: Distributing Future Bookings`);
    const futureResult = await distributeFutureBookings(scheduledTripTime, lineid, tripid);
    
    // Step 2: Distribute Instant Bookings (Rule 4: Ordered by timestamp)
    console.log(`[MatchingService] ⚡ Step 2: Distributing Instant Bookings`);
    const instantResult = await distributeInstantBookings(lineid, scheduledTripTime, tripid);
    
    return {
      success: true,
      future: futureResult,
      instant: instantResult,
      totalDistributed: futureResult.distributed + instantResult.distributed,
      totalRemaining: futureResult.remaining + instantResult.remaining,
    };
  } catch (error) {
    console.error('[MatchingService] Error distributing all bookings:', error);
    throw error;
  }
};

