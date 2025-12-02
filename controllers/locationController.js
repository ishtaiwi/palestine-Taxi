import VehicleLocation from '../models/VehicleLocation.js';
import Vehicle from '../models/Vehicle.js';
import Driver from '../models/Driver.js';
import logger from '../utils/logger.js';

/**
 * Update driver's current location
 * POST /api/locations/update
 */
export const updateDriverLocation = async (req, res, next) => {
    try {
        const driverid = req.user.driverid;
        const { latitude, longitude, heading, speed, accuracy } = req.body;

        // Validate required fields
        if (latitude === undefined || longitude === undefined) {
            return res.status(400).json({
                message: 'Latitude and longitude are required',
            });
        }

        // Validate coordinate ranges
        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return res.status(400).json({
                message: 'Invalid coordinate values',
            });
        }

        // Get driver's vehicle
        const driver = await Driver.findById(driverid);
        if (!driver) {
            return res.status(404).json({
                message: 'Driver not found',
            });
        }

        const vehicles = await Vehicle.findByDriverId(driverid);
        if (!vehicles || vehicles.length === 0) {
            return res.status(400).json({
                message: 'Driver does not have an assigned vehicle',
            });
        }

        const vehicle = vehicles[0]; // Use first vehicle

        // Update location
        const location = await VehicleLocation.upsert(vehicle.vehicleid, driverid, {
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
            heading: heading ? parseFloat(heading) : null,
            speed: speed ? parseFloat(speed) : null,
            accuracy: accuracy ? parseFloat(accuracy) : null,
        });

        logger.info('Driver location updated', {
            driverid,
            vehicleid: vehicle.vehicleid,
            latitude,
            longitude,
            isAtStation: location.is_at_station,
            currentStationid: location.current_stationid,
        });

        res.json({
            message: 'Location updated successfully',
            location: {
                locationid: location.locationid,
                latitude: location.latitude,
                longitude: location.longitude,
                heading: location.heading,
                speed: location.speed,
                accuracy: location.accuracy,
                is_at_station: location.is_at_station,
                current_stationid: location.current_stationid,
                updated_at: location.updated_at,
            },
        });
    } catch (error) {
        logger.error('Error updating driver location:', error);
        next(error);
    }
};

/**
 * Get driver's current location
 * GET /api/locations/driver/my-location
 */
export const getDriverLocation = async (req, res, next) => {
    try {
        const driverid = req.user.driverid;

        const location = await VehicleLocation.findByDriverId(driverid);
        if (!location) {
            return res.status(404).json({
                message: 'Location not found. Please update your location first.',
            });
        }

        res.json({
            location,
        });
    } catch (error) {
        logger.error('Error getting driver location:', error);
        next(error);
    }
};

/**
 * Get all active vehicle locations (for admin map)
 * GET /api/locations/admin/vehicles
 */
export const getAllVehicleLocations = async (req, res, next) => {
    try {
        const maxAgeMinutes = parseInt(req.query.maxAgeMinutes) || 2;
        const lineid = req.query.lineid || null;

        let locations = await VehicleLocation.findAllActive(maxAgeMinutes);

        // Filter by line if specified
        if (lineid) {
            locations = locations.filter(
                loc => loc.vehicle?.lineid === lineid
            );
        }

        res.json({
            locations,
            count: locations.length,
            maxAgeMinutes,
        });
    } catch (error) {
        logger.error('Error getting all vehicle locations:', error);
        next(error);
    }
};

/**
 * Get drivers currently at base station
 * GET /api/locations/admin/base-station/drivers
 */
export const getDriversAtBaseStation = async (req, res, next) => {
    try {
        const stationid = req.query.stationid || null;

        const drivers = await VehicleLocation.findDriversAtBaseStation(stationid);

        res.json({
            drivers,
            count: drivers.length,
        });
    } catch (error) {
        logger.error('Error getting drivers at base station:', error);
        next(error);
    }
};
