import Admin from '../models/Admin.js';
import User from '../models/User.js';
import Driver from '../models/Driver.js';
import Passenger from '../models/Passenger.js';
import Trip from '../models/Trip.js';
import Reservation from '../models/Reservation.js';
import Line from '../models/Line.js';
import Vehicle from '../models/Vehicle.js';
import Payment from '../models/Payment.js';
import { TRIP_STATUS, RESERVATION_STATUS, VEHICLE_STATUS, USER_ROLES, PAYMENT_STATUS } from '../utils/constants.js';
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

// Helper function to group data by time period
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
    const { startDate, endDate, groupBy = 'day' } = req.query;

    let payments = await Payment.findAll({ status: PAYMENT_STATUS.COMPLETED });

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

    res.json({
      data,
      totalRevenue,
      totalTransactions: payments.length,
    });
  } catch (error) {
    next(error);
  }
};

export const getBookingTimeSeries = async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day' } = req.query;

    let reservations = await Reservation.findAll();

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
        pending: items.filter((r) => r.status === RESERVATION_STATUS.PENDING).length,
      };
    });

    const byStatus = {
      confirmed: reservations.filter((r) => r.status === RESERVATION_STATUS.CONFIRMED).length,
      cancelled: reservations.filter((r) => r.status === RESERVATION_STATUS.CANCELLED).length,
      pending: reservations.filter((r) => r.status === RESERVATION_STATUS.PENDING).length,
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

    res.json({
      data,
      byStatus,
      byLine: Object.values(byLine),
    });
  } catch (error) {
    next(error);
  }
};

export const getTripStatistics = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    let trips = await Trip.findAll();

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
    const inProgress = trips.filter((t) => t.status === TRIP_STATUS.IN_PROGRESS).length;

    let totalUtilization = 0;
    let tripsWithBookings = 0;

    const grouped = groupByTimePeriod(trips, 'day', 'deptime');
    const overTime = grouped.map((group) => {
      const items = group.items;
      return {
        date: group.date,
        completed: items.filter((t) => t.status === TRIP_STATUS.COMPLETED).length,
        cancelled: items.filter((t) => t.status === TRIP_STATUS.CANCELLED).length,
        scheduled: items.filter((t) => t.status === TRIP_STATUS.SCHEDULED).length,
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

    res.json({
      totalTrips,
      completed,
      cancelled,
      scheduled,
      inProgress,
      averageUtilization,
      overTime,
    });
  } catch (error) {
    next(error);
  }
};

export const getUserGrowth = async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day' } = req.query;

    let users = await User.findAll();

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

    res.json({
      data,
      byRole,
      active: activeUsers,
      inactive: inactiveUsers,
      total: users.length,
    });
  } catch (error) {
    next(error);
  }
};

export const getVehicleUtilization = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    let trips = await Trip.findAll();
    const vehicles = await Vehicle.findAll();

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
      };
    });

    res.json({
      vehicleUtilization: Object.values(vehicleUtilization),
      vehicleStatusCount,
      activeVehiclesOverTime,
    });
  } catch (error) {
    next(error);
  }
};

export const getLinePerformance = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;

    let trips = await Trip.findAll();
    let reservations = await Reservation.findAll();
    const lines = await Line.findAll();

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

    const linePerformance = {};

    lines.forEach((line) => {
      linePerformance[line.lineid] = {
        lineid: line.lineid,
        linename: line.linename,
        revenue: 0,
        bookings: 0,
        trips: 0,
        utilization: 0,
      };
    });

    trips.forEach((trip) => {
      if (trip.lineid && linePerformance[trip.lineid]) {
        linePerformance[trip.lineid].trips++;
        if (trip.totalbookings > 0 && trip.availableseats !== undefined) {
          const totalSeats = (trip.totalbookings || 0) + (trip.availableseats || 0);
          if (totalSeats > 0) {
            linePerformance[trip.lineid].utilization +=
              (trip.totalbookings || 0) / totalSeats;
          }
        }
      }
    });

    const completedPayments = await Payment.findAll({
      status: PAYMENT_STATUS.COMPLETED,
    });

    reservations.forEach((res) => {
      const lineid = res.trip?.lineid;
      if (lineid && linePerformance[lineid]) {
        linePerformance[lineid].bookings++;
        if (res.paymentid) {
          const payment = completedPayments.find((p) => p.paymentid === res.paymentid);
          if (payment) {
            linePerformance[lineid].revenue += payment.amount || 0;
          }
        }
      }
    });

    Object.keys(linePerformance).forEach((lineid) => {
      const perf = linePerformance[lineid];
      if (perf.trips > 0) {
        perf.utilization = perf.utilization / perf.trips;
      }
    });

    res.json({
      linePerformance: Object.values(linePerformance),
    });
  } catch (error) {
    next(error);
  }
};

