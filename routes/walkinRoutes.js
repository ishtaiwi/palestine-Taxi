import express from 'express';
import { registerWalkIn } from '../controllers/walkinController.js';
import { userDataLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

// Public route - no authentication required
// Rate limiting applied to prevent abuse
router.post('/register', userDataLimiter, registerWalkIn);

export default router;

