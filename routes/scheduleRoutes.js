import express from 'express';
import {
  getAllSchedules,
  getScheduleById,
  createSchedule,
  updateSchedule,
  deleteSchedule,
  createTripsForSchedule,
  triggerDailyTripCreation,
} from '../controllers/scheduleController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();

router.use(authenticate);

router.get('/', getAllSchedules);

router.get('/:templateid', getScheduleById);

router.post('/', requireAdmin, createSchedule);

router.put('/:templateid', requireAdmin, updateSchedule);

router.delete('/:templateid', requireAdmin, deleteSchedule);

router.post('/:templateid/create-trips', requireAdmin, createTripsForSchedule);

router.post('/daily/create-trips', requireAdmin, triggerDailyTripCreation);

export default router;

