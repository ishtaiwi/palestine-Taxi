import { BOOKING_TYPE } from './constants.js';
import { getUtcNow, parseUtcDate } from './timeUtils.js';

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
    const tripTime = parseUtcDate(scheduledTripTime);
    if (!tripTime) {
      return false; // Invalid date format
    }
    const now = getUtcNow();
    if (tripTime.getTime() <= now.getTime()) {
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
    const deptime = parseUtcDate(tripData.deptime);
    if (!deptime) {
      errors.push('Invalid deptime format');
    } else {
      const now = getUtcNow();
      if (deptime.getTime() <= now.getTime()) {
        errors.push('Departure time must be in the future');
      }
    }
  }

  if (tripData.trip_opening_time && tripData.deptime) {
    const openingTime = parseUtcDate(tripData.trip_opening_time);
    const deptime = parseUtcDate(tripData.deptime);
    if (openingTime && deptime && openingTime.getTime() >= deptime.getTime()) {
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

