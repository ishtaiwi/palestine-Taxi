import express from 'express';
import {
  getAllReservations,
  getReservationById,
  getPassengerReservations,
  createReservation,
  updateReservation,
  cancelReservation,
  checkInReservation,
  getReservationQRCode,
} from '../controllers/reservationController.js';
import { authenticate } from '../middleware/auth.js';
import { requirePassenger, requireDriver, requireAdmin } from '../middleware/authorization.js';
import { userDataLimiter } from '../middleware/rateLimit.js';

const router = express.Router();


router.get('/my-reservations', userDataLimiter, authenticate, requirePassenger, getPassengerReservations);
router.get('/:bookingid/qrcode', authenticate, requirePassenger, getReservationQRCode);
router.post('/', authenticate, requirePassenger, createReservation);
router.put('/:bookingid/cancel', authenticate, requirePassenger, cancelReservation);


router.post('/check-in', authenticate, requireDriver, checkInReservation);


router.get('/', authenticate, requireAdmin, getAllReservations);
router.get('/:bookingid', authenticate, requireAdmin, getReservationById);
router.put('/:bookingid', authenticate, requireAdmin, updateReservation);

export default router;

