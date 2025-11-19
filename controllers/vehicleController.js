import Vehicle from '../models/Vehicle.js';
import Driver from '../models/Driver.js';
import Line from '../models/Line.js';
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
    const driverid = req.user.driverid || req.params.driverid;
    const vehicles = await Vehicle.findByDriverId(driverid);
    res.json(vehicles);
  } catch (error) {
    next(error);
  }
};


export const createVehicle = async (req, res, next) => {
  try {
    const { driverid, lineid, seatnum, seatlayout, plateno } = req.body;
    
    
    const driver = await Driver.findById(driverid);
    if (!driver) {
      return res.status(404).json({ 
        message: req.t('driver.not_found') || 'Driver not found' 
      });
    }
    
    
    if (lineid) {
      const line = await Line.findById(lineid);
      if (!line) {
        return res.status(404).json({ 
          message: req.t('line.not_found') || 'Line not found' 
        });
      }
    }
    
    const vehicleData = {
      vehicleid: uuidv4(),
      driverid,
      lineid: lineid || null,
      seatnum,
      seatlayout: seatlayout || '2+3',
      plateno,
      status: 'active',
    };
    
    const vehicle = await Vehicle.create(vehicleData);
    res.status(201).json({
      message: req.t('vehicle.created') || 'Vehicle created successfully',
      vehicle,
    });
  } catch (error) {
    next(error);
  }
};


export const updateVehicle = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const updates = req.body;
    
    const vehicle = await Vehicle.update(vehicleid, updates);
    res.json({
      message: req.t('vehicle.updated') || 'Vehicle updated successfully',
      vehicle,
    });
  } catch (error) {
    next(error);
  }
};


export const assignVehicleToLine = async (req, res, next) => {
  try {
    const { vehicleid } = req.params;
    const { lineid } = req.body;
    
    
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({ 
        message: req.t('line.not_found') || 'Line not found' 
      });
    }
    
    const vehicle = await Vehicle.update(vehicleid, { lineid });
    res.json({
      message: req.t('vehicle.assigned') || 'Vehicle assigned to line successfully',
      vehicle,
    });
  } catch (error) {
    next(error);
  }
};

