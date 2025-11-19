import express from 'express';
import {
  getAllTrips,
  getUpcomingTrips,
  getTripById,
  createTrip,
  updateTrip,
  startTrip,
  endTrip,
  getTripSeatMap,
} from '../controllers/tripController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin, requireDriver } from '../middleware/authorization.js';

const router = express.Router();


router.get('/', getAllTrips);
router.get('/upcoming', getUpcomingTrips);
router.get('/:tripid', getTripById);
router.get('/:tripid/seatmap', getTripSeatMap);


router.put('/:tripid/start', authenticate, requireDriver, startTrip);
router.put('/:tripid/end', authenticate, requireDriver, endTrip);


router.post('/', authenticate, requireAdmin, createTrip);
router.put('/:tripid', authenticate, requireAdmin, updateTrip);

export default router;

