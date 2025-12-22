export const USER_ROLES = {
  ADMIN: 'admin',
  DRIVER: 'driver',
  PASSENGER: 'passenger',
};

export const DRIVER_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  SUSPENDED: 'suspended',
};

export const VEHICLE_STATUS = {
  ACTIVE: 'active',
  INACTIVE: 'inactive',
  MAINTENANCE: 'maintenance',
};

export const VEHICLE_LAYOUT = {
  CAR_4_1: '2+3',
  VAN_3_3_2: '3+3+2',
  BUS_2_2: '2+2',
  MINI_1_1: '1+1',
};

export const TRIP_STATUS = {
  SCHEDULED: 'scheduled',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  CANCELLED: 'cancelled',
  DELAYED: 'delayed',
};

export const RESERVATION_STATUS = {
  PENDING: 'pending',
  CONFIRMED: 'confirmed',
  CHECKED_IN: 'checked_in',
  CANCELLED: 'cancelled',
  NO_SHOW: 'no_show',
  STANDBY: 'standby',
};

export const PAYMENT_STATUS = {
  PENDING: 'pending',
  COMPLETED: 'completed',
  FAILED: 'failed',
  REFUNDED: 'refunded',
};

export const PAYMENT_METHOD = {
  WALLET: 'wallet',
  CARD: 'card',
};

export const PASSENGER_TYPE = {
  WALK_IN: 'walk_in',
  APP_BASED: 'app_based',
};

export const SEAT_STATUS_COLORS = {
  AVAILABLE: 'green',
  CONFIRMED: 'blue',
  CHECKED_IN: 'yellow',
  STANDBY: 'orange',
  WALK_IN: 'red',
};

export const BOOKING_TYPE = {
  FUTURE: 'future',
  INSTANT: 'instant',
};

export const CANCELLATION_POLICY = {
  NO_CHARGE_HOURS: 1,
  PARTIAL_CHARGE_HOURS: 0,
  PARTIAL_CHARGE_PERCENTAGE: 0.25,
};

export const CHECK_IN_WINDOW = 15;

export const PAGINATION = {
  DEFAULT_PAGE: 1,
  DEFAULT_LIMIT: 20,
  MAX_LIMIT: 100,
};

