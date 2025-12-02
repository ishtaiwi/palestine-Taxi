/**
 * Polyline service for encoding and decoding route paths
 * Uses @mapbox/polyline for encoding/decoding
 */
import polyline from '@mapbox/polyline';

/**
 * Encode an array of coordinates to a polyline string
 * @param {Array} coordinates - Array of [lat, lng] or {lat, lng} objects
 * @returns {string} Encoded polyline string
 */
export function encodePolyline(coordinates) {
  if (!coordinates || coordinates.length === 0) {
    return null;
  }

  // Convert to array of [lat, lng] pairs
  const points = coordinates.map(coord => {
    if (Array.isArray(coord)) {
      return [coord[0], coord[1]]; // [lat, lng]
    } else if (coord.lat !== undefined && coord.lng !== undefined) {
      return [coord.lat, coord.lng];
    } else if (coord.latitude !== undefined && coord.longitude !== undefined) {
      return [coord.latitude, coord.longitude];
    }
    throw new Error('Invalid coordinate format');
  });

  return polyline.encode(points);
}

/**
 * Decode a polyline string to an array of coordinates
 * @param {string} encoded - Encoded polyline string
 * @returns {Array} Array of [lat, lng] pairs
 */
export function decodePolyline(encoded) {
  if (!encoded || typeof encoded !== 'string') {
    return [];
  }

  try {
    return polyline.decode(encoded);
  } catch (error) {
    console.error('Error decoding polyline:', error);
    return [];
  }
}

/**
 * Convert decoded polyline to waypoints format
 * @param {string} encoded - Encoded polyline string
 * @returns {Array} Array of {lat, lng} objects
 */
export function decodePolylineToWaypoints(encoded) {
  const decoded = decodePolyline(encoded);
  return decoded.map(([lat, lng]) => ({ lat, lng }));
}

