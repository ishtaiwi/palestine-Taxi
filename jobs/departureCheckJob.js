import cron from 'node-cron';
import { checkAndDepartTrips } from '../services/departureService.js';

/**
 * Background job to check and depart trips (runs every minute)
 * Checks for:
 * - Early departure (vehicle is full)
 * - Scheduled departure (time has arrived)
 * - Future booking rule (at least one future booking)
 */
export const startDepartureCheckJob = () => {
  console.log('[DepartureCheckJob] 🚀 Starting departure check job (runs every minute)');
  
  // Run every minute
  cron.schedule('* * * * *', async () => {
    try {
      console.log('[DepartureCheckJob] ⏰ Running departure check...');
      const result = await checkAndDepartTrips();
      
      if (result.departed > 0) {
        console.log(`[DepartureCheckJob] ✅ Departed ${result.departed} trips`);
      }
    } catch (error) {
      console.error('[DepartureCheckJob] ❌ Error in departure check job:', error);
    }
  });
  
  console.log('[DepartureCheckJob] ✅ Departure check job started');
};

