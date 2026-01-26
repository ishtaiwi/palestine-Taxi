import jwt from 'jsonwebtoken';
import appConfig from '../config/app.js';
import User from '../models/User.js';

export const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ 
        message: req.t?.('auth.no_token') || 'No token provided' 
      });
    }
    
    const decoded = jwt.verify(token, appConfig.jwt.secret);
    const user = await User.findById(decoded.userid);
    
    if (!user) {
      return res.status(401).json({ 
        message: req.t?.('auth.invalid_token') || 'Invalid token' 
      });
    }
    
    // Check if user is active
    if (user.active === false) {
      return res.status(403).json({ 
        message: req.t?.('auth.account_inactive') || 'Your account has been deactivated. Please contact support.' 
      });
    }
    
    req.user = {
      userid: user.userid,
      role: user.role,
      ...decoded,
    };
    
    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        message: req.t?.('auth.invalid_token') || 'Invalid token' 
      });
    }
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        message: req.t?.('auth.token_expired') || 'Token expired' 
      });
    }
    next(error);
  }
};

export const optionalAuth = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (token) {
      const decoded = jwt.verify(token, appConfig.jwt.secret);
      const user = await User.findById(decoded.userid);
      
      if (user) {
        req.user = {
          userid: user.userid,
          role: user.role,
          ...decoded,
        };
      }
    }
    
    next();
  } catch (error) {
    
    next();
  }
};

