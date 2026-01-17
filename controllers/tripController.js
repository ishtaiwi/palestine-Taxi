import Trip from '../models/Trip.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Reservation from '../models/Reservation.js';
import DriverQueue from '../models/DriverQueue.js';
import ScheduleTemplate from '../models/ScheduleTemplate.js';
import { buildSeatRows, normalizeSeatId } from '../utils/seatLayout.js';
import { calculateAvailablePassengerSeats, getTotalPassengerSeats } from '../utils/seatCalculation.js';
import { v4 as uuidv4 } from 'uuid';
import { TRIP_STATUS } from '../utils/constants.js';
import { getUtcNow, parseUtcDate, canBookInstant, getServerTimezoneOffset } from '../utils/timeUtils.js';
import logger from '../utils/logger.js';


export const getAllTrips = async (req, res, next) => {
  try {
    const { lineid, status, date } = req.query;
    const filters = {};

    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    if (date) filters.date = date;

    const allTrips = await Trip.findAll(filters);

    // Return all trips - don't filter out trips with same time but different direction or line
    // Admin needs to see all trips for all lines and all directions
    const sortedTrips = allTrips.sort((a, b) => {
      const timeA = new Date(a.deptime).getTime();
      const timeB = new Date(b.deptime).getTime();
      // If same time, sort by lineid then direction for consistent ordering
      if (timeA === timeB) {
        const lineCompare = (a.lineid || '').localeCompare(b.lineid || '');
        if (lineCompare !== 0) return lineCompare;
        return (a.direction || '').localeCompare(b.direction || '');
      }
      return timeA - timeB;
    });

    res.json(sortedTrips);
  } catch (error) {
    next(error);
  }
};


export const getUpcomingTrips = async (req, res, next) => {
  try {
    const { lineid, status, date, direction } = req.query;
    const filters = {};

    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    if (date) filters.date = date;
    if (direction) filters.direction = direction;

    const allTrips = await Trip.findUpcoming(filters);

    // Sort all trips by deptime, then lineid, then direction
    // This ensures all trips for all lines and directions are shown when filters are not applied
    const sortedTrips = allTrips.sort((a, b) => {
      const timeA = new Date(a.deptime).getTime();
      const timeB = new Date(b.deptime).getTime();
      if (timeA !== timeB) return timeA - timeB;

      // If same time, sort by lineid
      const lineA = a.lineid || '';
      const lineB = b.lineid || '';
      if (lineA !== lineB) return lineA.localeCompare(lineB);

      // If same line and time, sort by direction
      const directionA = a.direction || '';
      const directionB = b.direction || '';
      return directionA.localeCompare(directionB);
    });

    res.json(sortedTrips);
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
    const { lineid, vehicleid, deptime, availableseats, direction } = req.body;


    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: req.t('line.not_found') || 'Line not found'
      });
    }

    // Validate direction
    const tripDirection = direction || 'going';
    if (tripDirection !== 'going' && tripDirection !== 'return') {
      return res.status(400).json({
        message: req.t('trip.invalid_direction') || 'Invalid direction. Must be "going" or "return"',
      });
    }

    // Determine origin_stationid based on direction
    let origin_stationid = null;
    if (tripDirection === 'going') {
      origin_stationid = line.main_stationid || null;
    } else if (tripDirection === 'return') {
      origin_stationid = line.return_stationid || null;
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
      direction: tripDirection,
      origin_stationid: origin_stationid,
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

    // If status is being updated to completed, check for returning trip creation
    if (updates.status === TRIP_STATUS.COMPLETED) {
      const currentTrip = await Trip.findById(tripid);
      if (currentTrip && currentTrip.direction === 'going') {
        // Set arrivaltime if not provided
        if (!updates.arrivaltime) {
          updates.arrivaltime = getUtcNow().toISOString();
        }
      }
    }

    const trip = await Trip.update(tripid, updates);

    // If status was updated to completed and it's a going trip, create returning trip
    if (updates.status === TRIP_STATUS.COMPLETED) {
      const updatedTrip = await Trip.findById(tripid);
      if (updatedTrip && updatedTrip.direction === 'going') {
        try {
          const { processTripCompletion } = await import('../services/tripCompletionService.js');
          const returnTrip = await processTripCompletion(tripid);
          if (returnTrip) {
            console.log(`[TripController] ✅ Created returning trip ${returnTrip.tripid} for going trip ${tripid}`);
          }
        } catch (error) {
          console.error(`[TripController] ⚠️ Error creating returning trip:`, error);
          // Don't fail the trip update if returning trip creation fails
        }
      }
    }

    res.json({
      message: req.t('trip.updated') || 'Trip updated successfully',
      trip,
    });
  } catch (error) {
    next(error);
  }
};

export const deleteTrip = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    // Check if trip exists
    const trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found'
      });
    }

    // Delete the trip
    await Trip.delete(tripid);

    res.json({
      message: req.t('trip.deleted') || 'Trip has been deleted successfully',
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

    // Get trip before updating to check direction
    const currentTrip = await Trip.findById(tripid);

    const trip = await Trip.update(tripid, {
      status: TRIP_STATUS.COMPLETED,
      arrivaltime: getUtcNow().toISOString(),
    });

    // If this is a going trip, create returning trip
    if (currentTrip && currentTrip.direction === 'going') {
      try {
        const { processTripCompletion } = await import('../services/tripCompletionService.js');
        const returnTrip = await processTripCompletion(tripid);
        if (returnTrip) {
          console.log(`[TripController] ✅ Created returning trip ${returnTrip.tripid} for going trip ${tripid}`);
        }
      } catch (error) {
        console.error(`[TripController] ⚠️ Error creating returning trip:`, error);
        // Don't fail the trip end if returning trip creation fails
      }
    }

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

/**
 * Get available trips for a line on a specific date
 * Returns actual trips if they exist, otherwise generates them based on schedule
 */
export const getAvailableTripTimes = async (req, res, next) => {
  try {
    const { lineid, date } = req.query;

    if (!lineid || !date) {
      return res.status(400).json({
        message: req.t('trip.lineid_and_date_required') || 'lineid and date are required',
      });
    }

    // Get schedule for the line
    const schedules = await ScheduleTemplate.findByLineId(lineid);
    if (!schedules || schedules.length === 0) {
      return res.status(404).json({
        message: req.t('schedule.not_found') || 'No schedule found for this line',
      });
    }

    const schedule = schedules[0]; // Get first active schedule
    const { start_hour, end_hour, interval_minutes } = schedule;

    // Parse the date
    const targetDate = new Date(date);
    if (isNaN(targetDate.getTime())) {
      return res.status(400).json({
        message: req.t('trip.invalid_date') || 'Invalid date format',
      });
    }

    // First, try to get existing trips for this line and date
    const existingTrips = await Trip.findAll({
      lineid,
      date,
      status: 'scheduled',
    });

    // Also get open trips
    const openTrips = await Trip.findAll({
      lineid,
      date,
      status: 'open',
    });

    const allTrips = [...existingTrips, ...openTrips];
    const now = getUtcNow();

    // Filter to only future trips and sort by deptime
    const futureTrips = allTrips
      .filter(trip => {
        const deptime = parseUtcDate(trip.deptime);
        return deptime && deptime.getTime() > now.getTime();
      })
      .sort((a, b) => {
        const timeA = parseUtcDate(a.deptime)?.getTime() || 0;
        const timeB = parseUtcDate(b.deptime)?.getTime() || 0;
        return timeA - timeB;
      });

    // If we have trips, return them
    if (futureTrips.length > 0) {
      const tripsData = futureTrips.map(trip => {
        const deptime = parseUtcDate(trip.deptime);
        const localTime = deptime ? new Date(deptime.getTime()) : null;
        
        return {
          tripid: trip.tripid,
          deptime: trip.deptime,
          time: trip.deptime,
          hour: localTime ? localTime.getHours() : null,
          minute: localTime ? localTime.getMinutes() : null,
          status: trip.status,
          availableseats: trip.availableseats || 0,
          totalbookings: trip.totalbookings || 0,
          interval_minutes: interval_minutes,
        };
      });

      return res.json({
        lineid,
        date,
        schedule: {
          start_hour,
          end_hour,
          interval_minutes,
        },
        trips: tripsData,
      });
    }

    // If no trips exist, generate trip times based on schedule
    const timezoneOffset = await getServerTimezoneOffset();
    const tripTimes = [];
    const year = targetDate.getFullYear();
    const month = String(targetDate.getMonth() + 1).padStart(2, '0');
    const day = String(targetDate.getDate()).padStart(2, '0');
    const offsetSign = timezoneOffset >= 0 ? '+' : '-';
    const offsetHours = String(Math.abs(timezoneOffset)).padStart(2, '0');

    let currentMinutes = start_hour * 60;
    const endMinutes = end_hour * 60;

    while (currentMinutes <= endMinutes) {
      const hours = Math.floor(currentMinutes / 60);
      const mins = currentMinutes % 60;
      const localTimeString = `${year}-${month}-${day}T${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00${offsetSign}${offsetHours}:00`;
      const utcTime = parseUtcDate(localTimeString);
      
      if (utcTime && utcTime.getTime() > now.getTime()) {
        tripTimes.push({
          tripid: null, // No trip ID yet, will be created when booking
          deptime: utcTime.toISOString(),
          time: utcTime.toISOString(),
          hour: hours,
          minute: mins,
          status: 'scheduled',
          availableseats: 0,
          totalbookings: 0,
          interval_minutes: interval_minutes,
        });
      }

      currentMinutes += interval_minutes;
    }

    res.json({
      lineid,
      date,
      schedule: {
        start_hour,
        end_hour,
        interval_minutes,
      },
      trips: tripTimes,
    });
  } catch (error) {
    next(error);
  }
};
