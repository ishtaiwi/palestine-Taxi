import { body, validationResult } from 'express-validator';

export const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      message: req.t?.('validation.errors') || 'Validation errors',
      errors: errors.array(),
    });
  }
  next();
};

export const validateRegister = [
  body('fullname')
    .trim()
    .notEmpty()
    .withMessage('Full name is required')
    .isLength({ min: 2, max: 100 })
    .withMessage('Full name must be between 2 and 100 characters'),
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Invalid email format')
    .normalizeEmail(),
  body('phone')
    .optional()
    .trim()
    .matches(/^[0-9+\-\s()]+$/)
    .withMessage('Invalid phone number format'),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
  body('role')
    .notEmpty()
    .withMessage('Role is required')
    .isIn(['admin', 'driver', 'passenger'])
    .withMessage('Invalid role'),
  body('licenseid')
    .if(body('role').equals('driver'))
    .notEmpty()
    .withMessage('License ID is required for drivers'),
  body('lineid')
    .if(body('role').equals('driver'))
    .notEmpty()
    .withMessage('Line ID is required for drivers')
    .bail()
    .isLength({ min: 3 })
    .withMessage('Invalid line ID format'),
  validate,
];

export const validateLogin = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Invalid email format')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 1 })
    .withMessage('Password cannot be empty'),
  validate,
];

export const validateChangePassword = [
  body('currentPassword')
    .notEmpty()
    .withMessage('Current password is required')
    .isLength({ min: 1 })
    .withMessage('Current password cannot be empty'),
  body('newPassword')
    .notEmpty()
    .withMessage('New password is required')
    .isLength({ min: 6 })
    .withMessage('New password must be at least 6 characters'),
  validate,
];

export const validatePasswordResetRequest = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Invalid email format')
    .normalizeEmail(),
  validate,
];

export const validateVerifyResetCode = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Invalid email format')
    .normalizeEmail(),
  body('code')
    .trim()
    .notEmpty()
    .withMessage('Verification code is required')
    .isLength({ min: 6, max: 6 })
    .withMessage('Verification code must be 6 digits')
    .matches(/^\d+$/)
    .withMessage('Verification code must contain only numbers'),
  validate,
];

export const validatePasswordReset = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Invalid email format')
    .normalizeEmail(),
  body('code')
    .trim()
    .notEmpty()
    .withMessage('Verification code is required')
    .isLength({ min: 6, max: 6 })
    .withMessage('Verification code must be 6 digits')
    .matches(/^\d+$/)
    .withMessage('Verification code must contain only numbers'),
  body('newPassword')
    .notEmpty()
    .withMessage('New password is required')
    .isLength({ min: 6 })
    .withMessage('New password must be at least 6 characters'),
  validate,
];

export const validateLine = [
  // Support both old (linename) and new (name_ar, name_en) format
  body('name_ar')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Arabic name must be between 2 and 100 characters'),
  body('name_en')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('English name must be between 2 and 100 characters'),
  body('linename')
    .optional()
    .trim()
    .isLength({ min: 2, max: 100 })
    .withMessage('Line name must be between 2 and 100 characters'),
  // At least one name must be provided
  body()
    .custom((value) => {
      if (!value.name_ar && !value.linename) {
        throw new Error('Either name_ar or linename is required');
      }
      return true;
    }),
  body('baseprice')
    .notEmpty()
    .withMessage('Base price is required')
    .isFloat({ min: 0 })
    .withMessage('Base price must be a positive number'),
  body('additionalprice')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Additional price must be a positive number'),
  body('distance')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Distance must be a positive number'),
  body('estduration')
    .optional()
    .isInt({ min: 0 })
    .withMessage('Estimated duration must be a positive integer'),
  validate,
];

export const validateRating = [
  body('bookingid')
    .trim()
    .notEmpty()
    .withMessage('Booking ID is required')
    .isUUID()
    .withMessage('Booking ID must be a valid UUID'),
  body('rating')
    .notEmpty()
    .withMessage('Rating is required')
    .isInt({ min: 1, max: 5 })
    .withMessage('Rating must be an integer between 1 and 5'),
  body('comment')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Comment must not exceed 500 characters'),
  validate,
];

export const validateRatingUpdate = [
  body('rating')
    .optional()
    .isInt({ min: 1, max: 5 })
    .withMessage('Rating must be an integer between 1 and 5'),
  body('comment')
    .optional()
    .trim()
    .isLength({ max: 500 })
    .withMessage('Comment must not exceed 500 characters'),
  validate,
];

export const validateTrip = [
  body('lineid')
    .notEmpty()
    .withMessage('Line ID is required')
    .isUUID()
    .withMessage('Invalid line ID format'),
  body('vehicleid')
    .notEmpty()
    .withMessage('Vehicle ID is required')
    .isUUID()
    .withMessage('Invalid vehicle ID format'),
  body('deptime')
    .notEmpty()
    .withMessage('Departure time is required')
    .isISO8601()
    .withMessage('Invalid date format'),
  validate,
];

export const validateReservation = [
  body('tripid')
    .optional()
    .isUUID()
    .withMessage('Invalid trip ID format'),
  body('booking_type')
    .optional()
    .isIn(['future', 'instant'])
    .withMessage('booking_type must be either "future" or "instant"'),
  body('scheduled_trip_time')
    .optional()
    .isISO8601()
    .withMessage('scheduled_trip_time must be a valid ISO 8601 date'),
  body('seatlocation')
    .optional()
    .trim()
    .matches(/^seat_\d+$/)
    .withMessage('Invalid seat location format'),
  body('dropoffpoint')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Drop-off point must be less than 200 characters'),
  // Custom validation: tripid required for instant bookings
  body('tripid')
    .custom((value, { req }) => {
      if (req.body.booking_type === 'instant' && !value) {
        throw new Error('tripid is required for instant bookings');
      }
      return true;
    }),
  // Custom validation: scheduled_trip_time required for future bookings
  body('scheduled_trip_time')
    .custom((value, { req }) => {
      if (req.body.booking_type === 'future' && !value) {
        throw new Error('scheduled_trip_time is required for future bookings');
      }
      return true;
    }),
  validate,
];

export const validateVehicle = [
  body('driverid')
    .notEmpty()
    .withMessage('Driver ID is required')
    .isUUID()
    .withMessage('Invalid driver ID format'),
  body('seatnum')
    .notEmpty()
    .withMessage('Seat number is required')
    .isInt({ min: 1, max: 50 })
    .withMessage('Seat number must be between 1 and 50'),
  body('plateno')
    .trim()
    .notEmpty()
    .withMessage('Plate number is required')
    .matches(/^\d-\d{4}-[A-Za-z]$/)
    .withMessage('Plate number must be in format: number-4digits-letter (e.g., 3-1234-A)'),
  body('seatlayout')
    .optional()
    .isIn(['2+3', '3+3+2', '2+2', '1+1'])
    .withMessage('Invalid seat layout'),
  body('lineid')
    .optional()
    .isUUID()
    .withMessage('Invalid line ID format'),
  validate,
];

export const validatePayment = [
  body('amount')
    .notEmpty()
    .withMessage('Amount is required')
    .isFloat({ min: 0.01 })
    .withMessage('Amount must be greater than 0'),
  body('method')
    .notEmpty()
    .withMessage('Payment method is required')
    .isIn(['wallet', 'cash', 'card', 'palpay', 'jawwal_pay'])
    .withMessage('Invalid payment method'),
  validate,
];

