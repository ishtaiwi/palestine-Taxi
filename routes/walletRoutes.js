import express from 'express';
import {
  getUserWallets,
  getWalletById,
  createWallet,
  addBalance,
} from '../controllers/walletController.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();

router.get('/', authenticate, getUserWallets);
router.get('/:walletid', authenticate, getWalletById);
router.post('/', authenticate, createWallet);
router.post('/:walletid/add-balance', authenticate, addBalance);

export default router;

