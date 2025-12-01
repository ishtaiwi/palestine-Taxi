import Rating from '../models/Rating.js';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import { v4 as uuidv4 } from 'uuid';
import { RESERVATION_STATUS, TRIP_STATUS } from '../utils/constants.js';


export const submitRating = async (req, res, next) => {
  try {
    const { bookingid, rating, comment } = req.body;
    const passengerid = req.user.userid;

    
    if (!bookingid || !rating) {
      return res.status(400).json({
        message: req.t('rating.required_fields') || 'Booking ID and rating are required',
      });
    }

    
    if (rating < 1 || rating > 5 || !Number.isInteger(rating)) {
      return res.status(400).json({
        message: req.t('rating.invalid_range') || 'Rating must be an integer between 1 and 5',
      });
    }

    
    const reservation = await Reservation.findById(bookingid);

    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found',
      });
    }

    
    if (reservation.passengerid !== passengerid) {
      return res.status(403).json({
        message: req.t('rating.unauthorized') || 'You can only rate your own trips',
      });
    }

    
    if (!reservation.tripid) {
      return res.status(400).json({
        message: req.t('rating.no_trip') || 'This reservation is not associated with a trip yet',
      });
    }

    
    const trip = await Trip.findById(reservation.tripid);

    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found',
      });
    }

    
    if (trip.status !== TRIP_STATUS.COMPLETED) {
      return res.status(400).json({
        message: req.t('rating.trip_not_completed') || 'You can only rate completed trips',
      });
    }

    
    if (reservation.status !== RESERVATION_STATUS.CHECKED_IN && 
        reservation.status !== RESERVATION_STATUS.CONFIRMED) {
      return res.status(400).json({
        message: req.t('rating.reservation_not_completed') || 'You can only rate trips you completed',
      });
    }

    
    const existingRating = await Rating.findByBookingId(bookingid);
    if (existingRating) {
      return res.status(400).json({
        message: req.t('rating.already_exists') || 'You have already rated this trip',
      });
    }

    
    const ratingData = {
      ratingid: uuidv4(),
      bookingid,
      passengerid,
      tripid: reservation.tripid,
      rating: parseInt(rating),
      comment: comment?.trim() || null,
    };

    const newRating = await Rating.create(ratingData);

    res.status(201).json({
      message: req.t('rating.submitted') || 'Rating submitted successfully',
      rating: newRating,
    });
  } catch (error) {
    next(error);
  }
};


export const updateRating = async (req, res, next) => {
  try {
    const { ratingid } = req.params;
    const { rating, comment } = req.body;
    const passengerid = req.user.userid;

    
    const existingRating = await Rating.findById(ratingid);

    if (!existingRating) {
      return res.status(404).json({
        message: req.t('rating.not_found') || 'Rating not found',
      });
    }

    
    if (existingRating.passengerid !== passengerid) {
      return res.status(403).json({
        message: req.t('rating.unauthorized') || 'You can only update your own ratings',
      });
    }

    
    const updates = {};
    if (rating !== undefined) {
      if (rating < 1 || rating > 5 || !Number.isInteger(rating)) {
        return res.status(400).json({
          message: req.t('rating.invalid_range') || 'Rating must be an integer between 1 and 5',
        });
      }
      updates.rating = parseInt(rating);
    }
    if (comment !== undefined) {
      updates.comment = comment?.trim() || null;
    }

    
    const updatedRating = await Rating.update(ratingid, updates);

    res.json({
      message: req.t('rating.updated') || 'Rating updated successfully',
      rating: updatedRating,
    });
  } catch (error) {
    next(error);
  }
};


export const getRatingByBookingId = async (req, res, next) => {
  try {
    const { bookingid } = req.params;
    const passengerid = req.user.userid;

    
    const reservation = await Reservation.findById(bookingid);

    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found',
      });
    }

    
    if (reservation.passengerid !== passengerid) {
      return res.status(403).json({
        message: req.t('rating.unauthorized') || 'Unauthorized',
      });
    }

    
    const rating = await Rating.findByBookingId(bookingid);

    if (!rating) {
      return res.status(404).json({
        message: req.t('rating.not_found') || 'Rating not found',
      });
    }

    res.json(rating);
  } catch (error) {
    next(error);
  }
};


export const getTripRatings = async (req, res, next) => {
  try {
    const { tripid } = req.params;

    const ratings = await Rating.findByTripId(tripid);
    const averageRating = await Rating.getAverageRating(tripid);

    res.json({
      ratings,
      average: averageRating.average,
      count: averageRating.count,
    });
  } catch (error) {
    next(error);
  }
};


export const getMyRatings = async (req, res, next) => {
  try {
    const passengerid = req.user.userid;

    const ratings = await Rating.findByPassengerId(passengerid);

    res.json(ratings);
  } catch (error) {
    next(error);
  }
};


export const deleteRating = async (req, res, next) => {
  try {
    const { ratingid } = req.params;
    const passengerid = req.user.userid;

    
    const existingRating = await Rating.findById(ratingid);

    if (!existingRating) {
      return res.status(404).json({
        message: req.t('rating.not_found') || 'Rating not found',
      });
    }

    
    if (existingRating.passengerid !== passengerid) {
      return res.status(403).json({
        message: req.t('rating.unauthorized') || 'You can only delete your own ratings',
      });
    }

    await Rating.delete(ratingid);

    res.json({
      message: req.t('rating.deleted') || 'Rating deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

