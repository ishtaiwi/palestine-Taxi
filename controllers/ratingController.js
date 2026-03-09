import Rating from '../models/Rating.js';
import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Driver from '../models/Driver.js';
import { v4 as uuidv4 } from 'uuid';
import { RESERVATION_STATUS, TRIP_STATUS } from '../utils/constants.js';
import logger from '../utils/logger.js';

/**
 * Update driver's average rating based on all their trip ratings
 * @param {string} driverid - The driver ID
 */
const updateDriverRating = async (driverid) => {
  try {
    if (!driverid) return;

    const averageRatingResult = await Rating.getAverageRatingByDriver(driverid);
    const newRating = averageRatingResult.count > 0 ? averageRatingResult.average : null;

    await Driver.updateRating(driverid, newRating);
    logger.info(`[RatingController] ✅ Updated driver ${driverid} rating to ${newRating} (based on ${averageRatingResult.count} ratings)`);
  } catch (error) {
    logger.warn(`[RatingController] ⚠️ Error updating driver rating:`, error);
    // Don't throw - rating update failure shouldn't break rating submission
  }
};


export const submitRating = async (req, res, next) => {
  try {
    const { bookingid, rating, comment } = req.body;
    const userid = req.user.userid;
    const passengerid = req.user.passengerid || req.user.userid; // For validation


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

    // Validate that the reservation belongs to the passenger
    // Note: reservation.passengerid is the passenger table ID, we need to check ownership
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


    // Note: trip_rating.passengerid foreign key references user.userid, not passenger.passengerid
    const ratingData = {
      ratingid: uuidv4(),
      bookingid,
      passengerid: userid, // Use userid for the foreign key constraint
      tripid: reservation.tripid,
      rating: parseInt(rating),
      comment: comment?.trim() || null,
    };

    const newRating = await Rating.create(ratingData);

    // Update driver's average rating
    if (trip.assigned_driverid) {
      await updateDriverRating(trip.assigned_driverid);
    }

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
    const userid = req.user.userid; // Rating table stores userid in passengerid field


    const existingRating = await Rating.findById(ratingid);

    if (!existingRating) {
      return res.status(404).json({
        message: req.t('rating.not_found') || 'Rating not found',
      });
    }

    // Note: existingRating.passengerid contains userid (because of foreign key constraint)
    if (existingRating.passengerid !== userid) {
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

    // Update driver's average rating if rating value changed
    if (rating !== undefined) {
      const trip = await Trip.findById(updatedRating.tripid);
      if (trip && trip.assigned_driverid) {
        await updateDriverRating(trip.assigned_driverid);
      }
    }

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
    const passengerid = req.user.passengerid || req.user.userid;


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
    const userid = req.user.userid; // Rating table uses userid for passengerid field

    const ratings = await Rating.findByPassengerId(userid);

    res.json(ratings);
  } catch (error) {
    next(error);
  }
};


export const deleteRating = async (req, res, next) => {
  try {
    const { ratingid } = req.params;
    const userid = req.user.userid; // Rating table stores userid in passengerid field


    const existingRating = await Rating.findById(ratingid);

    if (!existingRating) {
      return res.status(404).json({
        message: req.t('rating.not_found') || 'Rating not found',
      });
    }

    // Note: existingRating.passengerid contains userid (because of foreign key constraint)
    if (existingRating.passengerid !== userid) {
      return res.status(403).json({
        message: req.t('rating.unauthorized') || 'You can only delete your own ratings',
      });
    }

    // Get trip info before deleting to update driver rating
    const trip = await Trip.findById(existingRating.tripid);
    const driverid = trip?.assigned_driverid;

    await Rating.delete(ratingid);

    // Update driver's average rating
    if (driverid) {
      await updateDriverRating(driverid);
    }

    res.json({
      message: req.t('rating.deleted') || 'Rating deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get pending ratings (completed trips that haven't been rated yet)
 */
export const getPendingRatings = async (req, res, next) => {
  try {
    const passengerid = req.user.passengerid || req.user.userid;

    const pendingRatings = await Rating.findPendingRatings(passengerid);

    // Get full reservation details for each pending rating
    const pendingReservations = await Promise.all(
      pendingRatings.map(async (pending) => {
        try {
          const reservation = await Reservation.findById(pending.bookingid);
          return reservation;
        } catch (error) {
          logger.warn(`[RatingController] ⚠️ Error loading reservation ${pending.bookingid}:`, error);
          return null;
        }
      })
    );

    // Filter out nulls and return
    const validReservations = pendingReservations.filter(r => r !== null);

    res.json(validReservations);
  } catch (error) {
    next(error);
  }
};

