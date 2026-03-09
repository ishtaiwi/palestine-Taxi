/**
 * Calculate distance between two coordinates using Haversine formula
 * @param {number} lat1 - Latitude of first point
 * @param {number} lng1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lng2 - Longitude of second point
 * @returns {number} - Distance in meters
 */
export function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in meters
}

/**
 * Convert degrees to radians
 * @param {number} degrees - Angle in degrees
 * @returns {number} - Angle in radians
 */
function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}

/**
 * Check if driver is within geofence radius of a station
 * @param {number} driverLat - Driver's latitude
 * @param {number} driverLng - Driver's longitude
 * @param {number} stationLat - Station's latitude
 * @param {number} stationLng - Station's longitude
 * @param {number} radius - Geofence radius in meters
 * @returns {boolean} - True if driver is within radius
 */
export function isWithinGeofence(driverLat, driverLng, stationLat, stationLng, radius) {
  if (!driverLat || !driverLng || !stationLat || !stationLng) {
    return false;
  }

  const distance = calculateDistance(driverLat, driverLng, stationLat, stationLng);
  return distance <= radius;
}

/**
 * Get required station for a direction from line
 * @param {Object} line - Line object with main_stationid and return_stationid
 * @param {string} direction - 'going' or 'returning'
 * @returns {string|null} - Station ID or null
 */
export function getRequiredStationForDirection(line, direction) {
  if (!line) {
    return null;
  }

  if (direction === 'going') {
    return line.main_stationid || null;
  } else if (direction === 'returning') {
    return line.return_stationid || null;
  }

  return null;
}


