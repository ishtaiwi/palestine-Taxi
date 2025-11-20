import crypto from 'crypto';
import User from '../models/User.js';
import Driver from '../models/Driver.js';
import Passenger from '../models/Passenger.js';
import Admin from '../models/Admin.js';
import Wallet from '../models/Wallet.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
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
      const { licenseid, lineid, vehiclePlate, vehicleSeatLayout } = req.body;
      if (!lineid) {
        return res.status(400).json({
          message: req.t('driver.line_required') || 'Line is required for drivers',
        });
      }

      const line = await Line.findById(lineid);
      if (!line) {
        return res.status(404).json({
          message: req.t('line.not_found') || 'Line not found',
        });
      }

      roleRecord = await Driver.create({
        driverid: uuidv4(),
        userid: user.userid,
        licenseid,
        lineid,
      });

      const seatLayout = (vehicleSeatLayout || '').trim();
      const normalizedLayout = seatLayout.length > 0 ? seatLayout : '4+1';
      const seatNum = normalizedLayout === '7+1' ? 8 : 5;

      await Vehicle.create({
        vehicleid: uuidv4(),
        driverid: roleRecord.driverid,
        lineid,
        seatnum: seatNum,
        seatlayout: normalizedLayout,
        plateno: vehiclePlate?.trim(),
        status: 'active',
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
      logger.warn('Login attempt with non-existent email', { email });
      return res.status(401).json({ 
        success: false,
        message: req.t('auth.invalid_credentials') || 'Invalid credentials' 
      });
    }

    logger.info('Login attempt', { 
      email, 
      userid: user.userid, 
      role: user.role,
      hasPassword: !!user.password,
      passwordLength: user.password ? user.password.length : 0
    });

    
    if (!user.password) {
      logger.warn('Login attempt with no password set', { email, userid: user.userid });
      return res.status(401).json({ 
        success: false,
        message: req.t('auth.no_password_set') || 'Password not set. Please reset your password.' 
      });
    }

    let isValid = await comparePassword(password, user.password);
    
    if (!isValid && user.password && !user.password.startsWith('$2')) {
      logger.warn('Password appears to be plain text, attempting direct comparison', {
        email,
        userid: user.userid,
        storedPasswordLength: user.password.length,
        inputPasswordLength: password.length
      });
      
      if (user.password === password) {
        logger.info('Plain text password matched, rehashing password');
        const newHashedPassword = await hashPassword(password);
        await User.update(user.userid, { password: newHashedPassword });
        isValid = true;
      }
    }
    
    logger.info('Password comparison result', { 
      email, 
      userid: user.userid, 
      isValid,
      role: user.role,
      passwordStartsWithHash: user.password?.startsWith('$2') || false
    });
    
    if (!isValid) {
      logger.warn('Login attempt with invalid password', { email, userid: user.userid, role: user.role });
      return res.status(401).json({ 
        success: false,
        message: req.t('auth.invalid_credentials') || 'Invalid credentials' 
      });
    }

    
    const normalizedRole = user.role?.toUpperCase();
    let roleData = null;
    try {
      if (normalizedRole === 'DRIVER') {
        roleData = await Driver.findByUserId(user.userid);
      } else if (normalizedRole === 'PASSENGER') {
        roleData = await Passenger.findByUserId(user.userid);
      } else if (normalizedRole === 'ADMIN') {
        roleData = await Admin.findByUserId(user.userid);
        if (!roleData) {
          logger.warn(`Admin role data not found for user ${user.userid}, creating admin record`);
          try {
            roleData = await Admin.create({
              id: uuidv4(),
              userid: user.userid,
              permissions: [],
            });
            logger.info(`Admin record created for user ${user.userid}`);
          } catch (createError) {
            logger.error('Error creating admin record', { error: createError.message, userid: user.userid });
          }
        }
      }
    } catch (roleError) {
      logger.error('Error fetching role data', { 
        error: roleError.message, 
        userid: user.userid, 
        role: user.role,
        normalizedRole 
      });
      if (normalizedRole === 'ADMIN') {
        try {
          roleData = await Admin.create({
            id: uuidv4(),
            userid: user.userid,
            permissions: [],
          });
          logger.info(`Admin record created after error for user ${user.userid}`);
        } catch (createError) {
          logger.error('Error creating admin record after error', { 
            error: createError.message, 
            userid: user.userid 
          });
        }
      }
    }

    
    const token = generateToken({
      userid: user.userid,
      role: normalizedRole || user.role,
    });

    const sanitizedUser = sanitizeUser(user);

    logger.info('Login successful', { 
      email, 
      userid: user.userid, 
      role: normalizedRole || user.role,
      hasRoleData: !!roleData 
    });

    const responseUser = {
      ...sanitizedUser,
      role: normalizedRole || user.role,
    };
    
    if (roleData) {
      const roleKey = (normalizedRole || user.role)?.toLowerCase() || 'roleData';
      responseUser[roleKey] = roleData;
    }

    res.json({
      success: true,
      message: req.t('auth.login_success') || 'Login successful',
      token,
      user: responseUser,
    });
  } catch (error) {
    logger.error('Login error', { error: error.message, stack: error.stack });
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

    
    const successMessage = req.t('auth.reset_email_sent') || 'If an account exists, a verification code has been sent to your email.';

    if (!user) {
      return res.json({ message: successMessage });
    }

    
    await PasswordResetToken.invalidateAllForUser(user.userid);

    
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + RESET_TOKEN_EXPIRATION_MINUTES * 60 * 1000).toISOString();

    await PasswordResetToken.create({
      userid: user.userid,
      token: verificationCode,
      expiresAt,
    });

    if (!isProduction) {
      logger.info('Password reset verification code generated', {
        email: user.email,
        code: verificationCode,
      });
    }

    const emailResult = await sendPasswordResetEmail({
      to: user.email,
      code: verificationCode,
    });

    const response = {
      message: successMessage,
      emailSent: emailResult.sent,
    };

    if (!isProduction) {
      response.debugCode = verificationCode;
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


export const verifyResetCode = async (req, res, next) => {
  try {
    const { email, code } = req.body;

    const user = await User.findByEmail(email);
    if (!user) {
      return res.status(400).json({
        message: req.t('auth.invalid_reset_code') || 'Invalid verification code',
      });
    }

    const tokenRecord = await PasswordResetToken.findValidByCode(code);
    if (!tokenRecord || tokenRecord.userid !== user.userid) {
      return res.status(400).json({
        message: req.t('auth.invalid_reset_code') || 'Invalid or expired verification code',
      });
    }

    res.json({
      message: req.t('auth.code_verified') || 'Verification code is valid',
      verified: true,
    });
  } catch (error) {
    next(error);
  }
};

export const resetPassword = async (req, res, next) => {
  try {
    const { email, code, newPassword } = req.body;

    const user = await User.findByEmail(email);
    if (!user) {
      return res.status(400).json({
        message: req.t('auth.invalid_reset_code') || 'Invalid verification code',
      });
    }

    const tokenRecord = await PasswordResetToken.findValidByCode(code);
    if (!tokenRecord || tokenRecord.userid !== user.userid) {
      return res.status(400).json({
        message: req.t('auth.invalid_reset_code') || 'Invalid or expired verification code',
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

export const adminResetPassword = async (req, res, next) => {
  try {
    const { email, newPassword } = req.body;
    
    if (!email || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email and new password are required'
      });
    }
    
    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }
    
    const user = await User.findByEmail(email);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }
    
    const normalizedRole = user.role?.toUpperCase();
    if (normalizedRole !== 'ADMIN') {
      return res.status(403).json({
        success: false,
        message: 'This endpoint is only for admin users'
      });
    }
    
    const hashedPassword = await hashPassword(newPassword);
    await User.update(user.userid, { password: hashedPassword });
    
    logger.info('Admin password reset directly', {
      email,
      userid: user.userid
    });
    
    res.json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (error) {
    logger.error('Admin password reset error', { error: error.message });
    next(error);
  }
};

