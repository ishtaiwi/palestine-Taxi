import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';


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
  const { tripid, seatlocation, dropoffpoint, aging } = req.body;

  try {
    const passengerid = req.user.passengerid || req.user.userid;
    const paymentMethod = (req.body.paymentmethod || 'wallet').toLowerCase();
    
    
    trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({ 
        message: req.t('trip.not_found') || 'Trip not found' 
      });
    }
    
    
    if (trip.availableseats <= 0) {
      return res.status(400).json({ 
        message: req.t('reservation.no_seats') || 'No available seats' 
      });
    }
    
    
    if (seatlocation) {
      const existingReservation = await Reservation.getBySeatLocation(tripid, seatlocation);
      if (existingReservation.length > 0) {
        return res.status(400).json({ 
          message: req.t('reservation.seat_taken') || 'Seat already taken' 
        });
      }
    }
    
    
    const line = trip.line;
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
      tripid,
      seatlocation: seatlocation || null,
      bookingprice: bookingPrice,
      dropoffpoint: dropoffpoint || null,
      aging: aging || null,
      status: reservationStatus,
      driver_status: 'pending',
    };
    
    const reservation = await Reservation.create(reservationData);
    
    
    await Trip.updateAvailableSeats(tripid, trip.availableseats - 1);
    seatsUpdated = true;
    await Trip.incrementBookings(tripid);
    bookingsIncremented = true;
    
    
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
    
    
    const trip = await Trip.findById(reservation.tripid);
    const now = new Date();
    const deptime = new Date(trip.deptime);
    const hoursUntilDeparture = (deptime - now) / (1000 * 60 * 60);
    
    let refundAmount = 0;
    if (hoursUntilDeparture > 2) {
      
      refundAmount = reservation.bookingprice;
    } else if (hoursUntilDeparture > 1) {
      
      refundAmount = reservation.bookingprice * 0.5;
    }
    
    
    if (refundAmount > 0 && reservation.paymentid) {
      const payment = await Payment.findById(reservation.paymentid);
      if (payment && payment.status === 'completed') {
        const wallets = await Wallet.findByUserId(req.user.userid, 'main');
        if (wallets.length > 0) {
          await Wallet.updateBalance(wallets[0].walletid, refundAmount, 'add');
        }
      }
    }
    
    
    await Reservation.update(bookingid, { status: 'cancelled' });
    
    
    await Trip.updateAvailableSeats(reservation.tripid, trip.availableseats + 1);
    
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

