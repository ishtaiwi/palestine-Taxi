import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';
import { BOOKING_TYPE } from '../utils/constants.js';
import { validateReservationData } from '../utils/validation.js';
import { distributeInstantBookings } from '../services/matchingService.js';


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
    
    const reservations = await Reservation.findByPassengerId(
      req.user.passengerid || req.user.userid,
      filters
    );
    
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
    const paymentMethod = (req.body.paymentmethod || 'wallet').toLowerCase();
    
    // Determine booking type (default: instant)
    const bookingType = booking_type || BOOKING_TYPE.INSTANT;
    
    // Validate booking data
    const validation = validateReservationData({
      booking_type: bookingType,
      scheduled_trip_time: scheduled_trip_time,
    });
    
    if (!validation.valid) {
      return res.status(400).json({
        message: validation.errors.join(', '),
      });
    }
    
    // For future bookings, scheduled_trip_time is required and must be in the future
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
    
    // For instant bookings, tripid is required
    if (bookingType === BOOKING_TYPE.INSTANT && !tripid) {
      return res.status(400).json({
        message: req.t('reservation.tripid_required') || 'tripid is required for instant bookings',
      });
    }
    
    // Get trip details (for instant bookings or future bookings with tripid)
    if (tripid) {
      trip = await Trip.findById(tripid);
      if (!trip) {
        return res.status(404).json({ 
          message: req.t('trip.not_found') || 'Trip not found' 
        });
      }
      
      // For instant bookings, check available seats
      if (bookingType === BOOKING_TYPE.INSTANT) {
        if (trip.availableseats <= 0) {
          return res.status(400).json({ 
            message: req.t('reservation.no_seats') || 'No available seats' 
          });
        }
      }
      
      // For future bookings with tripid, scheduled_trip_time should match trip departure time
      if (bookingType === BOOKING_TYPE.FUTURE && scheduled_trip_time) {
        const tripDeptime = new Date(trip.deptime);
        const scheduledTime = new Date(scheduled_trip_time);
        if (tripDeptime.getTime() !== scheduledTime.getTime()) {
          return res.status(400).json({
            message: req.t('reservation.scheduled_trip_time_mismatch') || 'scheduled_trip_time must match trip departure time',
          });
        }
      }
    }
    
    // Check seat availability (only for instant bookings with tripid)
    if (seatlocation && tripid && bookingType === BOOKING_TYPE.INSTANT) {
      const existingReservation = await Reservation.getBySeatLocation(tripid, seatlocation);
      if (existingReservation.length > 0) {
        return res.status(400).json({ 
          message: req.t('reservation.seat_taken') || 'Seat already taken' 
        });
      }
    }
    
    // Get line info (from trip if exists, or from request for future bookings)
    let line = null;
    if (trip && trip.line) {
      line = trip.line;
    } else if (bookingType === BOOKING_TYPE.FUTURE) {
      // For future bookings, lineid is required in request
      if (!req.body.lineid) {
        return res.status(400).json({
          message: req.t('reservation.lineid_required') || 'lineid is required for future bookings',
        });
      }
      const Line = (await import('../models/Line.js')).default;
      line = await Line.findById(req.body.lineid);
      if (!line) {
        return res.status(404).json({
          message: req.t('line.not_found') || 'Line not found',
        });
      }
    }
    let bookingPrice = line.baseprice;
    
    if (dropoffpoint && line.additionalprice) {
      bookingPrice += line.additionalprice;
    }
    
    
    paymentRecord = await Payment.create({
      paymentid: uuidv4(),
      amount: bookingPrice,
      method: paymentMethod,
      status: 'pending',
      type: 'reservation',
    });
    
    
    if (paymentMethod === 'wallet') {
      const wallets = await Wallet.findByUserId(req.user.userid, 'main');
      const wallet = wallets?.[0];
      
      if (!wallet) {
        await Payment.update(paymentRecord.paymentid, { status: 'failed' });
        return res.status(400).json({ 
          message: req.t('payment.wallet_not_found') || 'Wallet not found' 
        });
      }
      
      if ((wallet.balance || 0) < bookingPrice) {
        await Payment.update(paymentRecord.paymentid, { status: 'failed' });
        return res.status(400).json({ 
          message: req.t('payment.insufficient_balance') || 'Insufficient balance' 
        });
      }
      
      await Wallet.updateBalance(wallet.walletid, bookingPrice, 'subtract');
      walletUsed = wallet.walletid;
      walletChargeAmount = bookingPrice;
      
      await Payment.update(paymentRecord.paymentid, { 
        status: 'completed',
        fromwalletid: wallet.walletid,
      });
    } else if (['cash', 'card', 'palpay', 'jawwal_pay'].includes(paymentMethod)) {
      await Payment.update(paymentRecord.paymentid, { status: 'pending' });
    } else {
      await Payment.update(paymentRecord.paymentid, { 
        status: 'pending',
        method: 'other',
      });
    }
    
    
    const reservationStatus = paymentMethod === 'wallet' ? 'confirmed' : 'pending_payment';
    const reservationData = {
      bookingid: uuidv4(),
      passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: bookingType === BOOKING_TYPE.INSTANT ? tripid : null, // Future bookings don't have tripid initially
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
    
    // Update trip seats only for instant bookings (future bookings will be assigned when trip opens)
    if (bookingType === BOOKING_TYPE.INSTANT && tripid) {
      await Trip.updateAvailableSeats(tripid, trip.availableseats - 1);
      seatsUpdated = true;
      await Trip.incrementBookings(tripid);
      bookingsIncremented = true;
    }
    
    // Call Matching Engine for instant bookings (if trip is open)
    if (bookingType === BOOKING_TYPE.INSTANT && tripid) {
      try {
        // Check if trip is open (trip_opening_time has passed)
        const now = new Date();
        const tripOpeningTime = trip.trip_opening_time ? new Date(trip.trip_opening_time) : null;
        
        if (tripOpeningTime && tripOpeningTime <= now) {
          // Trip is open, distribute immediately
          await distributeInstantBookings(trip.lineid, trip.deptime);
        }
      } catch (error) {
        console.error('[ReservationController] Error in matching engine:', error);
        // Don't fail reservation creation if matching fails
      }
    }
    
    
    const qrCode = await generateQRCode(JSON.stringify({
      bookingid: reservation.bookingid,
      passengerid,
      tripid,
    }));
    
    const paymentDetails = await Payment.findById(paymentRecord.paymentid);
    
    res.status(201).json({
      message: req.t('reservation.created') || 'Reservation created successfully',
      reservation,
      payment: paymentDetails,
      qrCode,
    });
  } catch (error) {
    if (walletUsed && walletChargeAmount > 0) {
      await Wallet.updateBalance(walletUsed, walletChargeAmount, 'add').catch(() => {});
    }
    if (paymentRecord) {
      await Payment.update(paymentRecord.paymentid, { status: 'failed' }).catch(() => {});
    }
    if (seatsUpdated) {
      await Trip.findById(req.body.tripid)
        .then((currentTrip) => {
          if (!currentTrip || typeof currentTrip.availableseats !== 'number') return null;
          return Trip.updateAvailableSeats(req.body.tripid, currentTrip.availableseats + 1);
        })
        .catch(() => {});
    }
    if (bookingsIncremented) {
      await Trip.findById(req.body.tripid)
        .then((currentTrip) => {
          if (!currentTrip || typeof currentTrip.totalbookings !== 'number') return null;
          const updatedCount = Math.max((currentTrip.totalbookings || 1) - 1, 0);
          return Trip.update(tripid, { totalbookings: updatedCount });
        })
        .catch(() => {});
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
    
    // Check if reservation can be cancelled
    if (reservation.status === 'cancelled' || reservation.status === 'no_show') {
      return res.status(400).json({
        message: req.t('reservation.already_cancelled') || 'Reservation is already cancelled or marked as no-show',
      });
    }
    
    // Get trip details (if exists)
    let trip = null;
    let deptime = null;
    
    if (reservation.tripid) {
      trip = await Trip.findById(reservation.tripid);
      if (trip) {
        deptime = new Date(trip.deptime);
      }
    } else if (reservation.scheduled_trip_time) {
      // For future bookings without trip assigned yet
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
    
    // Updated cancellation policy: 60 minutes (no charge), less than 60 minutes (25% charge)
    const { CANCELLATION_POLICY } = await import('../utils/constants.js');
    const { calculateRefund } = await import('../utils/helpers.js');
    
    const refundAmount = calculateRefund(
      reservation.bookingprice,
      hoursUntilDeparture,
      CANCELLATION_POLICY
    );
    
    
    // Refund to wallet if payment was completed
    if (refundAmount > 0 && reservation.paymentid) {
      const payment = await Payment.findById(reservation.paymentid);
      if (payment && payment.status === 'completed') {
        const wallets = await Wallet.findByUserId(req.user.userid, 'main');
        if (wallets.length > 0) {
          await Wallet.updateBalance(wallets[0].walletid, refundAmount, 'add');
          
          // Create refund payment record
          await Payment.create({
            paymentid: uuidv4(),
            amount: refundAmount,
            method: 'refund',
            status: 'completed',
            type: 'refund',
            fromwalletid: wallets[0].walletid,
            towalletid: wallets[0].walletid,
          });
        }
      }
    }
    
    // Update reservation status to cancelled
    await Reservation.update(bookingid, { status: 'cancelled' });
    
    // Update trip available seats if trip exists and reservation was confirmed
    if (reservation.tripid && trip && (reservation.status === 'confirmed' || reservation.status === 'checked_in')) {
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
    const { bookingid } = req.body;
    
    const reservation = await Reservation.findById(bookingid);
    if (!reservation) {
      return res.status(404).json({ 
        message: req.t('reservation.not_found') || 'Reservation not found' 
      });
    }
    
    await Reservation.update(bookingid, { status: 'checked_in' });
    
    res.json({
      message: req.t('reservation.checked_in') || 'Passenger checked in successfully',
    });
  } catch (error) {
    next(error);
  }
};

