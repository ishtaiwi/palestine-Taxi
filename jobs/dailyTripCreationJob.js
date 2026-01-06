import cron from 'node-cron';
import { createDailyTrips } from '../services/dailyTripService.js';
import logger from '../utils/logger.js';

export function startDailyTripCreationJob() {
  const cronExpression = '43 12 * * *';

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

