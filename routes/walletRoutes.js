import express from 'express';
import {
  getUserWallets,
  getWalletById,
  createWallet,
  addBalance,
  getMyWallet,
  addBalanceToMyWallet,
  createStripeTopUp,
  checkTopUpStatus,
} from '../controllers/walletController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authenticate, getUserWallets);
router.get('/my-wallet', authenticate, getMyWallet); 
router.get('/:walletid', authenticate, getWalletById);
router.post('/', authenticate, createWallet);
router.post('/add-balance', authenticate, addBalanceToMyWallet); 
router.post('/stripe-topup', authenticate, createStripeTopUp);
router.get('/check-topup/:paymentIntentId', authenticate, checkTopUpStatus);
router.post('/:walletid/add-balance', authenticate, addBalance);

export default router;

