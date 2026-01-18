import express from 'express';
import { registerWalkIn, getWalkInTrips, getWalkInLines } from '../controllers/walkinController.js';
import { userDataLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

// Public routes - no authentication required
// Rate limiting applied to prevent abuse

// Get all active lines for walk-in terminal
router.get('/lines', getWalkInLines);

// Get available trips for a line (for instant booking)
router.get('/trips', getWalkInTrips);

// Register walk-in passenger and create reservation
router.post('/register', userDataLimiter, registerWalkIn);

export default router;

