import express from 'express';
import {
  getAllPayments,
  getPaymentById,
  getWalletPayments,
  createPayment,
  updatePaymentStatus,
} from '../controllers/paymentController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.get('/my-payments', authenticate, getWalletPayments);
router.post('/', authenticate, createPayment);


router.get('/', authenticate, requireAdmin, getAllPayments);
router.get('/:paymentid', authenticate, requireAdmin, getPaymentById);
router.put('/:paymentid/status', authenticate, requireAdmin, updatePaymentStatus);

export default router;

