import cron from 'node-cron';
import { openScheduledTrips } from '../services/tripOpeningService.js';

/**
 * Background job to open scheduled trips (runs every minute)
 * Opens trips 45 minutes before their scheduled departure time
 */
export const startTripOpeningJob = () => {
  console.log('[TripOpeningJob] 🚀 Starting trip opening job (runs every minute)');
  
  // Run every minute
  cron.schedule('* * * * *', async () => {
    try {
      console.log('[TripOpeningJob] ⏰ Running trip opening check...');
      const result = await openScheduledTrips(45); // 45 minutes before departure
      
      if (result.opened > 0) {
        console.log(`[TripOpeningJob] ✅ Opened ${result.opened} trips`);
      }
    } catch (error) {
      console.error('[TripOpeningJob] ❌ Error in trip opening job:', error);
    }
  });
  
  console.log('[TripOpeningJob] ✅ Trip opening job started');
};

