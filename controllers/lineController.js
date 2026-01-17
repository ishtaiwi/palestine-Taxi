import Line from '../models/Line.js';
import { v4 as uuidv4 } from 'uuid';
import logger from '../utils/logger.js';


export const getAllLines = async (req, res, next) => {
  try {
    const { active } = req.query;
    const filters = {};
    
    if (active !== undefined) {
      filters.active = active === 'true';
    }
    
    const lines = await Line.findAll(filters);
    res.json(lines);
  } catch (error) {
    next(error);
  }
};


export const getActiveLines = async (req, res, next) => {
  try {
    const lines = await Line.getActiveLines();
    res.json(lines);
  } catch (error) {
    next(error);
  }
};


export const getLineById = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    const line = await Line.findById(lineid);
    
    if (!line) {
      return res.status(404).json({ 
        message: req.t('line.not_found') || 'Line not found' 
      });
    }
    
    res.json(line);
  } catch (error) {
    next(error);
  }
};


export const createLine = async (req, res, next) => {
  try {
    const { name_ar, name_en, linename, baseprice, additionalprice, estduration, distance, active, main_stationid, return_stationid } = req.body;
    
    
    const finalNameAr = name_ar || linename || '';
    const finalNameEn = name_en || '';
    
    if (!finalNameAr) {
      return res.status(400).json({
        message: req.t('line.name_ar_required') || 'Arabic name (name_ar) is required',
      });
    }
    
    const lineData = {
      lineid: uuidv4(),
      name_ar: finalNameAr,
      name_en: finalNameEn || null,
      linename: finalNameAr, 
      baseprice,
      additionalprice: additionalprice || 0,
      estduration,
      distance,
      active: active !== undefined ? active : true,
      main_stationid: main_stationid || null,
      return_stationid: return_stationid || null,
    };
    
    const line = await Line.create(lineData);
    res.status(201).json({
      message: req.t('line.created') || 'Line created successfully',
      line,
    });
  } catch (error) {
    next(error);
  }
};


export const updateLine = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    const { name_ar, name_en, linename, ...otherUpdates } = req.body;
    
    const updates = { ...otherUpdates };
    
    
    if (name_ar !== undefined) {
      updates.name_ar = name_ar;
      
      if (!linename) {
        updates.linename = name_ar;
      }
    }
    if (name_en !== undefined) {
      updates.name_en = name_en || null;
    }
    
    if (linename !== undefined && !name_ar) {
      updates.linename = linename;
      
      if (!name_ar) {
        updates.name_ar = linename;
      }
    }
    
    const line = await Line.update(lineid, updates);
    res.json({
      message: req.t('line.updated') || 'Line updated successfully',
      line,
    });
  } catch (error) {
    next(error);
  }
};


export const deleteLine = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    
    // Check if line exists
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: req.t('line.not_found') || 'Line not found'
      });
    }

    // Delete all related data before deleting the line
    
    // 1. Remove lineid from all vehicles associated with this line
    try {
      const Vehicle = (await import('../models/Vehicle.js')).default;
      const vehicles = await Vehicle.findByLineId(lineid);
      for (const vehicle of vehicles) {
        await Vehicle.update(vehicle.vehicleid, { lineid: null });
      }
      logger.info(`[LineController] ✅ Removed lineid from ${vehicles.length} vehicle(s)`);
    } catch (vehicleError) {
      logger.warn(`[LineController] ⚠️ Error updating vehicles:`, vehicleError);
      // Continue with deletion even if vehicle update fails
    }

    // 2. Delete all schedule templates for this line
    try {
      const ScheduleTemplate = (await import('../models/ScheduleTemplate.js')).default;
      const schedules = await ScheduleTemplate.findAll({ lineid });
      for (const schedule of schedules) {
        await ScheduleTemplate.delete(schedule.templateid);
      }
      logger.info(`[LineController] ✅ Deleted ${schedules.length} schedule template(s)`);
    } catch (scheduleError) {
      logger.warn(`[LineController] ⚠️ Error deleting schedules:`, scheduleError);
      // Continue with deletion even if schedule deletion fails
    }

    // 3. Delete all trips for this line
    try {
      const Trip = (await import('../models/Trip.js')).default;
      const trips = await Trip.findAll({ lineid });
      for (const trip of trips) {
        await Trip.delete(trip.tripid);
      }
      logger.info(`[LineController] ✅ Deleted ${trips.length} trip(s)`);
    } catch (tripError) {
      logger.warn(`[LineController] ⚠️ Error deleting trips:`, tripError);
      // Continue with deletion even if trip deletion fails
    }

    // 4. Remove lineid from all drivers associated with this line
    try {
      const Driver = (await import('../models/Driver.js')).default;
      const drivers = await Driver.findAll({ lineid });
      for (const driver of drivers) {
        await Driver.update(driver.driverid, { lineid: null });
      }
      logger.info(`[LineController] ✅ Removed lineid from ${drivers.length} driver(s)`);
    } catch (driverError) {
      logger.warn(`[LineController] ⚠️ Error updating drivers:`, driverError);
      // Continue with deletion even if driver update fails
    }

    // 5. Delete line path if exists
    try {
      const LinePath = (await import('../models/LinePath.js')).default;
      await LinePath.delete(lineid);
      logger.info(`[LineController] ✅ Deleted line path for line ${lineid}`);
    } catch (pathError) {
      logger.warn(`[LineController] ⚠️ Error deleting line path:`, pathError);
      // Continue with deletion even if path deletion fails
    }
    
    // Now delete the line from the database
    await Line.delete(lineid);
    
    res.json({
      message: req.t('line.deleted') || 'Line has been deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

