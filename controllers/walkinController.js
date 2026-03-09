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
  let reservation = null;

  try {
    const { lineid, phone, dropoffpoint, aging } = req.body;
    let { tripid } = req.body;

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
      // If no driver assigned, try to assign one from queue (walk-in instant booking logic)
      const tripHasDriver = trip.vehicleid && trip.assigned_driverid;
      let driverAssigned = false;
      let assignedDriverInfo = null;

      if (!tripHasDriver) {
        logger.info(`[WalkInController] Trip ${tripid} has no driver assigned, attempting instant assignment from queue`);

        // Get trip direction to filter queue
        const tripDirection = trip.direction || 'going';

        // Map trip direction to queue direction
        const { mapTripDirectionToQueueDirection } = await import('../utils/tripDirectionUtils.js');
        const queueDirection = mapTripDirectionToQueueDirection(tripDirection);

        const DriverQueue = (await import('../models/DriverQueue.js')).default;
        const queue = await DriverQueue.getActiveByLine(lineid, queueDirection);

        if (!queue || queue.length === 0) {
          logger.info(`[WalkInController] ⚠️ No drivers available in ${queueDirection} queue for line ${lineid}`);
          return res.status(503).json({
            message: 'No drivers available for this trip. Please try again later.',
            code: 'NO_DRIVERS_AVAILABLE',
          });
        }

        logger.info(`[WalkInController] 📋 Found ${queue.length} driver(s) in ${queueDirection} queue: ${queue.map((d, i) => `[${i + 1}] driver ${d.driverid}`).join(', ')}`);

        const Trip = (await import('../models/Trip.js')).default;
        const Vehicle = (await import('../models/Vehicle.js')).default;

        // Get trip departure time for conflict checking
        const { parseUtcDate } = await import('../utils/timeUtils.js');
        const tripDeptime = parseUtcDate(trip.deptime);

        let selectedDriver = null;
        let selectedVehicle = null;

        for (const driverQueueEntry of queue) {
          const driverid = driverQueueEntry.driverid;

          // Check if driver has conflicting trips at the same time
          const driverTrips = await Trip.findAssignedTrips(driverid, { fromNow: false });
          const hasTripAtSameTime = driverTrips.some(t => {
            if (t.status === 'completed' || t.status === 'cancelled') return false;

            if (tripDeptime && t.deptime) {
              const tDeptime = parseUtcDate(t.deptime);
              if (tDeptime) {
                const timeDiff = Math.abs(tDeptime.getTime() - tripDeptime.getTime());
                return timeDiff <= 60000; // Within 1 minute
              }
            }
            return false;
          });

          if (hasTripAtSameTime) {
            logger.info(`[WalkInController] ⚠️ Driver ${driverid} already assigned to a trip at this time, skipping`);
            continue;
          }

          // Get driver's vehicles
          const vehicles = await Vehicle.findByDriverId(driverid);
          if (!vehicles || vehicles.length === 0) {
            logger.warn(`[WalkInController] ⚠️ Driver ${driverid} has no vehicle assigned - removing from queue`);
            await DriverQueue.removeDriverFromQueue(driverid);
            continue;
          }

          selectedDriver = driverQueueEntry;
          selectedVehicle = vehicles[0];
          logger.info(`[WalkInController] ✅ Selected driver ${driverid} from queue (position ${queue.indexOf(driverQueueEntry) + 1})`);
          break;
        }

        if (!selectedDriver || !selectedVehicle) {
          logger.info(`[WalkInController] ⚠️ No available driver found in queue for line ${lineid}`);
          return res.status(503).json({
            message: 'No drivers available for this trip. Please try again later.',
            code: 'NO_DRIVERS_AVAILABLE',
          });
        }

        const driverid = selectedDriver.driverid;
        const vehicle = selectedVehicle;

        // Assign driver and vehicle to trip
        await Trip.update(tripid, {
          vehicleid: vehicle.vehicleid,
        });

        await Trip.assignDriver(tripid, driverid);

        // Update trip stats
        const { syncTripStats } = await import('../services/matchingService.js');
        await syncTripStats(tripid);

        // Remove driver from queue
        await DriverQueue.removeDriverFromQueue(driverid);

        // Transfer payments for this trip to the driver
        try {
          const { transferPaymentsForTrip } = await import('../services/paymentService.js');
          const transferResult = await transferPaymentsForTrip(tripid, driverid);
          if (transferResult.success) {
            logger.info(`[WalkInController] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${driverid} for trip ${tripid}`);
          } else {
            logger.warn(`[WalkInController] ⚠️ Payment transfer failed for trip ${tripid}: ${transferResult.error}`);
          }
        } catch (paymentError) {
          logger.error(`[WalkInController] ❌ Error transferring payments for trip ${tripid}:`, paymentError);
          // Don't fail booking if payment transfer fails
        }

        driverAssigned = true;
        assignedDriverInfo = {
          success: true,
          vehicle,
          driverid,
          trip: await Trip.findById(tripid),
        };

        // Refresh trip data after assignment
        trip = await Trip.findById(tripid);
        logger.info(`[WalkInController] ✅ Successfully assigned driver ${driverid} and vehicle ${vehicle.vehicleid} to trip ${tripid} for walk-in booking`);

        // Send notifications to the assigned driver
        try {
          const { sendNotification } = await import('../services/notificationService.js');
          const Driver = (await import('../models/Driver.js')).default;
          const Line = (await import('../models/Line.js')).default;

          const driver = await Driver.findById(driverid);
          const line = await Line.findById(lineid);

          if (driver?.userid) {
            const driverName = driver?.user?.fullname || 'Driver';
            const plateNumber = vehicle.platenumber || 'N/A';
            const tripDirection = trip.direction || 'going';

            const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');
            const { fromName: driverFromName, toName: driverToName, language: driverLanguage } = await getLineNamesForNotification(line, driver.userid, null, null, tripDirection);

            const { DateTime } = await import('luxon');
            const deptime = DateTime.fromISO(new Date(trip.deptime).toISOString())
              .setLocale(driverLanguage === 'en' ? 'en' : 'ar')
              .toLocaleString({
                year: 'numeric',
                month: 'long',
                day: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
                hour12: driverLanguage === 'en'
              });

            await sendNotification(
              driver.userid,
              'TRIP_ASSIGNED',
              {
                from: driverFromName,
                to: driverToName,
                time: deptime,
                tripid: tripid,
              },
              driverLanguage,
              { line, trip }
            );

            logger.info(`[WalkInController] 📱 Sent driver assignment notification to ${driver.userid}`);
          }
        } catch (notifError) {
          logger.warn(`[WalkInController] Failed to send driver notification for trip ${tripid}:`, notifError);
          // Don't fail booking if notification fails
        }
      }

      // Ensure trip has a vehicle before proceeding (required for seat calculation)
      if (!trip.vehicleid) {
        // If trip still has no vehicle after driver assignment attempt, that's an error
        return res.status(500).json({
          message: 'Trip setup incomplete. Please try again.',
        });
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
        active: true,
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

    // CRITICAL FIX: Check trip capacity BEFORE creating reservation
    // This prevents creating orphaned bookings when trip is full
    let finalTripid = tripid;
    if (tripid) {
      let currentTrip = await Trip.findById(tripid);
      if (!currentTrip) {
        throw new Error('Trip not found when checking capacity');
      }

      // Count current reservations for this trip (BEFORE creating new reservation)
      const tripReservations = await Reservation.findByTripId(tripid);
      const currentReservationCount = tripReservations.filter(
        r => r.status === 'confirmed' || r.status === 'checked_in'
      ).length;

      // Get vehicle to determine max seats for THIS trip
      let maxPassengerSeats = 4; // Default fallback
      if (currentTrip.vehicleid) {
        const Vehicle = (await import('../models/Vehicle.js')).default;
        const vehicle = await Vehicle.findById(currentTrip.vehicleid);
        if (vehicle) {
          const { calculateAvailablePassengerSeats } = await import('../utils/seatCalculation.js');
          maxPassengerSeats = calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0);
        }
      }

      // Check if trip would be full after adding this booking
      if (currentReservationCount >= maxPassengerSeats) {
        logger.info(`[WalkInController] 🚨 Trip ${tripid} is FULL (${currentReservationCount} bookings >= ${maxPassengerSeats} capacity) - checking for alternative trips or new trip creation`);

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
              logger.info(`[WalkInController] Found alternative trip ${otherTrip.tripid} with ${availableSeats} available seats`);
              break;
            }
          }
        }

        // If found alternative trip, use it for the booking
        if (targetTripForBooking) {
          finalTripid = targetTripForBooking.tripid;
          trip = await Trip.findById(finalTripid);
          logger.info(`[WalkInController] 📝 Will assign booking to alternative trip ${finalTripid}`);
        } else {
          // No alternative trip found - check if additional drivers can be assigned
          logger.info(`[WalkInController] No alternative trips found, checking queue for drivers...`);
          
          // Get trip direction to check correct queue
          const tripDirection = currentTrip.direction || 'going';
          const { mapTripDirectionToQueueDirection } = await import('../utils/tripDirectionUtils.js');
          const queueDirection = mapTripDirectionToQueueDirection(tripDirection);
          
          const DriverQueue = (await import('../models/DriverQueue.js')).default;
          const queueCheck = await DriverQueue.canAcceptInstantBooking(currentTrip.lineid, queueDirection);
          logger.info(`[WalkInController] Queue check result: allowed=${queueCheck.allowed}, driversAvailable=${queueCheck.driversAvailable}`);

          if (!queueCheck.allowed || queueCheck.driversAvailable === 0) {
            // No drivers in queue - return error BEFORE creating reservation
            logger.warn(`[WalkInController] ⚠️ Trip ${tripid} is full and no drivers available in queue - rejecting booking`);
            return res.status(400).json({
              message: 'No available seats on this trip and no additional drivers available',
            });
          }
          
          // CRITICAL FIX: Create new trip BEFORE creating reservation to avoid double-counting
          // This ensures the reservation is created with the correct tripid from the start
          logger.info(`[WalkInController] 🚨 Trip ${tripid} is full, but ${queueCheck.driversAvailable} driver(s) available - creating new trip BEFORE reservation`);
          
          // Create new trip with next driver
          // We create the trip manually here instead of using createNewTripForFullTripBooking
          // since that function expects a booking to already exist, but we want to create the trip first
          const queue = await DriverQueue.getActiveByLine(currentTrip.lineid, queueDirection);
          if (!queue || queue.length === 0) {
            logger.warn(`[WalkInController] ⚠️ No drivers available in queue (should not happen)`);
            return res.status(400).json({
              message: 'No available seats on this trip and no additional drivers available',
            });
          }

          const { parseUtcDate } = await import('../utils/timeUtils.js');
          const tripDeptime = parseUtcDate(currentTrip.deptime);
          if (!tripDeptime) {
            throw new Error('Invalid trip deptime');
          }

          let selectedDriver = null;
          let selectedVehicle = null;

          for (const driverQueueEntry of queue) {
            const driverid = driverQueueEntry.driverid;
            const driverTrips = await Trip.findAssignedTrips(driverid, { fromNow: false });
            const hasTripAtSameTime = driverTrips.some(t => {
              if (t.status === 'completed' || t.status === 'cancelled') return false;
              if (t.deptime) {
                const tDeptime = parseUtcDate(t.deptime);
                if (tDeptime) {
                  const timeDiff = Math.abs(tDeptime.getTime() - tripDeptime.getTime());
                  return timeDiff <= 60000;
                }
              }
              return false;
            });

            if (hasTripAtSameTime) {
              logger.info(`[WalkInController] Driver ${driverid} already has trip at this time, skipping`);
              continue;
            }

            const vehicles = await Vehicle.findByDriverId(driverid);
            if (!vehicles || vehicles.length === 0) {
              logger.warn(`[WalkInController] ⚠️ Driver ${driverid} has no vehicle, removing from queue`);
              await DriverQueue.removeDriverFromQueue(driverid);
              continue;
            }

            selectedDriver = driverQueueEntry;
            selectedVehicle = vehicles[0];
            logger.info(`[WalkInController] ✅ Selected driver ${driverid} from queue for new trip`);
            break;
          }

          if (!selectedDriver || !selectedVehicle) {
            logger.warn(`[WalkInController] ⚠️ No available driver found in queue`);
            return res.status(400).json({
              message: 'No available seats on this trip and no additional drivers available',
            });
          }

          const driverid = selectedDriver.driverid;
          const vehicle = selectedVehicle;

          // Create new trip
          const { calculateAvailablePassengerSeats } = await import('../utils/seatCalculation.js');
          const openingTime = new Date(tripDeptime.getTime() - 45 * 60 * 1000);
          const maxPassengerSeats = calculateAvailablePassengerSeats(vehicle.seatnum, 0, 0);

          const newTripData = {
            tripid: uuidv4(),
            lineid: currentTrip.lineid,
            vehicleid: vehicle.vehicleid,
            deptime: currentTrip.deptime,
            status: 'scheduled',
            availableseats: maxPassengerSeats,
            totalbookings: 0,
            trip_opening_time: openingTime.toISOString(),
            auto_departure_enabled: true,
            early_departure_allowed: true,
            scheduled_departure_enforced: true,
            direction: currentTrip.direction || 'going',
            origin_stationid: currentTrip.origin_stationid || null,
          };

          const newTrip = await Trip.create(newTripData);
          await Trip.assignDriver(newTrip.tripid, driverid);
          await DriverQueue.removeDriverFromQueue(driverid);
          
          // Update finalTripid to use the new trip
          finalTripid = newTrip.tripid;
          trip = await Trip.findById(finalTripid);
          
          logger.info(`[WalkInController] ✅ Created new trip ${newTrip.tripid} with driver ${driverid} BEFORE reservation creation`);
        }
      }
    }

    // Create payment record with CASH method and COMPLETED status
    // Walk-in passengers pay cash at the station
    paymentRecord = await Payment.create({
      paymentid: uuidv4(),
      amount: bookingPrice,
      method: PAYMENT_METHOD.CASH,
      status: PAYMENT_STATUS.COMPLETED, // Cash payment marked as completed (will be transferred to driver on check-in)
      type: 'reservation',
      tripid: finalTripid || null,
      time: new Date().toISOString(),
      // Note: towalletid is NOT set here - cash will be transferred to driver's wallet when passenger checks in (QR scan)
    });

    // Create reservation with walk-in passenger type
    // CRITICAL: finalTripid is now the correct trip (either original, alternative, or newly created)
    const reservationData = {
      bookingid: uuidv4(),
      passengerid: passenger.passengerid,
      paymentid: paymentRecord.paymentid,
      tripid: finalTripid || null,
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
    logger.info(`[WalkInController] Created walk-in reservation ${reservation.bookingid} for phone ${normalizedPhone}${finalTripid ? ` on trip ${finalTripid}` : ''}`);

    // Update tripid variable to use finalTripid for rest of processing
    tripid = finalTripid;

    // Sync trip stats for the trip (whether original, alternative, or newly created)
    if (tripid) {
      const { syncTripStats } = await import('../services/matchingService.js');
      await syncTripStats(tripid);
      logger.info(`[WalkInController] ✅ Synced trip stats for trip ${tripid}`);
      
      // Transfer payments for the trip to the driver (if driver is assigned)
      const currentTrip = await Trip.findById(tripid);
      if (currentTrip && currentTrip.assigned_driverid) {
        try {
          const { transferPaymentsForTrip } = await import('../services/paymentService.js');
          const transferResult = await transferPaymentsForTrip(tripid, currentTrip.assigned_driverid);
          if (transferResult.success) {
            logger.info(`[WalkInController] ✅ Transferred ${transferResult.transferred} payment(s) to driver ${currentTrip.assigned_driverid} for trip ${tripid}`);
          }
        } catch (paymentError) {
          logger.warn(`[WalkInController] ⚠️ Error transferring payments for trip ${tripid}:`, paymentError);
        }
      }

      // Check if trip already has driver (through vehicle relationship or assigned_driverid)
      const tripHasDriverAlready = (trip.vehicle && trip.vehicle.driver) || trip.assigned_driverid;

      // If trip doesn't have driver yet, try to assign one from queue
      if (trip && !tripHasDriverAlready) {
        try {
          const assignmentResult = await assignVehicleFromQueue(tripid, trip.lineid);
          if (assignmentResult && assignmentResult.success) {
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
    if (reservation) {
      try {
        await Reservation.delete(reservation.bookingid);
        logger.info(`[WalkInController] ✅ Cleaned up reservation ${reservation.bookingid} after error`);
      } catch (cleanupError) {
        logger.warn('[WalkInController] Failed to delete reservation on error:', cleanupError);
      }
    }

    if (paymentRecord) {
      try {
        await Payment.update(paymentRecord.paymentid, { status: PAYMENT_STATUS.FAILED });
        logger.info(`[WalkInController] ✅ Updated payment ${paymentRecord.paymentid} status to FAILED after error`);
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

      // Skip trips with no available seats, EXCEPT for open trips (show them even if full)
      if (availableSeats <= 0 && trip.status !== TRIP_STATUS.OPEN) {
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
