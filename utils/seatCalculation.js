/**
 * Calculate available passenger seats (excluding driver seat)
 * Note: Broken seats are NOT subtracted - they are handled separately in the UI
 * @param {number} totalSeats - Total seats in vehicle (including driver)
 * @param {number} reservedSeats - Number of reserved seats
 * @param {number} brokenSeats - Number of broken seats (not used in calculation)
 * @returns {number} - Available passenger seats (excluding driver)
 */
export const calculateAvailablePassengerSeats = (totalSeats, reservedSeats = 0, brokenSeats = 0) => {
  // Total passenger seats = total seats - 1 (driver seat)
  // Note: broken seats are not subtracted - they are handled in the UI/seat selection
  const totalPassengerSeats = totalSeats - 1;
  const availableSeats = totalPassengerSeats - reservedSeats;
  return Math.max(0, availableSeats);
};

/**
 * Get total passenger seats (excluding driver)
 * @param {number} totalSeats - Total seats in vehicle (including driver)
 * @returns {number} - Total passenger seats
 */
export const getTotalPassengerSeats = (totalSeats) => {
  return Math.max(0, totalSeats - 1);
};

