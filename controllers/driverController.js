import Driver from '../models/Driver.js';
import Line from '../models/Line.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import { v4 as uuidv4 } from 'uuid';
import { RESERVATION_STATUS, PAYMENT_STATUS, PAYMENT_METHOD } from '../utils/constants.js';
import { checkAndAssignWaitingTrips } from '../services/tripOpeningService.js';

const buildQueueResponse = (queue = [], driverid) => {
  const normalizedQueue = queue.map((entry, index) => ({
    position: index + 1,
    queueid: entry.queueid,
    driverid: entry.driverid,
    lineid: entry.lineid,
    status: entry.status,
    joinedAt: entry.joined_at,
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

    const queue = await DriverQueue.getActiveByLine(driverRecord.lineid);
    const response = buildQueueResponse(queue, driverRecord.driverid);

    res.json({
      line: line,
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

    const existing = await DriverQueue.findActiveByDriver(driverRecord.driverid);
    if (existing) {
      const queue = await DriverQueue.getActiveByLine(existing.lineid);
      const response = buildQueueResponse(queue, driverRecord.driverid);
      return res.status(200).json({
        message: req.t('driver.queue_exists') || 'Driver already in queue',
        ...response,
      });
    }

    const entry = await DriverQueue.join(driverRecord.driverid, driverRecord.lineid);
    const queue = await DriverQueue.getActiveByLine(driverRecord.lineid);
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

    // Filter out trips with no bookings (only show trips with at least 1 booking)
    const tripsWithBookings = uniqueTrips.filter(trip => {
      const totalBookings = trip.totalbookings || 0;
      return totalBookings > 0;
    });

    // If upcoming=true, filter to include:
    // - Future trips (deptime >= now)
    // - Delayed trips (status = delayed, even if deptime passed, because passengers are waiting)
    // - In-progress trips
    // - Open/scheduled trips that have passed departure time (should be marked as delayed but include them anyway)
    if (req.query.upcoming === 'true') {
      const now = new Date().toISOString();
      const filteredTrips = tripsWithBookings.filter(trip => {
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

    res.json(tripsWithBookings);
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
          
          if (passengerUserid) {
            const wallets = await Wallet.findByUserId(passengerUserid, 'main');
            if (wallets && wallets.length > 0) {
              // Refund full amount to passenger's wallet
              await Wallet.updateBalance(wallets[0].walletid, refundAmount, 'add');

              // Create refund payment record
              await Payment.create({
                paymentid: uuidv4(),
                amount: refundAmount,
                method: PAYMENT_METHOD.WALLET,
                status: PAYMENT_STATUS.REFUNDED,
                type: 'refund',
                fromwalletid: wallets[0].walletid,
                towalletid: wallets[0].walletid,
              });
            }
          }
        }
      }

      // Free up the seat - make it available again
      if (reservation.tripid && (reservation.status === RESERVATION_STATUS.CONFIRMED || reservation.status === RESERVATION_STATUS.CHECKED_IN)) {
        // Fetch latest trip data to ensure we have current seat count
        const currentTrip = await Trip.findById(reservation.tripid);
        if (currentTrip) {
          // Get vehicle to know max seats
          const Vehicle = (await import('../models/Vehicle.js')).default;
          let maxSeats = null;
          if (currentTrip.vehicleid) {
            const vehicle = await Vehicle.findById(currentTrip.vehicleid);
            if (vehicle) {
              maxSeats = vehicle.seatnum - 1; // Exclude driver seat
            }
          }

          // Update available seats (increase by 1), but don't exceed max
          const newSeatCount = currentTrip.availableseats + 1;
          const finalSeatCount = (maxSeats !== null && newSeatCount > maxSeats) ? maxSeats : newSeatCount;
          await Trip.updateAvailableSeats(reservation.tripid, finalSeatCount);
        }
      }
    } else if (action === 'checkin') {
      updates.driver_status = 'approved';
      updates.status = RESERVATION_STATUS.CHECKED_IN;
    }

    const updatedReservation = await Reservation.update(bookingid, updates);

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

