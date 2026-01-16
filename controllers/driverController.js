import Driver from '../models/Driver.js';
import Line from '../models/Line.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import Rating from '../models/Rating.js';
import { v4 as uuidv4 } from 'uuid';
import { RESERVATION_STATUS, PAYMENT_STATUS, PAYMENT_METHOD } from '../utils/constants.js';
import { checkAndAssignWaitingTrips } from '../services/tripOpeningService.js';
import { syncTripStats } from '../services/matchingService.js';
import logger from '../utils/logger.js';

const buildQueueResponse = (queue = [], driverid) => {
  const normalizedQueue = queue.map((entry, index) => ({
    position: index + 1,
    queueid: entry.queueid,
    driverid: entry.driverid,
    lineid: entry.lineid,
    status: entry.status,
    joinedAt: entry.joined_at,
    direction: entry.direction,
    stationid: entry.stationid,
    driver: entry.driver,
  }));

  const currentEntry = normalizedQueue.find((item) => item.driverid === driverid) || null;

  return {
    queue: normalizedQueue,
    currentEntry,
    aheadCount: currentEntry ? currentEntry.position - 1 : normalizedQueue.length,
    behindCount: currentEntry ? normalizedQueue.length - currentEntry.position : 0,
  };
};

export const getDriverProfile = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);
    if (!driverRecord) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    const vehicles = await Vehicle.findByDriverId(driverRecord.driverid);
    const line = driverRecord.lineid ? await Line.findById(driverRecord.lineid) : null;

    res.json({
      driver: driverRecord,
      vehicles: vehicles || [],
      line: line,
      hasVehicle: vehicles && vehicles.length > 0,
      hasLine: !!driverRecord.lineid,
    });
  } catch (error) {
    next(error);
  }
};

export const getDriverQueue = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);

    if (!driverRecord?.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver does not have an assigned line',
      });
    }

    const line = await Line.findById(driverRecord.lineid);
    if (!line) {
      return res.status(404).json({
        message: req.t('line.not_found') || 'Line not found',
      });
    }

    // Get station information for the line
    const BaseStation = (await import('../models/BaseStation.js')).default;
    const mainStation = line.main_stationid ? await BaseStation.findById(line.main_stationid) : null;
    const returnStation = line.return_stationid ? await BaseStation.findById(line.return_stationid) : null;

    // Get current queue entry to determine direction
    const currentEntry = await DriverQueue.findActiveByDriver(driverRecord.driverid);
    const driverDirection = currentEntry?.direction || null;

    // Get direction from query parameter if driver is not in queue
    // If driver is in queue, always use their current direction (ignore requested direction)
    const requestedDirection = req.query.direction;
    const direction = driverDirection || requestedDirection || null;

    // Validate direction if provided
    if (direction && direction !== 'going' && direction !== 'returning') {
      return res.status(400).json({
        message: req.t('driver.invalid_direction') || 'Invalid direction. Must be "going" or "returning"',
      });
    }

    // Get queue for the specified direction
    // When driver is in queue, only show drivers in their direction
    // When driver is not in queue, show drivers in the requested direction (or both if none requested)
    let queue = [];
    if (direction) {
      // Filter by direction: either driver's current direction or requested direction
      queue = await DriverQueue.getActiveByLine(driverRecord.lineid, direction);
    } else {
      // If no direction specified and driver not in queue, return both directions for display
      const goingQueue = await DriverQueue.getActiveByLine(driverRecord.lineid, 'going');
      const returningQueue = await DriverQueue.getActiveByLine(driverRecord.lineid, 'returning');
      queue = [...goingQueue, ...returningQueue];
    }

    const response = buildQueueResponse(queue, driverRecord.driverid);

    res.json({
      line: line,
      direction: direction, // Send back the direction used for filtering
      currentDirection: driverDirection,
      mainStation: mainStation,
      returnStation: returnStation,
      ...response,
    });
  } catch (error) {
    next(error);
  }
};

export const joinDriverQueue = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);

    if (!driverRecord?.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver does not have an assigned line',
      });
    }

    // Get direction from request body (default to 'going')
    const direction = req.body.direction || 'going';
    
    // Validate direction
    if (direction !== 'going' && direction !== 'returning') {
      return res.status(400).json({
        message: req.t('driver.invalid_direction') || 'Invalid direction. Must be "going" or "returning"',
      });
    }

    // Check if location validation is enabled
    const AppConfig = (await import('../models/AppConfig.js')).default;
    const locationValidationEnabled = await AppConfig.getQueueLocationValidationEnabled();

    // Validate location if enabled
    if (locationValidationEnabled) {
      const { validateQueueJoinLocation } = await import('../services/locationValidationService.js');
      const locationValidation = await validateQueueJoinLocation(
        driverRecord.driverid,
        driverRecord.lineid,
        direction
      );

      if (!locationValidation.valid) {
        return res.status(400).json({
          message: locationValidation.error || 'Location validation failed',
          locationValidation: {
            valid: false,
            station: locationValidation.station,
            distance: locationValidation.distance,
            driverLocation: locationValidation.driverLocation,
          },
        });
      }
    }

    // Get line to determine station
    const Line = (await import('../models/Line.js')).default;
    const line = await Line.findById(driverRecord.lineid);
    
    // Determine stationid based on direction
    let stationid = null;
    if (direction === 'going') {
      stationid = line?.main_stationid || null;
    } else if (direction === 'returning') {
      stationid = line?.return_stationid || null;
    }

    // Check if driver is already in a queue (will be automatically removed by join method)
    const existing = await DriverQueue.findActiveByDriver(driverRecord.driverid);
    if (existing && existing.direction === direction && existing.lineid === driverRecord.lineid) {
      const queue = await DriverQueue.getActiveByLine(driverRecord.lineid, direction);
      const response = buildQueueResponse(queue, driverRecord.driverid);
      return res.status(200).json({
        message: req.t('driver.queue_exists') || 'Driver already in queue',
        ...response,
      });
    }

    // Join queue with direction and station
    const entry = await DriverQueue.join(driverRecord.driverid, driverRecord.lineid, direction, stationid);
    const queue = await DriverQueue.getActiveByLine(driverRecord.lineid, direction);
    const response = buildQueueResponse(queue, driverRecord.driverid);

    // Check for waiting trips and assign vehicle (event-driven assignment)
    try {
      await checkAndAssignWaitingTrips(driverRecord.lineid);
    } catch (error) {
      // Log error but don't fail the queue join operation
      console.error('[DriverController] Error checking waiting trips after queue join:', error);
    }

    res.status(201).json({
      message: req.t('driver.queue_joined') || 'Driver added to queue',
      entry,
      ...response,
    });
  } catch (error) {
    if (error.code === '23505') {
      error.message = req.t('driver.queue_exists') || 'Driver already in queue';
    }
    next(error);
  }
};

export const leaveDriverQueue = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);

    if (!driverRecord?.lineid) {
      return res.status(400).json({
        message: req.t('driver.line_missing') || 'Driver does not have an assigned line',
      });
    }

    const entry = await DriverQueue.leaveActiveByDriver(driverRecord.driverid);
    if (!entry) {
      return res.status(404).json({
        message: req.t('driver.queue_not_found') || 'Driver queue entry not found',
      });
    }

    const queue = await DriverQueue.getActiveByLine(driverRecord.lineid);
    const response = buildQueueResponse(queue, driverRecord.driverid);

    res.json({
      message: req.t('driver.queue_left') || 'Driver left the queue',
      ...response,
    });
  } catch (error) {
    next(error);
  }
};

export const getDriverTrips = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);

    const vehicles = await Vehicle.findByDriverId(driverRecord.driverid);
    const vehicleIds = vehicles.map((vehicle) => vehicle.vehicleid).filter(Boolean);

    const filters = {};
    if (req.query.status) {
      filters.status = req.query.status;
    }
    // Note: We don't filter by fromNow when upcoming=true because we want to include delayed trips
    // that have passed departure time but haven't departed yet (passengers are waiting)

    // Get trips by vehicle IDs
    const tripsByVehicle = vehicleIds.length > 0
      ? await Trip.findByVehicleIds(vehicleIds, filters)
      : [];

    // Also get trips assigned to this driver (by assigned_driverid)
    const tripsByDriver = await Trip.findAssignedTrips(driverRecord.driverid, filters);

    // Combine and deduplicate trips
    const allTrips = [...tripsByVehicle, ...tripsByDriver];
    const uniqueTrips = Array.from(
      new Map(allTrips.map(trip => [trip.tripid, trip])).values()
    );

    // Show ALL trips assigned to driver (don't filter by booking count)
    // Driver needs to see their assigned trips even if no bookings yet
    // Only filter completed/cancelled old trips without bookings
    const relevantTrips = uniqueTrips.filter(trip => {
      const totalBookings = trip.totalbookings || 0;
      const status = trip.status;

      // Always show trips with bookings
      if (totalBookings > 0) return true;

      // Show trips with no bookings ONLY if they are active (assigned to driver)
      // These are trips the driver is assigned to but haven't received bookings yet
      if (status === 'scheduled' || status === 'open' || status === 'delayed' || status === 'in_progress') {
        // Only show if this driver is explicitly assigned
        return trip.assigned_driverid === driverRecord.driverid;
      }

      // Hide completed/cancelled trips with no bookings
      return false;
    });

    // If upcoming=true, filter to include:
    // - Future trips (deptime >= now)
    // - Delayed trips (status = delayed, even if deptime passed, because passengers are waiting)
    // - In-progress trips
    // - Open/scheduled trips that have passed departure time (should be marked as delayed but include them anyway)
    if (req.query.upcoming === 'true') {
      const now = new Date().toISOString();
      const filteredTrips = relevantTrips.filter(trip => {
        // Include delayed trips (passengers are waiting)
        if (trip.status === 'delayed') return true;
        // Include in-progress trips
        if (trip.status === 'in_progress') return true;
        // Include future trips
        if (trip.deptime && trip.deptime >= now) return true;
        // Include open/scheduled trips that have passed departure time
        // These have passengers waiting even if not yet marked as delayed
        if ((trip.status === 'open' || trip.status === 'scheduled') && trip.deptime && trip.deptime < now) {
          return true;
        }
        return false;
      });
      return res.json(filteredTrips);
    }

    res.json(relevantTrips);
  } catch (error) {
    next(error);
  }
};

const ensureDriverOwnsTrip = (trip, driverid) => {
  const tripDriverId =
    trip?.vehicle?.driver?.driverid ||
    trip?.vehicle?.driverid ||
    trip?.driverid ||
    null;

  if (!tripDriverId || tripDriverId !== driverid) {
    const error = new Error('Driver not authorized for this trip');
    error.statusCode = 403;
    throw error;
  }
};

export const getDriverTripReservations = async (req, res, next) => {
  try {
    const { tripid } = req.params;
    const trip = await Trip.findById(tripid);

    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found',
      });
    }

    ensureDriverOwnsTrip(trip, req.user.driverid);

    const reservations = await Reservation.findByTripId(tripid);

    res.json({
      trip,
      reservations,
    });
  } catch (error) {
    if (error.statusCode === 403) {
      return res.status(403).json({
        message: req.t('driver.trip_forbidden') || 'Driver not authorized for this trip',
      });
    }
    next(error);
  }
};

export const updateDriverReservationStatus = async (req, res, next) => {
  try {
    const { tripid, bookingid } = req.params;
    const { action } = req.body;

    if (!['approve', 'reject', 'checkin'].includes(action)) {
      return res.status(400).json({
        message: req.t('reservation.invalid_action') || 'Invalid action',
      });
    }

    const trip = await Trip.findById(tripid);
    if (!trip) {
      return res.status(404).json({
        message: req.t('trip.not_found') || 'Trip not found',
      });
    }

    ensureDriverOwnsTrip(trip, req.user.driverid);

    const reservation = await Reservation.findById(bookingid);
    if (!reservation) {
      return res.status(404).json({
        message: req.t('reservation.not_found') || 'Reservation not found',
      });
    }

    if (reservation.tripid !== tripid) {
      return res.status(400).json({
        message: req.t('reservation.trip_mismatch') || 'Reservation does not belong to this trip',
      });
    }

    const updates = {};
    let refundAmount = null;

    // Capture the reservation status BEFORE updating it (needed for syncTripStats check after rejection)
    const reservationWasActive = reservation.status === RESERVATION_STATUS.CONFIRMED || reservation.status === RESERVATION_STATUS.CHECKED_IN;

    if (action === 'approve') {
      updates.driver_status = 'approved';
      if (reservation.status === 'pending_driver') {
        updates.status = RESERVATION_STATUS.CONFIRMED;
      }
    } else if (action === 'reject') {
      updates.driver_status = 'rejected';
      updates.status = RESERVATION_STATUS.CANCELLED;

      // Process full refund for passenger when driver rejects
      refundAmount = reservation.bookingprice || 0;
      if (refundAmount > 0 && reservation.paymentid) {
        const payment = await Payment.findById(reservation.paymentid);
        if (payment && payment.status === PAYMENT_STATUS.COMPLETED) {
          // Get passenger's userid from reservation
          const passenger = reservation.passenger;
          const passengerUserid = passenger?.user?.userid;

          // Capture driver wallet ID before potentially removing it
          const driverWalletId = payment.towalletid;

          // If payment was already transferred to driver (towalletid exists), deduct from driver's wallet
          if (driverWalletId) {
            try {
              const driverWallet = await Wallet.findById(driverWalletId);
              if (driverWallet) {
                // Deduct the refund amount from driver's wallet
                await Wallet.updateBalance(driverWalletId, refundAmount, 'subtract');
                logger.info(`[DriverController] ✅ Deducted ${refundAmount} from driver wallet ${driverWalletId} due to reservation rejection`);

                // Update payment to remove towalletid (payment reversed)
                await Payment.update(reservation.paymentid, {
                  towalletid: null,
                });
              }
            } catch (driverWalletError) {
              logger.error(`[DriverController] ❌ Error deducting from driver wallet:`, driverWalletError);
              // Continue with passenger refund even if driver wallet deduction fails
            }
          }

          if (passengerUserid) {
            const wallets = await Wallet.findByUserId(passengerUserid, 'main');
            if (wallets && wallets.length > 0) {
              // Refund full amount to passenger's wallet
              await Wallet.updateBalance(wallets[0].walletid, refundAmount, 'add');
              logger.info(`[DriverController] ✅ Refunded ${refundAmount} to passenger wallet ${wallets[0].walletid} due to reservation rejection`);

              // Create refund payment record
              // fromwalletid: Driver wallet if payment was transferred, null if not yet transferred
              // towalletid: Passenger wallet (refund destination)
              await Payment.create({
                paymentid: uuidv4(),
                amount: refundAmount,
                method: PAYMENT_METHOD.WALLET,
                status: PAYMENT_STATUS.REFUNDED,
                type: 'refund',
                fromwalletid: driverWalletId || null, // Driver wallet if payment was transferred, null if not
                towalletid: wallets[0].walletid, // Passenger wallet (refund destination)
                tripid: reservation.tripid || null,
                time: new Date().toISOString(), // Explicitly set refund time
                external_reference: 'cancelled_by_driver', // Track that driver cancelled/rejected the reservation
              });
            }
          }
        }
      }
    } else if (action === 'checkin') {
      updates.driver_status = 'approved';
      updates.status = RESERVATION_STATUS.CHECKED_IN;
    }

    const updatedReservation = await Reservation.update(bookingid, updates);

    // Sync trip stats after reservation status update
    // This ensures available seats are recalculated correctly when reservation is cancelled/rejected
    if (action === 'reject' && reservation.tripid && reservationWasActive) {
      try {
        await syncTripStats(reservation.tripid);
        logger.info(`[DriverController] ✅ Synced trip stats for trip ${reservation.tripid} after reservation rejection - seat freed up`);
      } catch (syncError) {
        logger.error(`[DriverController] ❌ Error syncing trip stats after rejection:`, syncError);
        // Don't fail the rejection if stats sync fails
      }
    }

    // Send notification to passenger when driver rejects/cancels reservation
    if (action === 'reject') {
      try {
        const { sendNotification, NOTIFICATION_TYPES } = await import('../services/notificationService.js');
        const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');
        const Passenger = (await import('../models/Passenger.js')).default;
        
        // Get passenger information
        const passenger = await Passenger.findById(reservation.passengerid);
        if (passenger?.userid) {
          // Get trip and line information
          let line = null;
          let trip = null;
          
          if (reservation.tripid) {
            trip = await Trip.findById(reservation.tripid);
            if (trip?.lineid) {
              line = await Line.findById(trip.lineid);
            }
          } else if (reservation.lineid) {
            line = await Line.findById(reservation.lineid);
          }
          
          // Get line names for passenger's language
          const { fromName, toName, language } = await getLineNamesForNotification(line, passenger.userid, req);
          
          // Format time if trip exists
          let deptime = '';
          if (trip?.deptime) {
            const { DateTime } = await import('luxon');
            const date = DateTime.fromISO(new Date(trip.deptime).toISOString());
            
            if (language === 'en') {
              deptime = date.setLocale('en').toLocaleString({ 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric', 
                hour: '2-digit', 
                minute: '2-digit',
                hour12: true
              });
            } else {
              deptime = date.setLocale('ar').toLocaleString({ 
                year: 'numeric', 
                month: 'long', 
                day: 'numeric', 
                hour: '2-digit', 
                minute: '2-digit'
              });
            }
          }
          
          // Send notification to passenger
          await sendNotification(
            passenger.userid,
            NOTIFICATION_TYPES.RESERVATION_CANCELLED,
            {
              from: fromName,
              to: toName,
              bookingid: reservation.bookingid,
              ...(deptime && { time: deptime }),
            },
            language,
            { line, trip } // Pass raw data for separate Arabic/English formatting
          );
        }
      } catch (notifError) {
        logger.warn('[DriverController] Failed to send cancellation notification to passenger:', notifError);
        // Don't fail the rejection if notification fails
      }
    }

    // Prepare response message
    let message;
    if (action === 'approve') {
      message = req.t('reservation.driver_approved') || 'Reservation approved';
    } else if (action === 'reject') {
      message = req.t('reservation.driver_rejected') || `Reservation rejected. Full refund of ${refundAmount || 0} processed.`;
    } else {
      message = req.t('reservation.checked_in') || 'Passenger checked in';
    }

    res.json({
      message,
      reservation: updatedReservation,
      ...(refundAmount !== null && { refundAmount }),
    });
  } catch (error) {
    if (error.statusCode === 403) {
      return res.status(403).json({
        message: req.t('driver.trip_forbidden') || 'Driver not authorized for this trip',
      });
    }
    next(error);
  }
};

export const getDriverStatistics = async (req, res, next) => {
  try {
    const driverRecord = await Driver.findById(req.user.driverid);
    if (!driverRecord) {
      return res.status(404).json({
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    // Get today's date range (UTC)
    const now = new Date();
    const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
    const todayEnd = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 23, 59, 59, 999));
    const todayStartISO = todayStart.toISOString();
    const todayEndISO = todayEnd.toISOString();

    // Get vehicles for this driver
    const vehicles = await Vehicle.findByDriverId(driverRecord.driverid);
    const vehicleIds = vehicles.map((vehicle) => vehicle.vehicleid).filter(Boolean);

    // Get all trips for this driver (similar to getDriverTrips)
    const tripsByVehicle = vehicleIds.length > 0
      ? await Trip.findByVehicleIds(vehicleIds)
      : [];
    const tripsByDriver = await Trip.findAssignedTrips(driverRecord.driverid);

    // Combine and deduplicate trips
    const allTrips = [...tripsByVehicle, ...tripsByDriver];
    const uniqueTrips = Array.from(
      new Map(allTrips.map(trip => [trip.tripid, trip])).values()
    );

    // Filter for today's trips
    const todayTrips = uniqueTrips.filter(trip => {
      if (!trip.deptime) return false;
      const tripDate = new Date(trip.deptime);
      return tripDate >= todayStart && tripDate <= todayEnd;
    });

    const todayTripsCount = todayTrips.length;

    // Get passenger count (confirmed/checked_in reservations for today's trips)
    const todayTripIds = todayTrips.map(trip => trip.tripid);
    let totalPassengers = 0;

    if (todayTripIds.length > 0) {
      // Get reservations for today's trips
      const allReservations = await Reservation.findAll({});
      const todayReservations = allReservations.filter(res => 
        todayTripIds.includes(res.tripid) &&
        (res.status === RESERVATION_STATUS.CONFIRMED || res.status === RESERVATION_STATUS.CHECKED_IN)
      );
      totalPassengers = todayReservations.length;
    }

    // Get driver rating (use driver.rating field, or calculate from trip_rating if null/0)
    let driverRating = driverRecord.rating || 0;
    
    // If driver rating is null or 0, calculate from trip_rating
    if (!driverRating || driverRating === 0) {
      // Get ratings for all trips
      let totalRating = 0;
      let ratingCount = 0;
      
      for (const trip of uniqueTrips) {
        const tripRating = await Rating.getAverageRating(trip.tripid);
        if (tripRating.count > 0) {
          totalRating += tripRating.average * tripRating.count;
          ratingCount += tripRating.count;
        }
      }

      if (ratingCount > 0) {
        driverRating = Math.round((totalRating / ratingCount) * 10) / 10;
      }
    }

    res.json({
      todayTrips: todayTripsCount,
      passengers: totalPassengers,
      rating: driverRating || 0,
    });
  } catch (error) {
    next(error);
  }
};

