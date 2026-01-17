import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import Driver from '../models/Driver.js';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import { PAYMENT_STATUS } from '../utils/constants.js';
import logger from '../utils/logger.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Transfer payment from one driver to another when a reservation is reassigned
 * This reverses the payment from the original driver and transfers to the new driver
 * @param {string} paymentid - The payment ID
 * @param {string} fromDriverid - The original driver ID (to reverse payment from)
 * @param {string} toDriverid - The new driver ID (to transfer payment to)
 * @returns {Promise<object>} - Transfer result
 */
export const reassignPaymentToDriver = async (paymentid, fromDriverid, toDriverid) => {
  try {
    logger.info(`[PaymentService] 🔄 Reassigning payment ${paymentid} from driver ${fromDriverid} to driver ${toDriverid}`);

    // Get the payment
    const payment = await Payment.findById(paymentid);
    if (!payment) {
      logger.error(`[PaymentService] ❌ Payment ${paymentid} not found`);
      return { success: false, error: 'Payment not found' };
    }

    // Check if payment is completed
    if (payment.status !== PAYMENT_STATUS.COMPLETED) {
      logger.warn(`[PaymentService] ⚠️ Payment ${paymentid} is not completed (status: ${payment.status})`);
      return { success: false, error: 'Payment not completed' };
    }

    const transferAmount = payment.amount;

    // Step 1: Reverse payment from original driver (if it was already transferred)
    if (payment.towalletid && fromDriverid) {
      try {
        // Subtract from original driver's wallet
        await Wallet.updateBalance(payment.towalletid, transferAmount, 'subtract');
        logger.info(`[PaymentService] ✅ Reversed ${transferAmount} from original driver wallet ${payment.towalletid}`);
      } catch (error) {
        logger.error(`[PaymentService] ❌ Failed to reverse payment from original driver:`, error);
        return { success: false, error: 'Failed to reverse payment from original driver' };
      }
    }

    // Step 2: Transfer to new driver
    const newDriver = await Driver.findById(toDriverid);
    if (!newDriver) {
      logger.error(`[PaymentService] ❌ New driver ${toDriverid} not found`);
      // Try to restore original driver's wallet if we already subtracted
      if (payment.towalletid && fromDriverid) {
        await Wallet.updateBalance(payment.towalletid, transferAmount, 'add').catch(() => {});
      }
      return { success: false, error: 'New driver not found' };
    }

    if (!newDriver.userid) {
      logger.error(`[PaymentService] ❌ New driver ${toDriverid} has no userid`);
      // Try to restore original driver's wallet if we already subtracted
      if (payment.towalletid && fromDriverid) {
        await Wallet.updateBalance(payment.towalletid, transferAmount, 'add').catch(() => {});
      }
      return { success: false, error: 'New driver has no user ID' };
    }

    // Get or create new driver's wallet
    let newDriverWallets = await Wallet.findByUserId(newDriver.userid, 'main');
    let newDriverWallet = newDriverWallets?.[0];

    if (!newDriverWallet) {
      logger.info(`[PaymentService] 📝 Creating wallet for new driver ${toDriverid} (userid: ${newDriver.userid})`);
      newDriverWallet = await Wallet.create({
        walletid: uuidv4(),
        userid: newDriver.userid,
        type: 'main',
        balance: 0,
      });
    }

    // Add amount to new driver's wallet
    await Wallet.updateBalance(newDriverWallet.walletid, transferAmount, 'add');
    logger.info(`[PaymentService] ✅ Added ${transferAmount} to new driver wallet ${newDriverWallet.walletid}`);

    // Update payment with new towalletid
    await Payment.update(paymentid, {
      towalletid: newDriverWallet.walletid,
    });
    logger.info(`[PaymentService] ✅ Updated payment ${paymentid} towalletid to ${newDriverWallet.walletid}`);

    return {
      success: true,
      payment: await Payment.findById(paymentid),
      fromWallet: payment.towalletid,
      toWallet: newDriverWallet.walletid,
      amount: transferAmount,
    };
  } catch (error) {
    logger.error(`[PaymentService] ❌ Error reassigning payment ${paymentid}:`, error);
    return { success: false, error: error.message };
  }
};

/**
 * Transfer a payment to a driver's wallet
 * @param {string} paymentid - The payment ID
 * @param {string} driverid - The driver ID
 * @returns {Promise<object>} - Transfer result
 */
export const transferPaymentToDriver = async (paymentid, driverid) => {
  try {
    logger.info(`[PaymentService] 💰 Transferring payment ${paymentid} to driver ${driverid}`);

    // Get the payment
    const payment = await Payment.findById(paymentid);
    if (!payment) {
      logger.error(`[PaymentService] ❌ Payment ${paymentid} not found`);
      return { success: false, error: 'Payment not found' };
    }

    // Check if payment is already transferred
    if (payment.towalletid) {
      logger.info(`[PaymentService] ℹ️ Payment ${paymentid} already transferred to wallet ${payment.towalletid}`);
      return { success: true, alreadyTransferred: true, payment };
    }

    // Check if payment is completed
    if (payment.status !== PAYMENT_STATUS.COMPLETED) {
      logger.warn(`[PaymentService] ⚠️ Payment ${paymentid} is not completed (status: ${payment.status}), cannot transfer`);
      return { success: false, error: 'Payment not completed' };
    }

    // Get driver and their wallet
    const driver = await Driver.findById(driverid);
    if (!driver) {
      logger.error(`[PaymentService] ❌ Driver ${driverid} not found`);
      return { success: false, error: 'Driver not found' };
    }

    if (!driver.userid) {
      logger.error(`[PaymentService] ❌ Driver ${driverid} has no userid`);
      return { success: false, error: 'Driver has no user ID' };
    }

    // Get or create driver's wallet
    let driverWallets = await Wallet.findByUserId(driver.userid, 'main');
    let driverWallet = driverWallets?.[0];

    if (!driverWallet) {
      logger.info(`[PaymentService] 📝 Creating wallet for driver ${driverid} (userid: ${driver.userid})`);
      driverWallet = await Wallet.create({
        walletid: uuidv4(),
        userid: driver.userid,
        type: 'main',
        balance: 0,
      });
      logger.info(`[PaymentService] ✅ Created wallet ${driverWallet.walletid} for driver ${driverid}`);
    }

    // Check if payment has a fromwalletid (passenger wallet)
    if (!payment.fromwalletid) {
      logger.warn(`[PaymentService] ⚠️ Payment ${paymentid} has no fromwalletid, cannot transfer`);
      return { success: false, error: 'Payment has no source wallet' };
    }

    // Transfer amount to driver wallet
    const transferAmount = payment.amount;
    await Wallet.updateBalance(driverWallet.walletid, transferAmount, 'add');
    logger.info(`[PaymentService] ✅ Added ${transferAmount} to driver wallet ${driverWallet.walletid}`);

    // Update payment with towalletid
    await Payment.update(paymentid, {
      towalletid: driverWallet.walletid,
    });
    logger.info(`[PaymentService] ✅ Updated payment ${paymentid} with towalletid ${driverWallet.walletid}`);

    // Send notification to driver about payment received
    try {
      const { sendNotification, NOTIFICATION_TYPES } = await import('./notificationService.js');
      const Reservation = (await import('../models/Reservation.js')).default;
      const Passenger = (await import('../models/Passenger.js')).default;
      
      // Get reservation and passenger info
      const reservation = payment.tripid ? 
        (await Reservation.findByTripId(payment.tripid)).find(r => r.paymentid === paymentid) : null;
      
      if (reservation) {
        const passenger = await Passenger.findById(reservation.passengerid);
        const passengerName = passenger?.user?.fullname || 'Passenger';
        const amount = transferAmount.toFixed(2);
        
        // Get driver's language preference (defaults to 'ar' if not set)
        const { getUserLanguage } = await import('../utils/lineHelpers.js');
        const driverLanguage = await getUserLanguage(driver.userid);

        await sendNotification(
          driver.userid,
          NOTIFICATION_TYPES.PAYMENT_RECEIVED,
          {
            amount,
            passengerName,
            paymentid: paymentid,
          },
          driverLanguage
        );
      }
    } catch (notifError) {
      logger.warn(`[PaymentService] Failed to send payment notification for payment ${paymentid}:`, notifError);
    }

    return {
      success: true,
      payment: await Payment.findById(paymentid),
      driverWallet,
      amount: transferAmount,
    };
  } catch (error) {
    logger.error(`[PaymentService] ❌ Error transferring payment ${paymentid} to driver ${driverid}:`, error);
    return { success: false, error: error.message };
  }
};

/**
 * Transfer all pending payments for a trip to the assigned driver
 * @param {string} tripid - The trip ID
 * @param {string} driverid - The driver ID
 * @returns {Promise<object>} - Transfer result with count
 */
export const transferPaymentsForTrip = async (tripid, driverid) => {
  try {
    logger.info(`[PaymentService] 💰 Transferring payments for trip ${tripid} to driver ${driverid}`);

    if (!tripid || !driverid) {
      logger.warn(`[PaymentService] ⚠️ Missing tripid or driverid: tripid=${tripid}, driverid=${driverid}`);
      return { success: false, error: 'Missing tripid or driverid', transferred: 0 };
    }

    // Get payments directly by tripid
    const paymentsByTrip = await Payment.findByTripId(tripid);
    
    // Also get payments through reservations (for backward compatibility)
    const reservations = await Reservation.findByTripId(tripid);
    const activeReservations = reservations.filter(
      r => r.status === 'confirmed' || r.status === 'checked_in'
    );
    const reservationPaymentIds = activeReservations
      .map(r => r.paymentid)
      .filter(id => id != null);

    // Combine both sources and get unique payments
    const allPaymentIds = new Set();
    paymentsByTrip.forEach(p => allPaymentIds.add(p.paymentid));
    reservationPaymentIds.forEach(id => allPaymentIds.add(id));

    if (allPaymentIds.size === 0) {
      logger.info(`[PaymentService] ℹ️ No payments found for trip ${tripid}`);
      return { success: true, transferred: 0, message: 'No payments found for this trip' };
    }

    // Find payments that need to be transferred (completed but not yet transferred)
    const paymentsToTransfer = [];
    for (const paymentId of allPaymentIds) {
      try {
        const payment = await Payment.findById(paymentId);
        if (payment && 
            payment.status === PAYMENT_STATUS.COMPLETED && 
            !payment.towalletid) {
          paymentsToTransfer.push(payment);
        }
      } catch (error) {
        logger.warn(`[PaymentService] ⚠️ Error fetching payment ${paymentId}:`, error);
      }
    }

    if (paymentsToTransfer.length === 0) {
      logger.info(`[PaymentService] ℹ️ No payments to transfer for trip ${tripid} (all already transferred or not completed)`);
      return { success: true, transferred: 0, message: 'No payments to transfer' };
    }

    logger.info(`[PaymentService] 📋 Found ${paymentsToTransfer.length} payment(s) to transfer for trip ${tripid}`);

    // Transfer each payment
    let transferredCount = 0;
    let failedCount = 0;
    const errors = [];

    for (const payment of paymentsToTransfer) {
      try {
        const result = await transferPaymentToDriver(payment.paymentid, driverid);
        if (result.success) {
          transferredCount++;
          logger.info(`[PaymentService] ✅ Transferred payment ${payment.paymentid} to driver ${driverid}`);
        } else {
          failedCount++;
          errors.push({ paymentid: payment.paymentid, error: result.error });
          logger.warn(`[PaymentService] ⚠️ Failed to transfer payment ${payment.paymentid}: ${result.error}`);
        }
      } catch (error) {
        failedCount++;
        errors.push({ paymentid: payment.paymentid, error: error.message });
        logger.error(`[PaymentService] ❌ Error transferring payment ${payment.paymentid}:`, error);
      }
    }

    logger.info(`[PaymentService] ✅ Completed transfer for trip ${tripid}: ${transferredCount} transferred, ${failedCount} failed`);

    return {
      success: true,
      transferred: transferredCount,
      failed: failedCount,
      errors: errors.length > 0 ? errors : undefined,
    };
  } catch (error) {
    logger.error(`[PaymentService] ❌ Error transferring payments for trip ${tripid} to driver ${driverid}:`, error);
    return { success: false, error: error.message, transferred: 0 };
  }
};

