import Trip from '../models/Trip.js';
import ScheduleTemplate from '../models/ScheduleTemplate.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import logger from '../utils/logger.js';
import { v4 as uuidv4 } from 'uuid';
import supabase from '../config/dbcon.js';
import { calculateAvailablePassengerSeats } from '../utils/seatCalculation.js';
import { getServerTimezoneOffset, parseUtcDate, getUtcNow, getOpeningWindowMinutes } from '../utils/timeUtils.js';

/**
 * Generate trip times based on schedule template
 * Converts local schedule times to UTC using admin-configured timezone
 * @param {number} startHour - Starting hour (0-23) in local timezone
 * @param {number} endHour - Ending hour (0-23) in local timezone
 * @param {number} intervalMinutes - Interval between trips in minutes
 * @param {Date} targetDate - Date to generate trips for
 * @returns {Promise<Date[]>} Array of trip departure times in UTC
 */
async function generateTripTimes(startHour, endHour, intervalMinutes, targetDate) {

  const timezoneOffset = await getServerTimezoneOffset();

  const tripTimes = [];


  const year = targetDate.getFullYear();
  const month = String(targetDate.getMonth() + 1).padStart(2, '0');
  const day = String(targetDate.getDate()).padStart(2, '0');


  const offsetSign = timezoneOffset >= 0 ? '+' : '-';
  const offsetHours = String(Math.abs(timezoneOffset)).padStart(2, '0');


  let currentMinutes = startHour * 60;
  const endMinutes = endHour * 60;

  while (currentMinutes <= endMinutes) {
    const hours = Math.floor(currentMinutes / 60);
    const mins = currentMinutes % 60;



    const localTimeString = `${year}-${month}-${day}T${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}:00${offsetSign}${offsetHours}:00`;


    const utcTime = parseUtcDate(localTimeString);
    if (utcTime) {
      tripTimes.push(utcTime);
    }

    currentMinutes += intervalMinutes;
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
  const { templateid, lineid, start_hour, end_hour, interval_minutes, direction } = template;
  const tripDirection = direction || 'going'; // Use template direction or default to 'going'

  try {

    const tripTimes = await generateTripTimes(start_hour, end_hour, interval_minutes, targetDate);

    if (tripTimes.length === 0) {
      logger.warn('No trip times generated', { templateid, targetDate });
      return { created: 0, errors: [] };
    }


    const line = await Line.findById(lineid);
    if (!line) {
      logger.error('Line not found', { lineid });
      return { created: 0, errors: ['Line not found'] };
    }



    const vehicle = await getVehicleForLine(lineid);

    const createdTrips = [];
    const errors = [];


    const now = getUtcNow();
    for (const deptime of tripTimes) {
      try {

        if (deptime.getTime() <= now.getTime()) {
          logger.debug('Skipping trip in the past', {
            lineid,
            deptime: deptime.toISOString(),
            now: now.toISOString(),
          });
          continue;
        }



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


        const openingWindowMinutes = getOpeningWindowMinutes(interval_minutes);
        const openingTime = new Date(deptime.getTime() - openingWindowMinutes * 60 * 1000);



        const defaultSeats = vehicle ? vehicle.seatnum : 5;
        const defaultAvailableSeats = calculateAvailablePassengerSeats(defaultSeats, 0, 0);



        // Determine origin_stationid based on direction
        let origin_stationid = null;
        if (tripDirection === 'going' && line.main_stationid) {
          origin_stationid = line.main_stationid;
        } else if (tripDirection === 'return' && line.return_stationid) {
          origin_stationid = line.return_stationid;
        }

        const tripData = {
          tripid: uuidv4(),
          lineid,
          vehicleid: null,
          deptime: deptime.toISOString(),
          status: 'scheduled',
          availableseats: defaultAvailableSeats,
          totalbookings: 0,
          trip_opening_time: openingTime.toISOString(),
          auto_departure_enabled: template.auto_departure_enabled ?? false,
          early_departure_allowed: true,
          scheduled_departure_enforced: template.scheduled_departure_enforced ?? false,
          templateid: templateid,
          direction: tripDirection,
          origin_stationid: origin_stationid,
        };

        const trip = await Trip.create(tripData);

        // Assign any existing future bookings to this newly created trip
        try {
          const { distributeFutureBookings } = await import('./matchingService.js');
          const futureResult = await distributeFutureBookings(deptime.toISOString(), lineid, trip.tripid);
          if (futureResult.distributed > 0) {
            logger.info('Assigned existing future bookings to newly created trip', {
              tripid: trip.tripid,
              lineid,
              deptime: deptime.toISOString(),
              distributed: futureResult.distributed,
            });
          }
        } catch (error) {
          logger.warn('Error assigning future bookings to new trip', {
            tripid: trip.tripid,
            lineid,
            deptime: deptime.toISOString(),
            error: error.message,
          });
          // Don't fail trip creation if booking assignment fails
        }

        createdTrips.push(trip);

        logger.info('Trip created from schedule', {
          tripid: trip.tripid,
          lineid,
          deptime: deptime.toISOString(),
          vehicleid: null,
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


    const tomorrow = new Date();

    tomorrow.setDate(tomorrow.getDate() + 1);

    tomorrow.setHours(0, 0, 0, 0);

    const results = [];
    let totalCreated = 0;


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


