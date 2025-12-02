import cron from 'node-cron';
import { checkNoShowForDepartingTrips } from '../services/noShowService.js';

/**
 * Background job to check and mark No-Show reservations (runs every 2 minutes)
 * Marks reservations as No-Show if passenger didn't check in before trip departure
 */
export const startNoShowCheckJob = () => {
  console.log('[NoShowCheckJob] 🚀 Starting No-Show check job (runs every 2 minutes)');
  
  // Run every 2 minutes
  cron.schedule('*/2 * * * *', async () => {
    try {
      console.log('[NoShowCheckJob] ⏰ Running No-Show check...');
      const result = await checkNoShowForDepartingTrips();
      
      if (result.totalMarked > 0) {
        console.log(`[NoShowCheckJob] ✅ Marked ${result.totalMarked} reservations as No-Show`);
      }
    } catch (error) {
      console.error('[NoShowCheckJob] ❌ Error in No-Show check job:', error);
    }
  });
  
  console.log('[NoShowCheckJob] ✅ No-Show check job started');
};

