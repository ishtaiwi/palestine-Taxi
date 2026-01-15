import logger from '../utils/logger.js';

/**
 * Proxy route requests to OSRM to avoid CORS issues on web
 * POST /api/routing/route
 */
export const getRoute = async (req, res, next) => {
  try {
    const { waypoints } = req.body;

    if (!waypoints || !Array.isArray(waypoints) || waypoints.length < 2) {
      return res.status(400).json({
        success: false,
        message: 'At least 2 waypoints are required',
      });
    }

    // Build coordinates string for OSRM: lng,lat;lng,lat;...
    const coordinates = waypoints
      .map((wp) => `${wp.lng},${wp.lat}`)
      .join(';');

    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${coordinates}?overview=full&geometries=polyline&steps=false`;

    logger.info('Fetching route from OSRM', { waypointCount: waypoints.length });

    const response = await fetch(osrmUrl, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      logger.error('OSRM request failed', { status: response.status });
      return res.status(502).json({
        success: false,
        message: 'Failed to fetch route from routing service',
      });
    }

    const data = await response.json();

    if (data.code !== 'Ok' || !data.routes || data.routes.length === 0) {
      logger.warn('OSRM returned no routes', { code: data.code });
      return res.status(404).json({
        success: false,
        message: 'No route found between the specified waypoints',
      });
    }

    const route = data.routes[0];

    res.json({
      success: true,
      route: {
        geometry: route.geometry,
        distance: route.distance,
        duration: route.duration,
      },
    });
  } catch (error) {
    logger.error('Error fetching route:', error);
    next(error);
  }
};

