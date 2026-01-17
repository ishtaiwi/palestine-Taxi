import { getMessaging, isFirebaseInitialized } from '../config/firebase.js';
import Notification from '../models/Notification.js';
import UserFcmToken from '../models/UserFcmToken.js';
import User from '../models/User.js';
import { getNotificationContent, NOTIFICATION_TYPES } from '../utils/notificationTemplates.js';
import logger from '../utils/logger.js';

/**
 * Send a push notification to a user
 * @param {string} userid - User ID to send notification to
 * @param {string} notificationType - Type of notification (from NOTIFICATION_TYPES)
 * @param {object} data - Data for template substitution and notification payload
 * @param {string} language - Language code ('ar' or 'en'), defaults to 'ar'
 * @returns {Promise<object>} - Result object with success status
 */
export const sendNotification = async (userid, notificationType, data = {}, language = null, rawData = null) => {
  try {
    // Get user to determine language preference if not provided
    let userLanguage = language;
    if (!userLanguage) {
      try {
        const user = await User.findById(userid);
        // Check if user has language preference (defaults to 'ar' if not set)
        // language_preference can be 'ar' or 'en'
        userLanguage = user?.language_preference;
        
        // If not set in database, default to Arabic
        if (!userLanguage || (userLanguage !== 'en' && userLanguage !== 'ar')) {
          userLanguage = 'ar';
        }
      } catch (error) {
        logger.warn(`[NotificationService] Could not fetch user ${userid} for language preference:`, error.message);
        userLanguage = 'ar'; // Default to Arabic
      }
    }
    
    // Log for debugging
    logger.info(`[NotificationService] Sending ${notificationType} to user ${userid} in language: ${userLanguage}`);

    // Format data separately for Arabic and English when saving to database
    let dataAr = data;
    let dataEn = data;
    
    // If rawData is provided (contains line and trip objects), format separately
    if (rawData && (rawData.line || rawData.trip)) {
      const { getLineNamesForNotification } = await import('../utils/lineHelpers.js');
      const { DateTime } = await import('luxon');
      
      const line = rawData.line;
      const trip = rawData.trip;
      
      if (line) {
        // Get trip direction if available
        const tripDirection = trip?.direction || 'going';
        
        // Format for Arabic
        try {
          const { fromName: fromNameAr, toName: toNameAr } = await getLineNamesForNotification(line, userid, null, 'ar', tripDirection);
          // Only use re-fetched values if they are valid (not null, not empty, not 'Unknown')
          // Check for corrupted data like ".ijn" or very short strings that might be partial names
          // Also check if both values are the same (which means it's the line name fallback)
          // More strict validation: names must be at least 3 chars, not start with '.', not be common corrupted patterns
          const isValidFromAr = fromNameAr && 
            fromNameAr !== 'Unknown' && 
            fromNameAr.trim().length >= 3 && 
            !fromNameAr.trim().startsWith('.') &&
            !fromNameAr.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
          const isValidToAr = toNameAr && 
            toNameAr !== 'Unknown' && 
            toNameAr.trim().length >= 3 && 
            !toNameAr.trim().startsWith('.') &&
            !toNameAr.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
          const isLineNameFallback = fromNameAr && toNameAr && fromNameAr.trim() === toNameAr.trim();
          
          // If both values are valid AND different (not line name fallback), use them
          // Otherwise, prefer values from data object if they exist and are different
          if (isValidFromAr && isValidToAr && !isLineNameFallback) {
            dataAr = { ...data, from: fromNameAr.trim(), to: toNameAr.trim() };
          } else if (isLineNameFallback && data.from && data.to && data.from !== data.to) {
            // If re-fetch returned line name (same for both), but data has different values, use data
            dataAr = { ...data };
            logger.warn(`[NotificationService] Re-fetch returned line name fallback (Arabic). Using values from data object instead. From: ${data.from}, To: ${data.to}`);
          } else {
            // Fallback to values from data if re-fetch returns invalid values
            // Use data.from and data.to if they exist and are valid, otherwise keep the invalid values for debugging
            // Also validate data values - reject common corrupted patterns
            const isDataFromValid = data.from && data.from.trim().length >= 3 && 
              !data.from.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
            const isDataToValid = data.to && data.to.trim().length >= 3 && 
              !data.to.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
            
            if (isDataFromValid && isDataToValid) {
              dataAr = { ...data };
            } else {
              // If both re-fetch and data are invalid, use re-fetched values anyway (better than empty)
              dataAr = { ...data, from: (fromNameAr && fromNameAr.trim()) || data.from || 'Unknown', to: (toNameAr && toNameAr.trim()) || data.to || 'Unknown' };
            }
            logger.warn(`[NotificationService] Invalid station names from getLineNamesForNotification (Arabic). From: ${fromNameAr}, To: ${toNameAr}. Data object has: From: ${data.from}, To: ${data.to}`);
          }
        } catch (error) {
          // Fallback to values from data if re-fetch fails
          dataAr = { ...data };
          logger.warn(`[NotificationService] Error fetching station names for Arabic:`, error);
        }
        
        // Format for English
        try {
          const { fromName: fromNameEn, toName: toNameEn } = await getLineNamesForNotification(line, userid, null, 'en', tripDirection);
          // Only use re-fetched values if they are valid (not null, not empty, not 'Unknown')
          // Check for corrupted data like ".ijn" or very short strings that might be partial names
          // Also check if both values are the same (which means it's the line name fallback)
          // More strict validation: names must be at least 3 chars, not start with '.', not be common corrupted patterns
          const isValidFromEn = fromNameEn && 
            fromNameEn !== 'Unknown' && 
            fromNameEn.trim().length >= 3 && 
            !fromNameEn.trim().startsWith('.') &&
            !fromNameEn.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
          const isValidToEn = toNameEn && 
            toNameEn !== 'Unknown' && 
            toNameEn.trim().length >= 3 && 
            !toNameEn.trim().startsWith('.') &&
            !toNameEn.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
          const isLineNameFallback = fromNameEn && toNameEn && fromNameEn.trim() === toNameEn.trim();
          
          // If both values are valid AND different (not line name fallback), use them
          // Otherwise, prefer values from data object if they exist and are different
          if (isValidFromEn && isValidToEn && !isLineNameFallback) {
            dataEn = { ...data, from: fromNameEn.trim(), to: toNameEn.trim() };
          } else if (isLineNameFallback && data.from && data.to && data.from !== data.to) {
            // If re-fetch returned line name (same for both), but data has different values, use data
            dataEn = { ...data };
            logger.warn(`[NotificationService] Re-fetch returned line name fallback (English). Using values from data object instead. From: ${data.from}, To: ${data.to}`);
          } else {
            // Fallback to values from data if re-fetch returns invalid values
            // Use data.from and data.to if they exist and are valid, otherwise keep the invalid values for debugging
            // Also validate data values - reject common corrupted patterns
            const isDataFromValid = data.from && data.from.trim().length >= 3 && 
              !data.from.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
            const isDataToValid = data.to && data.to.trim().length >= 3 && 
              !data.to.trim().toLowerCase().match(/^(ijn|ij|main|station|unknown)$/i);
            
            if (isDataFromValid && isDataToValid) {
              dataEn = { ...data };
            } else {
              // If both re-fetch and data are invalid, use re-fetched values anyway (better than empty)
              dataEn = { ...data, from: (fromNameEn && fromNameEn.trim()) || data.from || 'Unknown', to: (toNameEn && toNameEn.trim()) || data.to || 'Unknown' };
            }
            logger.warn(`[NotificationService] Invalid station names from getLineNamesForNotification (English). From: ${fromNameEn}, To: ${toNameEn}. Data object has: From: ${data.from}, To: ${data.to}`);
          }
        } catch (error) {
          // Fallback to values from data if re-fetch fails
          dataEn = { ...data };
          logger.warn(`[NotificationService] Error fetching station names for English:`, error);
        }
        
        // Format time if trip is provided (only use trip.deptime, not data.time which is already formatted)
        if (trip?.deptime) {
          const date = DateTime.fromISO(new Date(trip.deptime).toISOString());
          
          // Arabic time format
          const timeAr = date.setLocale('ar').toLocaleString({ 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit'
          });
          dataAr = { ...dataAr, time: timeAr };
          
          // English time format
          const timeEn = date.setLocale('en').toLocaleString({ 
            year: 'numeric', 
            month: 'long', 
            day: 'numeric', 
            hour: '2-digit', 
            minute: '2-digit',
            hour12: true
          });
          dataEn = { ...dataEn, time: timeEn };
        } else if (data.time) {
          // If no trip.deptime but data.time exists, use it as-is for both (already formatted)
          // This handles cases where time is passed but no trip object
          dataAr = { ...dataAr, time: data.time };
          dataEn = { ...dataEn, time: data.time };
        }
      }
    }
    
    // Format data for the user's language (for FCM and display)
    // Use the language-specific formatted data if rawData was provided, otherwise use original data
    const formattedData = (rawData && (rawData.line || rawData.trip)) 
      ? (userLanguage === 'en' ? dataEn : dataAr)
      : data;

    // Log for debugging
    if (rawData && (rawData.line || rawData.trip)) {
      logger.info(`[NotificationService] Formatted notification data - Language: ${userLanguage}, From: ${formattedData.from}, To: ${formattedData.to}, Time: ${formattedData.time || 'N/A'}`);
    }

    // Get notification content
    const content = getNotificationContent(notificationType, userLanguage, formattedData);

    // Get user's FCM tokens
    const tokens = await UserFcmToken.findByUserId(userid, true);
    
    if (!tokens || tokens.length === 0) {
      logger.info(`[NotificationService] No FCM tokens found for user ${userid}, saving notification to database only`);
      
      // Save notification to database even if no tokens
      const notificationData = {
        userid,
        type: notificationType,
        title_ar: getNotificationContent(notificationType, 'ar', dataAr).title,
        title_en: getNotificationContent(notificationType, 'en', dataEn).title,
        body_ar: getNotificationContent(notificationType, 'ar', dataAr).body,
        body_en: getNotificationContent(notificationType, 'en', dataEn).body,
        data: formattedData,
        fcm_sent: false,
      };

      await Notification.create(notificationData);
      return {
        success: true,
        message: 'Notification saved to database (no FCM tokens)',
        notificationSaved: true,
        fcmSent: false,
      };
    }

    // Check if Firebase is initialized
    if (!isFirebaseInitialized()) {
      logger.warn('[NotificationService] Firebase not initialized, saving notification to database only');
      
      const notificationData = {
        userid,
        type: notificationType,
        title_ar: getNotificationContent(notificationType, 'ar', dataAr).title,
        title_en: getNotificationContent(notificationType, 'en', dataEn).title,
        body_ar: getNotificationContent(notificationType, 'ar', dataAr).body,
        body_en: getNotificationContent(notificationType, 'en', dataEn).body,
        data: formattedData,
        fcm_sent: false,
      };

      await Notification.create(notificationData);
      return {
        success: true,
        message: 'Notification saved to database (Firebase not initialized)',
        notificationSaved: true,
        fcmSent: false,
      };
    }

    const messaging = getMessaging();
    if (!messaging) {
      throw new Error('Firebase messaging not available');
    }

    // Prepare FCM message
    const fcmTokens = tokens.map(t => t.fcm_token);
    const fcmMessage = {
      notification: {
        title: content.title,
        body: content.body,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          sound: 'default',
          priority: 'high',
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            alert: {
              title: content.title,
              body: content.body,
            },
          },
        },
      },
      data: {
        type: notificationType,
        ...Object.keys(formattedData).reduce((acc, key) => {
          acc[key] = String(formattedData[key] || '');
          return acc;
        }, {}),
      },
      tokens: fcmTokens,
    };

    // Send notification via FCM
    let fcmSent = false;
    let fcmSentAt = null;
    let fcmError = null;

    try {
      const response = await messaging.sendEachForMulticast(fcmMessage);
      
      if (response.successCount > 0) {
        fcmSent = true;
        fcmSentAt = new Date().toISOString();
        logger.info(`[NotificationService] ✅ Sent notification to user ${userid}: ${response.successCount} device(s)`);
        
        // Update last_used_at for successful tokens
        const successfulTokens = tokens.filter((_, index) => {
          return response.responses[index]?.success === true;
        });
        
        for (const token of successfulTokens) {
          try {
            await UserFcmToken.updateLastUsed(token.tokenid);
          } catch (error) {
            logger.warn(`[NotificationService] Failed to update last_used_at for token ${token.tokenid}:`, error.message);
          }
        }

        // Deactivate failed tokens
        const failedTokens = tokens.filter((_, index) => {
          const responseItem = response.responses[index];
          return responseItem?.success === false && 
                 (responseItem?.error?.code === 'messaging/invalid-registration-token' ||
                  responseItem?.error?.code === 'messaging/registration-token-not-registered');
        });

        for (const token of failedTokens) {
          try {
            await UserFcmToken.deactivate(token.tokenid);
            logger.info(`[NotificationService] Deactivated invalid token ${token.tokenid}`);
          } catch (error) {
            logger.warn(`[NotificationService] Failed to deactivate token ${token.tokenid}:`, error.message);
          }
        }
      }

      if (response.failureCount > 0) {
        logger.warn(`[NotificationService] ⚠️ Failed to send notification to ${response.failureCount} device(s) for user ${userid}`);
        response.responses.forEach((resp, index) => {
          if (!resp.success) {
            logger.warn(`[NotificationService] Token ${fcmTokens[index]} error:`, resp.error?.message || 'Unknown error');
          }
        });
      }
    } catch (error) {
      fcmError = error.message;
      logger.error(`[NotificationService] ❌ Error sending FCM notification to user ${userid}:`, error.message);
    }

    // Save notification to database
    const notificationData = {
      userid,
      type: notificationType,
      title_ar: getNotificationContent(notificationType, 'ar', dataAr).title,
      title_en: getNotificationContent(notificationType, 'en', dataEn).title,
      body_ar: getNotificationContent(notificationType, 'ar', dataAr).body,
      body_en: getNotificationContent(notificationType, 'en', dataEn).body,
      data: formattedData,
      fcm_sent: fcmSent,
      fcm_sent_at: fcmSentAt,
    };

    const notification = await Notification.create(notificationData);

    return {
      success: true,
      notificationid: notification.notificationid,
      notificationSaved: true,
      fcmSent,
      fcmSentAt,
      fcmError,
      devicesNotified: fcmSent ? tokens.length : 0,
    };
  } catch (error) {
    logger.error(`[NotificationService] ❌ Error in sendNotification for user ${userid}:`, error);
    return {
      success: false,
      error: error.message,
    };
  }
};

/**
 * Send notifications to multiple users
 * @param {Array<string>} userids - Array of user IDs
 * @param {string} notificationType - Type of notification
 * @param {object} data - Data for template substitution
 * @param {string} language - Language code
 * @returns {Promise<object>} - Result with success/failure counts
 */
export const sendBulkNotifications = async (userids, notificationType, data = {}, language = 'ar') => {
  try {
    const results = {
      total: userids.length,
      success: 0,
      failed: 0,
      errors: [],
    };

    // Process in batches to avoid overwhelming the system
    const batchSize = 10;
    for (let i = 0; i < userids.length; i += batchSize) {
      const batch = userids.slice(i, i + batchSize);
      
      const batchPromises = batch.map(async (userid) => {
        try {
          const result = await sendNotification(userid, notificationType, data, language);
          if (result.success) {
            results.success++;
          } else {
            results.failed++;
            results.errors.push({ userid, error: result.error });
          }
        } catch (error) {
          results.failed++;
          results.errors.push({ userid, error: error.message });
        }
      });

      await Promise.all(batchPromises);
    }

    logger.info(`[NotificationService] Bulk notification result: ${results.success} success, ${results.failed} failed`);
    return results;
  } catch (error) {
    logger.error('[NotificationService] ❌ Error in sendBulkNotifications:', error);
    throw error;
  }
};

export { NOTIFICATION_TYPES };
