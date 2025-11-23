import Trip from '../models/Trip.js';
import ScheduleTemplate from '../models/ScheduleTemplate.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import logger from '../utils/logger.js';
import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/dbcon.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';

/**
 * Generate trip times based on schedule template
 * @param {number} startHour - Starting hour (0-23)
 * @param {number} endHour - Ending hour (0-23)
 * @param {number} intervalMinutes - Interval between trips in minutes
 * @param {Date} targetDate - Date to generate trips for
 * @returns {Date[]} Array of trip departure times
 */
function generateTripTimes(startHour, endHour, intervalMinutes, targetDate) {
  const tripTimes = [];
  const date = new Date(targetDate);
  date.setHours(startHour, 0, 0, 0); // Start at startHour:00:00
  
  const endTime = new Date(targetDate);
  endTime.setHours(endHour, 0, 0, 0); // End at endHour:00:00
  
  while (date <= endTime) {
    tripTimes.push(new Date(date));
    date.setMinutes(date.getMinutes() + intervalMinutes);
  }
  
  return tripTimes;
}

/**
 * Find or get a default vehicle for a line
 * @param {string} lineid - Line ID
 * @returns {Object|null} Vehicle object or null
 */
async function getVehicleForLine(lineid) {
  try {
    // Try to find an active vehicle for this line
    const { data: vehicles, error } = await supabase
      .from('vehicle')
      .select('*')
      .eq('lineid', lineid)
      .eq('status', 'active')
      .limit(1);
    
    if (error) {
      logger.warn('Error finding vehicle for line', { lineid, error });
      return null;
    }
    
    if (vehicles && vehicles.length > 0) {
      return vehicles[0];
    }
    
    // If no vehicle found, return null (trip will be created without vehicle assignment)
    logger.warn('No vehicle found for line', { lineid });
    return null;
  } catch (error) {
    logger.error('Error in getVehicleForLine', { lineid, error });
    return null;
  }
}

/**
 * Create trips for a specific date based on schedule template
 * @param {Object} template - Schedule template object
 * @param {Date} targetDate - Date to create trips for
 * @returns {Object} Result with created trips count and errors
 */
async function createTripsForDate(template, targetDate) {
  const { templateid, lineid, start_hour, end_hour, interval_minutes } = template;
  
  try {
    // Generate trip times for the target date
    const tripTimes = generateTripTimes(start_hour, end_hour, interval_minutes, targetDate);
    
    if (tripTimes.length === 0) {
      logger.warn('No trip times generated', { templateid, targetDate });
      return { created: 0, errors: [] };
    }
    
    // Get line info
    const line = await Line.findById(lineid);
    if (!line) {
      logger.error('Line not found', { lineid });
      return { created: 0, errors: ['Line not found'] };
    }
    
    // Get vehicle for this line (or use null if none available)
    const vehicle = await getVehicleForLine(lineid);
    
    const createdTrips = [];
    const errors = [];
    
    // Create trips for each time
    for (const deptime of tripTimes) {
      try {
        // Check if trip already exists for this time and line
        // Use a time window of ±5 minutes to avoid duplicates
        const timeWindowStart = new Date(deptime.getTime() - 5 * 60 * 1000);
        const timeWindowEnd = new Date(deptime.getTime() + 5 * 60 * 1000);
        
        const { data: existingTrips, error: checkError } = await supabase
          .from('trip')
          .select('tripid')
          .eq('lineid', lineid)
          .gte('deptime', timeWindowStart.toISOString())
          .lte('deptime', timeWindowEnd.toISOString())
          .limit(1);
        
        if (checkError) {
          logger.warn('Error checking existing trips', { lineid, error: checkError });
        }
        
        const tripExists = existingTrips && existingTrips.length > 0;
        
        if (tripExists) {
          logger.debug('Trip already exists, skipping', {
            lineid,
            deptime: deptime.toISOString(),
          });
          continue;
        }
        
        // Use vehicle if available, otherwise skip this trip (vehicle is required)
        if (!vehicle) {
          logger.warn('No vehicle available for line, skipping trip creation', {
            lineid,
            deptime: deptime.toISOString(),
          });
          errors.push({
            deptime: deptime.toISOString(),
            error: 'No vehicle available for this line',
          });
          continue;
        }
        
        // Calculate trip_opening_time (45 minutes before departure)
        const openingTime = new Date(deptime.getTime() - 45 * 60 * 1000);
        
        // Calculate available passenger seats (excluding driver seat only)
        // Note: broken seats are NOT subtracted - they are handled in seat selection UI
        const tripData = {
          tripid: uuidv4(),
          lineid,
          vehicleid: vehicle.vehicleid, // Vehicle is required
          deptime: deptime.toISOString(),
          status: 'scheduled',
          availableseats: calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0),
          totalbookings: 0,
          trip_opening_time: openingTime.toISOString(),
          auto_departure_enabled: true,
          early_departure_allowed: true,
          scheduled_departure_enforced: true,
          templateid: templateid, // Link trip to schedule template
        };
        
        const trip = await Trip.create(tripData);
        createdTrips.push(trip);
        
        logger.info('Trip created from schedule', {
          tripid: trip.tripid,
          lineid,
          deptime: deptime.toISOString(),
          vehicleid: vehicle ? vehicle.vehicleid : 'none',
        });
      } catch (error) {
        logger.error('Error creating trip', {
          lineid,
          deptime: deptime.toISOString(),
          error: error.message,
        });
        errors.push({
          deptime: deptime.toISOString(),
          error: error.message,
        });
      }
    }
    
    return {
      created: createdTrips.length,
      trips: createdTrips,
      errors,
    };
  } catch (error) {
    logger.error('Error in createTripsForDate', {
      templateid,
      targetDate,
      error: error.message,
    });
    return {
      created: 0,
      errors: [error.message],
    };
  }
}

/**
 * Create daily trips for tomorrow based on all active schedule templates
 * @returns {Object} Summary of created trips
 */
export async function createDailyTrips() {
  try {
    logger.info('Starting daily trip creation job');
    
    // Get all active schedule templates
    const templates = await ScheduleTemplate.getActiveTemplates();
    
    if (templates.length === 0) {
      logger.info('No active schedule templates found');
      return {
        success: true,
        templatesProcessed: 0,
        totalTripsCreated: 0,
        results: [],
      };
    }
    
    // Target date: tomorrow
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(0, 0, 0, 0);
    
    const results = [];
    let totalCreated = 0;
    
    // Process each template
    for (const template of templates) {
      try {
        const result = await createTripsForDate(template, tomorrow);
        totalCreated += result.created;
        
        results.push({
          templateid: template.templateid,
          lineid: template.lineid,
          linename: template.line?.linename || 'Unknown',
          created: result.created,
          errors: result.errors,
        });
        
        logger.info('Template processed', {
          templateid: template.templateid,
          lineid: template.lineid,
          created: result.created,
        });
      } catch (error) {
        logger.error('Error processing template', {
          templateid: template.templateid,
          error: error.message,
        });
        results.push({
          templateid: template.templateid,
          lineid: template.lineid,
          created: 0,
          errors: [error.message],
        });
      }
    }
    
    logger.info('Daily trip creation job completed', {
      templatesProcessed: templates.length,
      totalTripsCreated: totalCreated,
    });
    
    return {
      success: true,
      templatesProcessed: templates.length,
      totalTripsCreated: totalCreated,
      results,
    };
  } catch (error) {
    logger.error('Error in createDailyTrips', { error: error.message });
    return {
      success: false,
      error: error.message,
      templatesProcessed: 0,
      totalTripsCreated: 0,
      results: [],
    };
  }
}

/**
 * Create trips for a specific date and template
 * @param {string} templateid - Template ID
 * @param {Date} targetDate - Target date
 * @returns {Object} Result with created trips
 */
export async function createTripsForTemplate(templateid, targetDate) {
  try {
    const template = await ScheduleTemplate.findById(templateid);
    if (!template) {
      throw new Error('Schedule template not found');
    }
    
    const date = targetDate ? new Date(targetDate) : new Date();
    date.setHours(0, 0, 0, 0);
    
    return await createTripsForDate(template, date);
  } catch (error) {
    logger.error('Error in createTripsForTemplate', {
      templateid,
      targetDate,
      error: error.message,
    });
    throw error;
  }
}


