import { v4 as uuidv4 } from 'uuid';

// Generate UUID
export const generateId = () => {
  return uuidv4();
};

// Format date
export const formatDate = (date, format = 'YYYY-MM-DD HH:mm:ss') => {
  if (!date) return null;
  
  const d = new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  const hours = String(d.getHours()).padStart(2, '0');
  const minutes = String(d.getMinutes()).padStart(2, '0');
  const seconds = String(d.getSeconds()).padStart(2, '0');
  
  return format
    .replace('YYYY', year)
    .replace('MM', month)
    .replace('DD', day)
    .replace('HH', hours)
    .replace('mm', minutes)
    .replace('ss', seconds);
};

// Calculate time difference in hours
export const hoursUntil = (date) => {
  const now = new Date();
  const target = new Date(date);
  return (target - now) / (1000 * 60 * 60);
};

// Check if date is in the past
export const isPast = (date) => {
  return new Date(date) < new Date();
};

// Check if date is in the future
export const isFuture = (date) => {
  return new Date(date) > new Date();
};

// Generate seat location from number
export const generateSeatLocation = (seatNumber) => {
  return `seat_${seatNumber}`;
};

// Parse seat number from location
export const parseSeatNumber = (seatLocation) => {
  const match = seatLocation?.match(/seat_(\d+)/);
  return match ? parseInt(match[1], 10) : null;
};

// Calculate refund amount based on cancellation policy
// Updated policy: 60 minutes (no charge), less than 60 minutes (25% charge)
export const calculateRefund = (bookingPrice, hoursUntilDeparture, policy) => {
  // If cancelled 60+ minutes (1 hour) before departure: full refund (no charge)
  if (hoursUntilDeparture >= policy.NO_CHARGE_HOURS) {
    return bookingPrice; // Full refund
  }
  // If cancelled less than 60 minutes (but more than 0) before departure: 25% charge (75% refund)
  else if (hoursUntilDeparture > 0 && hoursUntilDeparture < policy.NO_CHARGE_HOURS) {
    return bookingPrice * (1 - policy.PARTIAL_CHARGE_PERCENTAGE); // 75% refund (25% charge)
  }
  // If cancelled at or after departure time: no refund
  return 0; // No refund
};

// Validate email
export const isValidEmail = (email) => {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
};

// Validate phone number (Palestinian format)
export const isValidPhone = (phone) => {
  const re = /^(\+972|0)?[5][0-9]{8}$/;
  return re.test(phone?.replace(/[\s\-()]/g, ''));
};

// Sanitize input
export const sanitize = (str) => {
  if (typeof str !== 'string') return str;
  return str.trim().replace(/[<>]/g, '');
};

// Paginate results
export const paginate = (array, page = 1, limit = 20) => {
  const startIndex = (page - 1) * limit;
  const endIndex = startIndex + limit;
  
  return {
    data: array.slice(startIndex, endIndex),
    pagination: {
      page,
      limit,
      total: array.length,
      totalPages: Math.ceil(array.length / limit),
      hasNext: endIndex < array.length,
      hasPrev: page > 1,
    },
  };
};

// Group by key
export const groupBy = (array, key) => {
  return array.reduce((result, item) => {
    const group = item[key];
    if (!result[group]) {
      result[group] = [];
    }
    result[group].push(item);
    return result;
  }, {});
};

// Calculate distance (simplified - you may want to use a proper geolocation library)
export const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371; // Radius of the Earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c; // Distance in km
};

// Format currency
export const formatCurrency = (amount, currency = 'ILS') => {
  return new Intl.NumberFormat('ar-PS', {
    style: 'currency',
    currency: currency,
  }).format(amount);
};

