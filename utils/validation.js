import { BOOKING_TYPE } from './constants.js';

/**
 * Validate booking_type value
 * @param {string} bookingType - The booking type to validate
 * @returns {boolean} - True if valid
 */
export const isValidBookingType = (bookingType) => {
  return bookingType === BOOKING_TYPE.FUTURE || bookingType === BOOKING_TYPE.INSTANT;
};

/**
 * Validate scheduled_trip_time for future bookings
 * @param {string} bookingType - The booking type
 * @param {string|Date} scheduledTripTime - The scheduled trip time
 * @returns {boolean} - True if valid
 */
export const validateScheduledTripTime = (bookingType, scheduledTripTime) => {
  if (bookingType === BOOKING_TYPE.FUTURE) {
    if (!scheduledTripTime) {
      return false; // Future bookings must have scheduled_trip_time
    }
    const tripTime = new Date(scheduledTripTime);
    const now = new Date();
    if (tripTime <= now) {
      return false; // Future bookings must be for future trips
    }
  }
  return true;
};

/**
 * Validate reservation data before creation
 * @param {object} reservationData - The reservation data to validate
 * @returns {object} - { valid: boolean, errors: string[] }
 */
export const validateReservationData = (reservationData) => {
  const errors = [];
  
  if (reservationData.booking_type) {
    if (!isValidBookingType(reservationData.booking_type)) {
      errors.push(`Invalid booking_type: ${reservationData.booking_type}. Must be 'future' or 'instant'`);
    }
    
    if (!validateScheduledTripTime(reservationData.booking_type, reservationData.scheduled_trip_time)) {
      errors.push('Future bookings must have a valid scheduled_trip_time in the future');
    }
  }
  
  return {
    valid: errors.length === 0,
    errors,
  };
};

/**
 * Validate trip data before creation
 * @param {object} tripData - The trip data to validate
 * @returns {object} - { valid: boolean, errors: string[] }
 */
export const validateTripData = (tripData) => {
  const errors = [];
  
  if (tripData.deptime) {
    const deptime = new Date(tripData.deptime);
    const now = new Date();
    if (deptime <= now) {
      errors.push('Departure time must be in the future');
    }
  }
  
  if (tripData.trip_opening_time && tripData.deptime) {
    const openingTime = new Date(tripData.trip_opening_time);
    const deptime = new Date(tripData.deptime);
    if (openingTime >= deptime) {
      errors.push('Trip opening time must be before departure time');
    }
  }
  
  if (tripData.auto_departure_enabled !== undefined && typeof tripData.auto_departure_enabled !== 'boolean') {
    errors.push('auto_departure_enabled must be a boolean');
  }
  
  if (tripData.early_departure_allowed !== undefined && typeof tripData.early_departure_allowed !== 'boolean') {
    errors.push('early_departure_allowed must be a boolean');
  }
  
  if (tripData.scheduled_departure_enforced !== undefined && typeof tripData.scheduled_departure_enforced !== 'boolean') {
    errors.push('scheduled_departure_enforced must be a boolean');
  }
  
  return {
    valid: errors.length === 0,
    errors,
  };
};

