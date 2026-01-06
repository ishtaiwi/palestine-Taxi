import cron from 'node-cron';
import { markTripsAsDelayed } from '../services/tripOpeningService.js';
import logger from '../utils/logger.js';

/**
 * Background job to mark trips as delayed (runs every minute)
 * Marks trips as delayed if:
 * - They have no vehicle 1 minute before departure, OR
 * - They have reservations and departure time has passed
 */
export const startDelayedTripCheckJob = () => {
  logger.info('[DelayedTripCheckJob] 🚀 Starting delayed trip check job (runs every minute)');
  
  // Run every minute
  cron.schedule('* * * * *', async () => {
    try {
      logger.debug('[DelayedTripCheckJob] ⏰ Running delayed trip check...');
      const result = await markTripsAsDelayed();
      
      if (result.marked > 0) {
        logger.info(`[DelayedTripCheckJob] ⚠️ Marked ${result.marked} trips as delayed`);
      }
    } catch (error) {
      logger.error('[DelayedTripCheckJob] ❌ Error in delayed trip check job:', error);
    }
  });
  
  logger.info('[DelayedTripCheckJob] ✅ Delayed trip check job started');
};

