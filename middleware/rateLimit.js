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
    '/api/locations/', // Skip location endpoints - they have their own limiter
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

export const userDataLimiter = rateLimit({
  ...baseLimiterConfig,
  windowMs: 1 * 60 * 1000, // 1 minute
  max: isProduction ? 60 : 120, // Higher limit for frequently accessed user data endpoints
});

/**
 * Location update rate limiter - specifically for GPS location updates from drivers
 * 
 * GPS updates typically happen every 2-5 seconds, so we need:
 * - Short window (10 seconds)
 * - High request limit per window
 * - Per-user keying (based on user ID from JWT token)
 * 
 * This allows ~6 requests per 10 seconds = 36 requests/minute per driver
 * which is generous for GPS updates (typically 1 per 2-5 seconds)
 */
export const locationUpdateLimiter = rateLimit({
  windowMs: 10 * 1000, // 10 second window
  max: isProduction ? 10 : 20, // 10 requests per 10 seconds in production (1 per second)
  standardHeaders: true,
  legacyHeaders: false,
  // Key by user ID if available, otherwise by IP
  keyGenerator: (req) => {
    // Use authenticated user ID if available (from JWT middleware)
    if (req.user?.userid) {
      return `location:${req.user.userid}`;
    }
    // Fallback to IP address
    return `location:ip:${req.ip}`;
  },
  // Custom handler with less verbose logging for location updates
  handler: (req, res) => {
    // Only log once per minute to avoid log spam
    const userId = req.user?.userid || req.ip;
    const cacheKey = `location_limit_logged:${userId}`;
    
    // Use a simple in-memory check (rate limit already handles the limiting)
    if (!global._locationLimitLogCache) {
      global._locationLimitLogCache = new Map();
    }
    
    const now = Date.now();
    const lastLogged = global._locationLimitLogCache.get(cacheKey) || 0;
    
    // Only log once per minute per user
    if (now - lastLogged > 60000) {
      logger.warn('Location update rate limit exceeded', {
        userId: req.user?.userid,
        ip: req.ip,
      });
      global._locationLimitLogCache.set(cacheKey, now);
      
      // Clean up old entries every 5 minutes
      if (global._locationLimitLogCache.size > 1000) {
        const threshold = now - 300000; // 5 minutes
        for (const [key, timestamp] of global._locationLimitLogCache.entries()) {
          if (timestamp < threshold) {
            global._locationLimitLogCache.delete(key);
          }
        }
      }
    }
    
    res.status(429).json({
      message: req.t?.('location.rate_limited') || 'Location updates too frequent. Please wait a moment.',
      retryAfter: 10, // seconds
    });
  },
  // Skip rate limiting in development if needed for testing
  skip: (req) => {
    return false; // Always apply rate limiting
  },
});

/**
 * Realtime data rate limiter - for endpoints that need frequent polling
 * but less frequent than location updates
 */
export const realtimeLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute window
  max: isProduction ? 120 : 240, // 2 requests per second average
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