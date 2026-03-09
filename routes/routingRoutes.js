import express from 'express';
import { getRoute } from '../controllers/routingController.js';

const router = express.Router();

// Public endpoint - no auth required for routing
router.post('/route', getRoute);

export default router;

