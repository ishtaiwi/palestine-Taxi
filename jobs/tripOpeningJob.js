import cron from 'node-cron';
import { openScheduledTrips } from '../services/tripOpeningService.js';

/**
 * Background job to open scheduled trips (runs every minute)
 * Opens trips based on their interval: 30 min intervals = 20 min before, 60 min intervals = 45 min before
 */
export const startTripOpeningJob = () => {
  console.log('[TripOpeningJob] 🚀 Starting trip opening job (runs every minute)');
  
  
  cron.schedule('* * * * *', async () => {
    try {
      console.log('[TripOpeningJob] ⏰ Running trip opening check...');
      
      const result = await openScheduledTrips(45);
      
      if (result.opened > 0) {
        console.log(`[TripOpeningJob] ✅ Opened ${result.opened} trips`);
      }
    } catch (error) {
      console.error('[TripOpeningJob] ❌ Error in trip opening job:', error);
    }
  });
  
  console.log('[TripOpeningJob] ✅ Trip opening job started');
};

