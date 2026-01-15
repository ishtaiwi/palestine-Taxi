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
  ];
  return frequentPaths.some(path => req.originalUrl.startsWith(path));
};

export const generalLimiter = rateLimit({
  ...baseLimiterConfig,
  max: isProduction ? 200 : 500,
  skip: skipFrequentEndpoints, // Skip general limiter for frequent endpoints
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
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: isProduction ? 1000 : 2000, // Much higher limit for admin endpoints
});

