import express from 'express';
import authRoutes from './authRoutes.js';
import lineRoutes from './lineRoutes.js';
import tripRoutes from './tripRoutes.js';
import reservationRoutes from './reservationRoutes.js';
import vehicleRoutes from './vehicleRoutes.js';
import paymentRoutes from './paymentRoutes.js';
import walletRoutes from './walletRoutes.js';
import adminRoutes from './adminRoutes.js';
import driverRoutes from './driverRoutes.js';
import routingRoutes from './routingRoutes.js';

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/lines', lineRoutes);
router.use('/trips', tripRoutes);
router.use('/reservations', reservationRoutes);
router.use('/vehicles', vehicleRoutes);
router.use('/payments', paymentRoutes);
router.use('/wallets', walletRoutes);
router.use('/admin', adminRoutes);
router.use('/drivers', driverRoutes);
router.use('/routing', routingRoutes);

export default router;

