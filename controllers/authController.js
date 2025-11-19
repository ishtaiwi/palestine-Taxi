import crypto from 'crypto';
import User from '../models/User.js';
import Driver from '../models/Driver.js';
import Passenger from '../models/Passenger.js';
import Admin from '../models/Admin.js';
import Wallet from '../models/Wallet.js';
import PasswordResetToken from '../models/PasswordResetToken.js';
import { generateToken, hashPassword, comparePassword } from '../utils/auth.js';
import { v4 as uuidv4 } from 'uuid';
import appConfig from '../config/app.js';
import logger from '../utils/logger.js';
import { sendPasswordResetEmail } from '../utils/email.js';

const RESET_TOKEN_EXPIRATION_MINUTES = 60;
const isProduction = appConfig.nodeEnv === 'production';

const sanitizeUser = (user) => {
  if (!user) return user;
  const sanitized = { ...user };
  if (sanitized.password) {
    delete sanitized.password;
  }
  return sanitized;
};


export const register = async (req, res, next) => {
  try {
    const { fullname, email, phone, password, role } = req.body;
    const normalizedRole = role?.toUpperCase();
    const roleKey = role?.toLowerCase() || normalizedRole?.toLowerCase();

    
    logger.info('Registration attempt', {
      email,
      role: normalizedRole,
      fullnameLength: fullname?.length || 0,
    });

    
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      return res.status(400).json({ 
        message: req.t('auth.email_exists') || 'Email already exists' 
      });
    }

    
    const hashedPassword = await hashPassword(password);

    
    const userData = {
      userid: uuidv4(),
      fullname: fullname.trim(), 
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: normalizedRole,
      password: hashedPassword, 
    };

    logger.info('Creating user', {
      userid: userData.userid,
      email: userData.email,
      role: userData.role,
      fullname: userData.fullname.substring(0, 20) + '...', 
    });

    const user = await User.create(userData);
    const sanitizedUser = sanitizeUser(user);

    logger.info('User created successfully', {
      userid: user.userid,
      email: user.email,
      role: user.role,
    });

    
    let roleRecord;
    if (normalizedRole === 'DRIVER') {
      const { licenseid } = req.body;
      roleRecord = await Driver.create({
        driverid: uuidv4(),
        userid: user.userid,
        licenseid,
      });
    } else if (normalizedRole === 'PASSENGER') {
      const passengerType = (req.body.type || 'app_based').toLowerCase();
      roleRecord = await Passenger.create({
        passengerid: uuidv4(),
        userid: user.userid,
        type: passengerType,
      });
    } else if (normalizedRole === 'ADMIN') {
      roleRecord = await Admin.create({
        id: uuidv4(),
        userid: user.userid,
        permissions: req.body.permissions || [],
      });
    }

    
    await Wallet.create({
      walletid: uuidv4(),
      userid: user.userid,
      type: 'main',
      balance: 0,
    });

    
    const token = generateToken({
      userid: user.userid,
      role: user.role,
    });

    res.status(201).json({
      message: req.t('auth.register_success') || 'Registration successful',
      token,
      user: {
        ...sanitizedUser,
        [roleKey || 'roleData']: roleRecord,
      },
    });
  } catch (error) {
    next(error);
  }
};


export const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    
    const user = await User.findByEmail(email);
    if (!user) {
      return res.status(401).json({ 
        message: req.t('auth.invalid_credentials') || 'Invalid credentials' 
      });
    }

    
    if (!user.password) {
      return res.status(401).json({ 
        message: req.t('auth.no_password_set') || 'Password not set. Please reset your password.' 
      });
    }

    const isValid = await comparePassword(password, user.password);
    if (!isValid) {
      return res.status(401).json({ 
        message: req.t('auth.invalid_credentials') || 'Invalid credentials' 
      });
    }

    
    let roleData = null;
    if (user.role === 'DRIVER') {
      roleData = await Driver.findByUserId(user.userid);
    } else if (user.role === 'PASSENGER') {
      roleData = await Passenger.findByUserId(user.userid);
    } else if (user.role === 'ADMIN') {
      roleData = await Admin.findByUserId(user.userid);
    }

    
    const token = generateToken({
      userid: user.userid,
      role: user.role,
    });

    const sanitizedUser = sanitizeUser(user);

    res.json({
      message: req.t('auth.login_success') || 'Login successful',
      token,
      user: {
        ...sanitizedUser,
        [user.role]: roleData,
      },
    });
  } catch (error) {
    next(error);
  }
};


export const getProfile = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userid);
    
    
    if (user.password) {
      delete user.password;
    }
    
    let roleData = null;
    if (user.role === 'DRIVER') {
      roleData = await Driver.findByUserId(user.userid);
    } else if (user.role === 'PASSENGER') {
      roleData = await Passenger.findByUserId(user.userid);
    } else if (user.role === 'ADMIN') {
      roleData = await Admin.findByUserId(user.userid);
    }

    res.json({
      ...user,
      [user.role]: roleData,
    });
  } catch (error) {
    next(error);
  }
};


export const updateProfile = async (req, res, next) => {
  try {
    const updates = { ...req.body };
    
    
    if (updates.password) {
      updates.password = await hashPassword(updates.password);
    }
    
    
    delete updates.email;
    delete updates.role;
    
    const user = await User.update(req.user.userid, updates);
    
    
    delete user.password;

    res.json({
      message: req.t('auth.profile_updated') || 'Profile updated successfully',
      user,
    });
  } catch (error) {
    next(error);
  }
};


export const changePassword = async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ 
        message: req.t('auth.password_required') || 'Current password and new password are required' 
      });
    }
    
    
    const user = await User.findById(req.user.userid, true);
    
    if (!user.password) {
      return res.status(400).json({ 
        message: req.t('auth.no_password_set') || 'Password not set' 
      });
    }
    
    
    const isValid = await comparePassword(currentPassword, user.password);
    if (!isValid) {
      return res.status(401).json({ 
        message: req.t('auth.invalid_current_password') || 'Current password is incorrect' 
      });
    }
    
    
    const hashedPassword = await hashPassword(newPassword);
    
    
    await User.update(req.user.userid, { password: hashedPassword });
    
    res.json({
      message: req.t('auth.password_changed') || 'Password changed successfully',
    });
  } catch (error) {
    next(error);
  }
};


export const requestPasswordReset = async (req, res, next) => {
  try {
    const { email } = req.body;
    const user = await User.findByEmail(email);

    
    const successMessage = req.t('auth.reset_email_sent') || 'If an account exists, a password reset email has been sent.';

    if (!user) {
      return res.json({ message: successMessage });
    }

    
    await PasswordResetToken.invalidateAllForUser(user.userid);

    
    const resetToken = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRATION_MINUTES * 60 * 1000).toISOString();

    await PasswordResetToken.create({
      userid: user.userid,
      token: resetToken,
      expiresAt,
    });

    if (!isProduction) {
      logger.info('Password reset token generated', {
        email: user.email,
        token: resetToken,
      });
    }

    const emailResult = await sendPasswordResetEmail({
      to: user.email,
      token: resetToken,
    });

    const response = {
      message: successMessage,
      emailSent: emailResult.sent,
    };

    if (!isProduction) {
      response.debugToken = resetToken;
      response.resetUrl = emailResult.resetUrl;
      response.emailInfo = emailResult.reason || 'sent';
    }

    if (!emailResult.sent) {
      logger.warn('Password reset email not sent', { email: user.email, reason: emailResult.reason });
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};


export const resetPassword = async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;

    const tokenRecord = await PasswordResetToken.findValid(token);
    if (!tokenRecord) {
      return res.status(400).json({
        message: req.t('auth.invalid_reset_token') || 'Invalid or expired reset token',
      });
    }

    const hashedPassword = await hashPassword(newPassword);
    await User.update(tokenRecord.userid, { password: hashedPassword });
    await PasswordResetToken.markUsed(tokenRecord.id);

    res.json({
      message: req.t('auth.password_reset_success') || 'Password has been reset successfully',
    });
  } catch (error) {
    next(error);
  }
};

