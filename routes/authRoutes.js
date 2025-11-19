import express from 'express';
import {
  register,
  login,
  getProfile,
  updateProfile,
  changePassword,
  requestPasswordReset,
  verifyResetCode,
  resetPassword,
  adminResetPassword,
} from '../controllers/authController.js';
import { authenticate } from '../middleware/auth.js';
import {
  validateRegister,
  validateLogin,
  validateChangePassword,
  validatePasswordResetRequest,
  validateVerifyResetCode,
  validatePasswordReset,
} from '../middleware/validation.js';
import { authLimiter, passwordResetLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

router.post('/register', authLimiter, validateRegister, register);
router.post('/login', authLimiter, validateLogin, login);
router.post('/check-user', async (req, res, next) => {
  try {
    const { email } = req.body;
    const User = (await import('../models/User.js')).default;
    const Admin = (await import('../models/Admin.js')).default;
    const logger = (await import('../utils/logger.js')).default;
    
    logger.info('Check user request', { email });
    
    const user = await User.findByEmail(email);
    if (!user) {
      return res.json({ 
        exists: false,
        message: 'User not found'
      });
    }
    
    const normalizedRole = user.role?.toUpperCase();
    let adminRecord = null;
    if (normalizedRole === 'ADMIN') {
      adminRecord = await Admin.findByUserId(user.userid);
      logger.info('Admin record check', { 
        userid: user.userid, 
        hasAdminRecord: !!adminRecord 
      });
    }
    
    res.json({
      exists: true,
      user: {
        userid: user.userid,
        email: user.email,
        role: user.role,
        normalizedRole: normalizedRole,
        hasPassword: !!user.password,
      },
      adminRecord: adminRecord ? { id: adminRecord.id, permissions: adminRecord.permissions } : null,
    });
  } catch (error) {
    next(error);
  }
});
router.get('/profile', authenticate, getProfile);
router.put('/profile', authenticate, updateProfile);
router.put('/change-password', authenticate, validateChangePassword, changePassword);
router.post('/password/reset/request', passwordResetLimiter, validatePasswordResetRequest, requestPasswordReset);
router.post('/password/reset/verify', passwordResetLimiter, validateVerifyResetCode, verifyResetCode);
router.post('/password/reset/confirm', passwordResetLimiter, validatePasswordReset, resetPassword);
router.post('/admin/reset-password', adminResetPassword);

export default router;

