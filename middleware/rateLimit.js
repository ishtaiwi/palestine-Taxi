import rateLimit from 'express-rate-limit';
import appConfig from '../config/app.js';
import logger from '../utils/logger.js';

const isProduction = appConfig.nodeEnv === 'production';

const baseLimiterConfig = {
  windowMs: 15 * 60 * 1000,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      path: req.originalUrl,
      method: req.method,
    });
    res.status(429).json({
      message: req.t?.('auth.rate_limited') || 'Too many requests, please try again later.',
    });
  },
};

// Create a skip function for frequently accessed endpoints
const skipFrequentEndpoints = (req) => {
  const frequentPaths = [
    '/api/reservations/my-reservations',
    '/api/notifications/unread-count',
    '/api/locations/',
  ];
  return frequentPaths.some(path => req.originalUrl.startsWith(path));
};

export const generalLimiter = rateLimit({
  ...baseLimiterConfig,
  max: isProduction ? 200 : 500,
  skip: skipFrequentEndpoints,
});

export const authLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 10 * 60 * 1000,
  max: isProduction ? 5 : 15,
});

export const passwordResetLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 60 * 60 * 1000,
  max: isProduction ? 3 : 10,
});

export const adminLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 15 * 60 * 1000,
  max: isProduction ? 1000 : 2000,
});

export const userDataLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 1 * 60 * 1000,
  max: isProduction ? 60 : 120,
});

export const locationUpdateLimiter = rateLimit({
  windowMs: 10 * 1000,
  max: isProduction ? 10 : 20,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    if (req.user?.userid) {
      return `location:${req.user.userid}`;
    }
    return `location:ip:${req.ip}`;
  },
  handler: (req, res) => {
    const userId = req.user?.userid || req.ip;
    const cacheKey = `location_limit_logged:${userId}`;
    if (!global._locationLimitLogCache) {
      global._locationLimitLogCache = new Map();
    }
    const now = Date.now();
    const lastLogged = global._locationLimitLogCache.get(cacheKey) || 0;
    if (now - lastLogged > 60000) {
      logger.warn('Location update rate limit exceeded', {
        userId: req.user?.userid,
        ip: req.ip,
      });
      global._locationLimitLogCache.set(cacheKey, now);
      if (global._locationLimitLogCache.size > 1000) {
        const threshold = now - 300000;
        for (const [key, timestamp] of global._locationLimitLogCache.entries()) {
          if (timestamp < threshold) {
            global._locationLimitLogCache.delete(key);
          }
        }
      }
    }
    res.status(429).json({
      message: req.t?.('location.rate_limited') || 'Location updates too frequent. Please wait a moment.',
      retryAfter: 10,
    });
  },
  skip: (req) => {
    return false;
  },
});

export const realtimeLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: isProduction ? 120 : 240,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => {
    if (req.user?.userid) {
      return `realtime:${req.user.userid}`;
    }
    return `realtime:ip:${req.ip}`;
  },
  handler: (req, res) => {
    res.status(429).json({
      message: req.t?.('auth.rate_limited') || 'Too many requests, please try again later.',
      retryAfter: 60,
    });
  },
});
