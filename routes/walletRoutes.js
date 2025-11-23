import express from 'express';
import {
  getUserWallets,
  getWalletById,
  createWallet,
  addBalance,
  getMyWallet,
  addBalanceToMyWallet,
} from '../controllers/walletController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authenticate, getUserWallets);
router.get('/my-wallet', authenticate, getMyWallet); // Must be before /:walletid
router.get('/:walletid', authenticate, getWalletById);
router.post('/', authenticate, createWallet);
router.post('/add-balance', authenticate, addBalanceToMyWallet); // Must be before /:walletid/add-balance
router.post('/:walletid/add-balance', authenticate, addBalance);

export default router;

