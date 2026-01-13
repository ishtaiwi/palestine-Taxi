/**
 * Get line name based on language preference
 * @param {object} line - Line object
 * @param {string} language - Language code ('ar' or 'en')
 * @returns {string} - Line name in the specified language
 */
export const getLineName = (line, language = 'ar') => {
  if (!line) return 'Unknown';
  
  // For Arabic: prefer name_ar, fallback to linename, then name_en
  if (language === 'ar' || language === 'arabic') {
    return line.name_ar || line.linename || line.name_en || 'Unknown';
  } 
  // For English: prefer name_en, fallback to linename, but DO NOT fallback to Arabic
  else {
    // Only return English name if it exists, otherwise use linename or 'Unknown'
    // Do not fallback to Arabic name when user wants English
    if (line.name_en && line.name_en.trim() !== '') {
      return line.name_en;
    }
    // Fallback to linename if it exists and looks like English (optional)
    if (line.linename && line.linename.trim() !== '') {
      return line.linename;
    }
    // If no English name available, return 'Unknown' instead of Arabic
    return 'Unknown';
  }
};

/**
 * Get user's language preference from database
 * Uses the same logic as notificationService to ensure consistency
 * @param {string} userid - User ID
 * @param {object} req - Optional Express request object to check Accept-Language header
 * @returns {Promise<string>} - Language code ('ar' or 'en')
 */
export const getUserLanguage = async (userid, req = null) => {
  try {
    const User = (await import('../models/User.js')).default;
    const user = await User.findById(userid);
    
    // Check if user has language preference (same logic as notificationService)
    const languagePref = user?.language_preference;
    
    // If language preference is valid, use it
    if (languagePref === 'en' || languagePref === 'ar') {
      return languagePref;
    }
    
    // If not set in database, check Accept-Language header as fallback
    if (req && req.headers && req.headers['accept-language']) {
      const acceptLang = req.headers['accept-language'].toLowerCase();
      if (acceptLang.includes('en')) {
        return 'en';
      }
    }
    
    // Default to Arabic if not set (same as notificationService)
    return 'ar';
  } catch (error) {
    // Default to Arabic if user not found or error (same as notificationService)
    return 'ar';
  }
};

/**
 * Get line names for notification based on user's language preference
 * This uses the same logic as notificationService to determine language
 * @param {object} line - Line object
 * @param {string} userid - User ID to get language preference
 * @param {object} req - Optional Express request object to check Accept-Language header
 * @param {string} preferredLanguage - Optional language to use (if provided, will use this instead of fetching from DB)
 * @returns {Promise<object>} - Object with fromName and toName in user's language, and language code
 */
export const getLineNamesForNotification = async (line, userid, req = null, preferredLanguage = null) => {
  // Determine language - use preferredLanguage if provided, otherwise get from user
  let language = preferredLanguage;
  if (!language) {
    language = await getUserLanguage(userid, req);
  }
  
  // Ensure language is valid
  if (language !== 'en' && language !== 'ar') {
    language = 'ar'; // Default to Arabic
  }
  
  if (!line) {
    return { fromName: 'Unknown', toName: 'Unknown', language };
  }
  
  // Line name represents the route, so use the same name for both from and to
  const lineName = getLineName(line, language);
  
  // Log for debugging if English name is missing
  if (language === 'en' && (!line.name_en || line.name_en.trim() === '')) {
    const logger = (await import('../utils/logger.js')).default;
    logger.warn(`[LineHelpers] Line ${line.lineid || 'unknown'} has no name_en, but language is 'en'. Line name will be: ${lineName}`);
  }
  
  return { fromName: lineName, toName: lineName, language };
};

/**
 * Get line name for display (auto-detect from request or default to Arabic)
 * @param {object} line - Line object
 * @param {object} req - Express request object (optional)
 * @returns {string} - Line name in the appropriate language
 */
export const getLineNameForDisplay = (line, req = null) => {
  if (!line) return '';
  
  // Try to detect language from request
  let language = 'ar'; // Default to Arabic
  
  if (req) {
    // Check if user has language preference in session/token
    // Or check Accept-Language header
    const acceptLanguage = req.headers['accept-language'];
    if (acceptLanguage && acceptLanguage.includes('en')) {
      language = 'en';
    }
  }
  
  return getLineName(line, language);
};

