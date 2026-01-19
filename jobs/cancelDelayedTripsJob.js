import cron from 'node-cron';
import { cancelDelayedTripsWithNoBookings } from '../services/tripOpeningService.js';
import logger from '../utils/logger.js';

/**
 * Background job to cancel delayed trips that have no bookings
 * Runs every minute to clean up trips that were marked as delayed but never received any bookings
 */
export const startCancelDelayedTripsJob = () => {
  logger.info('[CancelDelayedTripsJob] 🚀 Starting cancel delayed trips job (runs every minute)');

  // Run every minute
  cron.schedule('* * * * *', async () => {
    try {
      logger.debug('[CancelDelayedTripsJob] ⏰ Running cancel delayed trips check...');
      const result = await cancelDelayedTripsWithNoBookings();

      if (result.cancelled > 0) {
        logger.info(`[CancelDelayedTripsJob] 🚫 Cancelled ${result.cancelled} delayed trips with no bookings`);
      }
    } catch (error) {
      logger.error('[CancelDelayedTripsJob] ❌ Error in cancel delayed trips job:', error);
    }
  });

  logger.info('[CancelDelayedTripsJob] ✅ Cancel delayed trips job started');
};
