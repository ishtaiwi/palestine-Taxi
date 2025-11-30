import express from 'express';
import {
  getDashboardStats,
  getAllUsers,
  getUserById,
  updateUser,
  deleteUser,
  getRevenueAnalytics,
  updateAdminPermissions,
  getRushHourPredictionsReport,
  getLineDemandAnalysis,
  getScheduleRecommendations,
  applyScheduleRecommendation,
  triggerModelRetrain,
  getPredictionInsights,
} from '../controllers/adminController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.use(authenticate);
router.use(requireAdmin);

router.get('/dashboard/stats', getDashboardStats);
router.get('/dashboard/revenue', getRevenueAnalytics);
router.get('/predictions/rush-hours', getRushHourPredictionsReport);
router.get('/predictions/line-demand', getLineDemandAnalysis);
router.get('/predictions/insights', getPredictionInsights);
router.post('/predictions/retrain', triggerModelRetrain);
router.get('/recommendations', getScheduleRecommendations);
router.post('/recommendations/apply', applyScheduleRecommendation);
router.get('/users', getAllUsers);
router.get('/users/:userid', getUserById);
router.put('/users/:userid', updateUser);
router.delete('/users/:userid', deleteUser);
router.put('/admins/:adminid/permissions', updateAdminPermissions);

export default router;

