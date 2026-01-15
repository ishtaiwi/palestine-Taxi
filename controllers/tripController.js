import Trip from '../models/Trip.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Reservation from '../models/Reservation.js';
import DriverQueue from '../models/DriverQueue.js';
import { buildSeatRows, normalizeSeatId } from '../utils/seatLayout.js';
import { calculateAvailablePassengerSeats, getTotalPassengerSeats } from '../utils/seatCalculation.js';
import { v4 as uuidv4 } from 'uuid';
import { TRIP_STATUS } from '../utils/constants.js';
import { getUtcNow, parseUtcDate, canBookInstant } from '../utils/timeUtils.js';
import logger from '../utils/logger.js';


export const getAllTrips = async (req, res, next) => {
  try {
    const { lineid, status, date } = req.query;
    const filters = {};

    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    if (date) filters.date = date;

    const allTrips = await Trip.findAll(filters);

    // Group trips by deptime and show only the first trip for each time
    // This ensures frontend shows one trip per time, even though backend may have multiple
    const tripsByTime = new Map();

    for (const trip of allTrips) {
      const deptime = trip.deptime;
      if (!tripsByTime.has(deptime)) {
        tripsByTime.set(deptime, trip);
      } else {
        // If multiple trips exist for same time, prefer the one with more bookings or earlier created
        const existingTrip = tripsByTime.get(deptime);
        const existingBookings = existingTrip.totalbookings || 0;
        const currentBookings = trip.totalbookings || 0;

        // Prefer trip with more bookings, or if equal, keep the existing one (first found)
        if (currentBookings > existingBookings) {
          tripsByTime.set(deptime, trip);
        }
      }
    }

    // Convert map values back to array and sort by deptime
    const uniqueTrips = Array.from(tripsByTime.values()).sort((a, b) => {
      const timeA = new Date(a.deptime).getTime();
      const timeB = new Date(b.deptime).getTime();
      return timeA - timeB;
    });

    res.json(uniqueTrips);
  } catch (error) {
    next(error);
  }
};


export const getUpcomingTrips = async (req, res, next) => {
  try {
    const { lineid, status, date } = req.query;
    const filters = {};

    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    if (date) filters.date = date;

    const allTrips = await Trip.findUpcoming(filters);

    // Group trips by deptime and show only the first trip for each time
    // This ensures frontend shows one trip per time, even though backend may have multiple
    const tripsByTime = new Map();

    for (const trip of allTrips) {
      const deptime = trip.deptime;
      if (!tripsByTime.has(deptime)) {
        tripsByTime.set(deptime, trip);
      } else {
        // If multiple trips exist for same time, prefer the one with more bookings or earlier created
        const existingTrip = tripsByTime.get(deptime);
        const existingBookings = existingTrip.totalbookings || 0;
        const currentBookings = trip.totalbookings || 0;

        // Prefer trip with more bookings, or if equal, keep the existing one (first found)
        if (currentBookings > existingBookings) {
          tripsByTime.set(deptime, trip);
        }
      }
    }

    // Convert map values back to array and sort by deptime
    const uniqueTrips = Array.from(tripsByTime.values()).sort((a, b) => {
      const timeA = new Date(a.deptime).getTime();
      const timeB = new Date(b.deptime).getTime();
      return timeA - timeB;
    });

    res.json(uniqueTrips);
  } catch (error) {
    next(error);
  }
};


export const getTripById = async (req, res, next) => {
  try {
    const { tripid } = req.params;
    const trip = await Trip.findById(tripid);

    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found'
      });
    }


    const reservations = await Reservation.findByTripId(tripid);

    res.json({
      ...trip,
      reservations,
    });
  } catch (error) {
    next(error);
  }
};


export const createTrip = async (req, res, next) => {
  try {
    const { lineid, vehicleid, deptime, availableseats } = req.body;


    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: req.t('line.not_found') || 'Line not found'
      });
    }

    // Vehicle is optional - if provided, validate it; otherwise will be assigned from queue
    let vehicle = null;
    let defaultSeats = 5; // Default to 4+1
    if (vehicleid) {
      vehicle = await Vehicle.findById(vehicleid);
      if (!vehicle) {
        return res.status(404).json({
          message: req.t('vehicle.not_found') || 'Vehicle not found'
        });
      }
      defaultSeats = vehicle.seatnum;
    }


    // Parse deptime as UTC and calculate opening time (45 minutes before)
    const deptimeDate = parseUtcDate(deptime);
    if (!deptimeDate) {
      return res.status(400).json({
        message: req.t('trip.invalid_deptime') || 'Invalid deptime format',
      });
    }
    const openingTime = new Date(deptimeDate.getTime() - 45 * 60 * 1000);



    const initialAvailableSeats = availableseats !== undefined
      ? availableseats
      : calculateAvailablePassengerSeats(defaultSeats, 0, 0);

    // Set vehicleid to null if not provided - will be assigned from driver queue at opening
    const tripData = {
      tripid: uuidv4(),
      lineid,
      vehicleid: vehicleid || null, // Null if not provided - will be assigned from queue
      deptime,
      status: 'scheduled',
      availableseats: initialAvailableSeats,
      totalbookings: 0,
      trip_opening_time: openingTime.toISOString(),
      auto_departure_enabled: true,
      early_departure_allowed: true,
      scheduled_departure_enforced: true,
    };

    const trip = await Trip.create(tripData);

    // Assign any existing future bookings to this newly created trip
    try {
      const { distributeFutureBookings } = await import('../services/matchingService.js');
      const futureResult = await distributeFutureBookings(deptime, lineid, trip.tripid);
      if (futureResult.distributed > 0) {
        logger.info(`[TripController] ✅ Assigned ${futureResult.distributed} existing future booking(s) to newly created trip ${trip.tripid}`);
        // Refresh trip to get updated stats
        const updatedTrip = await Trip.findById(trip.tripid);
        if (updatedTrip) {
          trip.totalbookings = updatedTrip.totalbookings;
          trip.availableseats = updatedTrip.availableseats;
        }
      }
    } catch (error) {
      logger.warn(`[TripController] ⚠️ Error assigning future bookings to new trip ${trip.tripid}:`, error);
      // Don't fail trip creation if booking assignment fails
    }

    res.status(201).json({
      message: req.t('trip.created') || 'Trip created successfully',
      trip,
    });
  } catch (error) {
    next(error);
  }
};


export const updateTrip = async (req, res, next) => {
  try {
    const { tripid } = req.params;
    const updates = req.body;

    const trip = await Trip.update(tripid, updates);
    res.json({
      message: req.t('trip.updated') || 'Trip updated successfully',
      trip,
    });
  } catch (error) {
    next(error);
  }
};


export const startTrip = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    // Get trip details first to check for assigned driver
    const trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found',
      });
    }

    // Update trip status to in_progress
    const updatedTrip = await Trip.update(tripid, {
      status: 'in_progress',
      deptime: getUtcNow().toISOString(),
    });

    // Remove driver from queue if assigned
    if (trip.assigned_driverid) {
      try {
        await DriverQueue.removeDriverFromQueue(trip.assigned_driverid);
        console.log(`[TripController] ✅ Removed driver ${trip.assigned_driverid} from queue`);
      } catch (error) {
        console.error(`[TripController] ⚠️ Error removing driver from queue:`, error);
        // Don't fail the trip start if queue removal fails
      }
    }

    res.json({
      message: req.t('trip.started') || 'Trip started successfully',
      trip: updatedTrip,
    });
  } catch (error) {
    next(error);
  }
};


export const endTrip = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    const trip = await Trip.update(tripid, {
      status: TRIP_STATUS.COMPLETED,
      arrivaltime: getUtcNow().toISOString(),
    });

    res.json({
      message: req.t('trip.ended') || 'Trip ended successfully',
      trip,
    });
  } catch (error) {
    next(error);
  }
};


export const getTripSeatMap = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    const trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found'
      });
    }

    // Check if trip has vehicle assigned
    if (!trip.vehicleid) {
      return res.status(400).json({
        message: req.t('trip.no_vehicle') || 'Trip does not have a vehicle assigned yet'
      });
    }

    const reservations = await Reservation.findByTripId(tripid);
    const vehicle = await Vehicle.findById(trip.vehicleid);

    if (!vehicle) {
      return res.status(404).json({
        message: req.t('vehicle.not_found') || 'Vehicle not found'
      });
    }

    const seatMap = generateSeatMap(
      vehicle.seatlayout,
      vehicle.seatnum,
      reservations,
      vehicle.broken_seats || []
    );

    res.json({
      trip,
      seatMap,
      reservations,
      layout: buildSeatRows(vehicle.seatlayout, vehicle.seatnum),
      brokenSeats: vehicle.broken_seats || [],
    });
  } catch (error) {
    next(error);
  }
};


/**
 * Check if instant booking is available for a trip
 * Returns availability status based on:
 * 1. Trip has driver/vehicle assigned, OR
 * 2. There are drivers available in the queue for the trip's line
 */
export const checkInstantBookingAvailability = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    const trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found',
      });
    }

    // Check if trip is open for instant booking (timing check)
    const isOpen = canBookInstant(trip);
    if (!isOpen) {
      return res.json({
        available: false,
        reason: 'trip_not_open',
        message: req.t('trip.not_open_for_booking') || 'Trip is not yet open for instant bookings',
        tripStatus: trip.status,
        hasVehicle: !!trip.vehicleid,
        hasDriver: !!trip.assigned_driverid,
        driversInQueue: 0,
      });
    }

    // Check if trip already has a driver/vehicle assigned
    const tripHasDriver = trip.vehicleid && trip.assigned_driverid;

    if (tripHasDriver) {
      // Trip has driver, check available seats on this trip using real-time calculation
      const { getAvailableSeats, findTripsAtSameTime } = await import('../services/matchingService.js');
      const Vehicle = (await import('../models/Vehicle.js')).default;

      let availableSeats = 0;
      if (trip.vehicleid) {
        const vehicle = await Vehicle.findById(trip.vehicleid);
        if (vehicle) {
          availableSeats = await getAvailableSeats(vehicle, trip.tripid);
        }
      }

      // If this trip is full, check if there are other trips at the same time with capacity
      // OR if there are drivers in queue that can be assigned
      if (availableSeats <= 0) {
        // Check other trips at the same time
        const tripsAtSameTime = await findTripsAtSameTime(trip.deptime, trip.lineid);
        const otherTripsWithCapacity = tripsAtSameTime.filter(t =>
          t.tripid !== trip.tripid &&
          t.vehicleid &&
          t.assigned_driverid &&
          (t.status === 'scheduled' || t.status === 'open' || t.status === 'delayed')
        );

        let totalAvailableSeats = 0;
        for (const otherTrip of otherTripsWithCapacity) {
          const vehicle = await Vehicle.findById(otherTrip.vehicleid);
          if (vehicle) {
            const seats = await getAvailableSeats(vehicle, otherTrip.tripid);
            totalAvailableSeats += seats;
          }
        }

        // Check if there are drivers in queue
        const DriverQueue = (await import('../models/DriverQueue.js')).default;
        const queueCheck = await DriverQueue.canAcceptInstantBooking(trip.lineid);

        // Booking is available if:
        // 1. Other trips at same time have capacity, OR
        // 2. There are drivers in queue (can create new trip or assign to existing unassigned trips)
        const stillAvailable = totalAvailableSeats > 0 || (queueCheck.allowed && queueCheck.driversAvailable > 0);

        return res.json({
          available: stillAvailable,
          reason: stillAvailable ? 'other_trips_or_drivers_available' : 'no_seats',
          message: stillAvailable
            ? 'Instant booking is available (on other trips at same time or new driver can be assigned)'
            : req.t('reservation.no_seats') || 'No available seats',
          tripStatus: trip.status,
          hasVehicle: true,
          hasDriver: true,
          availableSeats: 0, // This trip is full
          otherTripsAvailable: totalAvailableSeats > 0,
          otherTripsCapacity: totalAvailableSeats,
          driversInQueue: queueCheck.allowed ? queueCheck.driversAvailable : 0,
        });
      }

      // Trip has seats available
      return res.json({
        available: true,
        reason: 'driver_assigned',
        message: 'Instant booking is available',
        tripStatus: trip.status,
        hasVehicle: true,
        hasDriver: true,
        availableSeats,
        driversInQueue: null, // Not relevant when this trip has seats
      });
    }

    // Trip has no driver - check queue availability
    const queueCheck = await DriverQueue.canAcceptInstantBooking(trip.lineid);

    if (!queueCheck.allowed) {
      return res.json({
        available: false,
        reason: 'no_drivers_in_queue',
        message: req.t('reservation.no_drivers_available') || 'Instant booking is currently unavailable. No drivers are available in the queue.',
        tripStatus: trip.status,
        hasVehicle: false,
        hasDriver: false,
        driversInQueue: 0,
      });
    }

    return res.json({
      available: true,
      reason: 'drivers_in_queue',
      message: 'Instant booking is available - drivers are waiting in queue',
      tripStatus: trip.status,
      hasVehicle: false,
      hasDriver: false,
      driversInQueue: queueCheck.driversAvailable,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Check instant booking availability for a line (not specific trip)
 * Useful for showing availability status before trip selection
 */
export const checkLineBookingAvailability = async (req, res, next) => {
  try {
    const { lineid } = req.params;

    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: req.t('line.not_found') || 'Line not found',
      });
    }

    // Check driver queue for this line
    const queueCheck = await DriverQueue.canAcceptInstantBooking(lineid);

    return res.json({
      lineid,
      lineName: line.linename,
      instantBookingAvailable: queueCheck.allowed,
      driversInQueue: queueCheck.driversAvailable,
      message: queueCheck.allowed
        ? 'Instant booking is available'
        : req.t('reservation.no_drivers_available') || 'No drivers available. Instant booking is temporarily unavailable.',
    });
  } catch (error) {
    next(error);
  }
};


function generateSeatMap(layout, totalSeats, reservations, brokenSeats = []) {
  const seatMap = {};
  const reservedSeats = reservations
    .map((r) => normalizeSeatId(r.seatlocation))
    .filter(Boolean);
  const brokenSeatIds = (brokenSeats || []).map((seat) => seat.toLowerCase());

  for (let i = 1; i <= totalSeats; i++) {
    const seatKey = `seat_${i}`;
    let status = 'available';
    if (brokenSeatIds.includes(seatKey)) {
      status = 'broken';
    } else if (reservedSeats.includes(seatKey)) {
      status = 'reserved';
    }

    seatMap[seatKey] = {
      number: i,
      status,
      reservation: reservations.find(r => r.seatlocation === seatKey) || null,
    };
  }

  return seatMap;
}

