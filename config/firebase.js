import dotenv from 'dotenv';
dotenv.config();
import admin from 'firebase-admin';
import logger from '../utils/logger.js';

let messaging = null;
let isInitialized = false;

/**
 * Initialize Firebase Admin SDK
 */
export const initializeFirebase = () => {
  if (isInitialized && messaging) {
    return messaging;
  }

  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

    if (!projectId || !privateKey || !clientEmail) {
      logger.warn('⚠️ Firebase configuration missing. Push notifications will not work.');
      logger.warn('Required environment variables: FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL');
      return null;
    }

    // Initialize Firebase Admin if not already initialized
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          privateKey,
          clientEmail,
        }),
      });
      logger.info('✅ Firebase Admin SDK initialized successfully');
    }

    messaging = admin.messaging();
    isInitialized = true;
    return messaging;
  } catch (error) {
    logger.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    return null;
  }
};

/**
 * Get Firebase Messaging instance
 */
export const getMessaging = () => {
  if (!isInitialized) {
    return initializeFirebase();
  }
  return messaging;
};

/**
 * Check if Firebase is initialized
 */
export const isFirebaseInitialized = () => {
  return isInitialized && messaging !== null;
};

// Initialize on module load
initializeFirebase();

export default messaging;
