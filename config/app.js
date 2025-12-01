import dotenv from "dotenv";
dotenv.config();


const parseCorsOrigins = (originsValue) => {
  if (!originsValue) {
    return [
      'http://localhost:3000',
      'http://localhost:4000',
      'http://localhost:5000',
    ];
  }

  const origins = originsValue
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (origins.length === 0) {
    return ['http://localhost:3000'];
  }

  return origins.length === 1 ? origins[0] : origins;
};

const allowedOrigins = parseCorsOrigins(process.env.CORS_ORIGIN);

export default {
  port: process.env.PORT || 3000,
  nodeEnv: process.env.NODE_ENV || 'development',
  appName: process.env.APP_NAME || 'Service Taxi Reservation System',
  defaultLanguage: process.env.DEFAULT_LANGUAGE || 'ar',
  jwt: {
    secret: process.env.JWT_SECRET ,
    expiresIn: process.env.JWT_ACCESS_EXPIRY ,
  },
  payment: {
    palpayApiKey: process.env.PALPAY_API_KEY,
    jawwalPayApiKey: process.env.JAWWAL_PAY_API_KEY,
  },
  email: {
    host: process.env.EMAIL_HOST,
    port: process.env.EMAIL_PORT ? parseInt(process.env.EMAIL_PORT, 10) : undefined,
    secure: process.env.EMAIL_SECURE === 'true',
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
    from: process.env.EMAIL_FROM || `no-reply@${process.env.DOMAIN || 'example.com'}`,
    resetUrlBase: process.env.PASSWORD_RESET_URL_BASE || 'http://localhost:3000/reset-password',
  },
  cors: {
    origin: allowedOrigins,
    credentials: true,
  },
};

