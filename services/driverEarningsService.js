import Reservation from '../models/Reservation.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { PAYMENT_STATUS, PAYMENT_METHOD, WALLET_TYPE } from '../utils/constants.js';
import logger from '../utils/logger.js';
import { DateTime } from 'luxon';

// Driver earnings percentage (100% goes to driver)
const DRIVER_EARNINGS_PERCENTAGE = 1.0;

/**
 * Calculate and record driver earnings for a completed trip
 * @param {string} tripid - The trip ID
 * @param {string} driverid - The driver ID
 * @returns {Promise<object>} - Earnings calculation result
 */
export const calculateDriverEarnings = async (tripid, driverid) => {
  try {
    // Get all reservations for this trip
    const reservations = await Reservation.findByTripId(tripid);
    
    // Filter only confirmed/checked_in reservations
    const activeReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );

    if (activeReservations.length === 0) {
      return {
        success: true,
        totalEarnings: 0,
        transactionCount: 0,
        message: 'No active reservations for this trip',
      };
    }

    // Get driver's user ID from driverid (we need to get userid from driver)
    // For now, assume driver has a wallet created with userid
    // We'll get driver's userid from the Driver model when needed

    let totalEarnings = 0;
    const earningsTransactions = [];

    // Calculate earnings for each reservation
    for (const reservation of activeReservations) {
      const bookingPrice = reservation.bookingprice || 0;
      if (bookingPrice <= 0) continue;

      // Get payment record
      if (!reservation.paymentid) continue;

      const payment = await Payment.findById(reservation.paymentid);
      if (!payment || payment.status !== PAYMENT_STATUS.COMPLETED) {
        continue; // Skip if payment not completed
      }

      // Calculate driver's share (100% of booking price - full amount)
      const driverEarning = bookingPrice * DRIVER_EARNINGS_PERCENTAGE; // Now equals bookingPrice since percentage is 1.0
      totalEarnings += driverEarning;

      earningsTransactions.push({
        reservationid: reservation.bookingid,
        passengerid: reservation.passengerid,
        bookingprice: bookingPrice,
        driverEarning: driverEarning,
        paymentid: payment.paymentid,
      });
    }

    // Get or create driver wallet
    // First, we need driver's userid - for now we'll pass it separately
    // This will be called from trip controller with userid

    return {
      success: true,
      totalEarnings,
      transactionCount: earningsTransactions.length,
      transactions: earningsTransactions,
    };
  } catch (error) {
    logger.error(`[DriverEarningsService] Error calculating earnings for trip ${tripid}:`, error);
    throw error;
  }
};

/**
 * Record earnings to driver's wallet when passenger books
 * @param {string} userid - Driver's user ID
 * @param {number} amount - Earnings amount (full booking price)
 * @param {string} tripid - Trip ID
 * @param {string} reservationid - Reservation ID
 * @param {string} bookingtime - Booking time (from reservation)
 * @returns {Promise<object>} - Payment record
 */
export const recordDriverEarnings = async (userid, amount, tripid, reservationid, bookingtime = null) => {
  try {
    if (amount <= 0) {
      return null;
    }

    // Check for duplicate earnings if reservationid and tripid are provided
    // Use a more specific check: look for payments with the exact same reservation and trip combination
    if (tripid && reservationid) {
      const expectedIntentId = `trip_${tripid}_reservation_${reservationid}`;
      
      // Check if payment already exists with this exact reservation and trip combination
      const existingPayment = await Payment.findByStripeIntentId(expectedIntentId);
      
      if (existingPayment && existingPayment.type === 'driver_earnings' && existingPayment.status === PAYMENT_STATUS.COMPLETED) {
        logger.info(`[DriverEarningsService] Earnings already recorded for reservation ${reservationid} on trip ${tripid}, skipping duplicate`);
        return existingPayment; // Return existing payment instead of null
      }
    }

    // Get or create driver wallet
    let wallets = await Wallet.findByUserId(userid, WALLET_TYPE.MAIN);
    let wallet;

    if (!wallets || wallets.length === 0) {
      // Create driver wallet
      wallet = await Wallet.create({
        walletid: uuidv4(),
        userid,
        type: WALLET_TYPE.MAIN,
        balance: 0,
      });
    } else {
      wallet = wallets[0];
    }

    // Add earnings to wallet
    await Wallet.updateBalance(wallet.walletid, amount, 'add');

    // Get current local time (matching laptop timezone)
    const localTime = DateTime.local();
    // Format as SQL timestamp for PostgreSQL: YYYY-MM-DD HH:mm:ss
    // toSQL() returns format suitable for SQL timestamp without timezone
    const localTimeString = localTime.toSQL({ includeOffset: false });

    // Create payment record for earnings with reservation and booking details
    const paymentData = {
      paymentid: uuidv4(),
      fromwalletid: null, // Platform wallet (future)
      towalletid: wallet.walletid,
      amount: amount,
      method: PAYMENT_METHOD.WALLET,
      type: 'driver_earnings',
      status: PAYMENT_STATUS.COMPLETED,
      tripid: tripid || null, // Link payment to trip
      time: localTimeString, // Explicitly set local time (matching laptop timezone)
    };
    
    // Store trip and reservation IDs for reference (format: trip_{tripid}_reservation_{reservationid})
    if (tripid && reservationid) {
      paymentData.stripe_payment_intent_id = `trip_${tripid}_reservation_${reservationid}`;
    } else if (tripid) {
      paymentData.stripe_payment_intent_id = `trip_${tripid}`;
    }
    
    logger.info(`[DriverEarningsService] 💰 Creating NEW payment record for reservation ${reservationid} on trip ${tripid} with amount ${amount} for driver ${userid} at local time ${localTimeString}`);
    logger.info(`[DriverEarningsService] 💰 Payment data: ${JSON.stringify({ paymentid: paymentData.paymentid, towalletid: paymentData.towalletid, stripe_payment_intent_id: paymentData.stripe_payment_intent_id })}`);
    
    const payment = await Payment.create(paymentData);
    
    logger.info(`[DriverEarningsService] ✅ SUCCESS: Payment record created for reservation ${reservationid} - Payment ID: ${payment.paymentid}, Amount: ${amount}, Time: ${payment.time || localTimeString}`);

    // Store additional metadata (we'll enrich in controller with reservation details)
    return {
      ...payment,
      reservationid,
      bookingtime,
    };
  } catch (error) {
    logger.error(`[DriverEarningsService] Error recording earnings:`, error);
    throw error;
  }
};

/**
 * Reverse earnings (deduct from driver wallet when booking is cancelled/rejected)
 * @param {string} userid - Driver's user ID
 * @param {number} amount - Amount to deduct
 * @param {string} reservationid - Reservation ID
 * @returns {Promise<object>} - Refund payment record
 */
export const reverseDriverEarnings = async (userid, amount, reservationid) => {
  try {
    if (amount <= 0) {
      return null;
    }

    // Get driver wallet
    let wallets = await Wallet.findByUserId(userid, WALLET_TYPE.MAIN);
    if (!wallets || wallets.length === 0) {
      throw new Error('Driver wallet not found');
    }

    const wallet = wallets[0];

    // Check if wallet has sufficient balance
    if ((wallet.balance || 0) < amount) {
      console.warn(`[DriverEarningsService] Driver wallet balance (${wallet.balance}) less than reversal amount (${amount})`);
      // Still deduct what we can (or set to 0)
      await Wallet.updateBalance(wallet.walletid, wallet.balance || 0, 'subtract');
    } else {
      // Deduct earnings from wallet
      await Wallet.updateBalance(wallet.walletid, amount, 'subtract');
    }

    // Create payment record for reversal
    const paymentData = {
      paymentid: uuidv4(),
      fromwalletid: wallet.walletid,
      towalletid: null, // Refund goes back to passenger
      amount: amount,
      method: PAYMENT_METHOD.WALLET,
      type: 'driver_earnings_reversal',
      status: PAYMENT_STATUS.COMPLETED,
      stripe_payment_intent_id: `reversal_reservation_${reservationid}`,
    };
    
    const payment = await Payment.create(paymentData);

    return payment;
  } catch (error) {
    logger.error(`[DriverEarningsService] Error reversing earnings:`, error);
    throw error;
  }
};

/**
 * Check and record earnings for a reservation when it gets assigned to a trip
 * This is used when future bookings are assigned to trips later
 * @param {string} reservationid - Reservation ID
 * @param {string} tripid - Trip ID
 * @returns {Promise<object|null>} - Earnings payment record or null
 */
export const checkAndRecordReservationEarnings = async (reservationid, tripid) => {
  try {
    // Get reservation details
    const Reservation = (await import('../models/Reservation.js')).default;
    const reservation = await Reservation.findById(reservationid);
    
    if (!reservation || reservation.status !== 'confirmed') {
      return null; // Only record for confirmed reservations
    }

    // Check if payment was completed
    if (!reservation.paymentid) {
      return null;
    }

    const Payment = (await import('../models/Payment.js')).default;
    const payment = await Payment.findById(reservation.paymentid);
    if (!payment || payment.status !== PAYMENT_STATUS.COMPLETED) {
      return null;
    }

    // Check if earnings already recorded (prevent duplicates)
    // Use a specific check by looking for the exact payment with matching stripe_payment_intent_id
    const expectedIntentId = `trip_${tripid}_reservation_${reservationid}`;
    const existingPayment = await Payment.findByStripeIntentId(expectedIntentId);
    
    if (existingPayment && existingPayment.type === 'driver_earnings' && existingPayment.status === PAYMENT_STATUS.COMPLETED) {
      logger.info(`[DriverEarningsService] Earnings already recorded for reservation ${reservationid} on trip ${tripid}`);
      return existingPayment; // Return existing payment instead of null
    }

    // Get trip and driver
    const Trip = (await import('../models/Trip.js')).default;
    const Driver = (await import('../models/Driver.js')).default;
    const trip = await Trip.findById(tripid);

    if (!trip || !trip.assigned_driverid) {
      return null; // No driver assigned yet
    }

    const driver = await Driver.findById(trip.assigned_driverid);
    if (!driver || !driver.userid) {
      return null;
    }

    const bookingPrice = reservation.bookingprice || 0;
    if (bookingPrice <= 0) {
      return null;
    }

    // Record earnings (100% of booking price)
    const earningsPayment = await recordDriverEarnings(
      driver.userid,
      bookingPrice,
      tripid,
      reservationid,
      reservation.bookedat || new Date().toISOString()
    );

    logger.info(`[DriverEarningsService] ✅ Earnings of ${bookingPrice} ₪ recorded for driver ${driver.userid} on reservation ${reservationid} (assigned to trip ${tripid})`);

    return earningsPayment;
  } catch (error) {
    logger.error(`[DriverEarningsService] Error checking/recording reservation earnings:`, error);
    return null; // Don't throw, just return null
  }
};

/**
 * Process earnings for a completed trip
 * NOTE: This is deprecated - earnings are now recorded when bookings are made
 * Kept for backwards compatibility
 * @param {string} tripid - Trip ID
 * @param {string} driverid - Driver ID
 * @param {string} userid - Driver's user ID
 * @returns {Promise<object>} - Processing result
 */
export const processTripEarnings = async (tripid, driverid, userid) => {
  try {
    // Earnings are now recorded when passenger books, not when trip completes
    // This function is kept for backwards compatibility but does nothing
    return {
      success: true,
      totalEarnings: 0,
      message: 'Earnings are recorded when bookings are made, not on trip completion',
    };
  } catch (error) {
    logger.error(`[DriverEarningsService] Error processing trip earnings:`, error);
    throw error;
  }
};
