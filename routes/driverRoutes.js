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
} from '../controllers/driverController.js';
import {
  getDriverWallet,
  getDriverTransactions,
  getDriverEarningsSummary,
} from '../controllers/driverWalletController.js';

const router = express.Router();

router.use(authenticate, requireDriver);

router.get('/profile', getDriverProfile);
router.get('/queue', getDriverQueue);
router.post('/queue/join', joinDriverQueue);
router.post('/queue/leave', leaveDriverQueue);
router.get('/trips', getDriverTrips);
router.get('/trips/:tripid/reservations', getDriverTripReservations);
router.patch('/trips/:tripid/reservations/:bookingid', updateDriverReservationStatus);
router.get('/wallet', getDriverWallet);
router.get('/wallet/transactions', getDriverTransactions);
router.get('/wallet/summary', getDriverEarningsSummary);

export default router;

