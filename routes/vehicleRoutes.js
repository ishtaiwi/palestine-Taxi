import express from 'express';
import {
  getAllVehicles,
  getVehicleById,
  getVehiclesByDriver,
  createVehicle,
  createMyVehicle,
  updateVehicle,
  assignVehicleToLine,
  getVehicleSeatMap,
  updateBrokenSeats,
} from '../controllers/vehicleController.js';
import { authenticate } from '../middleware/auth.js';
import { requireDriver, requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.get('/', getAllVehicles);
router.get('/driver/my-vehicles', authenticate, requireDriver, getVehiclesByDriver);
router.post('/driver/my-vehicle', authenticate, requireDriver, createMyVehicle);
router.get('/:vehicleid/seatmap', authenticate, requireDriver, getVehicleSeatMap);
router.put('/:vehicleid/broken-seats', authenticate, requireDriver, updateBrokenSeats);
router.get('/:vehicleid', getVehicleById);


router.post('/', authenticate, requireAdmin, createVehicle);
router.put('/:vehicleid', authenticate, requireAdmin, updateVehicle);
router.put('/:vehicleid/assign-line', authenticate, requireAdmin, assignVehicleToLine);

export default router;

