import express from 'express';
import {
  submitRating,
  updateRating,
  getRatingByBookingId,
  getTripRatings,
  getMyRatings,
  deleteRating,
} from '../controllers/ratingController.js';
import { authenticate } from '../middleware/auth.js';
import { requirePassenger } from '../middleware/authorization.js';
import { validateRating, validateRatingUpdate } from '../middleware/validation.js';

const router = express.Router();

// Public route - Get ratings for a trip
router.get('/trip/:tripid', getTripRatings);

// Protected routes - require authentication
router.use(authenticate);

// Passenger routes
router.post('/', requirePassenger, validateRating, submitRating);
router.get('/my-ratings', requirePassenger, getMyRatings);
router.get('/booking/:bookingid', requirePassenger, getRatingByBookingId);
router.put('/:ratingid', requirePassenger, validateRatingUpdate, updateRating);
router.delete('/:ratingid', requirePassenger, deleteRating);

export default router;

