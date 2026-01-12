import express from 'express';
import { authenticate } from '../middleware/auth.js';
import { requireDriver } from '../middleware/authorization.js';
import {
  getDriverProfile,
  getDriverQueue,
  joinDriverQueue,
  leaveDriverQueue,
  getDriverTrips,
  getDriverTripReservations,
  updateDriverReservationStatus,
  getDriverStatistics,
} from '../controllers/driverController.js';

const router = express.Router();

router.use(authenticate, requireDriver);

router.get('/profile', getDriverProfile);
router.get('/queue', getDriverQueue);
router.post('/queue/join', joinDriverQueue);
router.post('/queue/leave', leaveDriverQueue);
router.get('/trips', getDriverTrips);
router.get('/trips/:tripid/reservations', getDriverTripReservations);
router.patch('/trips/:tripid/reservations/:bookingid', updateDriverReservationStatus);
router.get('/statistics', getDriverStatistics);

export default router;

