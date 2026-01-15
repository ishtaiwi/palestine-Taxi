import cron from 'node-cron';
import { checkAndDepartTrips, sendDepartureReminders } from '../services/departureService.js';

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
      
      // Send departure reminders (15 minutes before)
      try {
        const reminderResult = await sendDepartureReminders();
        if (reminderResult.reminded > 0) {
          console.log(`[DepartureCheckJob] 📢 Sent ${reminderResult.reminded} departure reminder(s)`);
        }
      } catch (reminderError) {
        console.error('[DepartureCheckJob] ⚠️ Error sending departure reminders:', reminderError);
      }
      
      // Check and depart trips
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

