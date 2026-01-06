import AppConfig from '../models/AppConfig.js';
import { TRIP_STATUS } from './constants.js';

// Cache timezone offset to avoid repeated DB calls
let cachedTimezoneOffset = null;
let timezoneCacheTime = null;
const CACHE_DURATION_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Get current UTC time
 * @returns {Date} Current UTC time
 */
export const getUtcNow = () => {
  return new Date();
};

/**
 * Parse a date string as UTC, handling various formats
 * @param {string | Date} value - Date string or Date object
 * @returns {Date | null} Parsed UTC Date or null if invalid
 */
export const parseUtcDate = (value) => {
  if (!value) return null;

  if (value instanceof Date) {
    return value;
  }

  let str = value.toString().trim();

  // Normalize space to 'T' between date and time
  str = str.replace(' ', 'T');

  // Ensure timezone is explicit - if no timezone, treat as UTC
  if (!/[zZ]|[+\-]\d{2}:?\d{2}$/.test(str)) {
    str += 'Z';
  }

  const d = new Date(str);
  if (Number.isNaN(d.getTime())) {
    console.warn('[TimeUtils] Unable to parse date:', value);
    return null;
  }
  return d;
};

/**
 * Get server timezone offset from config (cached)
 * @returns {Promise<number>} Timezone offset in hours (e.g., 2 for UTC+2)
 */
export const getServerTimezoneOffset = async () => {
  const now = Date.now();
  
  // Return cached value if still valid
  if (cachedTimezoneOffset !== null && timezoneCacheTime && (now - timezoneCacheTime) < CACHE_DURATION_MS) {
    return cachedTimezoneOffset;
  }

  try {
    const offset = await AppConfig.getTimezoneOffset();
    cachedTimezoneOffset = offset;
    timezoneCacheTime = now;
    return offset;
  } catch (error) {
    console.warn('[TimeUtils] Error getting timezone offset, using default:', error);
    cachedTimezoneOffset = 2; // Default to UTC+2
    timezoneCacheTime = now;
    return cachedTimezoneOffset;
  }
};

/**
 * Convert local time to UTC
 * @param {Date} localDate - Date in local timezone
 * @param {number} timezoneOffset - Timezone offset in hours (e.g., 2 for UTC+2)
 * @returns {Date} UTC Date
 */
export const convertLocalToUtc = (localDate, timezoneOffset) => {
  if (!localDate) return null;
  
  // Create a date string with explicit timezone offset
  const year = localDate.getFullYear();
  const month = String(localDate.getMonth() + 1).padStart(2, '0');
  const day = String(localDate.getDate()).padStart(2, '0');
  const hours = String(localDate.getHours()).padStart(2, '0');
  const minutes = String(localDate.getMinutes()).padStart(2, '0');
  const seconds = String(localDate.getSeconds()).padStart(2, '0');
  
  // Format: YYYY-MM-DDTHH:mm:ss+HH:mm
  const offsetSign = timezoneOffset >= 0 ? '+' : '-';
  const offsetHours = String(Math.abs(timezoneOffset)).padStart(2, '0');
  const offsetMinutes = '00';
  
  const localDateString = `${year}-${month}-${day}T${hours}:${minutes}:${seconds}${offsetSign}${offsetHours}:${offsetMinutes}`;
  
  return parseUtcDate(localDateString);
};

/**
 * Convert UTC to local time
 * @param {Date} utcDate - Date in UTC
 * @param {number} timezoneOffset - Timezone offset in hours (e.g., 2 for UTC+2)
 * @returns {Date} Local Date (note: JavaScript Date objects are always in local timezone, this adjusts the time)
 */
export const convertUtcToLocal = (utcDate, timezoneOffset) => {
  if (!utcDate) return null;
  
  const utcTime = utcDate.getTime();
  const localTime = utcTime + (timezoneOffset * 60 * 60 * 1000);
  
  return new Date(localTime);
};

/**
 * Check if a trip is open (opening time has passed and status is 'open')
 * @param {object} trip - Trip object
 * @returns {boolean} True if trip is open
 */
export const isTripOpen = (trip) => {
  if (!trip) return false;
  
  // Status must be 'open'
  if (trip.status !== TRIP_STATUS.OPEN) {
    return false;
  }
  
  // Check if opening time has passed
  const now = getUtcNow();
  const openingTime = trip.trip_opening_time ? parseUtcDate(trip.trip_opening_time) : null;
  
  if (!openingTime) {
    // If no opening time set, check if deptime - 45 minutes has passed
    const deptime = trip.deptime ? parseUtcDate(trip.deptime) : null;
    if (!deptime) return false;
    
    const defaultOpeningTime = new Date(deptime.getTime() - 45 * 60 * 1000);
    return defaultOpeningTime.getTime() <= now.getTime();
  }
  
  return openingTime.getTime() <= now.getTime();
};

/**
 * Check if instant booking is allowed for a trip
 * @param {object} trip - Trip object
 * @returns {boolean} True if instant booking is allowed
 */
export const canBookInstant = (trip) => {
  if (!trip) return false;
  
  // Trip must be in a bookable status
  const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.OPEN, TRIP_STATUS.DELAYED];
  if (!validStatuses.includes(trip.status)) {
    return false;
  }
  
  // Trip must not have departed
  const departedStatuses = [TRIP_STATUS.IN_PROGRESS, TRIP_STATUS.COMPLETED];
  if (departedStatuses.includes(trip.status)) {
    return false;
  }
  
  // Must have available seats
  if (trip.availableseats <= 0) {
    return false;
  }
  
  // Check if opening time has passed
  const now = getUtcNow();
  const openingTime = trip.trip_opening_time ? parseUtcDate(trip.trip_opening_time) : null;
  
  if (openingTime) {
    // If opening time is set, check if it has passed
    if (openingTime.getTime() > now.getTime()) {
      return false;
    }
  } else {
    // If no opening time, check if deptime - 45 minutes has passed
    const deptime = trip.deptime ? parseUtcDate(trip.deptime) : null;
    if (!deptime) return false;
    
    const defaultOpeningTime = new Date(deptime.getTime() - 45 * 60 * 1000);
    if (defaultOpeningTime.getTime() > now.getTime()) {
      return false;
    }
  }
  
  return true;
};

/**
 * Check if a trip has departed
 * @param {object} trip - Trip object
 * @returns {boolean} True if trip has departed
 */
export const hasDeparted = (trip) => {
  if (!trip) return false;
  
  const departedStatuses = [TRIP_STATUS.IN_PROGRESS, TRIP_STATUS.COMPLETED];
  if (departedStatuses.includes(trip.status)) {
    return true;
  }
  
  // Also check if deptime has passed
  const now = getUtcNow();
  const deptime = trip.deptime ? parseUtcDate(trip.deptime) : null;
  
  if (deptime && deptime.getTime() <= now.getTime()) {
    return true;
  }
  
  return false;
};

/**
 * Add computed time flags to a trip object
 * @param {object} trip - Trip object
 * @returns {object} Trip object with added flags (canBookInstant, isOpen, hasDeparted, serverNow)
 */
export const addTimeFlagsToTrip = (trip) => {
  if (!trip) return trip;
  
  return {
    ...trip,
    canBookInstant: canBookInstant(trip),
    isOpen: isTripOpen(trip),
    hasDeparted: hasDeparted(trip),
    serverNow: getUtcNow().toISOString(),
  };
};

/**
 * Add computed time flags to an array of trips
 * @param {Array<object>} trips - Array of trip objects
 * @returns {Array<object>} Array of trip objects with added flags
 */
export const addTimeFlagsToTrips = (trips) => {
  if (!Array.isArray(trips)) return trips;
  
  return trips.map(trip => addTimeFlagsToTrip(trip));
};

