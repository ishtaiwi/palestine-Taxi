import appConfig from '../config/app.js';

export const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  
  console.error(err);

  
  if (err.code === '23505') {
    const message = 'Duplicate field value entered';
    error = { message, statusCode: 400 };
  }

  if (err.code === '23503') {
    const message = 'Resource not found';
    error = { message, statusCode: 404 };
  }

  if (err.code === 'PGRST116') {
    const message = 'Resource not found';
    error = { message, statusCode: 404 };
  }

  // Handle Supabase validation errors
  if (err.code === '23514' || err.code === '22P02' || err.message?.includes('invalid input')) {
    const message = err.details || err.hint || err.message || 'Invalid input provided';
    error = { message, statusCode: 400 };
  }

  // Handle Supabase constraint violations
  if (err.code === '23502') {
    const message = err.details || err.hint || 'Required field is missing';
    error = { message, statusCode: 400 };
  }

  
  if (err.name === 'JsonWebTokenError') {
    const message = 'Invalid token';
    error = { message, statusCode: 401 };
  }

  if (err.name === 'TokenExpiredError') {
    const message = 'Token expired';
    error = { message, statusCode: 401 };
  }

  
  if (err.name === 'ValidationError') {
    const message = Object.values(err.errors).map(val => val.message).join(', ');
    error = { message, statusCode: 400 };
  }

  // Extract error message - prefer details/hint from Supabase errors
  let errorMessage = error.message || 'Server Error';
  if (err.details && typeof err.details === 'string') {
    errorMessage = err.details;
  } else if (err.hint && typeof err.hint === 'string') {
    errorMessage = err.hint;
  }

  res.status(error.statusCode || 500).json({
    success: false,
    message: errorMessage,
    error: errorMessage,
    ...(appConfig.nodeEnv === 'development' && { 
      stack: err.stack,
      code: err.code,
      details: err.details,
      hint: err.hint,
    }),
  });
};

export const notFound = (req, res, next) => {
  const error = new Error(`Not Found - ${req.originalUrl}`);
  res.status(404);
  next(error);
};

