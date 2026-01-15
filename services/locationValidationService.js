import VehicleLocation from '../models/VehicleLocation.js';
import Line from '../models/Line.js';
import { isWithinGeofence, getRequiredStationForDirection } from '../utils/locationValidationUtils.js';
import logger from '../utils/logger.js';

/**
 * Validate driver location for queue join
 * @param {string} driverid - Driver ID
 * @param {string} lineid - Line ID
 * @param {string} direction - 'going' or 'returning'
 * @returns {Promise<{valid: boolean, error?: string, station?: Object, distance?: number}>}
 */
export async function validateQueueJoinLocation(driverid, lineid, direction) {
  try {
    // Get driver's current location
    const driverLocation = await VehicleLocation.getDriverLocation(driverid);
    
    if (!driverLocation || !driverLocation.latitude || !driverLocation.longitude) {
      return {
        valid: false,
        error: 'Driver location not found. Please enable location tracking.',
      };
    }

    // Get line with station information
    const line = await Line.findById(lineid);
    if (!line) {
      return {
        valid: false,
        error: 'Line not found',
      };
    }

    // Get required station for direction
    const stationId = getRequiredStationForDirection(line, direction);
    if (!stationId) {
      logger.warn(`No station configured for line ${lineid} direction ${direction}`);
      return {
        valid: false,
        error: `No station configured for ${direction} direction`,
      };
    }

    // Get station details
    const BaseStation = (await import('../models/BaseStation.js')).default;
    const station = await BaseStation.findById(stationId);
    
    if (!station) {
      return {
        valid: false,
        error: 'Station not found',
      };
    }

    // Validate location
    const validation = await VehicleLocation.validateDriverAtStation(
      driverid,
      station.latitude,
      station.longitude,
      station.geofence_radius_meters || 100
    );

    if (!validation.isAtStation) {
      const distanceKm = (validation.distance / 1000).toFixed(2);
      return {
        valid: false,
        error: `You must be at ${station.name} to join the ${direction} queue. You are ${distanceKm} km away.`,
        station: {
          stationid: station.stationid,
          name: station.name,
          latitude: station.latitude,
          longitude: station.longitude,
          geofence_radius_meters: station.geofence_radius_meters,
        },
        distance: validation.distance,
        driverLocation: {
          latitude: validation.driverLat,
          longitude: validation.driverLng,
        },
      };
    }

    return {
      valid: true,
      station: {
        stationid: station.stationid,
        name: station.name,
        latitude: station.latitude,
        longitude: station.longitude,
      },
    };
  } catch (error) {
    logger.error('Error validating queue join location:', error);
    return {
      valid: false,
      error: 'Error validating location. Please try again.',
    };
  }
}


