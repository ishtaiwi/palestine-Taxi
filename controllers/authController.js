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

const generateSecureVerificationCode = () => {
  return crypto.randomInt(100000, 999999).toString();
};

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
      active: true,
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
    let createdVehicle = null;
    if (normalizedRole === 'DRIVER') {



      const {
        licenseid,
        lineid,
        vehiclePlate,
        vehicleSeatLayout
      } = req.body;


      logger.info('Driver registration - vehicle will be created automatically', {
        email: user.email,
        userid: user.userid,
        licenseid: licenseid || null,
        lineid: lineid || null,
        vehiclePlate: vehiclePlate || null,
        vehicleSeatLayout: vehicleSeatLayout || null,
        note: 'Vehicle will be created automatically even if vehiclePlate or vehicleSeatLayout are missing',
      });


      if (!licenseid || !licenseid.trim()) {
        return res.status(400).json({
          message: req.t('driver.license_required') || 'License ID is required for drivers',
        });
      }

      const trimmedLicenseId = licenseid.trim();
      const existingDriver = await Driver.findByLicenseId(trimmedLicenseId);
      if (existingDriver) {
        return res.status(409).json({
          message: req.t('driver.license_exists') || 'This license ID is already registered',
        });
      }

      if (!lineid || !lineid.trim()) {
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


      const driverData = {
        driverid: uuidv4(),
        userid: user.userid,
        licenseid: trimmedLicenseId,
        lineid: lineid.trim(),
        approval_status: 'pending', // Drivers require admin approval
      };

      logger.info('Creating driver record', {
        driverid: driverData.driverid,
        userid: driverData.userid,
        licenseid: driverData.licenseid,
        lineid: driverData.lineid,
      });

      try {
        roleRecord = await Driver.create(driverData);
      } catch (error) {
        if (error.code === '23505' || (error.message && error.message.includes('unique'))) {
          return res.status(409).json({
            message: req.t('driver.license_exists') || 'This license ID is already registered',
          });
        }
        throw error;
      }

      logger.info('Driver record created successfully', {
        driverid: roleRecord.driverid,
        userid: roleRecord.userid,
      });


      logger.info('Preparing to create vehicle automatically for driver', {
        driverid: roleRecord.driverid,
        vehiclePlate: vehiclePlate || 'not provided (will be created without plate)',
        vehicleSeatLayout: vehicleSeatLayout || 'not provided (default: 4+1)',
        lineid: lineid,
      });


      const seatLayout = (vehicleSeatLayout || '').trim();
      let normalizedLayout = '4+1';
      let seatNum = 5;

      if (seatLayout === '4+1' || seatLayout === '7+1') {
        normalizedLayout = seatLayout;
        seatNum = seatLayout === '7+1' ? 8 : 5;
      } else if (seatLayout) {

        logger.warn('Unexpected seat layout format, defaulting to 4+1', {
          provided: seatLayout,
        });
      } else {

        logger.info('No seat layout provided - using default 4+1', {
          driverid: roleRecord.driverid,
        });
      }

      logger.info('Seat layout normalized', {
        original: seatLayout || 'not provided',
        normalized: normalizedLayout,
        seatNum: seatNum,
        seatNumType: typeof seatNum,
      });


      if (!vehiclePlate || !vehiclePlate.trim()) {
        return res.status(400).json({
          message: req.t('vehicle.plate_required') || 'Vehicle plate number is required',
        });
      }

      const trimmedPlate = vehiclePlate.trim();
      const plateRegex = /^\d-\d{4}-[A-Za-z]$/;
      if (!plateRegex.test(trimmedPlate)) {
        return res.status(400).json({
          message: req.t('vehicle.plate_invalid') || 'Plate number must be in format: number-4digits-letter (e.g., 3-1234-A)',
        });
      }


      const Vehicle = (await import('../models/Vehicle.js')).default;
      const existingVehicle = await Vehicle.findByPlateNumber(trimmedPlate);
      if (existingVehicle) {
        return res.status(409).json({
          message: req.t('vehicle.plate_exists') || 'This plate number is already registered',
        });
      }

      const plateNo = trimmedPlate;
      logger.info('Plate number validated', { plateNo });


      const baseVehicleData = {
        vehicleid: uuidv4(),
        driverid: roleRecord.driverid,
        lineid: lineid.trim(),
        seatnum: parseInt(seatNum, 10),
        seatlayout: String(normalizedLayout),
        plateno: plateNo,
        status: 'active',
      };

      logger.info('Vehicle data prepared', {
        vehicleid: baseVehicleData.vehicleid,
        driverid: baseVehicleData.driverid,
        lineid: baseVehicleData.lineid,
        seatnum: baseVehicleData.seatnum,
        seatlayout: baseVehicleData.seatlayout,
        plateno: baseVehicleData.plateno,
      });



      let createdVehicle = null;
      try {

        const vehicleData = {
          ...baseVehicleData,
          broken_seats: [],
        };

        logger.info('Attempting to create vehicle automatically (with broken_seats)', {
          vehicleid: vehicleData.vehicleid,
          driverid: vehicleData.driverid,
          lineid: vehicleData.lineid,
          seatlayout: vehicleData.seatlayout,
          seatnum: vehicleData.seatnum,
          plateno: vehicleData.plateno || 'null (can be added later)',
        });

        createdVehicle = await Vehicle.create(vehicleData);

        logger.info('✅ Vehicle created automatically with all data', {
          vehicleid: createdVehicle.vehicleid,
          driverid: createdVehicle.driverid,
          lineid: createdVehicle.lineid,
          plateno: createdVehicle.plateno || 'null (can be added later)',
          seatlayout: createdVehicle.seatlayout,
          seatnum: createdVehicle.seatnum,
          status: createdVehicle.status,
        });
      } catch (vehicleError) {

        if (vehicleError.code === '42703' || (vehicleError.message && vehicleError.message.includes('broken_seats'))) {
          logger.info('Retrying vehicle creation without broken_seats column', {
            error: vehicleError.message,
          });

          try {
            createdVehicle = await Vehicle.create(baseVehicleData);

            logger.info('✅ Vehicle created automatically (without broken_seats)', {
              vehicleid: createdVehicle.vehicleid,
              driverid: createdVehicle.driverid,
              lineid: createdVehicle.lineid,
              plateno: createdVehicle.plateno || 'null (can be added later)',
              seatlayout: createdVehicle.seatlayout,
              seatnum: createdVehicle.seatnum,
              status: createdVehicle.status,
            });
          } catch (retryError) {
            logger.error('❌ Failed to create vehicle automatically (retry without broken_seats)', {
              error: retryError.message,
              code: retryError.code,
              details: retryError.details,
              hint: retryError.hint,
              driverid: roleRecord.driverid,
              vehicleData: baseVehicleData,
            });


            const userFriendlyError = new Error(
              retryError.message || 'Failed to create vehicle automatically. Please contact support.'
            );
            userFriendlyError.code = retryError.code;
            userFriendlyError.details = retryError.details;
            userFriendlyError.hint = retryError.hint;
            throw userFriendlyError;
          }
        } else {
          logger.error('❌ Failed to create vehicle automatically during driver registration', {
            error: vehicleError.message,
            code: vehicleError.code,
            details: vehicleError.details,
            hint: vehicleError.hint,
            driverid: roleRecord.driverid,
            vehicleData: baseVehicleData,
            fullError: vehicleError,
          });


          const userFriendlyError = new Error(
            vehicleError.message || 'Failed to create vehicle automatically. Please contact support.'
          );
          userFriendlyError.code = vehicleError.code;
          userFriendlyError.details = vehicleError.details;
          userFriendlyError.hint = vehicleError.hint;
          throw userFriendlyError;
        }
      }

      if (!createdVehicle) {
        logger.error('❌ Vehicle creation failed but no error was thrown', {
          driverid: roleRecord.driverid,
        });
        throw new Error('Failed to create vehicle automatically for driver');
      }

      logger.info('✅ Vehicle created automatically for driver', {
        vehicleid: createdVehicle.vehicleid,
        driverid: roleRecord.driverid,
        note: 'Vehicle can be updated later with plate number and other details',
      });


      logger.info('✅ Driver registration complete - verifying data integrity', {
        userid: user.userid,
        driverid: roleRecord.driverid,
        vehicleid: createdVehicle.vehicleid,
        links: {
          'User → Driver': roleRecord.userid === user.userid,
          'Driver → Vehicle': createdVehicle.driverid === roleRecord.driverid,
          'Vehicle → Line': createdVehicle.lineid === lineid,
        },
      });
    } else if (normalizedRole === 'PASSENGER') {

      logger.info('Creating passenger record', {
        userid: user.userid,
      });

      roleRecord = await Passenger.create({
        passengerid: uuidv4(),
        userid: user.userid,

      });

      logger.info('✅ Passenger record created successfully', {
        passengerid: roleRecord.passengerid,
        userid: roleRecord.userid,
      });
    } else if (normalizedRole === 'ADMIN') {
      logger.info('Creating admin record', {
        userid: user.userid,
        permissions: req.body.permissions || [],
      });

      roleRecord = await Admin.create({
        id: uuidv4(),
        userid: user.userid,
        permissions: req.body.permissions || [],
      });

      logger.info('✅ Admin record created successfully', {
        adminid: roleRecord.id,
        userid: roleRecord.userid,
        permissions: roleRecord.permissions,
      });
    } else {

      logger.error('❌ Unknown role during registration', {
        userid: user.userid,
        providedRole: role,
        normalizedRole: normalizedRole,
      });


      try {
        await User.delete(user.userid);
        logger.info('User deleted due to unknown role', { userid: user.userid });
      } catch (deleteError) {
        logger.error('Failed to delete user after unknown role error', {
          userid: user.userid,
          error: deleteError.message,
        });
      }

      return res.status(400).json({
        message: req.t('auth.invalid_role') || `Invalid role: ${role}. Must be DRIVER, PASSENGER, or ADMIN`,
      });
    }


    if (!roleRecord) {
      logger.error('❌ Role record was not created', {
        userid: user.userid,
        role: normalizedRole,
      });


      try {
        await User.delete(user.userid);
        logger.info('User deleted due to missing role record', { userid: user.userid });
      } catch (deleteError) {
        logger.error('Failed to delete user after role record error', {
          userid: user.userid,
          error: deleteError.message,
        });
      }

      return res.status(500).json({
        message: req.t('auth.role_creation_failed') || 'Failed to create role record. Please try again.',
      });
    }

    logger.info('✅ Role record verified', {
      userid: user.userid,
      role: normalizedRole,
      roleRecordId: roleRecord.driverid || roleRecord.passengerid || roleRecord.id,
    });



    try {
      logger.info('Creating wallet for user', { userid: user.userid });

      await Wallet.create({
        walletid: uuidv4(),
        userid: user.userid,
        type: 'main',
        balance: 0,
      });

      logger.info('✅ Wallet created successfully for user', { userid: user.userid });
    } catch (walletError) {
      logger.error('❌ Failed to create wallet for user', {
        userid: user.userid,
        error: walletError.message,
        code: walletError.code,
      });



      logger.warn('Registration will continue despite wallet creation failure', {
        userid: user.userid,
      });
    }


    const token = generateToken({
      userid: user.userid,
      role: user.role,
    });


    let registrationMessage = req.t('auth.register_success') || 'Registration successful';
    if (normalizedRole === 'DRIVER' && roleRecord?.approval_status === 'pending') {
      registrationMessage = req.t('auth.driver_pending_approval') || 'Registration successful. Your account is pending admin approval.';
    }

    const responseData = {
      success: true,
      message: registrationMessage,
      token,
      user: {
        ...sanitizedUser,
        [roleKey || 'roleData']: roleRecord,
      },
    };

    if (normalizedRole === 'DRIVER') {
      responseData.approvalStatus = roleRecord?.approval_status || 'pending';
    }


    if (normalizedRole === 'DRIVER' && createdVehicle) {
      responseData.vehicle = {
        vehicleid: createdVehicle.vehicleid,
        plateno: createdVehicle.plateno,
        seatlayout: createdVehicle.seatlayout,
        seatnum: createdVehicle.seatnum,
        status: createdVehicle.status,
      };

      logger.info('Response includes vehicle data', {
        vehicleid: createdVehicle.vehicleid,
        driverid: roleRecord.driverid,
      });
    }


    logger.info('✅ Registration complete - final verification', {
      userid: user.userid,
      role: user.role,
      hasUser: !!user,
      hasRoleRecord: !!roleRecord,
      hasVehicle: normalizedRole === 'DRIVER' && !!createdVehicle,
      roleRecordType: normalizedRole,
      roleRecordId: roleRecord?.driverid || roleRecord?.passengerid || roleRecord?.id,
      approvalStatus: normalizedRole === 'DRIVER' ? roleRecord?.approval_status : null,
    });


    const verificationChecks = {
      userCreated: !!user && !!user.userid,
      roleRecordCreated: !!roleRecord,
      roleRecordLinked: roleRecord?.userid === user.userid,
      walletWillBeCreated: true,
    };

    if (normalizedRole === 'DRIVER') {
      verificationChecks.vehicleCreated = !!createdVehicle;
      verificationChecks.vehicleLinked = createdVehicle?.driverid === roleRecord?.driverid;
    }

    logger.info('Registration verification checks', verificationChecks);


    const criticalFailures = Object.entries(verificationChecks)
      .filter(([key, value]) => !value && !key.includes('WillBe'))
      .map(([key]) => key);

    if (criticalFailures.length > 0) {
      logger.error('❌ Registration verification failed', {
        userid: user.userid,
        failures: criticalFailures,
        verificationChecks,
      });
    }

    res.status(201).json(responseData);
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

    // Check if user is active
    if (user.active === false) {
      logger.warn('Login attempt with inactive user', { email, userid: user.userid });
      return res.status(403).json({
        success: false,
        message: req.t('auth.account_inactive') || 'Your account has been deactivated. Please contact support.'
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
        
        if (roleData && roleData.approval_status !== 'approved') {
          const status = roleData.approval_status || 'pending';
          logger.warn('Driver login attempt with non-approved status', {
            email,
            userid: user.userid,
            approval_status: status,
          });
          
          return res.status(403).json({
            success: false,
            message: status === 'rejected' 
              ? (req.t('auth.driver_rejected') || 'Your driver account has been rejected. Please contact support.')
              : (req.t('auth.driver_pending_approval') || 'Your driver account is pending admin approval. Please wait for approval before logging in.'),
            approvalStatus: status,
          });
        }
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


export const updateLanguagePreference = async (req, res, next) => {
  try {
    const { language } = req.body;
    
    // Validate language value
    if (!language || (language !== 'ar' && language !== 'en')) {
      return res.status(400).json({
        success: false,
        message: 'Invalid language. Must be "ar" or "en"',
      });
    }

    // Update user's language preference
    const user = await User.update(req.user.userid, { language_preference: language });
    
    // Remove password from response
    if (user && user.password) {
      delete user.password;
    }

    logger.info('Language preference updated', {
      userid: req.user.userid,
      language,
    });

    res.json({
      success: true,
      message: 'Language preference updated successfully',
      user,
      language_preference: language,
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


    const verificationCode = generateSecureVerificationCode();
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

