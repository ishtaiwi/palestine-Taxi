import User from '../models/User.js';
import Passenger from '../models/Passenger.js';
import Reservation from '../models/Reservation.js';
import Payment from '../models/Payment.js';
import Line from '../models/Line.js';
import Trip from '../models/Trip.js';
import DriverQueue from '../models/DriverQueue.js';
import Vehicle from '../models/Vehicle.js';
// Note: Wallet and Driver imports removed - cash transfer happens at check-in, not at booking
import { v4 as uuidv4 } from 'uuid';
import { generateQRCode } from '../utils/qrcode.js';
import { BOOKING_TYPE, PAYMENT_STATUS, PAYMENT_METHOD, RESERVATION_STATUS, PASSENGER_TYPE, TRIP_STATUS } from '../utils/constants.js';
import { canBookInstant } from '../utils/timeUtils.js';
import { syncTripStats, getAvailableSeats } from '../services/matchingService.js';
import { assignVehicleFromQueue } from '../services/tripOpeningService.js';
import logger from '../utils/logger.js';

/**
 * Register walk-in passenger and create reservation with instant booking
 * Public endpoint - no authentication required
 * Supports trip selection and cash payment
 */
export const registerWalkIn = async (req, res, next) => {
  let paymentRecord = null;
  let user = null;
  let passenger = null;
  let trip = null;

  try {
    const { lineid, phone, dropoffpoint, aging, tripid } = req.body;

    // Validate required fields
    if (!lineid) {
      return res.status(400).json({
        message: 'lineid is required',
      });
    }

    if (!phone) {
      return res.status(400).json({
        message: 'phone is required',
      });
    }

    // Validate phone format (basic validation - Palestinian format)
    const phoneRegex = /^(\+?970|0)?[5][0-9]{8}$/;
    const normalizedPhone = phone.trim().replace(/\s+/g, '');

    if (!phoneRegex.test(normalizedPhone)) {
      return res.status(400).json({
        message: 'Invalid phone number format. Please use Palestinian format (e.g., 0599123456 or +970599123456)',
      });
    }

    // Validate line exists and is active
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    if (!line.active) {
      return res.status(400).json({
        message: 'Line is not active',
      });
    }

    // If tripid is provided, validate the trip
    if (tripid) {
      trip = await Trip.findById(tripid);
      if (!trip) {
        return res.status(404).json({
          message: 'Trip not found',
        });
      }

      // Validate trip belongs to the selected line
      if (trip.lineid !== lineid) {
        return res.status(400).json({
          message: 'Trip does not belong to the selected line',
        });
      }

      // Check if trip is in a valid status for booking
      const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.OPEN, TRIP_STATUS.DELAYED];
      if (!validStatuses.includes(trip.status)) {
        return res.status(400).json({
          message: `Trip is ${trip.status} and cannot accept bookings`,
        });
      }

      // Check if trip has departed
      const departedStatuses = [TRIP_STATUS.IN_PROGRESS, TRIP_STATUS.COMPLETED];
      if (departedStatuses.includes(trip.status)) {
        return res.status(400).json({
          message: 'Trip has already departed',
        });
      }

      // Check if trip is open for instant booking
      if (!canBookInstant(trip)) {
        return res.status(400).json({
          message: 'Trip is not yet open for instant bookings',
        });
      }

      // Check driver availability - trip must have driver OR drivers in queue
      const tripHasDriver = trip.vehicleid && trip.assigned_driverid;
      if (!tripHasDriver) {
        const queueCheck = await DriverQueue.canAcceptInstantBooking(trip.lineid);
        if (!queueCheck.allowed) {
          return res.status(503).json({
            message: 'No drivers available for this trip. Please try again later.',
            code: 'NO_DRIVERS_AVAILABLE',
          });
        }
      }

      // Check available seats if trip has a vehicle
      if (trip.vehicleid) {
        const vehicle = await Vehicle.findById(trip.vehicleid);
        if (vehicle) {
          const availableSeats = await getAvailableSeats(vehicle, trip.tripid);
          if (availableSeats <= 0) {
            return res.status(400).json({
              message: 'No available seats on this trip',
            });
          }
        }
      }
    }

    // Find or create user by phone number
    user = await User.findByPhone(normalizedPhone);

    if (!user) {
      // Create new user for walk-in passenger
      const userData = {
        userid: uuidv4(),
        fullname: `Walk-in Passenger ${normalizedPhone.substring(normalizedPhone.length - 4)}`, // Use last 4 digits as identifier
        email: `walkin_${uuidv4().substring(0, 8)}@walkin.local`, // Temporary email
        phone: normalizedPhone,
        role: 'PASSENGER',
        password: null, // No password for walk-in passengers
      };

      user = await User.create(userData);
      logger.info(`[WalkInController] Created new user ${user.userid} for walk-in passenger with phone ${normalizedPhone}`);
    } else {
      logger.info(`[WalkInController] Found existing user ${user.userid} for phone ${normalizedPhone}`);
    }

    // Find or create passenger record
    passenger = await Passenger.findOrCreateByPhone(normalizedPhone, user.userid);

    // Calculate booking price
    let bookingPrice = line.baseprice;
    if (dropoffpoint && line.additionalprice) {
      bookingPrice += line.additionalprice;
    }

    // Create payment record with CASH method and COMPLETED status
    // Walk-in passengers pay cash at the station
    paymentRecord = await Payment.create({
      paymentid: uuidv4(),
      amount: bookingPrice,
      method: PAYMENT_METHOD.CASH,
      status: PAYMENT_STATUS.COMPLETED, // Cash payment marked as completed (will be transferred to driver on check-in)
      type: 'reservation',
      tripid: tripid || null,
      time: new Date().toISOString(),
      // Note: towalletid is NOT set here - cash will be transferred to driver's wallet when passenger checks in (QR scan)
    });

    // Create reservation with walk-in passenger type
    const reservationData = {
      bookingid: uuidv4(),
      passengerid: passenger.passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: tripid || null,
      lineid: line.lineid,
      seatlocation: null,
      bookingprice: bookingPrice,
      dropoffpoint: dropoffpoint || null,
      aging: aging || null,
      status: RESERVATION_STATUS.CONFIRMED,
      driver_status: 'approved',
      booking_type: BOOKING_TYPE.INSTANT,
      scheduled_trip_time: null,
      passenger_type: PASSENGER_TYPE.WALK_IN,
      phone_number: normalizedPhone,
    };

    const reservation = await Reservation.create(reservationData);
    logger.info(`[WalkInController] Created walk-in reservation ${reservation.bookingid} for phone ${normalizedPhone}${tripid ? ` on trip ${tripid}` : ''}`);

    // Sync trip stats if trip was provided
    let driverAssigned = false;
    if (tripid) {
      try {
        await syncTripStats(tripid);
        logger.info(`[WalkInController] Synced stats for trip ${tripid}`);
      } catch (syncError) {
        logger.warn('[WalkInController] Error syncing trip stats:', syncError);
      }

      // Check if trip already has driver (through vehicle relationship or assigned_driverid)
      const tripHasDriverAlready = (trip.vehicle && trip.vehicle.driver) || trip.assigned_driverid;

      // If trip doesn't have driver yet, try to assign one from queue
      if (trip && !tripHasDriverAlready) {
        try {
          const assignmentResult = await assignVehicleFromQueue(tripid, trip.lineid);
          if (assignmentResult && assignmentResult.success) {
            driverAssigned = true;
            logger.info(`[WalkInController] Driver ${assignmentResult.driverid} assigned to trip ${tripid}`);
            // Note: Cash payment will be transferred to driver's wallet when passenger checks in (QR scan)
          }
        } catch (assignError) {
          logger.warn('[WalkInController] Error assigning driver from queue:', assignError);
        }
      } else if (tripHasDriverAlready) {
        logger.info(`[WalkInController] Trip ${tripid} already has driver assigned`);
      }
    }

    // Generate QR code (same format as existing system)
    const qrData = JSON.stringify({
      bookingid: reservation.bookingid,
      passengerid: reservation.passengerid,
      tripid: reservation.tripid || null,
    });

    const qrCode = await generateQRCode(qrData);

    // Get payment details for response
    const paymentDetails = await Payment.findById(paymentRecord.paymentid);

    // Refresh trip data to get latest driver info (in case driver was just assigned)
    // Always refresh to get the most up-to-date driver/vehicle information
    let finalTrip = trip;
    if (tripid) {
      try {
        finalTrip = await Trip.findById(tripid);
        logger.info(`[WalkInController] Refreshed trip ${tripid}, assigned_driverid: ${finalTrip?.assigned_driverid}, vehicleid: ${finalTrip?.vehicleid}`);
      } catch (refreshError) {
        logger.warn('[WalkInController] Error refreshing trip, using original trip data:', refreshError);
        // Fall back to original trip if refresh fails
        finalTrip = trip;
      }
    }

    // Build trip info for response
    let tripInfo = null;
    let driverInfo = null;

    if (finalTrip) {
      tripInfo = {
        tripid: finalTrip.tripid,
        deptime: finalTrip.deptime,
        direction: finalTrip.direction,
        status: finalTrip.status,
        availableseats: finalTrip.availableseats,
      };

      // Get driver info - check both assigned_driverid and vehicle.driver
      let driverToUse = null;
      let vehicleToUse = null;

      // First, check if trip has vehicle with driver nested (from join)
      if (finalTrip.vehicle && finalTrip.vehicle.driver) {
        driverToUse = finalTrip.vehicle.driver;
        vehicleToUse = finalTrip.vehicle;
        logger.info(`[WalkInController] Found driver through vehicle relationship: ${driverToUse.driverid}`);
      }
      // Otherwise, check assigned_driverid and fetch driver separately
      else if (finalTrip.assigned_driverid) {
        try {
          const Driver = (await import('../models/Driver.js')).default;
          driverToUse = await Driver.findById(finalTrip.assigned_driverid);
          if (driverToUse) {
            logger.info(`[WalkInController] Fetched driver ${finalTrip.assigned_driverid} separately: ${driverToUse.driverid}`);
          } else {
            logger.warn(`[WalkInController] Driver ${finalTrip.assigned_driverid} not found`);
          }
        } catch (driverError) {
          logger.warn('[WalkInController] Error fetching driver by ID:', driverError);
        }
      } else {
        logger.info(`[WalkInController] Trip ${tripid} has no assigned_driverid and no vehicle.driver`);
      }

      // If we have driver, build driver info
      if (driverToUse) {
        driverInfo = {
          driverid: driverToUse.driverid,
          fullname: driverToUse.user?.fullname || null,
          phone: driverToUse.user?.phone || null,
        };

        // Get vehicle info if available
        if (vehicleToUse) {
          driverInfo.vehicle = {
            vehicleid: vehicleToUse.vehicleid,
            platenumber: vehicleToUse.platenumber,
            make: vehicleToUse.make,
            model: vehicleToUse.model,
            color: vehicleToUse.color,
          };
          logger.info(`[WalkInController] Using vehicle from relationship: ${vehicleToUse.platenumber}`);
        } else if (finalTrip.vehicleid) {
          try {
            const vehicle = await Vehicle.findById(finalTrip.vehicleid);
            if (vehicle) {
              driverInfo.vehicle = {
                vehicleid: vehicle.vehicleid,
                platenumber: vehicle.platenumber,
                make: vehicle.make,
                model: vehicle.model,
                color: vehicle.color,
              };
              logger.info(`[WalkInController] Fetched vehicle separately: ${vehicle.platenumber}`);
            }
          } catch (vehicleError) {
            logger.warn('[WalkInController] Error fetching vehicle info:', vehicleError);
          }
        }

        logger.info(`[WalkInController] Driver info prepared: ${driverInfo.fullname || 'No name'}, Phone: ${driverInfo.phone || 'None'}, Vehicle: ${driverInfo.vehicle?.platenumber || 'None'}`);
      } else {
        logger.info(`[WalkInController] No driver found for trip ${tripid} - assigned_driverid: ${finalTrip.assigned_driverid}, hasVehicle: ${!!finalTrip.vehicle}, hasVehicleDriver: ${!!(finalTrip.vehicle?.driver)}`);
      }
    }

    res.status(201).json({
      message: 'Walk-in reservation created successfully',
      reservation: {
        bookingid: reservation.bookingid,
        lineid: reservation.lineid,
        tripid: reservation.tripid,
        phone_number: reservation.phone_number,
        bookingprice: reservation.bookingprice,
        status: reservation.status,
        passenger_type: reservation.passenger_type,
      },
      payment: paymentDetails,
      qrCode,
      qrData,
      line: {
        lineid: line.lineid,
        name_ar: line.name_ar,
        name_en: line.name_en,
        linename: line.linename,
      },
      trip: tripInfo,
      driver: driverInfo,
    });
  } catch (error) {
    logger.error('[WalkInController] Error creating walk-in reservation:', error);

    // Clean up created records on error
    if (paymentRecord) {
      try {
        await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED });
      } catch (cleanupError) {
        logger.warn('[WalkInController] Failed to update payment status on error:', cleanupError);
      }
    }

    next(error);
  }
};

/**
 * Get available trips for walk-in booking
 * Public endpoint - no authentication required
 */
export const getWalkInTrips = async (req, res, next) => {
  try {
    const { lineid, direction } = req.query;

    if (!lineid) {
      return res.status(400).json({
        message: 'lineid is required',
      });
    }

    // Validate line exists
    const line = await Line.findById(lineid);
    if (!line) {
      return res.status(404).json({
        message: 'Line not found',
      });
    }

    // Build filters for upcoming trips
    const filters = {
      lineid,
    };
    if (direction) {
      filters.direction = direction;
    }

    // Get upcoming trips for the line
    const allTrips = await Trip.findUpcoming(filters);

    logger.info(`[WalkInController] Found ${allTrips.length} upcoming trips for line ${lineid}, direction: ${direction || 'all'}`);

    // Filter trips that are available for instant booking
    const availableTrips = [];

    for (const trip of allTrips) {
      // Check trip status - must be in a bookable status
      const validStatuses = [TRIP_STATUS.SCHEDULED, TRIP_STATUS.OPEN, TRIP_STATUS.DELAYED];
      if (!validStatuses.includes(trip.status)) {
        logger.debug(`[WalkInController] Trip ${trip.tripid} skipped - status: ${trip.status}`);
        continue;
      }

      // For OPEN trips, always show them (they're ready for booking)
      // For SCHEDULED/DELAYED trips, check if instant booking time has passed
      if (trip.status !== TRIP_STATUS.OPEN && !canBookInstant(trip)) {
        logger.debug(`[WalkInController] Trip ${trip.tripid} skipped - not open for instant booking yet`);
        continue;
      }

      // Check if trip has driver OR drivers available in queue for this direction
      const tripHasDriver = trip.vehicleid && trip.assigned_driverid;
      let driversAvailable = 0;

      if (!tripHasDriver) {
        // Pass the trip's direction to check for drivers in queue for that direction
        const queueCheck = await DriverQueue.canAcceptInstantBooking(trip.lineid, trip.direction);
        if (!queueCheck.allowed) {
          logger.debug(`[WalkInController] Trip ${trip.tripid} skipped - no driver and no drivers in queue for direction ${trip.direction}`);
          continue; // Skip trips without driver and no drivers in queue
        }
        driversAvailable = queueCheck.driversAvailable || 0;
      }

      // Calculate available seats
      let availableSeats = trip.availableseats || 4;
      if (trip.vehicleid) {
        try {
          const vehicle = await Vehicle.findById(trip.vehicleid);
          if (vehicle) {
            availableSeats = await getAvailableSeats(vehicle, trip.tripid);
          }
        } catch (seatError) {
          logger.warn(`[WalkInController] Error getting seats for trip ${trip.tripid}:`, seatError);
        }
      }

      // Skip trips with no available seats
      if (availableSeats <= 0) {
        continue;
      }

      availableTrips.push({
        tripid: trip.tripid,
        lineid: trip.lineid,
        deptime: trip.deptime,
        direction: trip.direction,
        status: trip.status,
        availableseats: availableSeats,
        hasDriver: tripHasDriver,
        driversInQueue: driversAvailable,
        trip_opening_time: trip.trip_opening_time,
        line: {
          lineid: line.lineid,
          name_ar: line.name_ar,
          name_en: line.name_en,
          linename: line.linename,
          baseprice: line.baseprice,
          additionalprice: line.additionalprice,
        },
      });
    }

    // Sort by departure time
    availableTrips.sort((a, b) => {
      const timeA = new Date(a.deptime).getTime();
      const timeB = new Date(b.deptime).getTime();
      return timeA - timeB;
    });

    res.json({
      trips: availableTrips,
      line: {
        lineid: line.lineid,
        name_ar: line.name_ar,
        name_en: line.name_en,
        linename: line.linename,
        baseprice: line.baseprice,
        additionalprice: line.additionalprice,
      },
    });
  } catch (error) {
    logger.error('[WalkInController] Error fetching walk-in trips:', error);
    next(error);
  }
};

/**
 * Get all active lines for walk-in terminal
 * Public endpoint - no authentication required
 */
export const getWalkInLines = async (req, res, next) => {
  try {
    // Get all active lines
    const lines = await Line.findAll({ active: true });

    const linesList = lines.map(line => ({
      lineid: line.lineid,
      name_ar: line.name_ar,
      name_en: line.name_en,
      linename: line.linename,
      baseprice: line.baseprice,
      additionalprice: line.additionalprice,
      main_stationid: line.main_stationid,
      return_stationid: line.return_stationid,
    }));

    res.json({
      lines: linesList,
    });
  } catch (error) {
    logger.error('[WalkInController] Error fetching lines:', error);
    next(error);
  }
};
