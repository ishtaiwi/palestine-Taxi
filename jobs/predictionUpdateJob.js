import cron from 'node-cron';
import logger from '../utils/logger.js';
import {
  trainModelBulk,
  getModelSummary,
} from '../services/rushHourPredictionService.js';
import { generateScheduleRecommendations } from '../services/recommendationService.js';

const CRON_EXPRESSION = '15 2 * * *'; // 02:15 AM daily

export function startPredictionUpdateJob() {
  logger.info('Scheduling prediction update job', {
    cronExpression: CRON_EXPRESSION,
  });

  cron.schedule(CRON_EXPRESSION, async () => {
    logger.info('Prediction update job triggered');
    try {
      const trainingResult = await trainModelBulk();
      const recommendations = await generateScheduleRecommendations({
        daysAhead: Number(process.env.PREDICTION_FORWARD_DAYS || 7),
      });

      logger.info('Prediction update job completed', {
        trainingResult,
        recommendationsGenerated: recommendations.length,
        modelSummary: getModelSummary(),
      });
    } catch (error) {
      logger.error('Prediction update job failed', {
        error: error.message,
        stack: error.stack,
      });
    }
  });
}

