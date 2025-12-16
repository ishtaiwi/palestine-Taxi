import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';
import { BOOKING_TYPE, PAYMENT_STATUS, PAYMENT_METHOD, RESERVATION_STATUS, TRIP_STATUS } from '../utils/constants.js';
import { validateReservationData } from '../utils/validation.js';
import { distributeInstantBookings } from '../services/matchingService.js';
import { updateModelIncremental } from '../services/rushHourPredictionService.js';
import logger from '../utils/logger.js';


export const getAllReservations = async (req, res, next) => {
  try {
    const { status, tripid } = req.query;
    const filters = {};

    if (status) filters.status = status;
    if (tripid) filters.tripid = tripid;

    const reservations = await Reservation.findAll(filters);
    res.json(reservations);
  } catch (error) {
    next(error);
  }
};


export const getReservationById = async (req, res, next) => {
  try {
    const { bookingid } = req.params;
    const reservation = await Reservation.findById(bookingid);

    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found'
      });
    }

    res.json(reservation);
  } catch (error) {
    next(error);
  }
};


export const getPassengerReservations = async (req, res, next) => {
  try {
    const { status } = req.query;
    const filters = status ? { status } : {};


    const passengerid = req.user.passengerid || req.user.userid;

    if (!passengerid) {
      return res.status(401).json({
        message: req.t('auth.unauthorized') || 'Unauthorized - No passenger ID found',
      });
    }


    const reservations = await Reservation.findByPassengerId(passengerid, filters);

    res.json(reservations);
  } catch (error) {
    next(error);
  }
};


export const createReservation = async (req, res, next) => {
  let paymentRecord = null;
  let walletUsed = null;
  let walletChargeAmount = 0;
  let seatsUpdated = false;
  let bookingsIncremented = false;
  let trip = null;
  const { tripid, seatlocation, dropoffpoint, aging, booking_type, scheduled_trip_time } = req.body;

  try {
    const passengerid = req.user.passengerid || req.user.userid;
    const paymentMethod = (req.body.paymentmethod || PAYMENT_METHOD.WALLET).toLowerCase();


    const bookingType = booking_type || BOOKING_TYPE.INSTANT;


    const validation = validateReservationData({
      booking_type: bookingType,
      scheduled_trip_time: scheduled_trip_time,
    });

    if (!validation.valid) {
      return res.status(400).json({
        message: validation.errors.join(', '),
      });
    }


    if (bookingType === BOOKING_TYPE.FUTURE) {
      if (!scheduled_trip_time) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_required') || 'scheduled_trip_time is required for future bookings',
        });
      }

      const scheduledTime = new Date(scheduled_trip_time);
      const now = new Date();

      if (scheduledTime <= now) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_future') || 'scheduled_trip_time must be in the future',
        });
      }
    }


    // Require tripid for both instant and future bookings
    if (!tripid) {
      return res.status(400).json({
        message: req.t('reservation.tripid_required') || 'tripid is required for bookings',
      });
    }

    // Fetch and validate trip exists
    trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found'
      });
    }

    // Check if trip status allows bookings
    // Allow bookings for scheduled and delayed trips (delayed trips haven't departed yet)
    const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.DELAYED, 'open']; // Allow 'open' as well if it exists
    if (!validStatuses.includes(trip.status)) {
      return res.status(400).json({
        message: req.t('reservation.trip_unavailable') || `Trip is ${trip.status} and cannot accept bookings`
      });
    }

    // Check if trip has already departed (based on status, not just time)
    // Trips that are in_progress or completed have departed
    const departedStatuses = [TRIP_STATUS.IN_PROGRESS, TRIP_STATUS.COMPLETED];
    if (departedStatuses.includes(trip.status)) {
      return res.status(400).json({
        message: req.t('reservation.trip_departed') || 'Trip has already departed'
      });
    }

    const tripDeptime = new Date(trip.deptime);
    const now = new Date();

    if (bookingType === BOOKING_TYPE.INSTANT) {
      // For instant bookings, check if trip opening time has passed
      // Note: Delayed trips can still accept bookings even if scheduled time has passed
      const tripOpeningTime = trip.trip_opening_time ? new Date(trip.trip_opening_time) : null;
      const defaultOpeningTime = new Date(tripDeptime.getTime() - 45 * 60 * 1000); // 45 minutes before departure
      const effectiveOpeningTime = tripOpeningTime || defaultOpeningTime;



      if (effectiveOpeningTime > now) {
        return res.status(400).json({
          message: req.t('reservation.trip_not_open') || 'Trip is not yet open for instant bookings'
        });
      }

      // Check available seats
      if (trip.availableseats <= 0) {
        return res.status(400).json({
          message: req.t('reservation.no_seats') || 'No available seats'
        });
      }
    }

    // For future bookings, scheduled_trip_time is required and must match trip departure time
    if (bookingType === BOOKING_TYPE.FUTURE) {
      if (!scheduled_trip_time) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_required') || 'scheduled_trip_time is required for future bookings',
        });
      }

      const scheduledTime = new Date(scheduled_trip_time);
      if (tripDeptime.getTime() !== scheduledTime.getTime()) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_mismatch') || 'scheduled_trip_time must match trip departure time',
        });
      }

      // Future bookings must be for trips that haven't departed (status check already done above)
      // No need to check time again since delayed trips can still accept future bookings
    }


    if (seatlocation && tripid && bookingType === BOOKING_TYPE.INSTANT) {
      const existingReservation = await Reservation.getBySeatLocation(tripid, seatlocation);
      if (existingReservation.length > 0) {
        return res.status(400).json({
          message: req.t('reservation.seat_taken') || 'Seat already taken'
        });
      }
    }


    // Get line from trip (tripid is now required for all bookings)
    let line = null;
    if (trip && trip.line) {
      line = trip.line;
    } else {
      // Fallback: load line if not populated in trip
      const Line = (await import('../models/Line.js')).default;
      line = await Line.findById(trip.lineid);
      if (!line) {
        return res.status(404).json({
          message: req.t('line.not_found') || 'Line not found',
        });
      }
    }

    // Validate that provided lineid (if any) matches trip's lineid
    if (req.body.lineid && req.body.lineid !== trip.lineid) {
      return res.status(400).json({
        message: req.t('reservation.lineid_mismatch') || 'Provided lineid does not match the trip\'s lineid',
      });
    }
    let bookingPrice = line.baseprice;

    if (dropoffpoint && line.additionalprice) {
      bookingPrice += line.additionalprice;
    }


    paymentRecord = await Payment.create({
      paymentid: uuidv4(),
      amount: bookingPrice,
      method: paymentMethod,
      status: PAYMENT_STATUS.PENDING,
      type: 'reservation',
    });


    if (paymentMethod === PAYMENT_METHOD.WALLET) {
      const wallets = await Wallet.findByUserId(req.user.userid, 'main');
      const wallet = wallets?.[0];

      if (!wallet) {
        await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED });
        return res.status(400).json({
          message: req.t('payment.wallet_not_found') || 'Wallet not found'
        });
      }

      if ((wallet.balance || 0) < bookingPrice) {
        await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED });
        return res.status(400).json({
          message: req.t('payment.insufficient_balance') || 'Insufficient balance'
        });
      }

      await Wallet.updateBalance(wallet.walletid, bookingPrice, 'subtract');
      walletUsed = wallet.walletid;
      walletChargeAmount = bookingPrice;

      await Payment.update(paymentRecord.paymentid, {
        status: PAYMENT_STATUS.COMPLETED,
        fromwalletid: wallet.walletid,
      });
    } else if ([PAYMENT_METHOD.CASH, PAYMENT_METHOD.CARD, PAYMENT_METHOD.PALPAY, PAYMENT_METHOD.JAWWAL_PAY].includes(paymentMethod)) {
      await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.PENDING });
    } else {
      await Payment.update(paymentRecord.paymentid, {
        status: PAYMENT_STATUS.PENDING,
        method: 'other',
      });
    }


    const reservationStatus = paymentMethod === PAYMENT_METHOD.WALLET ? RESERVATION_STATUS.CONFIRMED : RESERVATION_STATUS.PENDING;
    const reservationData = {
      bookingid: uuidv4(),
      passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: tripid, // Now required for both instant and future bookings
      seatlocation: seatlocation || null,
      bookingprice: bookingPrice,
      dropoffpoint: dropoffpoint || null,
      aging: aging || null,
      status: reservationStatus,
      driver_status: 'pending',
      booking_type: bookingType,
      scheduled_trip_time: bookingType === BOOKING_TYPE.FUTURE ? scheduled_trip_time : null,
    };

    const reservation = await Reservation.create(reservationData);


    if (bookingType === BOOKING_TYPE.INSTANT && tripid) {
      await Trip.updateAvailableSeats(tripid, trip.availableseats - 1);
      seatsUpdated = true;
      await Trip.incrementBookings(tripid);
      bookingsIncremented = true;
    }


    if (bookingType === BOOKING_TYPE.INSTANT && tripid) {
      try {

        const now = new Date();
        const tripOpeningTime = trip.trip_opening_time ? new Date(trip.trip_opening_time) : null;

        if (tripOpeningTime && tripOpeningTime <= now) {

          await distributeInstantBookings(trip.lineid, trip.deptime);
        }
      } catch (error) {
        console.error('[ReservationController] Error in matching engine:', error);

      }
    }


    const qrCode = await generateQRCode(JSON.stringify({
      bookingid: reservation.bookingid,
      passengerid,
      tripid: reservation.tripid || tripid || null,
    }));

    const paymentDetails = await Payment.findById(paymentRecord.paymentid);

    emitPredictionEvent({
      reservation,
      trip,
      lineid: trip?.lineid || req.body.lineid || null,
    });

    res.status(201).json({
      message: req.t('reservation.created') || 'Reservation created successfully',
      reservation,
      payment: paymentDetails,
      qrCode,
    });
  } catch (error) {
    if (walletUsed && walletChargeAmount > 0) {
      await Wallet.updateBalance(walletUsed, walletChargeAmount, 'add').catch(() => { });
    }
    if (paymentRecord) {
      await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED }).catch(() => { });
    }
    if (seatsUpdated) {
      await Trip.findById(req.body.tripid)
        .then((currentTrip) => {
          if (!currentTrip || typeof currentTrip.availableseats !== 'number') return null;
          return Trip.updateAvailableSeats(req.body.tripid, currentTrip.availableseats + 1);
        })
        .catch(() => { });
    }
    if (bookingsIncremented) {
      await Trip.findById(req.body.tripid)
        .then((currentTrip) => {
          if (!currentTrip || typeof currentTrip.totalbookings !== 'number') return null;
          const updatedCount = Math.max((currentTrip.totalbookings || 1) - 1, 0);
          return Trip.update(tripid, { totalbookings: updatedCount });
        })
        .catch(() => { });
    }
    next(error);
  }
};


export const updateReservation = async (req, res, next) => {
  try {
    const { bookingid } = req.params;
    const updates = req.body;

    const reservation = await Reservation.update(bookingid, updates);
    res.json({
      message: req.t('reservation.updated') || 'Reservation updated successfully',
      reservation,
    });
  } catch (error) {
    next(error);
  }
};


export const cancelReservation = async (req, res, next) => {
  try {
    const { bookingid } = req.params;

    const reservation = await Reservation.findById(bookingid);
    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found'
      });
    }


    if (reservation.status === RESERVATION_STATUS.CANCELLED || reservation.status === RESERVATION_STATUS.NO_SHOW) {
      return res.status(400).json({
        message: req.t('reservation.already_cancelled') || 'Reservation is already cancelled or marked as no-show',
      });
    }


    let trip = null;
    let deptime = null;

    if (reservation.tripid) {
      trip = await Trip.findById(reservation.tripid);
      if (trip) {
        deptime = new Date(trip.deptime);
      }
    } else if (reservation.scheduled_trip_time) {

      deptime = new Date(reservation.scheduled_trip_time);
    }

    if (!deptime) {
      return res.status(400).json({
        message: req.t('reservation.no_departure_time') || 'Cannot determine departure time for this reservation',
      });
    }

    const now = new Date();
    const minutesUntilDeparture = (deptime - now) / (1000 * 60);
    const hoursUntilDeparture = minutesUntilDeparture / 60;


    const { CANCELLATION_POLICY } = await import('../utils/constants.js');
    const { calculateRefund } = await import('../utils/helpers.js');

    const refundAmount = calculateRefund(
      reservation.bookingprice,
      hoursUntilDeparture,
      CANCELLATION_POLICY
    );



    if (refundAmount > 0 && reservation.paymentid) {
      const payment = await Payment.findById(reservation.paymentid);
      if (payment && payment.status === PAYMENT_STATUS.COMPLETED) {
        const wallets = await Wallet.findByUserId(req.user.userid, 'main');
        if (wallets.length > 0) {
          await Wallet.updateBalance(wallets[0].walletid, refundAmount, 'add');


          await Payment.create({
            paymentid: uuidv4(),
            amount: refundAmount,
            method: 'refund',
            status: PAYMENT_STATUS.REFUNDED,
            type: 'refund',
            fromwalletid: wallets[0].walletid,
            towalletid: wallets[0].walletid,
          });
        }
      }
    }


    await Reservation.update(bookingid, { status: RESERVATION_STATUS.CANCELLED });


    if (reservation.tripid && trip && (reservation.status === RESERVATION_STATUS.CONFIRMED || reservation.status === RESERVATION_STATUS.CHECKED_IN)) {
      await Trip.updateAvailableSeats(reservation.tripid, trip.availableseats + 1);
    }

    res.json({
      message: req.t('reservation.cancelled') || 'Reservation cancelled successfully',
      refundAmount,
    });
  } catch (error) {
    next(error);
  }
};


export const checkInReservation = async (req, res, next) => {
  try {
    const { bookingid, qrData } = req.body;
    const driverid = req.user.driverid;

    let finalBookingId = bookingid;


    if (qrData && !bookingid) {
      try {
        const qrInfo = JSON.parse(qrData);
        finalBookingId = qrInfo.bookingid;
      } catch (parseError) {
        return res.status(400).json({
          message: req.t('reservation.invalid_qr_code') || 'Invalid QR code data',
        });
      }
    }

    if (!finalBookingId) {
      return res.status(400).json({
        message: req.t('reservation.bookingid_required') || 'Booking ID or QR code is required',
      });
    }

    const reservation = await Reservation.findById(finalBookingId);
    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found'
      });
    }


    if (reservation.tripid) {
      const Trip = (await import('../models/Trip.js')).default;
      const trip = await Trip.findById(reservation.tripid);

      if (trip && trip.assigned_driverid !== driverid) {
        return res.status(403).json({
          message: req.t('driver.trip_forbidden') || 'Driver not authorized for this trip',
        });
      }
    }

    await Reservation.update(finalBookingId, { status: RESERVATION_STATUS.CHECKED_IN });

    const updatedReservation = await Reservation.findById(finalBookingId);

    res.json({
      message: req.t('reservation.checked_in') || 'Passenger checked in successfully',
      reservation: updatedReservation,
    });
  } catch (error) {
    next(error);
  }
};


export const getReservationQRCode = async (req, res, next) => {
  try {
    const { bookingid } = req.params;
    const passengerid = req.user.passengerid || req.user.userid;

    const reservation = await Reservation.findById(bookingid);
    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found'
      });
    }


    if (reservation.passengerid !== passengerid) {
      return res.status(403).json({
        message: req.t('auth.unauthorized') || 'Unauthorized access to this reservation',
      });
    }


    const qrData = JSON.stringify({
      bookingid: reservation.bookingid,
      passengerid: reservation.passengerid,
      tripid: reservation.tripid || null,
    });

    const qrCode = await generateQRCode(qrData);

    res.json({
      qrCode,
      qrData,
      reservation: {
        bookingid: reservation.bookingid,
        tripid: reservation.tripid,
        status: reservation.status,
      },
    });
  } catch (error) {
    next(error);
  }
};

async function emitPredictionEvent({ reservation, trip, lineid }) {
  try {
    const resolvedLineId = lineid || trip?.lineid;
    if (!resolvedLineId) {
      return;
    }

    const eventTime = trip?.deptime || reservation.scheduled_trip_time || reservation.bookedat;
    if (!eventTime) {
      return;
    }

    await updateModelIncremental([
      {
        bookingid: reservation.bookingid,
        lineid: resolvedLineId,
        eventTime,
        status: reservation.status,
        booking_type: reservation.booking_type,
      },
    ]);
  } catch (error) {
    logger.warn('Prediction event emit failed', {
      bookingid: reservation?.bookingid,
      error: error.message,
    });
  }
}

