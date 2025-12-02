import LinePath from '../models/LinePath.js';
import Line from '../models/Line.js';
import { encodePolyline } from '../services/polylineService.js';
import logger from '../utils/logger.js';

/**
 * Get line path
 * GET /api/lines/:lineid/path
 */
export const getLinePath = async (req, res, next) => {
  try {
    const { lineid } = req.params;

    // Verify line exists
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    const path = await LinePath.findByLineId(lineid);
    if (!path) {
      return res.status(404).json({
        message: 'Path not found for this line',
      });
    }

    res.json({
      path,
    });
  } catch (error) {
    logger.error('Error getting line path:', error);
    next(error);
  }
};

/**
 * Create or update line path
 * POST /api/admin/lines/:lineid/path
 */
export const createOrUpdateLinePath = async (req, res, next) => {
  try {
    const { lineid } = req.params;
    const { waypoints, polyline, distance_meters } = req.body;

    // Verify line exists
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    // Validate waypoints
    if (!waypoints || !Array.isArray(waypoints) || waypoints.length < 2) {
      return res.status(400).json({
        message: 'At least 2 waypoints are required',
      });
    }

    // Validate waypoint format
    for (const waypoint of waypoints) {
      if (waypoint.lat === undefined || waypoint.lng === undefined) {
        return res.status(400).json({
          message: 'Each waypoint must have lat and lng properties',
        });
      }
      if (waypoint.lat < -90 || waypoint.lat > 90 || waypoint.lng < -180 || waypoint.lng > 180) {
        return res.status(400).json({
          message: 'Invalid coordinate values in waypoints',
        });
      }
    }

    // Encode polyline if not provided
    let encodedPolyline = polyline;
    if (!encodedPolyline) {
      encodedPolyline = encodePolyline(waypoints);
    }

    // Create or update path
    const path = await LinePath.upsert(lineid, {
      waypoints,
      polyline: encodedPolyline,
      distance_meters: distance_meters ? parseFloat(distance_meters) : null,
    });

    logger.info('Line path created/updated', {
      lineid,
      pathid: path.pathid,
      waypointCount: waypoints.length,
      distanceMeters: path.distance_meters,
    });

    res.json({
      message: 'Line path saved successfully',
      path,
    });
  } catch (error) {
    logger.error('Error creating/updating line path:', error);
    next(error);
  }
};

/**
 * Delete line path
 * DELETE /api/admin/lines/:lineid/path
 */
export const deleteLinePath = async (req, res, next) => {
  try {
    const { lineid } = req.params;

    // Verify line exists
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    await LinePath.delete(lineid);

    logger.info('Line path deleted', {
      lineid,
    });

    res.json({
      message: 'Line path deleted successfully',
    });
  } catch (error) {
    logger.error('Error deleting line path:', error);
    next(error);
  }
};

