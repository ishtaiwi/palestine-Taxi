import express from 'express';
import {
  getAllLines,
  getActiveLines,
  getLineById,
  createLine,
  updateLine,
  deleteLine,
} from '../controllers/lineController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.get('/', getAllLines);
router.get('/active', getActiveLines);
router.get('/:lineid', getLineById);


router.post('/', authenticate, requireAdmin, createLine);
router.put('/:lineid', authenticate, requireAdmin, updateLine);
router.delete('/:lineid', authenticate, requireAdmin, deleteLine);

export default router;

