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

