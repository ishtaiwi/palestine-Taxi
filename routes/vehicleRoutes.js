import express from 'express';
import {
  getAllVehicles,
  getVehicleById,
  getVehiclesByDriver,
  createVehicle,
  updateVehicle,
  assignVehicleToLine,
} from '../controllers/vehicleController.js';
import { authenticate } from '../middleware/auth.js';
import { requireDriver, requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.get('/', getAllVehicles);
router.get('/:vehicleid', getVehicleById);


router.get('/driver/my-vehicles', authenticate, requireDriver, getVehiclesByDriver);


router.post('/', authenticate, requireAdmin, createVehicle);
router.put('/:vehicleid', authenticate, requireAdmin, updateVehicle);
router.put('/:vehicleid/assign-line', authenticate, requireAdmin, assignVehicleToLine);

export default router;

