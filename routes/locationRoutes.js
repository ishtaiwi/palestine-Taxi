import express from 'express';
import { updateDriverLocation, getDriverLocation } from '../controllers/locationController.js';
import { authenticate } from '../middleware/auth.js';
import { requireDriver, requireAdmin } from '../middleware/authorization.js';

const router = express.Router();

// Driver endpoints - for driver app to send location updates
router.post('/update', authenticate, requireDriver, updateDriverLocation);
router.get('/driver/my-location', authenticate, requireDriver, getDriverLocation);

// Admin endpoints - for admin dashboard to get all vehicle locations
router.get('/admin/vehicles', authenticate, requireAdmin, getAllVehicleLocations);

export default router;