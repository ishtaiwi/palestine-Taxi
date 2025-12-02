import BaseStation from '../models/BaseStation.js';
import VehicleLocation from '../models/VehicleLocation.js';
import logger from '../utils/logger.js';

/**
 * Get all base stations
 * GET /api/admin/base-station
 */
export const getAllBaseStations = async (req, res, next) => {
    try {
        const filters = {};
        if (req.query.is_active !== undefined) {
            filters.is_active = req.query.is_active === 'true';
        }
        if (req.query.lineid) {
            filters.lineid = req.query.lineid;
        }

        const stations = await BaseStation.findAll(filters);

        res.json({
            stations,
            count: stations.length,
        });
    } catch (error) {
        logger.error('Error getting base stations:', error);
        next(error);
    }
};

/**
 * Get base station by ID
 * GET /api/admin/base-station/:stationid
 */
export const getBaseStationById = async (req, res, next) => {
    try {
        const { stationid } = req.params;

        const station = await BaseStation.findById(stationid);
        if (!station) {
            return res.status(404).json({
                message: 'Base station not found',
            });
        }

        res.json({
            station,
        });
    } catch (error) {
        logger.error('Error getting base station:', error);
        next(error);
    }
};

/**
 * Create a new base station
 * POST /api/admin/base-station
 */
export const createBaseStation = async (req, res, next) => {
    try {
        const { name, latitude, longitude, geofence_radius_meters, lineid, is_active } = req.body;

        // Validate required fields
        if (!name || latitude === undefined || longitude === undefined) {
            return res.status(400).json({
                message: 'Name, latitude, and longitude are required',
            });
        }

        // Validate coordinate ranges
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return res.status(400).json({
                message: 'Invalid coordinate values',
            });
        }

        const station = await BaseStation.create({
            name,
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
            geofence_radius_meters: geofence_radius_meters || 100,
            lineid: lineid || null,
            is_active: is_active !== undefined ? is_active : true,
        });

        logger.info('Base station created', {
            stationid: station.stationid,
            name: station.name,
        });

        res.status(201).json({
            message: 'Base station created successfully',
            station,
        });
    } catch (error) {
        logger.error('Error creating base station:', error);
        next(error);
    }
};

/**
 * Update base station
 * PUT /api/admin/base-station/:stationid
 */
export const updateBaseStation = async (req, res, next) => {
    try {
        const { stationid } = req.params;
        const updates = req.body;

        // Validate coordinate ranges if provided
        if (updates.latitude !== undefined && (updates.latitude < -90 || updates.latitude > 90)) {
            return res.status(400).json({
                message: 'Invalid latitude value',
            });
        }
        if (updates.longitude !== undefined && (updates.longitude < -180 || updates.longitude > 180)) {
            return res.status(400).json({
                message: 'Invalid longitude value',
            });
        }

        // Convert numeric strings to numbers
        if (updates.latitude !== undefined) updates.latitude = parseFloat(updates.latitude);
        if (updates.longitude !== undefined) updates.longitude = parseFloat(updates.longitude);
        if (updates.geofence_radius_meters !== undefined) {
            updates.geofence_radius_meters = parseInt(updates.geofence_radius_meters);
        }

        const station = await BaseStation.update(stationid, updates);

        logger.info('Base station updated', {
            stationid: station.stationid,
        });

        res.json({
            message: 'Base station updated successfully',
            station,
        });
    } catch (error) {
        logger.error('Error updating base station:', error);
        next(error);
    }
};

/**
 * Delete base station
 * DELETE /api/admin/base-station/:stationid
 */
export const deleteBaseStation = async (req, res, next) => {
    try {
        const { stationid } = req.params;

        await BaseStation.delete(stationid);

        logger.info('Base station deleted', {
            stationid,
        });

        res.json({
            message: 'Base station deleted successfully',
        });
    } catch (error) {
        logger.error('Error deleting base station:', error);
        next(error);
    }
};

/**
 * Check if a driver is at a specific base station
 * GET /api/admin/base-station/check-driver/:driverid
 */
export const checkDriverAtStation = async (req, res, next) => {
    try {
        const { driverid } = req.params;
        const stationid = req.query.stationid || null;

        const location = await VehicleLocation.findByDriverId(driverid);
        if (!location) {
            return res.json({
                is_at_station: false,
                message: 'Driver location not found',
            });
        }

        let isAtStation = false;
        if (stationid) {
            isAtStation = location.is_at_station && location.current_stationid === stationid;
        } else {
            isAtStation = location.is_at_station;
        }

        res.json({
            is_at_station: isAtStation,
            location: location ? {
                latitude: location.latitude,
                longitude: location.longitude,
                current_stationid: location.current_stationid,
                is_at_station: location.is_at_station,
            } : null,
        });
    } catch (error) {
        logger.error('Error checking driver at station:', error);
        next(error);
    }
};

