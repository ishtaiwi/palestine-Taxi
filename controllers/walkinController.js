import User from '../models/User.js';
import Passenger from '../models/Passenger.js';
import Reservation from '../models/Reservation.js';
import Payment from '../models/Payment.js';
import Line from '../models/Line.js';
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';
import { BOOKING_TYPE, PAYMENT_STATUS, PAYMENT_METHOD, RESERVATION_STATUS, PASSENGER_TYPE } from '../utils/constants.js';
import logger from '../utils/logger.js';

/**
 * Register walk-in passenger and create reservation
 * Public endpoint - no authentication required
 */
export const registerWalkIn = async (req, res, next) => {
  let paymentRecord = null;
  let user = null;
  let passenger = null;

  try {
    const { lineid, phone, dropoffpoint, aging } = req.body;

    // Validate required fields
    if (!lineid) {
      return res.status(400).json({
        message: 'lineid is required',
      });
    }

    if (!phone) {
      return res.status(400).json({
        message: 'phone is required',
      });
    }

    // Validate phone format (basic validation - Palestinian format)
    const phoneRegex = /^(\+?970|0)?[5][0-9]{8}$/;
    const normalizedPhone = phone.trim().replace(/\s+/g, '');
    
    if (!phoneRegex.test(normalizedPhone)) {
      return res.status(400).json({
        message: 'Invalid phone number format. Please use Palestinian format (e.g., 0599123456 or +970599123456)',
      });
    }

    // Validate line exists and is active
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    if (!line.active) {
      return res.status(400).json({
        message: 'Line is not active',
      });
    }

    // Find or create user by phone number
    user = await User.findByPhone(normalizedPhone);

    if (!user) {
      // Create new user for walk-in passenger
      const userData = {
        userid: uuidv4(),
        fullname: `Walk-in Passenger ${normalizedPhone.substring(normalizedPhone.length - 4)}`, // Use last 4 digits as identifier
        email: `walkin_${uuidv4().substring(0, 8)}@walkin.local`, // Temporary email
        phone: normalizedPhone,
        role: 'PASSENGER',
        password: null, // No password for walk-in passengers
      };

      user = await User.create(userData);
      logger.info(`[WalkInController] Created new user ${user.userid} for walk-in passenger with phone ${normalizedPhone}`);
    } else {
      logger.info(`[WalkInController] Found existing user ${user.userid} for phone ${normalizedPhone}`);
    }

    // Find or create passenger record
    passenger = await Passenger.findOrCreateByPhone(normalizedPhone, user.userid);

    // Calculate booking price
    let bookingPrice = line.baseprice;
    if (dropoffpoint && line.additionalprice) {
      bookingPrice += line.additionalprice;
    }

    // Create payment record (status: pending - will be paid at station)
    // For walk-in passengers, payment is handled at the station
    paymentRecord = await Payment.create({
      paymentid: uuidv4(),
      amount: bookingPrice,
      method: PAYMENT_METHOD.CARD, // Default to card for walk-in, can be changed at station
      status: PAYMENT_STATUS.PENDING,
      type: 'reservation',
      tripid: null, // No trip assigned yet
      time: new Date().toISOString(),
    });

    // Create reservation with walk-in passenger type
    const reservationData = {
      bookingid: uuidv4(),
      passengerid: passenger.passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: null, // No trip assigned yet - will be assigned when driver scans QR
      lineid: line.lineid,
      seatlocation: null,
      bookingprice: bookingPrice,
      dropoffpoint: dropoffpoint || null,
      aging: aging || null,
      status: RESERVATION_STATUS.CONFIRMED,
      driver_status: 'approved',
      booking_type: BOOKING_TYPE.INSTANT,
      scheduled_trip_time: null,
      passenger_type: PASSENGER_TYPE.WALK_IN,
      phone_number: normalizedPhone,
    };

    const reservation = await Reservation.create(reservationData);
    logger.info(`[WalkInController] Created walk-in reservation ${reservation.bookingid} for phone ${normalizedPhone}`);

    // Generate QR code (same format as existing system)
    const qrData = JSON.stringify({
      bookingid: reservation.bookingid,
      passengerid: reservation.passengerid,
      tripid: reservation.tripid || null,
    });

    const qrCode = await generateQRCode(qrData);

    // Get payment details for response
    const paymentDetails = await Payment.findById(paymentRecord.paymentid);

    res.status(201).json({
      message: 'Walk-in reservation created successfully',
      reservation: {
        bookingid: reservation.bookingid,
        lineid: reservation.lineid,
        phone_number: reservation.phone_number,
        bookingprice: reservation.bookingprice,
        status: reservation.status,
        passenger_type: reservation.passenger_type,
      },
      payment: paymentDetails,
      qrCode,
      qrData,
      line: {
        lineid: line.lineid,
        name_ar: line.name_ar,
        name_en: line.name_en,
        linename: line.linename,
      },
    });
  } catch (error) {
    logger.error('[WalkInController] Error creating walk-in reservation:', error);

    // Clean up created records on error
    if (paymentRecord) {
      try {
        await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED });
      } catch (cleanupError) {
        logger.warn('[WalkInController] Failed to update payment status on error:', cleanupError);
      }
    }

    next(error);
  }
};

