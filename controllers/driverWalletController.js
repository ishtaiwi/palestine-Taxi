import Wallet from '../models/Wallet.js';
import Payment from '../models/Payment.js';
import Driver from '../models/Driver.js';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import { v4 as uuidv4 } from 'uuid';
import { getUtcNow } from '../utils/timeUtils.js';
import { PAYMENT_STATUS, WALLET_TYPE } from '../utils/constants.js';
import logger from '../utils/logger.js';

/**
 * Get driver wallet with balance and summary
 */
export const getDriverWallet = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);
    if (!driverRecord || !driverRecord.userid) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    const userid = driverRecord.userid;
    
    // Get or create driver wallet
    let wallets = await Wallet.findByUserId(userid, WALLET_TYPE.MAIN);
    let wallet;

    if (!wallets || wallets.length === 0) {
      // Create driver wallet if doesn't exist
      wallet = await Wallet.create({
        walletid: uuidv4(),
        userid,
        type: WALLET_TYPE.MAIN,
        balance: 0,
      });
    } else {
      wallet = wallets[0];
    }

    // Get all earnings transactions (payments with type 'driver_earnings')
    let payments = await Payment.findAll({ type: 'driver_earnings' });
    
    logger.info(`[DriverWalletController] Found ${payments?.length || 0} total driver_earnings payments`);
    logger.info(`[DriverWalletController] Driver wallet ID: ${wallet.walletid}`);
    
    // Filter payments where driver's wallet is the receiver
    const driverPayments = (payments || []).filter(p => {
      const matches = p.towalletid === wallet.walletid && 
                     (p.status === PAYMENT_STATUS.COMPLETED || p.status === 'completed');
      if (!matches && p.type === 'driver_earnings') {
        logger.debug(`[DriverWalletController] Payment ${p.paymentid} filtered out - towalletid: ${p.towalletid}, status: ${p.status}`);
      }
      return matches;
    });
    
    logger.info(`[DriverWalletController] Filtered to ${driverPayments.length} payments for this driver's wallet`);

    // Calculate summary
    const now = getUtcNow();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    const todayEarnings = driverPayments
      .filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= today;
      })
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const monthEarnings = driverPayments
      .filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= thisMonth;
      })
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const totalEarnings = driverPayments.reduce((sum, p) => sum + (p.amount || 0), 0);

    res.json({
      walletid: wallet.walletid,
      balance: wallet.balance || 0,
      type: wallet.type,
      summary: {
        today: todayEarnings,
        thisMonth: monthEarnings,
        total: totalEarnings,
      },
      transactions: driverPayments || [],
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get driver earnings transactions with filters
 */
export const getDriverTransactions = async (req, res, next) => {
  try {
    const { period, startDate, endDate, tripid } = req.query;
    const driverRecord = await Driver.findById(req.user.driverid);
    
    if (!driverRecord || !driverRecord.userid) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    const userid = driverRecord.userid;
    
    // Get driver wallet
    let wallets = await Wallet.findByUserId(userid, WALLET_TYPE.MAIN);
    if (!wallets || wallets.length === 0) {
      return res.json({
        transactions: [],
        summary: { total: 0 },
      });
    }

    const wallet = wallets[0];

    // Get all earnings transactions
    let payments = await Payment.findAll({ type: 'driver_earnings' });
    
    logger.info(`[DriverWalletController] Found ${payments?.length || 0} total driver_earnings payments for transactions`);
    logger.info(`[DriverWalletController] Driver wallet ID: ${wallet.walletid}`);
    
    // Filter by driver's wallet
    payments = (payments || []).filter(p => {
      const matches = p.towalletid === wallet.walletid && 
                     (p.status === PAYMENT_STATUS.COMPLETED || p.status === 'completed');
      if (!matches && p.type === 'driver_earnings') {
        logger.debug(`[DriverWalletController] Payment ${p.paymentid} filtered out - towalletid: ${p.towalletid}, status: ${p.status}`);
      }
      return matches;
    });
    
    logger.info(`[DriverWalletController] Filtered to ${payments.length} payments for this driver's wallet`);

    // Apply filters
    const now = getUtcNow();
    if (period === 'today') {
      const today = new Date(now);
      today.setHours(0, 0, 0, 0);
      payments = payments.filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= today;
      });
    } else if (period === 'thisMonth') {
      const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      payments = payments.filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= thisMonth;
      });
    } else if (period === 'thisWeek') {
      const thisWeek = new Date(now);
      thisWeek.setDate(now.getDate() - now.getDay());
      thisWeek.setHours(0, 0, 0, 0);
      payments = payments.filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= thisWeek;
      });
    }

    if (startDate) {
      const start = new Date(startDate);
      payments = payments.filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= start;
      });
    }

    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      payments = payments.filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate <= end;
      });
    }

    if (tripid) {
      // Filter by trip ID stored in stripe_payment_intent_id as "trip_{tripid}_reservation_{reservationid}"
      payments = payments.filter(p => 
        p.stripe_payment_intent_id && p.stripe_payment_intent_id.startsWith(`trip_${tripid}_reservation_`)
      );
    }

    // Sort by date (newest first)
    payments.sort((a, b) => {
      const dateA = new Date(a.time || a.created_at || 0);
      const dateB = new Date(b.time || b.created_at || 0);
      return dateB - dateA;
    });

    // Enrich with trip and reservation details
    const enrichedPayments = await Promise.all(
      payments.map(async (payment) => {
        const enriched = { ...payment };
        
        // Get trip and reservation details from stripe_payment_intent_id format "trip_{tripid}_reservation_{reservationid}"
        if (payment.stripe_payment_intent_id && payment.stripe_payment_intent_id.startsWith('trip_')) {
          try {
            // Extract tripid and reservationid from format: "trip_{tripid}_reservation_{reservationid}"
            const parts = payment.stripe_payment_intent_id.split('_reservation_');
            const tripid = parts[0].replace('trip_', '');
            const reservationid = parts[1] || null;
            
            const trip = await Trip.findById(tripid);
            if (trip) {
              enriched.trip = {
                tripid: trip.tripid,
                deptime: trip.deptime,
                line: trip.line,
                status: trip.status,
              };

              // Get specific reservation details if reservationid is available
              if (reservationid) {
                try {
                  const reservation = await Reservation.findById(reservationid);
                  if (reservation) {
                    enriched.reservation = {
                      bookingid: reservation.bookingid,
                      passenger: reservation.passenger,
                      bookingprice: reservation.bookingprice,
                      status: reservation.status,
                      bookedat: reservation.bookedat, // Booking time
                      dropoffpoint: reservation.dropoffpoint,
                    };
                    
                    // Also add to trip reservations for compatibility
                    enriched.trip.reservations = [{
                      bookingid: reservation.bookingid,
                      passenger: reservation.passenger,
                      bookingprice: reservation.bookingprice,
                      status: reservation.status,
                      bookedat: reservation.bookedat, // Booking time
                    }];
                  }
                } catch (reservationError) {
                  console.error(`Error fetching reservation ${reservationid}:`, reservationError);
                }
              } else {
                // Fallback: Get all reservations for this trip if no specific reservation ID
                const reservations = await Reservation.findByTripId(trip.tripid);
                enriched.trip.reservations = reservations
                  .filter(r => r.status === 'confirmed' || r.status === 'checked_in')
                  .map(r => ({
                    bookingid: r.bookingid,
                    passenger: r.passenger,
                    bookingprice: r.bookingprice,
                    status: r.status,
                    bookedat: r.bookedat, // Booking time
                  }));
              }
            }
          } catch (error) {
            console.error(`Error fetching trip details for ${payment.stripe_payment_intent_id}:`, error);
          }
        }

        return enriched;
      })
    );

    const totalEarnings = enrichedPayments.reduce((sum, p) => sum + (p.amount || 0), 0);

    res.json({
      transactions: enrichedPayments,
      summary: {
        total: totalEarnings,
        count: enrichedPayments.length,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get driver earnings summary (today, this month, total)
 */
export const getDriverEarningsSummary = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);
    
    if (!driverRecord || !driverRecord.userid) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    const userid = driverRecord.userid;
    
    // Get driver wallet
    let wallets = await Wallet.findByUserId(userid, WALLET_TYPE.MAIN);
    if (!wallets || wallets.length === 0) {
      return res.json({
        today: 0,
        thisWeek: 0,
        thisMonth: 0,
        total: 0,
        balance: 0,
      });
    }

    const wallet = wallets[0];

    // Get all earnings transactions
    let payments = await Payment.findAll({ type: 'driver_earnings' });
    const driverPayments = (payments || []).filter(
      p => p.towalletid === wallet.walletid && 
           (p.status === PAYMENT_STATUS.COMPLETED || p.status === 'completed')
    );

    const now = getUtcNow();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);
    
    const thisWeek = new Date(now);
    thisWeek.setDate(now.getDate() - now.getDay());
    thisWeek.setHours(0, 0, 0, 0);
    
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const todayEarnings = driverPayments
      .filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= today;
      })
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const weekEarnings = driverPayments
      .filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= thisWeek;
      })
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const monthEarnings = driverPayments
      .filter(p => {
        const paymentDate = new Date(p.time || p.created_at);
        return paymentDate >= thisMonth;
      })
      .reduce((sum, p) => sum + (p.amount || 0), 0);

    const totalEarnings = driverPayments.reduce((sum, p) => sum + (p.amount || 0), 0);

    res.json({
      today: todayEarnings,
      thisWeek: weekEarnings,
      thisMonth: monthEarnings,
      total: totalEarnings,
      balance: wallet.balance || 0,
    });
  } catch (error) {
    next(error);
  }
};
