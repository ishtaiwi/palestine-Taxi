import Trip from '../models/Trip.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Reservation from '../models/Reservation.js';
import { buildSeatRows, normalizeSeatId } from '../utils/seatLayout.js';
import { calculateAvailablePassengerSeats, getTotalPassengerSeats } from '../utils/seatCalculation.js';
import { v4 as uuidv4 } from 'uuid';
import { TRIP_STATUS } from '../utils/constants.js';


export const getAllTrips = async (req, res, next) => {
  try {
    const { lineid, status, date } = req.query;
    const filters = {};
    
    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    if (date) filters.date = date;
    
    const trips = await Trip.findAll(filters);
    res.json(trips);
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
    
    const trips = await Trip.findUpcoming(filters);
    res.json(trips);
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
    
    
    const deptimeDate = new Date(deptime);
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
    
    const trip = await Trip.update(tripid, {
      status: 'in_progress',
      deptime: new Date().toISOString(),
    });
    
    res.json({
      message: req.t('trip.started') || 'Trip started successfully',
      trip,
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
      arrivaltime: new Date().toISOString(),
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

