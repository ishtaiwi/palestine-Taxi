import Admin from '../models/Admin.js';
import User from '../models/User.js';
import Driver from '../models/Driver.js';
import Passenger from '../models/Passenger.js';
import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Payment from '../models/Payment.js';
import DriverQueue from '../models/DriverQueue.js';
import Wallet from '../models/Wallet.js';
import AppConfig from '../models/AppConfig.js';
import logger from '../utils/logger.js';
import { TRIP_STATUS, RESERVATION_STATUS, VEHICLE_STATUS, USER_ROLES, PAYMENT_STATUS } from '../utils/constants.js';
import { sendDriverApprovalEmail, sendDriverRejectionEmail } from '../utils/email.js';
import {
  trainModelBulk as trainRushHourModel,
  getRushHourPredictions as fetchRushHourPredictions,
  getLineDemandSnapshot,
  getTopDemandLines,
  getModelSummary as getPredictionModelSummary,
} from '../services/rushHourPredictionService.js';
import {
  generateScheduleRecommendations,
  getDemandInsights,
  applyRecommendation as applyScheduleRec,
} from '../services/recommendationService.js';

// Helper function to calculate previous period dates for comparison
function getPreviousPeriodDates(startDate, endDate) {
  const start = new Date(startDate);
  const end = new Date(endDate);
  const duration = end.getTime() - start.getTime();

  const previousEnd = new Date(start.getTime() - 1); // Day before current start
  const previousStart = new Date(previousEnd.getTime() - duration);

  return {
    previousStartDate: previousStart.toISOString().split('T')[0],
    previousEndDate: previousEnd.toISOString().split('T')[0],
  };
}

// Helper function to calculate percentage change
function calculatePercentageChange(current, previous) {
  if (previous === 0 || previous === null || previous === undefined) {
    return current > 0 ? 100 : 0;
  }
  return ((current - previous) / previous) * 100;
}

// Helper function to calculate statistics from numeric array
function calculateStats(values) {
  if (!values || values.length === 0) {
    return { min: 0, max: 0, average: 0, total: 0 };
  }
  const total = values.reduce((sum, v) => sum + v, 0);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const average = total / values.length;
  return { min, max, average, total };
}

export const getDashboardStats = async (req, res, next) => {
  try {
    const trips = await Trip.findAll();
    const reservations = await Reservation.findAll();
    const lines = await Line.findAll();
    const vehicles = await Vehicle.findAll();
    const users = await User.findAll();

    const stats = {
      totalTrips: trips.length,
      completedTrips: trips.filter(t => t.status === TRIP_STATUS.COMPLETED).length,
      cancelledTrips: trips.filter(t => t.status === TRIP_STATUS.CANCELLED).length,
      totalReservations: reservations.length,
      confirmedReservations: reservations.filter(r => r.status === RESERVATION_STATUS.CONFIRMED).length,
      totalLines: lines.filter(l => l.active).length,
      totalVehicles: vehicles.filter(v => v.status === VEHICLE_STATUS.ACTIVE).length,
      totalUsers: users.length,
      totalDrivers: users.filter(u => u.role === USER_ROLES.DRIVER).length,
      totalPassengers: users.filter(u => u.role === USER_ROLES.PASSENGER).length,
    };

    res.json(stats);
  } catch (error) {
    next(error);
  }
};


export const getAllUsers = async (req, res, next) => {
  try {
    const { role } = req.query;
    const filters = role ? { role } : {};

    const users = await User.findAll(filters);
    res.json(users);
  } catch (error) {
    next(error);
  }
};


export const getUserById = async (req, res, next) => {
  try {
    const { userid } = req.params;
    const user = await User.findById(userid);

    if (!user) {
      return res.status(404).json({
        message: req.t('user.not_found') || 'User not found'
      });
    }

    res.json(user);
  } catch (error) {
    next(error);
  }
};


export const updateUser = async (req, res, next) => {
  try {
    const { userid } = req.params;
    const updates = req.body;

    const user = await User.update(userid, updates);
    res.json({
      message: req.t('user.updated') || 'User updated successfully',
      user,
    });
  } catch (error) {
    next(error);
  }
};


export const deleteUser = async (req, res, next) => {
  try {
    const { userid } = req.params;


    const user = await User.findById(userid);
    if (!user) {
      return res.status(404).json({
        message: req.t('user.not_found') || 'User not found'
      });
    }


    const driver = await Driver.findByUserId(userid);
    if (driver) {

      await DriverQueue.deleteByDriverId(driver.driverid);




      const vehicles = await Vehicle.findByDriverId(driver.driverid);
      if (vehicles && vehicles.length > 0) {
        for (const vehicle of vehicles) {
          await Vehicle.delete(vehicle.vehicleid);
        }
      }


      await Driver.delete(driver.driverid);
    }

    const passenger = await Passenger.findByUserId(userid);
    if (passenger) {
      try {
        await Reservation.deleteByPassengerId(passenger.passengerid);
        logger.info('Deleted reservations for passenger before user deletion', {
          userid,
          passengerid: passenger.passengerid,
        });
      } catch (reservationError) {
        logger.warn('Could not delete reservations for passenger', {
          userid,
          passengerid: passenger.passengerid,
          error: reservationError.message,
        });
      }

      await Passenger.delete(passenger.passengerid);
    }

    const admin = await Admin.findByUserId(userid);
    if (admin) {
      await Admin.delete(admin.id);
      logger.info('Deleted admin record before user deletion', {
        userid,
        adminid: admin.id,
      });
    }

    try {
      const wallets = await Wallet.findByUserId(userid);
      if (wallets && wallets.length > 0) {
        const walletIds = wallets.map(w => w.walletid);

        try {
          await Payment.deleteByWalletIds(walletIds);
          logger.info('Deleted payments for user wallets before wallet deletion', {
            userid,
            wallets_count: wallets.length,
          });
        } catch (paymentError) {
          logger.warn('Could not delete payments for user wallets', {
            userid,
            error: paymentError.message,
          });
        }
      }

      await Wallet.deleteByUserId(userid);
      logger.info('Deleted wallets for user before user deletion', { userid });
    } catch (walletError) {
      logger.warn('Could not delete wallets for user', {
        userid,
        error: walletError.message,
      });
    }

    try {
      const PasswordResetToken = (await import('../models/PasswordResetToken.js')).default;
      await PasswordResetToken.deleteByUserId(userid);
      logger.info('Deleted password reset tokens for user before user deletion', { userid });
    } catch (tokenError) {
      logger.warn('Could not delete password reset tokens for user', {
        userid,
        error: tokenError.message,
      });
    }

    try {
      const Rating = (await import('../models/Rating.js')).default;
      await Rating.deleteByPassengerId(userid);
      logger.info('Deleted trip ratings for user before user deletion', { userid });
    } catch (ratingError) {
      logger.warn('Could not delete trip ratings for user', {
        userid,
        error: ratingError.message,
      });
    }

    try {
      const driversApprovedByUser = await Driver.updateByFilter(
        { approved_by: userid },
        { approved_by: null }
      );
      if (driversApprovedByUser && driversApprovedByUser.length > 0) {
        logger.info('Cleared approved_by references before user deletion', {
          userid,
          drivers_affected: driversApprovedByUser.length,
        });
      }
    } catch (updateError) {
      logger.warn('Could not clear approved_by references', {
        userid,
        error: updateError.message,
      });
    }

    await User.delete(userid);

    res.json({
      message: req.t('user.deleted') || 'User deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};


export const getRevenueAnalytics = async (req, res, next) => {
  try {
    const { startDate, endDate, lineid } = req.query;

    const { PAYMENT_STATUS } = await import('../utils/constants.js');
    let payments = await Payment.findAll({ status: PAYMENT_STATUS.COMPLETED });

    if (startDate) {
      payments = payments.filter(p => new Date(p.time) >= new Date(startDate));
    }
    if (endDate) {
      payments = payments.filter(p => new Date(p.time) <= new Date(endDate));
    }

    const totalRevenue = payments.reduce((sum, p) => sum + (p.amount || 0), 0);


    const revenueByLine = {};
    if (lineid) {
      const reservations = await Reservation.findAll();
      reservations.forEach(res => {
        if (res.trip && res.trip.lineid === lineid) {
          const payment = payments.find(p => p.paymentid === res.paymentid);
          if (payment) {
            revenueByLine[lineid] = (revenueByLine[lineid] || 0) + payment.amount;
          }
        }
      });
    }

    res.json({
      totalRevenue,
      revenueByLine,
      totalTransactions: payments.length,
    });
  } catch (error) {
    next(error);
  }
};


export const updateAdminPermissions = async (req, res, next) => {
  try {
    const { adminid } = req.params;
    const { permissions } = req.body;

    const admin = await Admin.updatePermissions(adminid, permissions);
    res.json({
      message: req.t('admin.permissions_updated') || 'Permissions updated successfully',
      admin,
    });
  } catch (error) {
    next(error);
  }
};

export const getRushHourPredictionsReport = async (req, res, next) => {
  try {
    const { lineid, daysAhead } = req.query;

    if (!lineid) {
      return res.status(400).json({
        message: req.t('line.id_required') || 'lineid query parameter is required',
      });
    }

    const days = daysAhead ? parseInt(daysAhead, 10) : undefined;
    const result = await fetchRushHourPredictions({
      lineid,
      daysAhead: days,
    });

    res.json(result);
  } catch (error) {
    next(error);
  }
};

export const getLineDemandAnalysis = async (req, res, next) => {
  try {
    const { lineid, limit, startDate, endDate } = req.query;

    if (lineid) {
      const snapshot = await getLineDemandSnapshot(lineid, { startDate, endDate });
      return res.json({
        lineid,
        snapshot,
      });
    }

    const topLines = await getTopDemandLines({
      limit: limit ? parseInt(limit, 10) : undefined,
      startDate,
      endDate,
    });

    res.json({
      topLines,
      model: getPredictionModelSummary(),
    });
  } catch (error) {
    next(error);
  }
};

export const getScheduleRecommendations = async (req, res, next) => {
  try {
    const { lineids, daysAhead, utilizationStartDate, utilizationEndDate } = req.query;
    const lineIds = lineids ? lineids.split(',').map((id) => id.trim()).filter(Boolean) : undefined;

    const recommendations = await generateScheduleRecommendations({
      lineIds,
      daysAhead: daysAhead ? parseInt(daysAhead, 10) : undefined,
      utilizationStartDate,
      utilizationEndDate,
    });

    res.json({
      recommendations,
    });
  } catch (error) {
    next(error);
  }
};

export const applyScheduleRecommendation = async (req, res, next) => {
  try {
    const { recommendation } = req.body;

    if (!recommendation) {
      return res.status(400).json({
        message: req.t('recommendation.payload_required') || 'Recommendation payload is required',
      });
    }

    const result = await applyScheduleRec(recommendation);
    res.json({
      message: req.t('recommendation.applied') || 'Recommendation applied successfully',
      result,
    });
  } catch (error) {
    next(error);
  }
};

export const triggerModelRetrain = async (req, res, next) => {
  try {
    const { lineid, startDate, endDate, booking_type } = req.body || {};

    const summary = await trainRushHourModel({
      lineid,
      startDate,
      endDate,
      booking_type,
    });

    res.json({
      message: req.t('prediction.retrained') || 'Prediction model retraining started',
      summary,
    });
  } catch (error) {
    next(error);
  }
};

export const getPredictionInsights = async (req, res, next) => {
  try {
    const insights = await getDemandInsights({
      limit: req.query.limit ? parseInt(req.query.limit, 10) : undefined,
      utilizationStartDate: req.query.startDate,
      utilizationEndDate: req.query.endDate,
    });

    res.json(insights);
  } catch (error) {
    next(error);
  }
};

function groupByTimePeriod(data, groupBy, dateField) {
  const groups = {};
  const periodFormats = {
    day: (date) => date.toISOString().split('T')[0],
    week: (date) => {
      const d = new Date(date);
      d.setDate(d.getDate() - d.getDay());
      return d.toISOString().split('T')[0];
    },
    month: (date) => {
      const d = new Date(date);
      return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    },
  };

  const format = periodFormats[groupBy] || periodFormats.day;

  data.forEach((item) => {
    const date = new Date(item[dateField]);
    const key = format(date);
    if (!groups[key]) {
      groups[key] = [];
    }
    groups[key].push(item);
  });

  return Object.keys(groups)
    .sort()
    .map((key) => ({
      date: key,
      items: groups[key],
    }));
}

export const getRevenueTimeSeries = async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day', comparePrevious = 'false' } = req.query;

    let allPayments = await Payment.findAll({ status: PAYMENT_STATUS.COMPLETED });

    // Current period data
    let payments = [...allPayments];
    if (startDate) {
      payments = payments.filter(
        (p) => new Date(p.time) >= new Date(startDate)
      );
    }
    if (endDate) {
      payments = payments.filter((p) => new Date(p.time) <= new Date(endDate));
    }

    const grouped = groupByTimePeriod(payments, groupBy, 'time');
    const data = grouped.map((group) => ({
      date: group.date,
      revenue: group.items.reduce((sum, p) => sum + (p.amount || 0), 0),
      transactions: group.items.length,
    }));

    const totalRevenue = payments.reduce((sum, p) => sum + (p.amount || 0), 0);
    const revenueValues = data.map(d => d.revenue);
    const stats = calculateStats(revenueValues);

    // Calculate revenue by line
    const revenueByLine = {};
    payments.forEach((p) => {
      const lineid = p.reservation?.trip?.lineid || p.lineid || 'unknown';
      revenueByLine[lineid] = (revenueByLine[lineid] || 0) + (p.amount || 0);
    });

    // Find best and worst days
    const bestDay = data.length > 0 ? data.reduce((best, d) => d.revenue > best.revenue ? d : best, data[0]) : null;
    const worstDay = data.length > 0 ? data.reduce((worst, d) => d.revenue < worst.revenue ? d : worst, data[0]) : null;

    const response = {
      data,
      totalRevenue,
      totalTransactions: payments.length,
      revenueByLine,
      stats: {
        min: stats.min,
        max: stats.max,
        average: stats.average,
        bestDay: bestDay ? { date: bestDay.date, revenue: bestDay.revenue } : null,
        worstDay: worstDay ? { date: worstDay.date, revenue: worstDay.revenue } : null,
      },
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let previousPayments = allPayments.filter(
        (p) => new Date(p.time) >= new Date(previousStartDate) &&
          new Date(p.time) <= new Date(previousEndDate)
      );

      const previousGrouped = groupByTimePeriod(previousPayments, groupBy, 'time');
      const previousData = previousGrouped.map((group) => ({
        date: group.date,
        revenue: group.items.reduce((sum, p) => sum + (p.amount || 0), 0),
        transactions: group.items.length,
      }));

      const previousTotalRevenue = previousPayments.reduce((sum, p) => sum + (p.amount || 0), 0);

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        data: previousData,
        totalRevenue: previousTotalRevenue,
        totalTransactions: previousPayments.length,
      };
      response.percentageChange = {
        revenue: calculatePercentageChange(totalRevenue, previousTotalRevenue),
        transactions: calculatePercentageChange(payments.length, previousPayments.length),
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getBookingTimeSeries = async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day', comparePrevious = 'false' } = req.query;

    let allReservations = await Reservation.findAll();

    // Current period
    let reservations = [...allReservations];
    if (startDate) {
      reservations = reservations.filter(
        (r) => new Date(r.bookedat) >= new Date(startDate)
      );
    }
    if (endDate) {
      reservations = reservations.filter(
        (r) => new Date(r.bookedat) <= new Date(endDate)
      );
    }

    const grouped = groupByTimePeriod(reservations, groupBy, 'bookedat');
    const data = grouped.map((group) => {
      const items = group.items;
      return {
        date: group.date,
        total: items.length,
        confirmed: items.filter((r) => r.status === RESERVATION_STATUS.CONFIRMED).length,
        cancelled: items.filter((r) => r.status === RESERVATION_STATUS.CANCELLED).length,
      };
    });

    const byStatus = {
      confirmed: reservations.filter((r) => r.status === RESERVATION_STATUS.CONFIRMED).length,
      cancelled: reservations.filter((r) => r.status === RESERVATION_STATUS.CANCELLED).length,
    };

    const byLine = {};
    reservations.forEach((res) => {
      const lineid = res.trip?.lineid || 'unknown';
      const linename = res.trip?.line?.linename || 'Unknown';
      if (!byLine[lineid]) {
        byLine[lineid] = { lineid, linename, count: 0 };
      }
      byLine[lineid].count++;
    });

    // Calculate peak booking hours
    const hourlyBookings = {};
    reservations.forEach((r) => {
      if (r.bookedat) {
        const hour = new Date(r.bookedat).getHours();
        hourlyBookings[hour] = (hourlyBookings[hour] || 0) + 1;
      }
    });
    const peakHours = Object.entries(hourlyBookings)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([hour, count]) => ({ hour: parseInt(hour), count }));

    // Calculate confirmation rate
    const totalBookings = reservations.length;
    const confirmedBookings = byStatus.confirmed;
    const confirmationRate = totalBookings > 0 ? (confirmedBookings / totalBookings) * 100 : 0;

    const response = {
      data,
      byStatus,
      byLine: Object.values(byLine),
      totalBookings,
      confirmationRate,
      peakHours,
      stats: calculateStats(data.map(d => d.total)),
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let previousReservations = allReservations.filter(
        (r) => new Date(r.bookedat) >= new Date(previousStartDate) &&
          new Date(r.bookedat) <= new Date(previousEndDate)
      );

      const previousConfirmed = previousReservations.filter((r) => r.status === RESERVATION_STATUS.CONFIRMED).length;
      const previousConfirmationRate = previousReservations.length > 0
        ? (previousConfirmed / previousReservations.length) * 100 : 0;

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        totalBookings: previousReservations.length,
        confirmed: previousConfirmed,
        confirmationRate: previousConfirmationRate,
      };
      response.percentageChange = {
        bookings: calculatePercentageChange(totalBookings, previousReservations.length),
        confirmed: calculatePercentageChange(confirmedBookings, previousConfirmed),
        confirmationRate: confirmationRate - previousConfirmationRate,
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getTripStatistics = async (req, res, next) => {
  try {
    const { startDate, endDate, comparePrevious = 'false' } = req.query;

    let allTrips = await Trip.findAll();

    // Current period
    let trips = [...allTrips];
    if (startDate) {
      trips = trips.filter((t) => new Date(t.deptime) >= new Date(startDate));
    }
    if (endDate) {
      trips = trips.filter((t) => new Date(t.deptime) <= new Date(endDate));
    }

    const totalTrips = trips.length;
    const completed = trips.filter((t) => t.status === TRIP_STATUS.COMPLETED).length;
    const cancelled = trips.filter((t) => t.status === TRIP_STATUS.CANCELLED).length;
    const scheduled = trips.filter((t) => t.status === TRIP_STATUS.SCHEDULED).length;
    const open = trips.filter((t) => t.status === TRIP_STATUS.OPEN).length;
    const inProgress = trips.filter((t) => t.status === TRIP_STATUS.IN_PROGRESS).length;

    let totalUtilization = 0;
    let tripsWithBookings = 0;

    const grouped = groupByTimePeriod(trips, 'day', 'deptime');
    const overTime = grouped.map((group) => {
      const items = group.items;
      return {
        date: group.date,
        total: items.length,
        completed: items.filter((t) => t.status === TRIP_STATUS.COMPLETED).length,
        cancelled: items.filter((t) => t.status === TRIP_STATUS.CANCELLED).length,
        scheduled: items.filter((t) => t.status === TRIP_STATUS.SCHEDULED).length,
        open: items.filter((t) => t.status === TRIP_STATUS.OPEN).length,
        inProgress: items.filter((t) => t.status === TRIP_STATUS.IN_PROGRESS).length,
      };
    });

    trips.forEach((trip) => {
      if (trip.totalbookings > 0 && trip.availableseats !== undefined) {
        const totalSeats = (trip.totalbookings || 0) + (trip.availableseats || 0);
        if (totalSeats > 0) {
          totalUtilization += (trip.totalbookings || 0) / totalSeats;
          tripsWithBookings++;
        }
      }
    });

    const averageUtilization = tripsWithBookings > 0 ? totalUtilization / tripsWithBookings : 0;
    const completionRate = totalTrips > 0 ? (completed / totalTrips) * 100 : 0;
    const cancellationRate = totalTrips > 0 ? (cancelled / totalTrips) * 100 : 0;

    const response = {
      totalTrips,
      completed,
      cancelled,
      scheduled,
      open,
      inProgress,
      averageUtilization,
      completionRate,
      cancellationRate,
      overTime,
      stats: calculateStats(overTime.map(d => d.total)),
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let previousTrips = allTrips.filter(
        (t) => new Date(t.deptime) >= new Date(previousStartDate) &&
          new Date(t.deptime) <= new Date(previousEndDate)
      );

      const prevCompleted = previousTrips.filter((t) => t.status === TRIP_STATUS.COMPLETED).length;
      const prevCancelled = previousTrips.filter((t) => t.status === TRIP_STATUS.CANCELLED).length;
      const prevCompletionRate = previousTrips.length > 0 ? (prevCompleted / previousTrips.length) * 100 : 0;

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        totalTrips: previousTrips.length,
        completed: prevCompleted,
        cancelled: prevCancelled,
        completionRate: prevCompletionRate,
      };
      response.percentageChange = {
        totalTrips: calculatePercentageChange(totalTrips, previousTrips.length),
        completed: calculatePercentageChange(completed, prevCompleted),
        completionRate: completionRate - prevCompletionRate,
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getUserGrowth = async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day', comparePrevious = 'false' } = req.query;

    let allUsers = await User.findAll();

    // Current period
    let users = [...allUsers];
    if (startDate) {
      users = users.filter((u) => {
        const createdAt = u.createdat || u.created_at;
        return createdAt && new Date(createdAt) >= new Date(startDate);
      });
    }
    if (endDate) {
      users = users.filter((u) => {
        const createdAt = u.createdat || u.created_at;
        return createdAt && new Date(createdAt) <= new Date(endDate);
      });
    }

    const dateField = users.length > 0 && users[0].createdat ? 'createdat' : 'created_at';
    const grouped = groupByTimePeriod(users, groupBy, dateField);
    const data = grouped.map((group) => ({
      date: group.date,
      total: group.items.length,
      drivers: group.items.filter((u) => u.role === USER_ROLES.DRIVER).length,
      passengers: group.items.filter((u) => u.role === USER_ROLES.PASSENGER).length,
      admins: group.items.filter((u) => u.role === USER_ROLES.ADMIN).length,
    }));

    const byRole = {
      drivers: users.filter((u) => u.role === USER_ROLES.DRIVER).length,
      passengers: users.filter((u) => u.role === USER_ROLES.PASSENGER).length,
      admins: users.filter((u) => u.role === USER_ROLES.ADMIN).length,
    };

    const activeUsers = users.filter((u) => u.active !== false).length;
    const inactiveUsers = users.length - activeUsers;

    // Calculate growth rate
    const growthRate = data.length >= 2
      ? calculatePercentageChange(
        data.slice(data.length / 2).reduce((sum, d) => sum + d.total, 0),
        data.slice(0, data.length / 2).reduce((sum, d) => sum + d.total, 0)
      )
      : 0;

    const response = {
      data,
      byRole,
      active: activeUsers,
      inactive: inactiveUsers,
      total: users.length,
      growthRate,
      stats: calculateStats(data.map(d => d.total)),
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let previousUsers = allUsers.filter((u) => {
        const createdAt = u.createdat || u.created_at;
        return createdAt &&
          new Date(createdAt) >= new Date(previousStartDate) &&
          new Date(createdAt) <= new Date(previousEndDate);
      });

      const prevByRole = {
        drivers: previousUsers.filter((u) => u.role === USER_ROLES.DRIVER).length,
        passengers: previousUsers.filter((u) => u.role === USER_ROLES.PASSENGER).length,
        admins: previousUsers.filter((u) => u.role === USER_ROLES.ADMIN).length,
      };

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        total: previousUsers.length,
        byRole: prevByRole,
      };
      response.percentageChange = {
        total: calculatePercentageChange(users.length, previousUsers.length),
        drivers: calculatePercentageChange(byRole.drivers, prevByRole.drivers),
        passengers: calculatePercentageChange(byRole.passengers, prevByRole.passengers),
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getVehicleUtilization = async (req, res, next) => {
  try {
    const { startDate, endDate, comparePrevious = 'false' } = req.query;

    let allTrips = await Trip.findAll();
    const vehicles = await Vehicle.findAll();

    // Current period
    let trips = [...allTrips];
    if (startDate) {
      trips = trips.filter((t) => new Date(t.deptime) >= new Date(startDate));
    }
    if (endDate) {
      trips = trips.filter((t) => new Date(t.deptime) <= new Date(endDate));
    }

    const vehicleUtilization = {};
    const vehicleStatusCount = {};

    vehicles.forEach((v) => {
      vehicleStatusCount[v.status] = (vehicleStatusCount[v.status] || 0) + 1;
      vehicleUtilization[v.vehicleid] = {
        vehicleid: v.vehicleid,
        plateno: v.plateno,
        tripCount: 0,
        totalBookings: 0,
        utilization: 0,
      };
    });

    trips.forEach((trip) => {
      if (trip.vehicleid && vehicleUtilization[trip.vehicleid]) {
        vehicleUtilization[trip.vehicleid].tripCount++;
        vehicleUtilization[trip.vehicleid].totalBookings += trip.totalbookings || 0;
      }
    });

    Object.keys(vehicleUtilization).forEach((vehicleid) => {
      const v = vehicleUtilization[vehicleid];
      if (v.tripCount > 0) {
        v.utilization = v.totalBookings / (v.tripCount * 10); // Assuming average capacity
      }
    });

    const grouped = groupByTimePeriod(trips, 'day', 'deptime');
    const activeVehiclesOverTime = grouped.map((group) => {
      const uniqueVehicles = new Set();
      group.items.forEach((trip) => {
        if (trip.vehicleid) {
          uniqueVehicles.add(trip.vehicleid);
        }
      });
      return {
        date: group.date,
        activeVehicles: uniqueVehicles.size,
        tripCount: group.items.length,
      };
    });

    // Calculate fleet statistics
    const utilizationValues = Object.values(vehicleUtilization).map(v => v.utilization);
    const averageFleetUtilization = utilizationValues.length > 0
      ? utilizationValues.reduce((a, b) => a + b, 0) / utilizationValues.length
      : 0;

    const activeVehicleCount = Object.values(vehicleUtilization).filter(v => v.tripCount > 0).length;
    const idleVehicleCount = vehicles.length - activeVehicleCount;

    const response = {
      vehicleUtilization: Object.values(vehicleUtilization),
      vehicleStatusCount,
      activeVehiclesOverTime,
      fleetStats: {
        totalVehicles: vehicles.length,
        activeVehicles: activeVehicleCount,
        idleVehicles: idleVehicleCount,
        averageUtilization: averageFleetUtilization,
        utilizationStats: calculateStats(utilizationValues),
      },
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let previousTrips = allTrips.filter(
        (t) => new Date(t.deptime) >= new Date(previousStartDate) &&
          new Date(t.deptime) <= new Date(previousEndDate)
      );

      const prevVehicleUtilization = {};
      vehicles.forEach((v) => {
        prevVehicleUtilization[v.vehicleid] = { tripCount: 0, totalBookings: 0, utilization: 0 };
      });
      previousTrips.forEach((trip) => {
        if (trip.vehicleid && prevVehicleUtilization[trip.vehicleid]) {
          prevVehicleUtilization[trip.vehicleid].tripCount++;
          prevVehicleUtilization[trip.vehicleid].totalBookings += trip.totalbookings || 0;
        }
      });
      Object.keys(prevVehicleUtilization).forEach((vid) => {
        const v = prevVehicleUtilization[vid];
        if (v.tripCount > 0) v.utilization = v.totalBookings / (v.tripCount * 10);
      });

      const prevUtilValues = Object.values(prevVehicleUtilization).map(v => v.utilization);
      const prevAvgUtilization = prevUtilValues.length > 0
        ? prevUtilValues.reduce((a, b) => a + b, 0) / prevUtilValues.length
        : 0;
      const prevActiveCount = Object.values(prevVehicleUtilization).filter(v => v.tripCount > 0).length;

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        tripCount: previousTrips.length,
        activeVehicles: prevActiveCount,
        averageUtilization: prevAvgUtilization,
      };
      response.percentageChange = {
        tripCount: calculatePercentageChange(trips.length, previousTrips.length),
        activeVehicles: calculatePercentageChange(activeVehicleCount, prevActiveCount),
        utilization: (averageFleetUtilization - prevAvgUtilization) * 100,
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getLinePerformance = async (req, res, next) => {
  try {
    const { startDate, endDate, comparePrevious = 'false' } = req.query;

    let allTrips = await Trip.findAll();
    let allReservations = await Reservation.findAll();
    const lines = await Line.findAll();
    const completedPayments = await Payment.findAll({
      status: PAYMENT_STATUS.COMPLETED,
    });

    // Helper to calculate line performance for a period
    const calculateLinePerf = (trips, reservations) => {
      const linePerf = {};
      lines.forEach((line) => {
        linePerf[line.lineid] = {
          lineid: line.lineid,
          linename: line.linename,
          revenue: 0,
          bookings: 0,
          trips: 0,
          utilization: 0,
        };
      });

      trips.forEach((trip) => {
        if (trip.lineid && linePerf[trip.lineid]) {
          linePerf[trip.lineid].trips++;
          if (trip.totalbookings > 0 && trip.availableseats !== undefined) {
            const totalSeats = (trip.totalbookings || 0) + (trip.availableseats || 0);
            if (totalSeats > 0) {
              linePerf[trip.lineid].utilization +=
                (trip.totalbookings || 0) / totalSeats;
            }
          }
        }
      });

      reservations.forEach((res) => {
        const lineid = res.trip?.lineid;
        if (lineid && linePerf[lineid]) {
          linePerf[lineid].bookings++;
          if (res.paymentid) {
            const payment = completedPayments.find((p) => p.paymentid === res.paymentid);
            if (payment) {
              linePerf[lineid].revenue += payment.amount || 0;
            }
          }
        }
      });

      Object.keys(linePerf).forEach((lineid) => {
        const perf = linePerf[lineid];
        if (perf.trips > 0) {
          perf.utilization = perf.utilization / perf.trips;
        }
      });

      return linePerf;
    };

    // Current period
    let trips = [...allTrips];
    let reservations = [...allReservations];
    if (startDate) {
      trips = trips.filter((t) => new Date(t.deptime) >= new Date(startDate));
      reservations = reservations.filter(
        (r) => new Date(r.bookedat) >= new Date(startDate)
      );
    }
    if (endDate) {
      trips = trips.filter((t) => new Date(t.deptime) <= new Date(endDate));
      reservations = reservations.filter(
        (r) => new Date(r.bookedat) <= new Date(endDate)
      );
    }

    const linePerformance = calculateLinePerf(trips, reservations);
    const perfArray = Object.values(linePerformance);

    // Calculate rankings
    const revenueRanking = [...perfArray].sort((a, b) => b.revenue - a.revenue);
    const bookingsRanking = [...perfArray].sort((a, b) => b.bookings - a.bookings);
    const utilizationRanking = [...perfArray].sort((a, b) => b.utilization - a.utilization);

    // Add rankings to performance data
    perfArray.forEach(perf => {
      perf.revenueRank = revenueRanking.findIndex(p => p.lineid === perf.lineid) + 1;
      perf.bookingsRank = bookingsRanking.findIndex(p => p.lineid === perf.lineid) + 1;
      perf.utilizationRank = utilizationRanking.findIndex(p => p.lineid === perf.lineid) + 1;
    });

    // Overall statistics
    const totalRevenue = perfArray.reduce((sum, p) => sum + p.revenue, 0);
    const totalBookings = perfArray.reduce((sum, p) => sum + p.bookings, 0);
    const totalTrips = perfArray.reduce((sum, p) => sum + p.trips, 0);
    const avgUtilization = perfArray.length > 0
      ? perfArray.reduce((sum, p) => sum + p.utilization, 0) / perfArray.length
      : 0;

    const response = {
      linePerformance: perfArray,
      topLines: {
        byRevenue: revenueRanking.slice(0, 5),
        byBookings: bookingsRanking.slice(0, 5),
        byUtilization: utilizationRanking.filter(p => p.trips > 0).slice(0, 5),
      },
      totals: {
        revenue: totalRevenue,
        bookings: totalBookings,
        trips: totalTrips,
        avgUtilization,
      },
    };

    // Previous period comparison
    if (comparePrevious === 'true' && startDate && endDate) {
      const { previousStartDate, previousEndDate } = getPreviousPeriodDates(startDate, endDate);

      let prevTrips = allTrips.filter(
        (t) => new Date(t.deptime) >= new Date(previousStartDate) &&
          new Date(t.deptime) <= new Date(previousEndDate)
      );
      let prevReservations = allReservations.filter(
        (r) => new Date(r.bookedat) >= new Date(previousStartDate) &&
          new Date(r.bookedat) <= new Date(previousEndDate)
      );

      const prevLinePerf = calculateLinePerf(prevTrips, prevReservations);
      const prevPerfArray = Object.values(prevLinePerf);

      const prevTotalRevenue = prevPerfArray.reduce((sum, p) => sum + p.revenue, 0);
      const prevTotalBookings = prevPerfArray.reduce((sum, p) => sum + p.bookings, 0);
      const prevTotalTrips = prevPerfArray.reduce((sum, p) => sum + p.trips, 0);

      response.previousPeriod = {
        startDate: previousStartDate,
        endDate: previousEndDate,
        totals: {
          revenue: prevTotalRevenue,
          bookings: prevTotalBookings,
          trips: prevTotalTrips,
        },
      };
      response.percentageChange = {
        revenue: calculatePercentageChange(totalRevenue, prevTotalRevenue),
        bookings: calculatePercentageChange(totalBookings, prevTotalBookings),
        trips: calculatePercentageChange(totalTrips, prevTotalTrips),
      };
    }

    res.json(response);
  } catch (error) {
    next(error);
  }
};

export const getTimezoneConfig = async (req, res, next) => {
  try {
    const offset = await AppConfig.getTimezoneOffset();

    const timezoneName = offset >= 0 ? `UTC+${offset}` : `UTC${offset}`;

    const timezoneDescriptions = {
      2: 'Palestine Standard Time',
      3: 'Arabia Standard Time',
      '-5': 'Eastern Standard Time',
      0: 'Coordinated Universal Time',
    };

    res.json({
      success: true,
      timezone_offset: offset,
      timezone_name: timezoneName,
      description: timezoneDescriptions[offset] || `UTC${offset >= 0 ? '+' : ''}${offset}`,
    });
  } catch (error) {
    next(error);
  }
};

export const updateTimezoneConfig = async (req, res, next) => {
  try {
    const { timezone_offset } = req.body;

    if (timezone_offset === undefined || timezone_offset === null) {
      return res.status(400).json({
        success: false,
        message: 'timezone_offset is required',
      });
    }

    const offset = parseInt(timezone_offset, 10);
    if (isNaN(offset) || offset < -12 || offset > 14) {
      return res.status(400).json({
        success: false,
        message: 'timezone_offset must be between -12 and 14',
      });
    }

    await AppConfig.setTimezoneOffset(offset);

    const timezoneName = offset >= 0 ? `UTC+${offset}` : `UTC${offset}`;

    res.json({
      success: true,
      message: 'Timezone configuration updated successfully',
      timezone_offset: offset,
      timezone_name: timezoneName,
    });
  } catch (error) {
    next(error);
  }
};

export const getPendingDrivers = async (req, res, next) => {
  try {
    const pendingDrivers = await Driver.findPendingDrivers();
    res.json({
      success: true,
      drivers: pendingDrivers,
      count: pendingDrivers.length,
    });
  } catch (error) {
    next(error);
  }
};

export const getAllDriversWithApprovalStatus = async (req, res, next) => {
  try {
    const { approval_status } = req.query;
    const filters = {};

    if (approval_status) {
      filters.approval_status = approval_status;
    }

    const drivers = await Driver.findAll(filters);
    res.json({
      success: true,
      drivers,
      count: drivers.length,
    });
  } catch (error) {
    next(error);
  }
};

export const approveDriver = async (req, res, next) => {
  try {
    const { driverid } = req.params;
    const { rejection_reason } = req.body;

    const driver = await Driver.findById(driverid);
    if (!driver) {
      return res.status(404).json({
        success: false,
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    if (!driver.user || driver.user.role?.toUpperCase() !== 'DRIVER') {
      logger.warn('Attempt to approve non-driver user', {
        driverid,
        user_role: driver.user?.role,
      });
      return res.status(400).json({
        success: false,
        message: req.t('driver.invalid_role') || 'This user is not a driver',
      });
    }

    const updates = {
      approval_status: 'approved',
      approval_date: new Date().toISOString(),
      approved_by: req.user.userid,
    };

    if (rejection_reason === null || rejection_reason === '') {
      updates.rejection_reason = null;
    }

    const updatedDriver = await Driver.update(driverid, updates);

    logger.info('Driver approved by admin', {
      driverid,
      approved_by: req.user.userid,
      driver_email: driver.user?.email,
    });

    if (driver.user?.email && driver.user.role?.toUpperCase() === 'DRIVER') {
      try {
        const emailResult = await sendDriverApprovalEmail({
          to: driver.user.email,
          driverName: driver.user.fullname || 'Driver',
        });

        if (emailResult.sent) {
          logger.info('Driver approval email sent successfully', {
            driverid,
            email: driver.user.email,
          });
        } else {
          logger.warn('Driver approval email not sent', {
            driverid,
            email: driver.user.email,
            reason: emailResult.reason,
          });
        }
      } catch (emailError) {
        logger.error('Error sending driver approval email', {
          driverid,
          email: driver.user.email,
          error: emailError.message,
        });
      }
    }

    res.json({
      success: true,
      message: req.t('driver.approved') || 'Driver approved successfully',
      driver: updatedDriver,
    });
  } catch (error) {
    next(error);
  }
};

export const rejectDriver = async (req, res, next) => {
  try {
    const { driverid } = req.params;
    const { rejection_reason } = req.body;

    if (!rejection_reason || !rejection_reason.trim()) {
      return res.status(400).json({
        success: false,
        message: req.t('driver.rejection_reason_required') || 'Rejection reason is required',
      });
    }

    const driver = await Driver.findById(driverid);
    if (!driver) {
      return res.status(404).json({
        success: false,
        message: req.t('driver.not_found') || 'Driver not found',
      });
    }

    // Verify this is actually a driver (extra safety check)
    if (!driver.user || driver.user.role?.toUpperCase() !== 'DRIVER') {
      logger.warn('Attempt to reject non-driver user', {
        driverid,
        user_role: driver.user?.role,
      });
      return res.status(400).json({
        success: false,
        message: req.t('driver.invalid_role') || 'This user is not a driver',
      });
    }

    const updates = {
      approval_status: 'rejected',
      approval_date: new Date().toISOString(),
      approved_by: req.user.userid,
      rejection_reason: rejection_reason.trim(),
    };

    const updatedDriver = await Driver.update(driverid, updates);

    logger.info('Driver rejected by admin', {
      driverid,
      rejected_by: req.user.userid,
      driver_email: driver.user?.email,
      rejection_reason: rejection_reason.trim(),
    });

    if (driver.user?.email && driver.user.role?.toUpperCase() === 'DRIVER') {
      try {
        const emailResult = await sendDriverRejectionEmail({
          to: driver.user.email,
          driverName: driver.user.fullname || 'Driver',
          rejectionReason: rejection_reason.trim(),
        });

        if (emailResult.sent) {
          logger.info('Driver rejection email sent successfully', {
            driverid,
            email: driver.user.email,
          });
        } else {
          logger.warn('Driver rejection email not sent', {
            driverid,
            email: driver.user.email,
            reason: emailResult.reason,
          });
        }
      } catch (emailError) {
        logger.error('Error sending driver rejection email', {
          driverid,
          email: driver.user.email,
          error: emailError.message,
        });
      }
    }

    res.json({
      success: true,
      message: req.t('driver.rejected') || 'Driver rejected successfully',
      driver: updatedDriver,
    });
  } catch (error) {
    next(error);
  }
};

