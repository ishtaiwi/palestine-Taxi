import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';
import appConfig from './config/app.js';
import { errorHandler, notFound } from './middleware/errorHandler.js';
import { i18n } from './middleware/i18n.js';
import logger from './utils/logger.js';
import { testConnection, getConnectionStatus } from './config/dbcon.js';
import swaggerUi from 'swagger-ui-express';
import swaggerSpec from './docs/swagger.js';
import { generalLimiter } from './middleware/rateLimit.js';
import timeRoutes from './routes/timeRoute.js';
import stripeRoutes from './routes/stripeRoutes.js';

import authRoutes from './routes/authRoutes.js';
import lineRoutes from './routes/lineRoutes.js';
import tripRoutes from './routes/tripRoutes.js';
import reservationRoutes from './routes/reservationRoutes.js';
import vehicleRoutes from './routes/vehicleRoutes.js';
import paymentRoutes from './routes/paymentRoutes.js';
import walletRoutes from './routes/walletRoutes.js';
import adminRoutes from './routes/adminRoutes.js';
import driverRoutes from './routes/driverRoutes.js';
import scheduleRoutes from './routes/scheduleRoutes.js';
import ratingRoutes from './routes/ratingRoutes.js';
import locationRoutes from './routes/locationRoutes.js';
import routingRoutes from './routes/routingRoutes.js';



import { startTripOpeningJob } from './jobs/tripOpeningJob.js';
import { startDepartureCheckJob } from './jobs/departureCheckJob.js';
import { startDelayedTripCheckJob } from './jobs/delayedTripCheckJob.js';
import { startNoShowCheckJob } from './jobs/noShowCheckJob.js';
import { startDailyTripCreationJob } from './jobs/dailyTripCreationJob.js';
import { startPredictionUpdateJob } from './jobs/predictionUpdateJob.js';
import { initializeModel } from './services/rushHourPredictionService.js';

const app = express();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);


app.use(cors(appConfig.cors));


app.use('/api/stripe', stripeRoutes);


app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(i18n);


app.use((req, res, next) => {
  res.charset = 'utf-8';
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  next();
});


app.use('/api/', generalLimiter);

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));


app.get('/health', (req, res) => {
  const dbStatus = getConnectionStatus();
  res.json({
    status: 'OK',
    message: 'Service Taxi Reservation System API',
    timestamp: new Date().toISOString(),
    database: dbStatus,
  });
});


app.get('/api/db/test', async (req, res) => {
  try {
    const result = await testConnection();
    if (result.connected) {
      res.json({
        success: true,
        message: 'Database connection successful',
        ...result,
      });
    } else {
      res.status(500).json({
        success: false,
        message: 'Database connection failed',
        ...result,
      });
    }
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error testing database connection',
      error: error.message,
    });
  }
});

// Config endpoint for client-side configuration (Supabase URL and anon key)
app.get('/api/config/supabase', (req, res) => {
  try {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;

    if (!supabaseUrl || !supabaseAnonKey) {
      return res.status(503).json({
        success: false,
        message: 'Supabase configuration not available',
      });
    }

    res.json({
      success: true,
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: 'Error retrieving Supabase configuration',
      error: error.message,
    });
  }
});


app.use('/api/auth', authRoutes);
app.use('/api/lines', lineRoutes);
app.use('/api/trips', tripRoutes);
app.use('/api/reservations', reservationRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/wallets', walletRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/drivers', driverRoutes);
app.use('/api/schedules', scheduleRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/time', timeRoutes);
app.use('/api/locations', locationRoutes);
app.use('/api/routing', routingRoutes);

app.use('/api/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));


app.use(notFound);


app.use(errorHandler);


const PORT = appConfig.port;
app.listen(PORT, async () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`Environment: ${appConfig.nodeEnv}`);
  logger.info(`API Base URL: http://localhost:${PORT}/api`);


  logger.info('Testing database connection...');
  const dbTest = await testConnection();
  if (dbTest.connected) {
    logger.info('✅ Database connection verified');


    logger.info('Starting background jobs...');
    startTripOpeningJob();
    startDelayedTripCheckJob();
    startDepartureCheckJob();
    startNoShowCheckJob();
    startDailyTripCreationJob();
    startPredictionUpdateJob();
    logger.info('✅ All background jobs started');


    setImmediate(async () => {
      try {
        await initializeModel();
      } catch (error) {
        logger.warn('⚠️ Failed to initialize prediction model on startup', {
          error: error.message,
        });
      }
    });
  } else {
    logger.warn('⚠️ Database connection failed. Please check your configuration.');
    logger.warn(`Error: ${dbTest.error || 'Unknown error'}`);
    logger.warn('⚠️ Background jobs not started due to database connection failure');
  }
}).on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    logger.error(`Port ${PORT} is already in use. Please use a different port.`);
  } else {
    logger.error(`Server error: ${err.message}`);
  }
  process.exit(1);
});

export default app;

