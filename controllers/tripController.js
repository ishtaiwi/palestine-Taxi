import Trip from '../models/Trip.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Reservation from '../models/Reservation.js';
import { buildSeatRows, normalizeSeatId } from '../utils/seatLayout.js';
import { v4 as uuidv4 } from 'uuid';


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
    const { lineid, status } = req.query;
    const filters = {};
    
    if (lineid) filters.lineid = lineid;
    if (status) filters.status = status;
    
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
    
    
    const vehicle = await Vehicle.findById(vehicleid);
    if (!vehicle) {
      return res.status(404).json({ 
        message: req.t('vehicle.not_found') || 'Vehicle not found' 
      });
    }
    
    const tripData = {
      tripid: uuidv4(),
      lineid,
      vehicleid,
      deptime,
      status: 'scheduled',
      availableseats: availableseats || vehicle.seatnum,
      totalbookings: 0,
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
      status: 'completed',
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
    
    const reservations = await Reservation.findByTripId(tripid);
    const vehicle = await Vehicle.findById(trip.vehicleid);
    
    
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

