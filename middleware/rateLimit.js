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

// More lenient limiter for frequently accessed user endpoints
// (notifications, reservations) that may be polled or accessed frequently
export const userDataLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 1 * 60 * 1000, // 1 minute window
  max: isProduction ? 100 : 300, // More requests allowed for frequently accessed endpoints
});
