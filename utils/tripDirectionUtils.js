import { TRIP_DIRECTION, QUEUE_DIRECTION } from './constants.js';

/**
 * Map queue direction to trip direction
 * @param {string} queueDirection - 'going' or 'returning'
 * @returns {string} - 'going' or 'return'
 */
export function mapQueueDirectionToTripDirection(queueDirection) {
  if (queueDirection === QUEUE_DIRECTION.RETURNING) {
    return TRIP_DIRECTION.RETURN;
  }
  return TRIP_DIRECTION.GOING;
}

/**
 * Map trip direction to queue direction
 * @param {string} tripDirection - 'going' or 'return'
 * @returns {string} - 'going' or 'returning'
 */
export function mapTripDirectionToQueueDirection(tripDirection) {
  if (tripDirection === TRIP_DIRECTION.RETURN) {
    return QUEUE_DIRECTION.RETURNING;
  }
  return QUEUE_DIRECTION.GOING;
}

/**
 * Reverse waypoint array for returning trips
 * @param {Array} waypoints - Array of waypoint objects
 * @returns {Array} - Reversed waypoint array
 */
export function getReversedWaypoints(waypoints) {
  if (!waypoints || !Array.isArray(waypoints)) {
    return [];
  }
  return [...waypoints].reverse();
}

/**
 * Get origin waypoint (first waypoint)
 * @param {Array} waypoints - Array of waypoint objects
 * @returns {Object|null} - First waypoint or null
 */
export function getOriginFromWaypoints(waypoints) {
  if (!waypoints || !Array.isArray(waypoints) || waypoints.length === 0) {
    return null;
  }
  return waypoints[0];
}

/**
 * Get destination waypoint (last waypoint)
 * @param {Array} waypoints - Array of waypoint objects
 * @returns {Object|null} - Last waypoint or null
 */
export function getDestinationFromWaypoints(waypoints) {
  if (!waypoints || !Array.isArray(waypoints) || waypoints.length === 0) {
    return null;
  }
  return waypoints[waypoints.length - 1];
}

/**
 * Calculate return trip departure time
 * @param {Object} goingTrip - The going trip object
 * @param {number} bufferMinutes - Buffer time in minutes (default: 15)
 * @returns {Date} - Calculated return trip departure time
 */
export function calculateReturnTripDeptime(goingTrip, bufferMinutes = 15) {
  if (!goingTrip) {
    throw new Error('Going trip is required');
  }

  const goingDeptime = new Date(goingTrip.deptime);
  if (isNaN(goingDeptime.getTime())) {
    throw new Error('Invalid going trip departure time');
  }

  // Estimate trip duration (default 60 minutes if not available)
  const estimatedDurationMinutes = goingTrip.line?.estduration || 60;
  
  // Return trip departs after going trip arrives + buffer
  const returnDeptime = new Date(goingDeptime.getTime() + (estimatedDurationMinutes + bufferMinutes) * 60 * 1000);
  
  return returnDeptime;
}


