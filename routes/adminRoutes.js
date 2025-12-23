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
  getRevenueTimeSeries,
  getBookingTimeSeries,
  getTripStatistics,
  getUserGrowth,
  getVehicleUtilization,
  getLinePerformance,
  getTimezoneConfig,
  updateTimezoneConfig,
} from '../controllers/adminController.js';
import {
  getAllBaseStations,
  getBaseStationById,
  createBaseStation,
  updateBaseStation,
  deleteBaseStation,
  checkDriverAtStation,
} from '../controllers/baseStationController.js';
import {
  getLinePath,
  createOrUpdateLinePath,
  deleteLinePath,
} from '../controllers/linePathController.js';
import { authenticate } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/authorization.js';

const router = express.Router();


router.use(authenticate);
router.use(requireAdmin);

router.get('/dashboard/stats', getDashboardStats);
router.get('/dashboard/revenue', getRevenueAnalytics);
router.get('/reports/revenue-timeseries', getRevenueTimeSeries);
router.get('/reports/booking-timeseries', getBookingTimeSeries);
router.get('/reports/trip-statistics', getTripStatistics);
router.get('/reports/user-growth', getUserGrowth);
router.get('/reports/vehicle-utilization', getVehicleUtilization);
router.get('/reports/line-performance', getLinePerformance);
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

// Base station routes
router.get('/base-station', getAllBaseStations);
router.get('/base-station/:stationid', getBaseStationById);
router.post('/base-station', createBaseStation);
router.put('/base-station/:stationid', updateBaseStation);
router.delete('/base-station/:stationid', deleteBaseStation);
router.get('/base-station/check-driver/:driverid', checkDriverAtStation);

// Line path routes
router.get('/lines/:lineid/path', getLinePath);
router.post('/lines/:lineid/path', createOrUpdateLinePath);
router.delete('/lines/:lineid/path', deleteLinePath);

// Timezone configuration routes
router.get('/config/timezone', getTimezoneConfig);
router.put('/config/timezone', updateTimezoneConfig);

export default router;

