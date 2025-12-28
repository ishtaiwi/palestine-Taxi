import { v4 as uuidv4 } from 'uuid';
import Driver from '../models/Driver.js';
import Passenger from '../models/Passenger.js';
import Admin from '../models/Admin.js';

const normalizeRole = (role) => (role || '').toLowerCase();

export const requireAdmin = async (req, res, next) => {
  try {
    if (normalizeRole(req.user.role) !== 'admin') {
      return res.status(403).json({ 
        message: req.t?.('auth.admin_required') || 'Admin access required' 
      });
    }
    
    
    let admin = await Admin.findByUserId(req.user.userid);
    if (!admin) {
      admin = await Admin.create({
        id: uuidv4(),
        userid: req.user.userid,
        permissions: [],
      });
    }
    
    req.user.adminid = admin.id;
    req.user.permissions = admin.permissions || [];
    next();
  } catch (error) {
    next(error);
  }
};

export const requireDriver = async (req, res, next) => {
  try {
    if (normalizeRole(req.user.role) !== 'driver') {
      return res.status(403).json({ 
        message: req.t?.('auth.driver_required') || 'Driver access required' 
      });
    }
    
    
    const driver = await Driver.findByUserId(req.user.userid);
    if (!driver) {
      return res.status(403).json({ 
        message: req.t?.('auth.driver_not_found') || 'Driver record not found' 
      });
    }
    
    if (driver.approval_status !== 'approved') {
      const status = driver.approval_status || 'pending';
      return res.status(403).json({ 
        message: status === 'rejected'
          ? (req.t?.('auth.driver_rejected') || 'Your driver account has been rejected. Please contact support.')
          : (req.t?.('auth.driver_pending_approval') || 'Your driver account is pending admin approval.'),
        approvalStatus: status,
      });
    }
    
    req.user.driverid = driver.driverid;
    req.user.driverStatus = driver.status;
    req.user.driverApprovalStatus = driver.approval_status;
    next();
  } catch (error) {
    next(error);
  }
};

export const requirePassenger = async (req, res, next) => {
  try {
    if (normalizeRole(req.user.role) !== 'passenger') {
      return res.status(403).json({ 
        message: req.t?.('auth.passenger_required') || 'Passenger access required' 
      });
    }
    
    
    const passenger = await Passenger.findByUserId(req.user.userid);
    if (!passenger) {
      return res.status(403).json({ 
        message: req.t?.('auth.passenger_not_found') || 'Passenger record not found' 
      });
    }
    
    req.user.passengerid = passenger.passengerid;
    next();
  } catch (error) {
    next(error);
  }
};

export const requireRole = (...roles) => {
  const normalizedRoles = roles.map((role) => normalizeRole(role));
  return async (req, res, next) => {
    try {
      if (!normalizedRoles.includes(normalizeRole(req.user.role))) {
        return res.status(403).json({ 
          message: req.t?.('auth.role_required') || 'Insufficient permissions' 
        });
      }
      next();
    } catch (error) {
      next(error);
    }
  };
};

export const requirePermission = (permission) => {
  return async (req, res, next) => {
    try {
      if (normalizeRole(req.user.role) !== 'admin') {
        return res.status(403).json({ 
          message: req.t?.('auth.permission_required') || 'Permission required' 
        });
      }
      
      const admin = await Admin.findByUserId(req.user.userid);
      if (!admin || !admin.permissions || !admin.permissions.includes(permission)) {
        return res.status(403).json({ 
          message: req.t?.('auth.permission_required') || 'Permission required' 
        });
      }
      
      next();
    } catch (error) {
      next(error);
    }
  };
};

