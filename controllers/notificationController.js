import Notification from '../models/Notification.js';
import UserFcmToken from '../models/UserFcmToken.js';
import { v4 as uuidv4 } from 'uuid';
import logger from '../utils/logger.js';
import { PAGINATION } from '../utils/constants.js';

/**
 * Register or update FCM token for a user
 */
export const registerToken = async (req, res, next) => {
  try {
    const { fcm_token, device_type, device_id } = req.body;
    const userid = req.user.userid;

    if (!fcm_token || !device_type) {
      return res.status(400).json({
        success: false,
        message: 'fcm_token and device_type are required',
      });
    }

    if (!['ios', 'android'].includes(device_type)) {
      return res.status(400).json({
        success: false,
        message: 'device_type must be "ios" or "android"',
      });
    }

    try {
      // Use upsert to handle existing tokens
      const tokenData = {
        userid,
        fcm_token,
        device_type,
        device_id: device_id || null,
      };

      const token = await UserFcmToken.upsert(tokenData);

      logger.info(`[NotificationController] Registered FCM token for user ${userid}`);

      res.json({
        success: true,
        message: 'FCM token registered successfully',
        token: {
          tokenid: token.tokenid,
          device_type: token.device_type,
        },
      });
    } catch (error) {
      if (error.code === '23505') {
        // Unique constraint violation - token already exists
        // Try to update it
        const existingToken = await UserFcmToken.findByToken(fcm_token);
        if (existingToken) {
          const updated = await UserFcmToken.update(existingToken.tokenid, {
            userid,
            device_type,
            device_id: device_id || null,
            is_active: true,
            last_used_at: new Date().toISOString(),
          });

          return res.json({
            success: true,
            message: 'FCM token updated successfully',
            token: {
              tokenid: updated.tokenid,
              device_type: updated.device_type,
            },
          });
        }
      }
      throw error;
    }
  } catch (error) {
    logger.error('[NotificationController] Error registering FCM token:', error);
    next(error);
  }
};

/**
 * Get user notifications with pagination
 */
export const getNotifications = async (req, res, next) => {
  try {
    const userid = req.user.userid;
    const page = parseInt(req.query.page) || PAGINATION.DEFAULT_PAGE;
    const limit = Math.min(parseInt(req.query.limit) || PAGINATION.DEFAULT_LIMIT, PAGINATION.MAX_LIMIT);
    const read = req.query.read !== undefined ? req.query.read === 'true' : undefined;
    const type = req.query.type;

    const filters = {};
    if (read !== undefined) filters.read = read;
    if (type) filters.type = type;

    // Get all notifications for user (we'll paginate manually since Supabase doesn't have built-in pagination)
    const allNotifications = await Notification.findByUserId(userid, filters);

    // Manual pagination
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedNotifications = allNotifications.slice(startIndex, endIndex);

    const total = allNotifications.length;
    const totalPages = Math.ceil(total / limit);

    res.json({
      success: true,
      notifications: paginatedNotifications,
      pagination: {
        page,
        limit,
        total,
        totalPages,
        hasMore: endIndex < total,
      },
    });
  } catch (error) {
    logger.error('[NotificationController] Error getting notifications:', error);
    next(error);
  }
};

/**
 * Get unread notification count
 */
export const getUnreadCount = async (req, res, next) => {
  try {
    const userid = req.user.userid;
    const count = await Notification.getUnreadCount(userid);

    res.json({
      success: true,
      count,
    });
  } catch (error) {
    logger.error('[NotificationController] Error getting unread count:', error);
    next(error);
  }
};

/**
 * Mark notification as read
 */
export const markAsRead = async (req, res, next) => {
  try {
    const { notificationid } = req.params;
    const userid = req.user.userid;

    // Verify notification belongs to user
    const notification = await Notification.findById(notificationid);
    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found',
      });
    }

    if (notification.userid !== userid) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to access this notification',
      });
    }

    const updated = await Notification.markAsRead(notificationid);

    res.json({
      success: true,
      message: 'Notification marked as read',
      notification: updated,
    });
  } catch (error) {
    logger.error('[NotificationController] Error marking notification as read:', error);
    next(error);
  }
};

/**
 * Mark all notifications as read for a user
 */
export const markAllAsRead = async (req, res, next) => {
  try {
    const userid = req.user.userid;
    const updated = await Notification.markAllAsRead(userid);

    res.json({
      success: true,
      message: 'All notifications marked as read',
      count: updated.length,
    });
  } catch (error) {
    logger.error('[NotificationController] Error marking all notifications as read:', error);
    next(error);
  }
};

/**
 * Delete notification
 */
export const deleteNotification = async (req, res, next) => {
  try {
    const { notificationid } = req.params;
    const userid = req.user.userid;

    // Verify notification belongs to user
    const notification = await Notification.findById(notificationid);
    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found',
      });
    }

    if (notification.userid !== userid) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to delete this notification',
      });
    }

    await Notification.delete(notificationid);

    res.json({
      success: true,
      message: 'Notification deleted successfully',
    });
  } catch (error) {
    logger.error('[NotificationController] Error deleting notification:', error);
    next(error);
  }
};
