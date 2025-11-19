import express from 'express';
import {
  register,
  login,
  getProfile,
  updateProfile,
  changePassword,
  requestPasswordReset,
  resetPassword,
} from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';
import {
  validateRegister,
  validateLogin,
  validateChangePassword,
  validatePasswordResetRequest,
  validatePasswordReset,
} from '../middleware/validation.js';
import { authLimiter, passwordResetLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

router.post('/register', authLimiter, validateRegister, register);
router.post('/login', authLimiter, validateLogin, login);
router.get('/profile', authenticate, getProfile);
router.put('/profile', authenticate, updateProfile);
router.put('/change-password', authenticate, validateChangePassword, changePassword);
router.post('/password/reset/request', passwordResetLimiter, validatePasswordResetRequest, requestPasswordReset);
router.post('/password/reset/confirm', passwordResetLimiter, validatePasswordReset, resetPassword);

export default router;

