import cron from 'node-cron';
import { createDailyTrips } from '../services/dailyTripService.js';
import logger from '../utils/logger.js';

/**
 * Daily trip creation job
 * Runs every day at 11:00 PM to create trips for tomorrow
 */
export function startDailyTripCreationJob() {
  // Run at 11:00 PM every day
  // Cron format: minute hour day month day-of-week
  // '0 23 * * *' = At 23:00 (11:00 PM) every day
  const cronExpression = '04 12 * * *';

  logger.info('Starting daily trip creation job', {
    schedule: 'Every day at 11:00 PM',
    cronExpression,
  });

  cron.schedule(cronExpression, async () => {
    try {
      logger.info('Daily trip creation job triggered');
      const result = await createDailyTrips();

      if (result.success) {
        logger.info('Daily trip creation job completed successfully', {
          templatesProcessed: result.templatesProcessed,
          totalTripsCreated: result.totalTripsCreated,
        });
      } else {
        logger.error('Daily trip creation job failed', {
          error: result.error,
        });
      }
    } catch (error) {
      logger.error('Error in daily trip creation job', {
        error: error.message,
        stack: error.stack,
      });
    }
  });

  logger.info('Daily trip creation job scheduled');
}

