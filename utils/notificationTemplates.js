/**
 * Notification templates with Arabic and English versions
 * Supports dynamic variable substitution using {variable} syntax
 */

export const NOTIFICATION_TYPES = {
  RESERVATION_CONFIRMED: 'RESERVATION_CONFIRMED',
  DRIVER_ASSIGNED: 'DRIVER_ASSIGNED',
  TRIP_OPENING_SOON: 'TRIP_OPENING_SOON',
  TRIP_DEPARTURE_SOON: 'TRIP_DEPARTURE_SOON',
  TRIP_DEPARTED: 'TRIP_DEPARTED',
  TRIP_COMPLETED: 'TRIP_COMPLETED',
  RESERVATION_CANCELLED: 'RESERVATION_CANCELLED',
  NEW_BOOKING_ASSIGNED: 'NEW_BOOKING_ASSIGNED',
  TRIP_ASSIGNED: 'TRIP_ASSIGNED',
  PASSENGER_CHECKED_IN: 'PASSENGER_CHECKED_IN',
  TRIP_FULL: 'TRIP_FULL',
  PAYMENT_RECEIVED: 'PAYMENT_RECEIVED',
  NO_SHOW_WARNING: 'NO_SHOW_WARNING',
  NO_SHOW_MARKED: 'NO_SHOW_MARKED',
  SEAT_ASSIGNED: 'SEAT_ASSIGNED',
};

const templates = {
  [NOTIFICATION_TYPES.RESERVATION_CONFIRMED]: {
    title_ar: 'تم تأكيد الحجز',
    title_en: 'Reservation Confirmed',
    body_ar: 'تم تأكيد حجزك من {from} إلى {to}. وقت الرحلة: {time}',
    body_en: 'Your reservation from {from} to {to} is confirmed. Trip time: {time}',
  },
  [NOTIFICATION_TYPES.DRIVER_ASSIGNED]: {
    title_ar: 'تم تعيين السائق',
    title_en: 'Driver Assigned',
    body_ar: 'تم تعيين السائق {driverName} لرحلتك. رقم المركبة: {plateNumber}',
    body_en: 'Driver {driverName} has been assigned to your trip. Vehicle: {plateNumber}',
  },
  [NOTIFICATION_TYPES.TRIP_OPENING_SOON]: {
    title_ar: 'قرب موعد فتح الحجز',
    title_en: 'Trip Opening Soon',
    body_ar: 'سيتم فتح الحجز لرحلتك من {from} إلى {to} خلال {minutes} دقيقة',
    body_en: 'Booking for your trip from {from} to {to} will open in {minutes} minutes',
  },
  [NOTIFICATION_TYPES.TRIP_DEPARTURE_SOON]: {
    title_ar: 'قرب موعد المغادرة',
    title_en: 'Departure Soon',
    body_ar: 'رحلتك من {from} إلى {to} ستنطلق خلال {minutes} دقيقة',
    body_en: 'Your trip from {from} to {to} will depart in {minutes} minutes',
  },
  [NOTIFICATION_TYPES.TRIP_DEPARTED]: {
    title_ar: 'انطلقت الرحلة',
    title_en: 'Trip Departed',
    body_ar: 'انطلقت رحلتك من {from} إلى {to}',
    body_en: 'Your trip from {from} to {to} has departed',
  },
  [NOTIFICATION_TYPES.TRIP_COMPLETED]: {
    title_ar: 'اكتملت الرحلة',
    title_en: 'Trip Completed',
    body_ar: 'اكتملت رحلتك من {from} إلى {to} بنجاح',
    body_en: 'Your trip from {from} to {to} has been completed',
  },
  [NOTIFICATION_TYPES.RESERVATION_CANCELLED]: {
    title_ar: 'تم إلغاء الحجز',
    title_en: 'Reservation Cancelled',
    body_ar: 'تم إلغاء حجزك من {from} إلى {to}',
    body_en: 'Your reservation from {from} to {to} has been cancelled',
  },
  [NOTIFICATION_TYPES.NEW_BOOKING_ASSIGNED]: {
    title_ar: 'حجز جديد',
    title_en: 'New Booking',
    body_ar: 'تم حجز مقعد جديد في رحلتك. الراكب: {passengerName}',
    body_en: 'A new seat has been booked on your trip. Passenger: {passengerName}',
  },
  [NOTIFICATION_TYPES.TRIP_ASSIGNED]: {
    title_ar: 'تم تعيين رحلة جديدة',
    title_en: 'New Trip Assigned',
    body_ar: 'تم تعيينك لرحلة من {from} إلى {to}. وقت المغادرة: {time}',
    body_en: 'You have been assigned to a trip from {from} to {to}. Departure: {time}',
  },
  [NOTIFICATION_TYPES.PASSENGER_CHECKED_IN]: {
    title_ar: 'تم تسجيل الراكب',
    title_en: 'Passenger Checked In',
    body_ar: 'تم تسجيل دخول الراكب {passengerName}',
    body_en: 'Passenger {passengerName} has checked in',
  },
  [NOTIFICATION_TYPES.TRIP_FULL]: {
    title_ar: 'اكتملت المقاعد',
    title_en: 'Trip Full',
    body_ar: 'اكتملت جميع المقاعد في رحلتك من {from} إلى {to}',
    body_en: 'All seats are now booked for your trip from {from} to {to}',
  },
  [NOTIFICATION_TYPES.PAYMENT_RECEIVED]: {
    title_ar: 'تم استلام الدفع',
    title_en: 'Payment Received',
    body_ar: 'تم استلام دفعة بقيمة {amount} شيكل من الراكب {passengerName}',
    body_en: 'Payment of {amount} ILS received from passenger {passengerName}',
  },
  [NOTIFICATION_TYPES.NO_SHOW_WARNING]: {
    title_ar: 'تحذير: تأخر في الحضور',
    title_en: 'Late Check-in Warning',
    body_ar: 'يرجى الحضور في الوقت المحدد لرحلتك من {from} إلى {to}',
    body_en: 'Please arrive on time for your trip from {from} to {to}',
  },
  [NOTIFICATION_TYPES.NO_SHOW_MARKED]: {
    title_ar: 'تم تسجيل عدم الحضور',
    title_en: 'No-Show Marked',
    body_ar: 'تم تسجيل الراكب {passengerName} كغير حاضر',
    body_en: 'Passenger {passengerName} has been marked as no-show',
  },
  [NOTIFICATION_TYPES.SEAT_ASSIGNED]: {
    title_ar: 'تم تعيين المقعد',
    title_en: 'Seat Assigned',
    body_ar: 'تم تعيينك في المقعد {seatNumber} لرحلتك من {from} إلى {to}',
    body_en: 'You have been assigned seat {seatNumber} for your trip from {from} to {to}',
  },
};

/**
 * Replace template variables in a string
 * @param {string} template - Template string with {variable} placeholders
 * @param {object} data - Data object with variable values
 * @returns {string} - String with variables replaced
 */
function replaceVariables(template, data = {}) {
  if (!template) return '';
  
  let result = template;
  Object.keys(data).forEach((key) => {
    const value = data[key] || '';
    result = result.replace(new RegExp(`\\{${key}\\}`, 'g'), value);
  });
  return result;
}

/**
 * Get notification content for a specific type and language
 * @param {string} type - Notification type
 * @param {string} language - Language code ('ar' or 'en')
 * @param {object} data - Data for variable substitution
 * @returns {object} - Object with title and body
 */
export function getNotificationContent(type, language = 'ar', data = {}) {
  const template = templates[type];
  
  if (!template) {
    return {
      title: 'إشعار',
      body: 'إشعار جديد',
    };
  }

  const isArabic = language === 'ar' || language === 'arabic';
  
  return {
    title: replaceVariables(
      isArabic ? template.title_ar : (template.title_en || template.title_ar),
      data
    ),
    body: replaceVariables(
      isArabic ? template.body_ar : (template.body_en || template.body_ar),
      data
    ),
  };
}

export default templates;
