import express from 'express';
import {
  updateDriverLocation,
  getDriverLocation,
  getAllVehicleLocations,
  getDriversAtBaseStation,
} from '../controllers/locationController.js';
import { authenticate } from '../middleware/auth.js';
import { requireDriver, requireAdmin } from '../middleware/authorization.js';
import { locationUpdateLimiter, realtimeLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

// Driver endpoints - for driver app to send location updates
// Apply specific location rate limiter AFTER authenticate (10 requests per 10 seconds per user)
// Authentication must happen first so we can key the rate limit by user ID
router.post('/update', authenticate, requireDriver, locationUpdateLimiter, updateDriverLocation);
router.get('/driver/my-location', authenticate, requireDriver, realtimeLimiter, getDriverLocation);

// Admin endpoints - for admin dashboard to get all vehicle locations
// These use realtime limiter for frequent polling
router.get('/admin/vehicles', authenticate, requireAdmin, realtimeLimiter, getAllVehicleLocations);
router.get('/admin/base-station/drivers', authenticate, requireAdmin, realtimeLimiter, getDriversAtBaseStation);

export default router;