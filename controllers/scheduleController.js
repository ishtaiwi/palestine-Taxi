import ScheduleTemplate from '../models/ScheduleTemplate.js';
import Trip from '../models/Trip.js';
import { createTripsForTemplate, createDailyTrips } from '../services/dailyTripService.js';
import logger from '../utils/logger.js';


/**
 * Validates schedule data (for both create and update operations)
 * @param {Object} data - The schedule data to validate
 * @param {Object} req - Express request object (for i18n)
 * @param {boolean} isCreate - Whether this is for create (true) or update (false)
 * @returns {Object|null} - Returns error response object if validation fails, null otherwise
 */
const validateScheduleData = (data, req, isCreate = false) => {
  // For create, lineid is required
  if (isCreate && !data.lineid) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.lineid_required') || 'lineid is required',
      },
    };
  }
  
  // For create, start_hour is required
  if (isCreate && data.start_hour === undefined) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_start_hour') || 'start_hour must be between 0 and 23',
      },
    };
  }
  
  // Validate start_hour (if provided)
  if (data.start_hour !== undefined && (data.start_hour < 0 || data.start_hour > 23)) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_start_hour') || 'start_hour must be between 0 and 23',
      },
    };
  }
  
  // For create, end_hour is required
  if (isCreate && data.end_hour === undefined) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_end_hour') || 'end_hour must be between 0 and 23',
      },
    };
  }
  
  // Validate end_hour (if provided)
  if (data.end_hour !== undefined && (data.end_hour < 0 || data.end_hour > 23)) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_end_hour') || 'end_hour must be between 0 and 23',
      },
    };
  }
  
  // Validate end_hour >= start_hour (if both are provided)
  if (data.start_hour !== undefined && data.end_hour !== undefined && data.end_hour < data.start_hour) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.end_before_start') || 'end_hour must be >= start_hour',
      },
    };
  }
  
  // For create, interval_minutes is required
  if (isCreate && data.interval_minutes === undefined) {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_interval') || 'interval_minutes must be > 0',
      },
    };
  }
  
  // Validate interval_minutes (if provided)
  if (data.interval_minutes !== undefined) {
    if (data.interval_minutes <= 0) {
      return {
        status: 400,
        body: {
          message: req.t('schedule.invalid_interval') || 'interval_minutes must be > 0',
        },
      };
    }
    // Only allow 30 or 60 minute intervals
    if (data.interval_minutes !== 30 && data.interval_minutes !== 60) {
      return {
        status: 400,
        body: {
          message: req.t('schedule.invalid_interval_value') || 'interval_minutes must be either 30 or 60 minutes',
        },
      };
    }
  }
  
  // Validate boolean fields
  if (data.auto_departure_enabled !== undefined && typeof data.auto_departure_enabled !== 'boolean') {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_auto_departure') || 'auto_departure_enabled must be a boolean',
      },
    };
  }
  
  if (data.scheduled_departure_enforced !== undefined && typeof data.scheduled_departure_enforced !== 'boolean') {
    return {
      status: 400,
      body: {
        message: req.t('schedule.invalid_scheduled_departure') || 'scheduled_departure_enforced must be a boolean',
      },
    };
  }
  
  return null; // Validation passed
};


export const getAllSchedules = async (req, res, next) => {
  try {
    const { lineid, active } = req.query;
    
    const filters = {};
    if (lineid) filters.lineid = lineid;
    if (active !== undefined) filters.active = active === 'true';
    
    const schedules = await ScheduleTemplate.findAll(filters);
    
    res.json({
      message: req.t('schedule.list') || 'Schedules retrieved successfully',
      schedules,
    });
  } catch (error) {
    next(error);
  }
};


export const getScheduleById = async (req, res, next) => {
  try {
    const { templateid } = req.params;
    const schedule = await ScheduleTemplate.findById(templateid);
    
    if (!schedule) {
      return res.status(404).json({
        message: req.t('schedule.not_found') || 'Schedule template not found',
      });
    }
    
    res.json({
      message: req.t('schedule.found') || 'Schedule template found',
      schedule,
    });
  } catch (error) {
    next(error);
  }
};


export const createSchedule = async (req, res, next) => {
  try {
    const { lineid, start_hour, end_hour, interval_minutes, active, auto_departure_enabled, scheduled_departure_enforced } = req.body;
    
    // Validate schedule data
    const validationError = validateScheduleData(req.body, req, true);
    if (validationError) {
      return res.status(validationError.status).json(validationError.body);
    }
    
    // Check if a schedule already exists for this line
    const scheduleExists = await ScheduleTemplate.existsForLine(lineid);
    if (scheduleExists) {
      return res.status(400).json({
        success: false,
        message: req.t('schedule.duplicate_line') || 'A schedule already exists for this line. Only one schedule per line is allowed.',
      });
    }
    
    const scheduleData = {
      lineid,
      start_hour: parseInt(start_hour, 10),
      end_hour: parseInt(end_hour, 10),
      interval_minutes: parseInt(interval_minutes, 10),
      active: active !== undefined ? active : true,
      auto_departure_enabled: auto_departure_enabled !== undefined ? auto_departure_enabled : false,
      scheduled_departure_enforced: scheduled_departure_enforced !== undefined ? scheduled_departure_enforced : false,
    };
    
    const schedule = await ScheduleTemplate.create(scheduleData);
    
    res.status(201).json({
      message: req.t('schedule.created') || 'Schedule template created successfully',
      schedule,
    });
  } catch (error) {
    next(error);
  }
};


export const updateSchedule = async (req, res, next) => {
  try {
    const { templateid } = req.params;
    const updates = req.body;
    
    // Validate schedule data
    const validationError = validateScheduleData(updates, req, false);
    if (validationError) {
      return res.status(validationError.status).json(validationError.body);
    }
    
    const schedule = await ScheduleTemplate.update(templateid, updates);
    
    res.json({
      message: req.t('schedule.updated') || 'Schedule template updated successfully',
      schedule,
    });
  } catch (error) {
    next(error);
  }
};


export const deleteSchedule = async (req, res, next) => {
  try {
    const { templateid } = req.params;
    
    // Check if there are any trips referencing this schedule template
    const trips = await Trip.findAll({ templateid });
    if (trips && trips.length > 0) {
      const errorMessage = req.t('schedule.has_trips') || 
        `Cannot delete schedule. There are ${trips.length} trip(s) associated with this schedule. Please delete or reassign the trips first.`;
      return res.status(400).json({
        success: false,
        message: errorMessage,
      });
    }
    
    await ScheduleTemplate.delete(templateid);
    
    res.json({
      success: true,
      message: req.t('schedule.deleted') || 'Schedule template deleted successfully',
    });
  } catch (error) {
    // Handle foreign key constraint error
    if (error.code === '23503' || error.message?.includes('foreign key constraint')) {
      const errorMessage = req.t('schedule.has_trips') || 
        'Cannot delete schedule. There are trips associated with this schedule. Please delete or reassign the trips first.';
      return res.status(400).json({
        success: false,
        message: errorMessage,
      });
    }
    next(error);
  }
};


export const createTripsForSchedule = async (req, res, next) => {
  try {
    const { templateid } = req.params;
    const { target_date } = req.body;
    
    const targetDate = target_date ? new Date(target_date) : new Date();
    
    const result = await createTripsForTemplate(templateid, targetDate);
    
    res.json({
      message: req.t('schedule.trips_created') || 'Trips created successfully',
      result,
    });
  } catch (error) {
    next(error);
  }
};


export const triggerDailyTripCreation = async (req, res, next) => {
  try {
    const result = await createDailyTrips();
    
    res.json({
      message: req.t('schedule.daily_trips_created') || 'Daily trips creation completed',
      result,
    });
  } catch (error) {
    next(error);
  }
};

