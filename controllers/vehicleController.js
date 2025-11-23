import Vehicle from '../models/Vehicle.js';
import Driver from '../models/Driver.js';
import Line from '../models/Line.js';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import { buildSeatRows, normalizeSeatId } from '../utils/seatLayout.js';
import { v4 as uuidv4 } from 'uuid';


export const getAllVehicles = async (req, res, next) => {
  try {
    const { status, lineid } = req.query;
    const filters = {};
    
    if (status) filters.status = status;
    if (lineid) filters.lineid = lineid;
    
    const vehicles = await Vehicle.findAll(filters);
    res.json(vehicles);
  } catch (error) {
    next(error);
  }
};


export const getVehicleById = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const vehicle = await Vehicle.findById(vehicleid);
    
    if (!vehicle) {
      return res.status(404).json({ 
        message: req.t('vehicle.not_found') || 'Vehicle not found' 
      });
    }
    
    res.json(vehicle);
  } catch (error) {
    next(error);
  }
};


export const getVehiclesByDriver = async (req, res, next) => {
  try {
    const driverid = req.user.driverid;
    if (!driverid) {
      return res.status(403).json({
        message: req.t?.('auth.driver_required') || 'Driver access required',
      });
    }

    const vehicles = await Vehicle.findByDriverId(driverid);
    res.json(vehicles);
  } catch (error) {
    next(error);
  }
};


export const createVehicle = async (req, res, next) => {
  try {
    const { driverid, lineid, seatnum, seatlayout, plateno, brokenSeats } = req.body;
    
    // Validate plate number is required
    if (!plateno || !plateno.trim()) {
      return res.status(400).json({
        message: req.t('vehicle.plate_required') || 'Vehicle plate number is required',
      });
    }
    
    const trimmedPlate = plateno.trim();
    const plateRegex = /^\d-\d{4}-[A-Za-z]$/;
    if (!plateRegex.test(trimmedPlate)) {
      return res.status(400).json({
        message: req.t('vehicle.plate_invalid') || 'Plate number must be in format: number-4digits-letter (e.g., 3-1234-A)',
      });
    }
    
    // Check if plate number already exists (must be unique)
    const existingVehicle = await Vehicle.findByPlateNumber(trimmedPlate);
    if (existingVehicle) {
      return res.status(409).json({
        message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
      });
    }
    
    const driver = await Driver.findById(driverid);
    if (!driver) {
      return res.status(404).json({ 
        message: req.t('driver.not_found') || 'Driver not found' 
      });
    }
    
    if (!driver.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver must have an assigned line before creating vehicles',
      });
    }

    if (lineid && lineid !== driver.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_mismatch') || 'Vehicle line must match the driver line',
      });
    }

    const resolvedLineId = lineid || driver.lineid;

    const line = await Line.findById(resolvedLineId);
    if (!line) {
      return res.status(404).json({ 
        message: req.t('line.not_found') || 'Line not found' 
      });
    }
    
    const vehicleData = {
      vehicleid: uuidv4(),
      driverid,
      lineid: resolvedLineId,
      seatnum,
      seatlayout: seatlayout || '2+3',
      plateno: trimmedPlate, // Use trimmed and validated plate
      status: 'active',
      broken_seats: Array.isArray(brokenSeats) ? brokenSeats : [],
    };
    
    const vehicle = await Vehicle.create(vehicleData);
    res.status(201).json({
      message: req.t('vehicle.created') || 'Vehicle created successfully',
      vehicle,
    });
  } catch (error) {
    // Handle unique constraint violation
    if (error.code === '23505' || (error.message && error.message.includes('unique'))) {
      return res.status(409).json({
        message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
      });
    }
    next(error);
  }
};


export const updateVehicle = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const updates = req.body;
    
    // If plateno is being updated, validate it
    if (updates.plateno !== undefined) {
      if (!updates.plateno || !updates.plateno.trim()) {
        return res.status(400).json({
          message: req.t('vehicle.plate_required') || 'Vehicle plate number is required',
        });
      }
      
      const trimmedPlate = updates.plateno.trim();
      const plateRegex = /^\d-\d{4}-[A-Za-z]$/;
      if (!plateRegex.test(trimmedPlate)) {
        return res.status(400).json({
          message: req.t('vehicle.plate_invalid') || 'Plate number must be in format: number-4digits-letter (e.g., 3-1234-A)',
        });
      }
      
      // Check if plate number already exists for another vehicle (must be unique)
      const existingVehicle = await Vehicle.findByPlateNumber(trimmedPlate);
      if (existingVehicle && existingVehicle.vehicleid !== vehicleid) {
        return res.status(409).json({
          message: req.t('vehicle.plate_exists') || 'This plate number is already registered to another vehicle',
        });
      }
      
      updates.plateno = trimmedPlate;
    }
    
    const vehicle = await Vehicle.update(vehicleid, updates);
    res.json({
      message: req.t('vehicle.updated') || 'Vehicle updated successfully',
      vehicle,
    });
  } catch (error) {
    // Handle unique constraint violation
    if (error.code === '23505' || (error.message && error.message.includes('unique'))) {
      return res.status(409).json({
        message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
      });
    }
    next(error);
  }
};


export const assignVehicleToLine = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const { lineid } = req.body;
    
    const vehicle = await Vehicle.findById(vehicleid);
    if (!vehicle) {
      return res.status(404).json({
        message: req.t('vehicle.not_found') || 'Vehicle not found',
      });
    }

    const driver = await Driver.findById(vehicle.driverid);
    if (!driver) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    if (!driver.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver must have an assigned line',
      });
    }

    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({ 
        message: req.t('line.not_found') || 'Line not found' 
      });
    }

    if (driver.lineid !== lineid) {
      return res.status(400).json({
        message: req.t('driver.line_mismatch') || 'Cannot assign vehicle to a line different from the driver line',
      });
    }
    
    const updatedVehicle = await Vehicle.update(vehicleid, { lineid });
    res.json({
      message: req.t('vehicle.assigned') || 'Vehicle assigned to line successfully',
      vehicle: updatedVehicle,
    });
  } catch (error) {
    next(error);
  }
};

const ensureDriverOwnsVehicle = async (vehicleid, driverid, t) => {
  const vehicle = await Vehicle.findById(vehicleid);
  if (!vehicle) {
    const error = new Error(t?.('vehicle.not_found') || 'Vehicle not found');
    error.statusCode = 404;
    throw error;
  }

  if (vehicle.driverid !== driverid) {
    const error = new Error(t?.('auth.driver_forbidden') || 'You do not have access to this vehicle');
    error.statusCode = 403;
    throw error;
  }

  return vehicle;
};

const buildSeatStatus = (vehicle, reservations = []) => {
  const seatRows = buildSeatRows(vehicle.seatlayout, vehicle.seatnum);
  const brokenSeats = (vehicle.broken_seats || []).map((seat) => seat.toLowerCase().trim());
  const reservedSeats = reservations
    .map((reservation) => {
      const normalized = normalizeSeatId(reservation.seatlocation);
      return normalized ? normalized.toLowerCase().trim() : null;
    })
    .filter(Boolean);

  console.log('[buildSeatStatus] Building seat status:', {
    vehicleId: vehicle.vehicleid,
    seatLayout: vehicle.seatlayout,
    seatNum: vehicle.seatnum,
    brokenSeats: brokenSeats,
    reservationsCount: reservations.length,
    reservedSeats: reservedSeats,
    reservationSeatLocations: reservations.map(r => r.seatlocation),
  });

  let counter = 1;
  const rows = seatRows.map((row) =>
    row.map(() => {
      const seatId = `seat_${counter}`;
      const seatIdLower = seatId.toLowerCase();
      let status = 'available';
      
      if (brokenSeats.includes(seatIdLower)) {
        status = 'broken';
      } else if (reservedSeats.includes(seatIdLower)) {
        status = 'reserved';
      }

      const seat = {
        id: seatId,
        number: counter,
        label: counter === 1 ? 'Driver' : `Seat ${counter - 1}`,
        status,
        reservation: reservations.find(
          (reservation) => {
            const normalized = normalizeSeatId(reservation.seatlocation);
            return normalized && normalized.toLowerCase().trim() === seatIdLower;
          }
        ) || null,
      };
      
      if (status === 'reserved') {
        console.log(`[buildSeatStatus] Seat ${counter} is RESERVED:`, {
          seatId: seatId,
          reservation: seat.reservation,
        });
      }
      
      counter += 1;
      return seat;
    })
  );

  return rows;
};

export const getVehicleSeatMap = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const driverid = req.user.driverid;
    const vehicle = await ensureDriverOwnsVehicle(vehicleid, driverid, req.t);

    let upcomingTrip = null;
    let reservations = [];

    try {
      upcomingTrip = await Trip.findUpcomingByVehicle(vehicle.vehicleid);
      if (upcomingTrip) {
        reservations = await Reservation.findByTripId(upcomingTrip.tripid);
      }
    } catch (error) {
      reservations = [];
    }

    const seatMap = buildSeatStatus(vehicle, reservations);

    console.log('[getVehicleSeatMap] Response data:', {
      vehicleId: vehicle.vehicleid,
      hasUpcomingTrip: !!upcomingTrip,
      reservationsCount: reservations.length,
      seatMapRows: seatMap.length,
      reservedSeatsCount: reservations.length,
    });

    res.json({
      success: true,
      vehicle,
      seatMap,
      layout: buildSeatRows(vehicle.seatlayout, vehicle.seatnum),
      brokenSeats: vehicle.broken_seats || [],
      reservedSeats: reservations
        .map((reservation) => normalizeSeatId(reservation.seatlocation))
        .filter(Boolean),
      upcomingTrip,
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    next(error);
  }
};

export const updateBrokenSeats = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const driverid = req.user.driverid;
    const vehicle = await ensureDriverOwnsVehicle(vehicleid, driverid, req.t);
    const seats = Array.isArray(req.body.seats) ? req.body.seats : [];

    const normalizedSeats = Array.from(
      new Set(
        seats
          .map(normalizeSeatId)
          .filter(Boolean)
      )
    );

    const updatedVehicle = await Vehicle.update(vehicle.vehicleid, {
      broken_seats: normalizedSeats,
    });

    res.json({
      message: req.t?.('vehicle.broken_seats_updated') || 'Seat statuses updated successfully',
      brokenSeats: updatedVehicle.broken_seats || [],
    });
  } catch (error) {
    if (error.statusCode) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    next(error);
  }
};

export const createMyVehicle = async (req, res, next) => {
  try {
    const driverid = req.user.driverid;
    if (!driverid) {
      return res.status(403).json({
        message: req.t?.('auth.driver_required') || 'Driver access required',
      });
    }

    const driver = await Driver.findById(driverid);
    if (!driver) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    if (!driver.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver must have an assigned line before creating vehicles',
      });
    }

    const { plateno, seatlayout } = req.body;

    if (!plateno || !plateno.trim()) {
      return res.status(400).json({
        message: req.t('vehicle.plate_required') || 'Vehicle plate number is required',
      });
    }

    const trimmedPlate = plateno.trim();
    const plateRegex = /^\d-\d{4}-[A-Za-z]$/;
    if (!plateRegex.test(trimmedPlate)) {
      return res.status(400).json({
        message: req.t('vehicle.plate_invalid') || 'Plate number must be in format: number-4digits-letter (e.g., 3-1234-A)',
      });
    }

    // Check if plate number already exists (must be unique)
    const existingVehicle = await Vehicle.findByPlateNumber(trimmedPlate);
    if (existingVehicle) {
      return res.status(409).json({
        message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
      });
    }

    const normalizedLayout = (seatlayout || '4+1').trim();
    if (normalizedLayout !== '4+1' && normalizedLayout !== '7+1') {
      return res.status(400).json({
        message: req.t('vehicle.seat_layout_invalid') || 'Seat layout must be either 4+1 or 7+1',
      });
    }

    const seatNum = normalizedLayout === '7+1' ? 8 : 5;

    const existingVehicles = await Vehicle.findByDriverId(driverid);
    if (existingVehicles && existingVehicles.length > 0) {
      return res.status(400).json({
        message: req.t('vehicle.already_exists') || 'You already have a vehicle registered',
      });
    }

    const baseVehicleData = {
      vehicleid: uuidv4(),
      driverid,
      lineid: driver.lineid,
      seatnum: seatNum,
      seatlayout: normalizedLayout,
      plateno: trimmedPlate, // Use trimmed and validated plate
      status: 'active',
    };

    try {
      // Try with broken_seats first
      const vehicleData = {
        ...baseVehicleData,
        broken_seats: [],
      };
      const vehicle = await Vehicle.create(vehicleData);
      return res.status(201).json({
        message: req.t('vehicle.created') || 'Vehicle created successfully',
        vehicle,
      });
    } catch (createError) {
      // Handle unique constraint violation
      if (createError.code === '23505' || (createError.message && createError.message.includes('unique')) || (createError.message && createError.message.includes('already registered'))) {
        return res.status(409).json({
          message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
        });
      }
      
      // If broken_seats column doesn't exist (error code 42703), try without it
      if (createError.code === '42703' || (createError.message && createError.message.includes('broken_seats'))) {
        try {
          const vehicle = await Vehicle.create(baseVehicleData);
          return res.status(201).json({
            message: req.t('vehicle.created') || 'Vehicle created successfully',
            vehicle,
          });
        } catch (retryError) {
          // Handle unique constraint violation in retry
          if (retryError.code === '23505' || (retryError.message && retryError.message.includes('unique')) || (retryError.message && retryError.message.includes('already registered'))) {
            return res.status(409).json({
              message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
            });
          }
          console.error('[createMyVehicle] Retry error:', retryError.message || retryError);
          return next(retryError);
        }
      }
      console.error('[createMyVehicle] Error:', createError.message || createError);
      return next(createError);
    }
  } catch (error) {
    console.error('[createMyVehicle] Outer error:', error.message || error);
    next(error);
  }
};

