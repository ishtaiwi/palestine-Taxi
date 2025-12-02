import express from 'express';
import {
  getAllLines,
  getActiveLines,
  getLineById,
  createLine,
  updateLine,
  deleteLine,
} from '../controllers/lineController.js';
import { getLinePath } from '../controllers/linePathController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';
import { validateLine } from '../middleware/validation.js';

const router = express.Router();


router.get('/', getAllLines);
router.get('/active', getActiveLines);
router.get('/:lineid', getLineById);
router.get('/:lineid/path', getLinePath); // Public endpoint for drivers to get their line path


router.post('/', authenticate, requireAdmin, validateLine, createLine);
router.put('/:lineid', authenticate, requireAdmin, validateLine, updateLine);
router.delete('/:lineid', authenticate, requireAdmin, deleteLine);

export default router;

