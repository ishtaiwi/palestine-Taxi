import Reservation from '../models/Reservation.js';
import Trip from '../models/Trip.js';
import Payment from '../models/Payment.js';
import Wallet from '../models/Wallet.js';
import DriverQueue from '../models/DriverQueue.js';
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';
import { BOOKING_TYPE, PAYMENT_STATUS, PAYMENT_METHOD, RESERVATION_STATUS, TRIP_STATUS } from '../utils/constants.js';
import { validateReservationData } from '../utils/validation.js';
import { syncTripStats } from '../services/matchingService.js';
import { updateModelIncremental } from '../services/rushHourPredictionService.js';
import { assignVehicleFromQueue } from '../services/tripOpeningService.js';
import logger from '../utils/logger.js';
import { canBookInstant } from '../utils/timeUtils.js';


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
  let { tripid, seatlocation, dropoffpoint, aging, booking_type, scheduled_trip_time } = req.body;

  try {
    const passengerid = req.user.passengerid || req.user.userid;
    const paymentMethod = PAYMENT_METHOD.WALLET;


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

    // Check for duplicate reservations - prevent passenger from booking same trip multiple times
    const existingReservations = await Reservation.findByPassengerId(passengerid);
    const activeStatuses = [RESERVATION_STATUS.CONFIRMED, RESERVATION_STATUS.CHECKED_IN];

    if (bookingType === BOOKING_TYPE.INSTANT && tripid) {
      // Check if passenger already has an active reservation for this trip
      const duplicateReservation = existingReservations.find(
        r => r.tripid === tripid && activeStatuses.includes(r.status)
      );

      if (duplicateReservation) {
        return res.status(400).json({
          message: req.t('reservation.duplicate_booking') || 'Cannot make reservation: You already have an active reservation for this trip. Please cancel your existing reservation first or wait for it to complete.',
        });
      }
    }

    if (bookingType === BOOKING_TYPE.FUTURE && scheduled_trip_time) {
      // Normalize scheduled_trip_time for comparison
      const scheduledTime = new Date(scheduled_trip_time);
      if (!Number.isNaN(scheduledTime.getTime())) {
        const scheduledTimeISO = scheduledTime.toISOString();

        // Check if passenger already has an active reservation for this scheduled time
        const duplicateReservation = existingReservations.find(
          r => r.booking_type === BOOKING_TYPE.FUTURE &&
            activeStatuses.includes(r.status) &&
            r.scheduled_trip_time && (
              r.scheduled_trip_time === scheduled_trip_time ||
              (new Date(r.scheduled_trip_time).toISOString() === scheduledTimeISO)
            )
        );

        if (duplicateReservation) {
          return res.status(400).json({
            message: req.t('reservation.duplicate_booking') || 'Cannot make reservation: You already have an active reservation for this trip time. Please cancel your existing reservation first or wait for it to complete.',
          });
        }
      }

      // Also check if tripid is provided and passenger already has a reservation for that trip
      if (tripid) {
        const duplicateTripReservation = existingReservations.find(
          r => r.tripid === tripid && activeStatuses.includes(r.status)
        );

        if (duplicateTripReservation) {
          return res.status(400).json({
            message: req.t('reservation.duplicate_booking') || 'Cannot make reservation: You already have an active reservation for this trip. Please cancel your existing reservation first or wait for it to complete.',
          });
        }
      }
    }


    if (bookingType === BOOKING_TYPE.FUTURE) {
      if (!scheduled_trip_time) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_required') || 'scheduled_trip_time is required for future bookings',
        });
      }

      // Parse scheduled_trip_time as UTC
      const scheduledTime = new Date(scheduled_trip_time);
      if (Number.isNaN(scheduledTime.getTime())) {
        return res.status(400).json({
          message: req.t('reservation.invalid_scheduled_trip_time') || 'Invalid scheduled_trip_time format',
        });
      }

      const now = new Date(); // UTC now
      if (scheduledTime.getTime() <= now.getTime()) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_future') || 'scheduled_trip_time must be in the future',
        });
      }
    }


    if (bookingType === BOOKING_TYPE.INSTANT && !tripid) {
      return res.status(400).json({
        message: req.t('reservation.tripid_required') || 'tripid is required for instant bookings',
      });
    }

    if (bookingType === BOOKING_TYPE.FUTURE && !tripid && !req.body.lineid) {
      return res.status(400).json({
        message: req.t('reservation.lineid_required') || 'lineid is required for future bookings without tripid',
      });
    }

    if (tripid) {
      trip = await Trip.findById(tripid);
      if (!trip) {
        return res.status(404).json({
          message: req.t('trip.not_found') || 'Trip not found'
        });
      }
    }

    // CRITICAL RULE: Check driver queue availability for instant bookings
    // Passengers are not allowed to make an instant booking unless there are drivers available in the queue
    if (bookingType === BOOKING_TYPE.INSTANT && trip) {
      // Check if trip already has a driver/vehicle assigned
      const tripHasDriver = trip.vehicleid && trip.assigned_driverid;

      if (!tripHasDriver) {
        // Trip has no driver assigned - check if there are drivers in the queue
        const queueCheck = await DriverQueue.canAcceptInstantBooking(trip.lineid);

        if (!queueCheck.allowed) {
          return res.status(503).json({
            message: req.t('reservation.no_drivers_available') || 'Instant booking is currently unavailable. No drivers are available in the queue. Please try again later or book a future trip.',
            code: 'NO_DRIVERS_AVAILABLE',
            driversAvailable: 0,
          });
        }
      }
    }

    if (trip) {
      const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.OPEN, TRIP_STATUS.DELAYED];
      if (!validStatuses.includes(trip.status)) {
        return res.status(400).json({
          message: req.t('reservation.trip_unavailable') || `Trip is ${trip.status} and cannot accept bookings`
        });
      }

      const departedStatuses = [TRIP_STATUS.IN_PROGRESS, TRIP_STATUS.COMPLETED];
      if (departedStatuses.includes(trip.status)) {
        return res.status(400).json({
          message: req.t('reservation.trip_departed') || 'Trip has already departed'
        });
      }
    }

    if (bookingType === BOOKING_TYPE.INSTANT) {
      if (!trip) {
        return res.status(400).json({
          message: req.t('reservation.tripid_required') || 'tripid is required for instant bookings',
        });
      }

      // Use UTC-based canBookInstant utility to check if trip is open for instant bookings
      if (!canBookInstant(trip)) {
        return res.status(400).json({
          message: req.t('reservation.trip_not_open') || 'Trip is not yet open for instant bookings'
        });
      }

      // REMOVED: Early check for available seats - we'll check after booking creation
      // This allows us to create a new trip if the current trip is full
      // The check will happen after booking creation in the full trip handling logic
      // if (trip.availableseats <= 0) {
      //   return res.status(400).json({
      //     message: req.t('reservation.no_seats') || 'No available seats'
      //   });
      // }
    }

    if (bookingType === BOOKING_TYPE.FUTURE) {
      if (!scheduled_trip_time) {
        return res.status(400).json({
          message: req.t('reservation.scheduled_trip_time_required') || 'scheduled_trip_time is required for future bookings',
        });
      }

      // Parse scheduled_trip_time as UTC
      const scheduledTime = new Date(scheduled_trip_time);
      if (Number.isNaN(scheduledTime.getTime())) {
        return res.status(400).json({
          message: req.t('reservation.invalid_scheduled_trip_time') || 'Invalid scheduled_trip_time format',
        });
      }

      if (trip && trip.deptime) {
        const tripDeptime = new Date(trip.deptime);
        // Compare UTC times
        if (tripDeptime.getTime() !== scheduledTime.getTime()) {
          return res.status(400).json({
            message: req.t('reservation.scheduled_trip_time_mismatch') || 'scheduled_trip_time must match trip departure time',
          });
        }
      }
    }


    if (seatlocation && tripid && bookingType === BOOKING_TYPE.INSTANT) {
      const existingReservation = await Reservation.getBySeatLocation(tripid, seatlocation);
      if (existingReservation.length > 0) {
        return res.status(400).json({
          message: req.t('reservation.seat_taken') || 'Seat already taken'
        });
      }
    }


    let line = null;
    const Line = (await import('../models/Line.js')).default;

    if (trip) {
      if (trip.line) {
        line = trip.line;
      } else {
        line = await Line.findById(trip.lineid);
        if (!line) {
          return res.status(404).json({
            message: req.t('line.not_found') || 'Line not found',
          });
        }
      }

      if (req.body.lineid && trip.lineid && req.body.lineid !== trip.lineid) {
        return res.status(400).json({
          message: req.t('reservation.lineid_mismatch') || 'Provided lineid does not match the trip\'s lineid',
        });
      }
    } else {
      if (!req.body.lineid) {
        return res.status(400).json({
          message: req.t('reservation.lineid_required') || 'lineid is required for future bookings without tripid',
        });
      }
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
      status: PAYMENT_STATUS.PENDING,
      type: 'reservation',
      tripid: tripid || null,
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
          message: req.t('payment.insufficient_balance') || 'Insufficient balance',
          insufficientAmount: bookingPrice - (wallet.balance || 0),
          currentBalance: wallet.balance || 0,
          requiredAmount: bookingPrice,
        });
      }

      await Wallet.updateBalance(wallet.walletid, bookingPrice, 'subtract');
      walletUsed = wallet.walletid;
      walletChargeAmount = bookingPrice;

      await Payment.update(paymentRecord.paymentid, {
        status: PAYMENT_STATUS.COMPLETED,
        fromwalletid: wallet.walletid,
      });
    }


    const reservationStatus = RESERVATION_STATUS.CONFIRMED;

    const reservationData = {
      bookingid: uuidv4(),
      passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: tripid || null,
      lineid: line.lineid,
      seatlocation: seatlocation || null,
      bookingprice: bookingPrice,
      dropoffpoint: dropoffpoint || null,
      aging: aging || null,
      status: reservationStatus,
      driver_status: 'approved',
      booking_type: bookingType,
      scheduled_trip_time: bookingType === BOOKING_TYPE.FUTURE ? scheduled_trip_time : null,
    };

    const reservation = await Reservation.create(reservationData);

    // For future bookings without tripid, try to find an existing trip at the scheduled time
    if (bookingType === BOOKING_TYPE.FUTURE && !reservation.tripid && scheduled_trip_time && line) {
      try {
        const { findTripsAtSameTime } = await import('../services/matchingService.js');
        const tripsAtScheduledTime = await findTripsAtSameTime(scheduled_trip_time, line.lineid);

        // Find a trip that has capacity and is in a valid status
        const Vehicle = (await import('../models/Vehicle.js')).default;
        const { getAvailableSeats } = await import('../services/matchingService.js');

        let assignedTrip = null;
        for (const candidateTrip of tripsAtScheduledTime) {
          // Check if trip is in a valid status
          const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.OPEN, TRIP_STATUS.DELAYED];
          if (!validStatuses.includes(candidateTrip.status)) {
            continue;
          }

          // Check if trip has capacity
          if (candidateTrip.vehicleid) {
            const vehicle = await Vehicle.findById(candidateTrip.vehicleid);
            if (vehicle) {
              const availableSeats = await getAvailableSeats(vehicle, candidateTrip.tripid);
              if (availableSeats > 0) {
                assignedTrip = candidateTrip;
                break;
              }
            }
          } else {
            // Trip has no vehicle yet, but we can still assign the booking to it
            // The driver will be assigned later when the trip opens
            assignedTrip = candidateTrip;
            break;
          }
        }

        if (assignedTrip) {
          await Reservation.update(reservation.bookingid, {
            tripid: assignedTrip.tripid,
          });
          reservation.tripid = assignedTrip.tripid;
          tripid = assignedTrip.tripid;
          // Update trip variable to the assigned trip
          trip = await Trip.findById(assignedTrip.tripid);
          logger.info(`[ReservationController] ✅ Assigned future booking ${reservation.bookingid} to existing trip ${assignedTrip.tripid}`);
        }
      } catch (error) {
        logger.warn(`[ReservationController] ⚠️ Error finding existing trip for future booking:`, error);
        // Don't fail the reservation creation if this fails
      }
    }

    // Set payment.tripid to link payment to trip (for both instant and future bookings)
    // This allows payment transfer when driver gets assigned
    if (reservation.tripid) {
      try {
        await Payment.update(paymentRecord.paymentid, {
          tripid: reservation.tripid,
        });
        logger.info(`[ReservationController] ✅ Linked payment ${paymentRecord.paymentid} to trip ${reservation.tripid}`);
      } catch (error) {
        logger.warn(`[ReservationController] ⚠️ Failed to set payment.tripid:`, error);
        // Don't fail the reservation creation if this fails
      }
    }

    // Update trip stats for ANY booking that has a tripid assigned
    // This includes both instant bookings (always have tripid) and future bookings (may have tripid)
    if (tripid) {
      // For instant bookings, validate seat availability before syncing
      // We need to check BEFORE the sync since the reservation is already created
      let currentTrip = await Trip.findById(tripid);
      if (!currentTrip) {
        throw new Error('Trip not found when updating seats');
      }

      // Count actual reservations for this trip (including the one we just created)
      const tripReservations = await Reservation.findByTripId(tripid);
      const activeReservationCount = tripReservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      ).length;

      // Get vehicle to determine max seats for THIS trip
      let maxPassengerSeats = 4; // Default fallback
      if (currentTrip.vehicleid) {
        const Vehicle = (await import('../models/Vehicle.js')).default;
        const vehicle = await Vehicle.findById(currentTrip.vehicleid);
        if (vehicle) {
          maxPassengerSeats = vehicle.seatnum - 1; // Exclude driver seat
        }
      }

      // For instant bookings, check if THIS trip is full
      // If full, check for other trips at the same time with capacity, or if additional drivers can be assigned
      // CRITICAL: activeReservationCount includes the booking we just created, so if it's > maxPassengerSeats, the trip is now full
      if (bookingType === BOOKING_TYPE.INSTANT && activeReservationCount > maxPassengerSeats) {
        logger.info(`[ReservationController] 🚨 Trip ${tripid} is FULL (${activeReservationCount} bookings > ${maxPassengerSeats} capacity) - new booking ${reservation.bookingid} made it full, checking for other trips or creating new trip`);

        // Check for other trips at the same time with capacity
        const { findTripsAtSameTime, getAvailableSeats } = await import('../services/matchingService.js');
        const Vehicle = (await import('../models/Vehicle.js')).default;

        const tripsAtSameTime = await findTripsAtSameTime(currentTrip.deptime, currentTrip.lineid);
        const otherTripsWithCapacity = tripsAtSameTime.filter(t =>
          t.tripid !== tripid &&
          t.vehicleid &&
          t.assigned_driverid &&
          (t.status === 'scheduled' || t.status === 'open' || t.status === 'delayed')
        );

        // Find a trip with available capacity
        let targetTripForBooking = null;
        for (const otherTrip of otherTripsWithCapacity) {
          const vehicle = await Vehicle.findById(otherTrip.vehicleid);
          if (vehicle) {
            const availableSeats = await getAvailableSeats(vehicle, otherTrip.tripid);
            if (availableSeats > 0) {
              targetTripForBooking = otherTrip;
              logger.info(`[ReservationController] Found alternative trip ${otherTrip.tripid} with ${availableSeats} available seats`);
              break;
            }
          }
        }

        // If found alternative trip, reassign booking to it
        if (targetTripForBooking) {
          const originalTripId = tripid;
          await Reservation.update(reservation.bookingid, {
            tripid: targetTripForBooking.tripid,
          });
          logger.info(`[ReservationController] ✅ Reassigned booking ${reservation.bookingid} from full trip ${originalTripId} to alternative trip ${targetTripForBooking.tripid}`);

          // Update payment.tripid to match the new trip
          try {
            await Payment.update(paymentRecord.paymentid, {
              tripid: targetTripForBooking.tripid,
            });
            logger.info(`[ReservationController] ✅ Updated payment ${paymentRecord.paymentid} tripid to ${targetTripForBooking.tripid}`);
          } catch (error) {
            logger.warn(`[ReservationController] ⚠️ Failed to update payment.tripid after reassignment:`, error);
          }

          // Update reservation object with new tripid for the rest of the function
          reservation.tripid = targetTripForBooking.tripid;
          // Update tripid variable to use the alternative trip for rest of processing
          tripid = targetTripForBooking.tripid;

          // Refresh currentTrip to the alternative trip
          currentTrip = await Trip.findById(tripid);

          logger.info(`[ReservationController] 📝 Using alternative trip ${tripid} for rest of booking processing`);
        } else {
          // No alternative trip found - check if additional drivers can be assigned
          logger.info(`[ReservationController] No alternative trips found, checking queue for drivers...`);
          const queueCheck = await DriverQueue.canAcceptInstantBooking(currentTrip.lineid);
          logger.info(`[ReservationController] Queue check result: allowed=${queueCheck.allowed}, driversAvailable=${queueCheck.driversAvailable}`);

          if (queueCheck.allowed && queueCheck.driversAvailable > 0) {
            // Allow booking - immediately create new trip with next driver and assign booking to it
            logger.info(`[ReservationController] 🚨 Trip ${tripid} is full (${activeReservationCount} bookings > ${maxPassengerSeats} capacity), but ${queueCheck.driversAvailable} driver(s) available in queue - creating new trip and assigning booking ${reservation.bookingid}`);

            // Use the direct function to immediately create a new trip and assign the booking
            const { createNewTripForFullTripBooking } = await import('../services/matchingService.js');
            logger.info(`[ReservationController] Calling createNewTripForFullTripBooking with fullTripId=${tripid}, bookingId=${reservation.bookingid}`);
            const newTrip = await createNewTripForFullTripBooking(tripid, reservation.bookingid);

            if (newTrip) {
              logger.info(`[ReservationController] ✅ SUCCESS: Created new trip ${newTrip.tripid} and assigned booking ${reservation.bookingid} to it`);

              // IMPORTANT: Sync stats for the ORIGINAL full trip to remove this booking from its count
              const originalFullTripId = tripid;
              const { syncTripStats } = await import('../services/matchingService.js');
              await syncTripStats(originalFullTripId);
              logger.info(`[ReservationController] ✅ Synced stats for original full trip ${originalFullTripId} (removed booking ${reservation.bookingid} from count)`);

              // Update payment.tripid to match the new trip
              try {
                await Payment.update(paymentRecord.paymentid, {
                  tripid: newTrip.tripid,
                });
                logger.info(`[ReservationController] ✅ Updated payment ${paymentRecord.paymentid} tripid to ${newTrip.tripid}`);
              } catch (error) {
                logger.warn(`[ReservationController] ⚠️ Failed to update payment.tripid after new trip creation:`, error);
              }

              // Update reservation and tripid for rest of processing
              reservation.tripid = newTrip.tripid;
              tripid = newTrip.tripid;
              currentTrip = await Trip.findById(tripid);

              // Sync stats for the new trip (booking is already assigned, this just updates the count)
              await syncTripStats(tripid);
              logger.info(`[ReservationController] ✅ Synced stats for new trip ${tripid}`);

              // Mark that we've already handled this booking - skip the distribution logic below
              seatsUpdated = true;
              bookingsIncremented = true;

              // IMPORTANT: Skip the rest of the distribution logic since booking is already assigned to new trip
              // The new trip already has a driver assigned, so we don't need to run distribution
              logger.info(`[ReservationController] ⏭️ Skipping distribution logic - booking already assigned to new trip with driver`);
            } else {
              logger.error(`[ReservationController] ❌ FAILED: createNewTripForFullTripBooking returned null for booking ${reservation.bookingid}`);
              // Failed to create new trip - try the old method as fallback
              logger.warn(`[ReservationController] ⚠️ Direct trip creation failed, trying fallback method`);
              const { checkAndAssignAdditionalDrivers } = await import('../services/matchingService.js');
              const additionalDriversResult = await checkAndAssignAdditionalDrivers(tripid);

              if (additionalDriversResult.assigned > 0 && additionalDriversResult.success) {
                // Find the newly created trip and reassign booking
                const { findTripsAtSameTime, getAvailableSeats } = await import('../services/matchingService.js');
                const Vehicle = (await import('../models/Vehicle.js')).default;

                let targetTripForReassignment = null;
                for (let attempt = 0; attempt < 3; attempt++) {
                  const tripsAtSameTime = await findTripsAtSameTime(currentTrip.deptime, currentTrip.lineid);
                  const tripsWithCapacity = tripsAtSameTime.filter(t =>
                    t.tripid !== tripid &&
                    t.vehicleid &&
                    t.assigned_driverid &&
                    (t.status === 'scheduled' || t.status === 'open' || t.status === 'delayed')
                  );

                  for (const otherTrip of tripsWithCapacity) {
                    const vehicle = await Vehicle.findById(otherTrip.vehicleid);
                    if (vehicle) {
                      const availableSeats = await getAvailableSeats(vehicle, otherTrip.tripid);
                      if (availableSeats > 0) {
                        targetTripForReassignment = otherTrip;
                        break;
                      }
                    }
                  }

                  if (targetTripForReassignment) break;
                  if (attempt < 2) {
                    await new Promise(resolve => setTimeout(resolve, 100));
                  }
                }

                if (targetTripForReassignment) {
                  await Reservation.update(reservation.bookingid, {
                    tripid: targetTripForReassignment.tripid,
                  });

                  // Update payment.tripid to match the new trip
                  try {
                    await Payment.update(paymentRecord.paymentid, {
                      tripid: targetTripForReassignment.tripid,
                    });
                    logger.info(`[ReservationController] ✅ Updated payment ${paymentRecord.paymentid} tripid to ${targetTripForReassignment.tripid}`);
                  } catch (error) {
                    logger.warn(`[ReservationController] ⚠️ Failed to update payment.tripid after reassignment:`, error);
                  }

                  reservation.tripid = targetTripForReassignment.tripid;
                  tripid = targetTripForReassignment.tripid;
                  currentTrip = await Trip.findById(tripid);
                  const { syncTripStats } = await import('../services/matchingService.js');
                  await syncTripStats(tripid);
                } else {
                  logger.error(`[ReservationController] ❌ Could not find trip with capacity for reassignment - rejecting booking`);
                  await Reservation.delete(reservation.bookingid);
                  if (walletUsed && walletChargeAmount > 0) {
                    await Wallet.updateBalance(walletUsed, walletChargeAmount, 'add').catch(() => { });
                  }
                  if (paymentRecord) {
                    await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED }).catch(() => { });
                  }
                  return res.status(400).json({
                    message: req.t('reservation.no_seats') || 'No available seats - unable to assign to new trip',
                  });
                }
              } else {
                // No drivers were assigned - reject booking
                logger.warn(`[ReservationController] ⚠️ Could not assign additional drivers - rejecting booking`);
                await Reservation.delete(reservation.bookingid);
                if (walletUsed && walletChargeAmount > 0) {
                  await Wallet.updateBalance(walletUsed, walletChargeAmount, 'add').catch(() => { });
                }
                if (paymentRecord) {
                  await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED }).catch(() => { });
                }
                return res.status(400).json({
                  message: req.t('reservation.no_seats') || 'No available seats on this trip and no drivers available in queue',
                });
              }
            }
          } else {
            // No capacity anywhere - reject booking
            logger.warn(`[ReservationController] Trip ${tripid} is full and no alternative trips or drivers available - rejecting booking`);
            await Reservation.delete(reservation.bookingid);
            if (walletUsed && walletChargeAmount > 0) {
              await Wallet.updateBalance(walletUsed, walletChargeAmount, 'add').catch(() => { });
            }
            if (paymentRecord) {
              await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED }).catch(() => { });
            }
            return res.status(400).json({
              message: req.t('reservation.no_seats') || 'No available seats on this trip or alternative trips',
            });
          }
        }
      }

      // Sync trip stats based on actual reservation count (ensures accuracy)
      // This will sync the correct trip (original or alternative if reassigned)
      const { syncTripStats } = await import('../services/matchingService.js');
      await syncTripStats(tripid);
      seatsUpdated = true;
      bookingsIncremented = true;

      // Ensure payment.tripid is set to the final tripid (in case trip was reassigned)
      // This is critical for payment transfer to work correctly
      if (reservation.tripid && reservation.tripid === tripid) {
        try {
          // Double-check payment.tripid is set correctly (in case it wasn't set earlier or trip was reassigned)
          const currentPayment = await Payment.findById(paymentRecord.paymentid);
          if (currentPayment && currentPayment.tripid !== tripid) {
            await Payment.update(paymentRecord.paymentid, {
              tripid: tripid,
            });
            logger.info(`[ReservationController] ✅ Updated payment ${paymentRecord.paymentid} tripid to ${tripid} (after trip sync)`);
          }
        } catch (error) {
          logger.warn(`[ReservationController] ⚠️ Failed to verify/update payment.tripid after sync:`, error);
        }
      }

      // IMMEDIATE DRIVER ASSIGNMENT: If trip has no driver and there's a driver in queue, assign immediately
      // BUT: Skip if booking was already moved to a new trip (which already has a driver)
      const currentTripAfterSync = await Trip.findById(tripid);
      if (currentTripAfterSync && currentTripAfterSync.lineid) {
        // If trip already has a driver, transfer payment immediately
        if (currentTripAfterSync.assigned_driverid && currentTripAfterSync.vehicleid) {
          logger.info(`[ReservationController] 💰 Trip ${tripid} already has driver ${currentTripAfterSync.assigned_driverid} - transferring payment immediately`);
          try {
            // Transfer the specific payment for this reservation
            const { transferPaymentToDriver } = await import('../services/paymentService.js');
            const transferResult = await transferPaymentToDriver(paymentRecord.paymentid, currentTripAfterSync.assigned_driverid);
            if (transferResult.success) {
              logger.info(`[ReservationController] ✅ Transferred payment ${paymentRecord.paymentid} (${transferResult.amount || paymentRecord.amount}) to driver ${currentTripAfterSync.assigned_driverid} for trip ${tripid}`);
            } else {
              logger.warn(`[ReservationController] ⚠️ Payment transfer failed for payment ${paymentRecord.paymentid}: ${transferResult.error}`);
              // Also try the batch transfer method as fallback
              const { transferPaymentsForTrip } = await import('../services/paymentService.js');
              const batchResult = await transferPaymentsForTrip(tripid, currentTripAfterSync.assigned_driverid);
              if (batchResult.success) {
                logger.info(`[ReservationController] ✅ Batch transfer succeeded: ${batchResult.transferred} payment(s) transferred`);
              }
            }
          } catch (paymentError) {
            logger.error(`[ReservationController] ❌ Error transferring payments for trip ${tripid}:`, paymentError);
            // Don't fail the reservation creation if payment transfer fails
          }
        } else {
          try {
            // Step 1: Assign first driver if trip has no driver
            logger.info(`[ReservationController] 🔍 Checking for available driver in queue for trip ${tripid} (immediate assignment)`);
            const assignmentResult = await assignVehicleFromQueue(tripid, currentTripAfterSync.lineid);

            if (assignmentResult && assignmentResult.success) {
              logger.info(`[ReservationController] ✅ Driver ${assignmentResult.driverid} immediately assigned to trip ${tripid} after booking creation`);

              // Refresh trip after assignment
              const tripAfterAssignment = await Trip.findById(tripid);

              // Step 2: Distribute all bookings for this trip (this ensures the booking is assigned to the correct driver)
              const { distributeAllBookings } = await import('../services/matchingService.js');
              try {
                await distributeAllBookings(tripid);
                logger.info(`[ReservationController] ✅ Distributed bookings for trip ${tripid} after driver assignment`);
              } catch (distError) {
                logger.warn(`[ReservationController] ⚠️ Error distributing bookings after driver assignment:`, distError);
                // Don't fail the reservation creation if distribution fails
              }

              // Step 3: Check if we need additional drivers due to capacity (only after distribution)
              // CRITICAL: Only check if trip is full AND there are bookings that exceed capacity
              // Don't create new trips if trip is full but all bookings fit
              const refreshedTripAfterDist = await Trip.findById(tripid);
              if (refreshedTripAfterDist && refreshedTripAfterDist.vehicleid && refreshedTripAfterDist.assigned_driverid) {
                const Vehicle = (await import('../models/Vehicle.js')).default;
                const { getAvailableSeats } = await import('../services/matchingService.js');
                const vehicle = await Vehicle.findById(refreshedTripAfterDist.vehicleid);

                if (vehicle) {
                  const availableSeats = await getAvailableSeats(vehicle, tripid);

                  // Only check for additional drivers if trip is actually full (no available seats)
                  // AND there are bookings that exceed capacity (this booking just made it full)
                  if (availableSeats <= 0) {
                    logger.info(`[ReservationController] Trip ${tripid} is full after new booking - checking if additional drivers needed`);
                    const { checkAndAssignAdditionalDrivers } = await import('../services/matchingService.js');
                    const additionalDriversResult = await checkAndAssignAdditionalDrivers(tripid);

                    if (additionalDriversResult.assigned > 0) {
                      logger.info(`[ReservationController] ✅ Assigned ${additionalDriversResult.assigned} additional drivers to trip ${tripid} due to capacity`);

                      // Redistribute bookings across all drivers if additional drivers were assigned
                      try {
                        await distributeAllBookings(tripid);
                        logger.info(`[ReservationController] ✅ Redistributed bookings after additional driver assignment`);
                      } catch (distError) {
                        logger.warn(`[ReservationController] ⚠️ Error redistributing bookings after additional driver assignment:`, distError);
                      }
                    }
                  }
                }
              }
            } else {
              logger.info(`[ReservationController] ℹ️ No driver available in queue for immediate assignment to trip ${tripid}`);
            }
          } catch (assignError) {
            logger.error(`[ReservationController] ❌ Error assigning driver immediately after booking:`, assignError);
            // Don't fail the reservation creation if driver assignment fails
            // The driver will be assigned later when trip opens or driver joins queue
          }
        }
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

    // Send notification to passenger
    try {
      const { sendNotification, NOTIFICATION_TYPES } = await import('../services/notificationService.js');
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');
      const Line = (await import('../models/Line.js')).default;
      
      // Ensure we have a complete line object with all fields (including name_en)
      // Fetch fresh if we don't have lineid or if trip.line might be incomplete
      let line = null;
      const lineid = trip?.lineid || req.body.lineid;
      if (lineid) {
        line = await Line.findById(lineid);
      } else if (trip?.line) {
        // Use trip.line if no lineid available, but it might be incomplete
        line = trip.line;
      }
      
      // Get line names using user's language preference (pass req for Accept-Language fallback)
      const { fromName, toName, language } = await getLineNamesForNotification(line, req.user.userid, req);
      
      // Format time based on language using Luxon for reliable locale formatting
      let deptime = '';
      if (trip?.deptime || scheduled_trip_time) {
        const { DateTime } = await import('luxon');
        const timeToFormat = trip?.deptime || scheduled_trip_time;
        const date = DateTime.fromISO(new Date(timeToFormat).toISOString());
        
        if (language === 'en') {
          // Full English format: "January 12, 2026 at 07:00 PM"
          deptime = date.setLocale('en').toLocaleString({ 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: true
          });
        } else {
          // Arabic format
          deptime = date.setLocale('ar').toLocaleString({ 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit'
          });
        }
      }

      await sendNotification(
        req.user.userid,
        NOTIFICATION_TYPES.RESERVATION_CONFIRMED,
        {
          from: fromName,
          to: toName,
          time: deptime,
          bookingid: reservation.bookingid,
          tripid: reservation.tripid || '',
        },
        language,
        { line, trip } // Pass raw data for separate Arabic/English formatting
      );
    } catch (notifError) {
      logger.warn('[ReservationController] Failed to send reservation confirmation notification:', notifError);
      // Don't fail the request if notification fails
    }

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
    // If stats were updated and there was an error, re-sync to correct state
    // The reservation might have been deleted already, so syncTripStats will recalculate correctly
    if ((seatsUpdated || bookingsIncremented) && req.body.tripid) {
      await syncTripStats(req.body.tripid).catch(() => { });
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
            method: PAYMENT_METHOD.WALLET,
            status: PAYMENT_STATUS.REFUNDED,
            type: 'refund',
            fromwalletid: wallets[0].walletid,
            towalletid: wallets[0].walletid,
          });
        }
      }
    }


    await Reservation.update(bookingid, { status: RESERVATION_STATUS.CANCELLED });


    // Sync trip stats after cancellation - this will recalculate based on actual active reservations
    if (reservation.tripid && (reservation.status === RESERVATION_STATUS.CONFIRMED || reservation.status === RESERVATION_STATUS.CHECKED_IN)) {
      await syncTripStats(reservation.tripid);
    }

    // Send notification to passenger about cancellation
    try {
      const { sendNotification, NOTIFICATION_TYPES } = await import('../services/notificationService.js');
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');
      const Line = (await import('../models/Line.js')).default;
      const trip = reservation.tripid ? await Trip.findById(reservation.tripid) : null;
      
      // Ensure we have a complete line object with all fields (including name_en)
      let line = null;
      const lineid = trip?.lineid || reservation.lineid;
      if (lineid) {
        line = await Line.findById(lineid);
      } else if (trip?.line) {
        line = trip.line;
      }
      
      // Get line names for passenger (pass req for Accept-Language fallback)
      const { fromName: passengerFromName, toName: passengerToName, language: passengerLanguage } = await getLineNamesForNotification(line, req.user.userid, req);

      await sendNotification(
        req.user.userid,
        NOTIFICATION_TYPES.RESERVATION_CANCELLED,
        {
          from: passengerFromName,
          to: passengerToName,
          bookingid: reservation.bookingid,
        },
        passengerLanguage,
        { line, trip } // Pass raw data for separate Arabic/English formatting
      );

      // Notify driver if trip has driver assigned
      if (trip?.assigned_driverid) {
        const Driver = (await import('../models/Driver.js')).default;
        const driver = await Driver.findById(trip.assigned_driverid);
        if (driver?.userid) {
          const Passenger = (await import('../models/Passenger.js')).default;
          const passenger = await Passenger.findById(reservation.passengerid);
          const passengerName = passenger?.user?.fullname || 'Passenger';

          // Get line names for driver (pass req for Accept-Language fallback if available)
          const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, req);

          await sendNotification(
            driver.userid,
            NOTIFICATION_TYPES.RESERVATION_CANCELLED,
            {
              passengerName,
              from: driverFromName,
              to: driverToName,
            },
            driverLanguage,
            { line, trip } // Pass raw data for separate Arabic/English formatting
          );
        }
      }
    } catch (notifError) {
      logger.warn('[ReservationController] Failed to send cancellation notification:', notifError);
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

    // Send notification to driver about passenger check-in
    try {
      const { sendNotification, NOTIFICATION_TYPES } = await import('../services/notificationService.js');
      const Passenger = (await import('../models/Passenger.js')).default;
      const passenger = await Passenger.findById(reservation.passengerid);
      const passengerName = passenger?.user?.fullname || 'Passenger';
      
      // Get driver's language preference
      const { getUserLanguage } = await import('../utils/lineHelpers.js');
      const driverLanguage = await getUserLanguage(req.user.userid);

      await sendNotification(
        req.user.userid, // Driver's userid
        NOTIFICATION_TYPES.PASSENGER_CHECKED_IN,
        {
          passengerName,
          bookingid: reservation.bookingid,
        },
        driverLanguage
      );
    } catch (notifError) {
      logger.warn('[ReservationController] Failed to send check-in notification:', notifError);
    }

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

