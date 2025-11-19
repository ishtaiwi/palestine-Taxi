import express from 'express';
import {
  getAllReservations,
  getReservationById,
  getPassengerReservations,
  createReservation,
  updateReservation,
  cancelReservation,
  checkInReservation,
} from '../controllers/reservationController.js';
import { authenticate } from '../middleware/auth.js';
import { requirePassenger, requireDriver, requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.get('/my-reservations', authenticate, requirePassenger, getPassengerReservations);
router.post('/', authenticate, requirePassenger, createReservation);
router.put('/:bookingid/cancel', authenticate, requirePassenger, cancelReservation);


router.post('/check-in', authenticate, requireDriver, checkInReservation);


router.get('/', authenticate, requireAdmin, getAllReservations);
router.get('/:bookingid', authenticate, requireAdmin, getReservationById);
router.put('/:bookingid', authenticate, requireAdmin, updateReservation);

export default router;

