import Driver from '../models/Driver.js';
import Line from '../models/Line.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import { RESERVATION_STATUS } from '../utils/constants.js';

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

    if (vehicleIds.length === 0) {
      return res.json([]);
    }

    const filters = {};
    if (req.query.status) {
      filters.status = req.query.status;
    }
    if (req.query.upcoming === 'true') {
      filters.fromNow = true;
    }

    const trips = await Trip.findByVehicleIds(vehicleIds, filters);

    res.json(trips);
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
    if (action === 'approve') {
      updates.driver_status = 'approved';
      if (reservation.status === RESERVATION_STATUS.PENDING || reservation.status === 'pending_driver') {
        updates.status = RESERVATION_STATUS.CONFIRMED;
      }
    } else if (action === 'reject') {
      updates.driver_status = 'rejected';
      updates.status = RESERVATION_STATUS.CANCELLED;
    } else if (action === 'checkin') {
      updates.driver_status = 'approved';
      updates.status = RESERVATION_STATUS.CHECKED_IN;
    }

    const updatedReservation = await Reservation.update(bookingid, updates);

    res.json({
      message:
        action === 'approve'
          ? req.t('reservation.driver_approved') || 'Reservation approved'
          : action === 'reject'
              ? req.t('reservation.driver_rejected') || 'Reservation rejected'
              : req.t('reservation.checked_in') || 'Passenger checked in',
      reservation: updatedReservation,
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

