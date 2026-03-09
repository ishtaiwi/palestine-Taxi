import express from 'express';
import {
  registerToken,
  getNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotification,
} from '../controllers/notificationController.js';
import { authenticate } from '../middleware/auth.js';
import { userDataLimiter } from '../middleware/rateLimit.js';

const router = express.Router();

// All routes require authentication
router.use(authenticate);

// Register FCM token
router.post('/register-token', registerToken);

// Get notifications (paginated) - use userDataLimiter for higher limits
router.get('/', userDataLimiter, getNotifications);

// Get unread count - use more lenient rate limiter
router.get('/unread-count', userDataLimiter, getUnreadCount);

// Mark notification as read
router.put('/:notificationid/read', markAsRead);

// Mark all notifications as read
router.put('/read-all', markAllAsRead);

// Delete notification
router.delete('/:notificationid', deleteNotification);

export default router;
