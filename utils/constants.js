// User Roles
export const USER_ROLES = {
  ADMIN: 'admin',
  DRIVER: 'driver',
  PASSENGER: 'passenger',
};

// Driver Status
export const DRIVER_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  SUSPENDED: 'suspended',
};

// Vehicle Status
export const VEHICLE_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  MAINTENANCE: 'maintenance',
};

// Vehicle Layout
export const VEHICLE_LAYOUT = {
  CAR_4_1: '2+3',      // Car with 4+1 seats
  VAN_3_3_2: '3+3+2',  // Van with 3+3+2 seats
  BUS_2_2: '2+2',      // Bus with 2+2 seats
  MINI_1_1: '1+1',     // Mini with 1+1 seats
};

// Trip Status
export const TRIP_STATUS = {
  SCHEDULED: 'scheduled',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled',
  DELAYED: 'delayed',
};

// Reservation Status
export const RESERVATION_STATUS = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CHECKED_IN: 'checked_in',
  CANCELLED: 'cancelled',
  NO_SHOW: 'no_show',
  STANDBY: 'standby',
};

// Payment Status
export const PAYMENT_STATUS = {
  PENDING: 'pending',
  COMPLETED: 'completed',
  FAILED: 'failed',
  REFUNDED: 'refunded',
};

// Payment Method
export const PAYMENT_METHOD = {
  WALLET: 'wallet',
  CASH: 'cash',
  CARD: 'card',
  PALPAY: 'palpay',
  JAWWAL_PAY: 'jawwal_pay',
};

// Passenger Type
export const PASSENGER_TYPE = {
  WALK_IN: 'walk_in',
  APP_BASED: 'app_based',
};

// Seat Status Colors (for driver app)
export const SEAT_STATUS_COLORS = {
  AVAILABLE: 'green',
  CONFIRMED: 'blue',
  CHECKED_IN: 'yellow',
  STANDBY: 'orange',
  WALK_IN: 'red',
};

// Booking Type
export const BOOKING_TYPE = {
  FUTURE: 'future',    // Scheduled booking for a specific trip time
  INSTANT: 'instant',  // Booking for the next available trip
};

// Cancellation Policy
// Updated according to requirements: 60 minutes (no charge), less than 60 minutes (25% charge)
export const CANCELLATION_POLICY = {
  NO_CHARGE_HOURS: 1,           // No charge if cancelled 60+ minutes (1 hour) before departure
  PARTIAL_CHARGE_HOURS: 0,      // Partial charge if cancelled less than 60 minutes before departure
  PARTIAL_CHARGE_PERCENTAGE: 0.25, // 25% charge for late cancellation
};

// Check-in Window (minutes before departure)
export const CHECK_IN_WINDOW = 15;

// Default Pagination
export const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
};

