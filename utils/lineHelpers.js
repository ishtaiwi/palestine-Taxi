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
 * Get line names for notification based on user's language preference and trip direction
 * This uses the same logic as notificationService to determine language
 * @param {object} line - Line object
 * @param {string} userid - User ID to get language preference
 * @param {object} req - Optional Express request object to check Accept-Language header
 * @param {string} preferredLanguage - Optional language to use (if provided, will use this instead of fetching from DB)
 * @param {string} direction - Trip direction ('going' or 'return') to determine origin/destination stations
 * @returns {Promise<object>} - Object with fromName and toName in user's language, and language code
 */
export const getLineNamesForNotification = async (line, userid, req = null, preferredLanguage = null, direction = null) => {
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
  
  // If direction is provided, get station names based on direction
  // For 'going': from = main_station, to = return_station
  // For 'return': from = return_station, to = main_station
  if (direction && (direction === 'going' || direction === 'return')) {
    try {
      const BaseStation = (await import('../models/BaseStation.js')).default;
      
      let originStation = null;
      let destinationStation = null;
      
      if (direction === 'going') {
        // Going: from main_station to return_station
        if (line.main_stationid) {
          try {
            originStation = await BaseStation.findById(line.main_stationid);
          } catch (err) {
            const logger = (await import('../utils/logger.js')).default;
            logger.warn(`[LineHelpers] Error fetching main station ${line.main_stationid} for line ${line.lineid}:`, err);
          }
        }
        if (line.return_stationid) {
          try {
            destinationStation = await BaseStation.findById(line.return_stationid);
          } catch (err) {
            const logger = (await import('../utils/logger.js')).default;
            logger.warn(`[LineHelpers] Error fetching return station ${line.return_stationid} for line ${line.lineid}:`, err);
          }
        }
      } else {
        // Return: from return_station to main_station
        if (line.return_stationid) {
          try {
            originStation = await BaseStation.findById(line.return_stationid);
          } catch (err) {
            const logger = (await import('../utils/logger.js')).default;
            logger.warn(`[LineHelpers] Error fetching return station ${line.return_stationid} for line ${line.lineid}:`, err);
          }
        }
        if (line.main_stationid) {
          try {
            destinationStation = await BaseStation.findById(line.main_stationid);
          } catch (err) {
            const logger = (await import('../utils/logger.js')).default;
            logger.warn(`[LineHelpers] Error fetching main station ${line.main_stationid} for line ${line.lineid}:`, err);
          }
        }
      }
      
      // Only use station names if they exist and are valid
      let fromName = (originStation && originStation.name && originStation.name.trim()) ? originStation.name.trim() : null;
      let toName = (destinationStation && destinationStation.name && destinationStation.name.trim()) ? destinationStation.name.trim() : null;
      
      // Validate station names - reject obviously corrupted data
      // Reject names that are too short, corrupted patterns, or generic placeholders
      const corruptedPatterns = /^(ijn|ij|station|unknown|n\/a|na|main)$/i;
      if (fromName && (fromName.length < 3 || corruptedPatterns.test(fromName))) {
        const logger = (await import('../utils/logger.js')).default;
        logger.warn(`[LineHelpers] Rejected corrupted station name "${fromName}" for origin station. Setting to null.`);
        fromName = null;
      }
      if (toName && (toName.length < 3 || corruptedPatterns.test(toName))) {
        const logger = (await import('../utils/logger.js')).default;
        logger.warn(`[LineHelpers] Rejected corrupted station name "${toName}" for destination station. Setting to null.`);
        toName = null;
      }
      
      // If both station names are valid, return them
      if (fromName && toName) {
        const logger = (await import('../utils/logger.js')).default;
        logger.info(`[LineHelpers] Successfully retrieved station names for line ${line.lineid} (direction: ${direction}, language: ${language}). From: ${fromName}, To: ${toName}`);
        return { fromName, toName, language };
      }
      
      // If direction is provided but stations are missing/invalid, fall back to line name
      // Split line name by "-" to get station names
      const logger = (await import('../utils/logger.js')).default;
      if (!fromName || !toName) {
        logger.warn(`[LineHelpers] Missing or invalid station names for line ${line.lineid} (direction: ${direction}, language: ${language}). From: ${fromName || 'missing'}, To: ${toName || 'missing'}. Main station ID: ${line.main_stationid}, Return station ID: ${line.return_stationid}. Falling back to line name.`);
        
        // Fallback: Use line name and split by "-"
        const lineName = getLineName(line, language);
        
        // Split line name by "-" to get station names
        if (lineName && lineName.includes('-')) {
          const parts = lineName.split('-').map(part => part.trim()).filter(part => part.length > 0);
          
          if (parts.length >= 2) {
            // For "going": from = first part, to = second part
            // For "return": from = second part, to = first part
            if (direction === 'going') {
              return { 
                fromName: parts[0], 
                toName: parts[1], 
                language 
              };
            } else if (direction === 'return') {
              return { 
                fromName: parts[1], 
                toName: parts[0], 
                language 
              };
            }
          }
        }
        
        // If line name doesn't have "-" or can't be split, return Unknown
        logger.warn(`[LineHelpers] Line name "${lineName}" cannot be split by "-" for line ${line.lineid}. Returning Unknown.`);
        return { 
          fromName: fromName || 'Unknown', 
          toName: toName || 'Unknown', 
          language 
        };
      }
    } catch (error) {
      const logger = (await import('../utils/logger.js')).default;
      logger.error(`[LineHelpers] Error fetching station names for line ${line.lineid} (direction: ${direction}):`, error);
      
      // Fallback: Use line name and split by "-"
      try {
        const lineName = getLineName(line, language);
        
        // Split line name by "-" to get station names
        if (lineName && lineName.includes('-')) {
          const parts = lineName.split('-').map(part => part.trim()).filter(part => part.length > 0);
          
          if (parts.length >= 2) {
            // For "going": from = first part, to = second part
            // For "return": from = second part, to = first part
            if (direction === 'going') {
              return { 
                fromName: parts[0], 
                toName: parts[1], 
                language 
              };
            } else if (direction === 'return') {
              return { 
                fromName: parts[1], 
                toName: parts[0], 
                language 
              };
            }
          }
        }
      } catch (fallbackError) {
        logger.error(`[LineHelpers] Error in fallback to line name for line ${line.lineid}:`, fallbackError);
      }
      
      return { fromName: 'Unknown', toName: 'Unknown', language };
    }
  }
  
  // Fallback: If direction was NOT provided or invalid, use line name
  // Split line name by "-" to get station names if possible
  const lineName = getLineName(line, language);
  
  // Log for debugging if English name is missing
  if (language === 'en' && (!line.name_en || line.name_en.trim() === '')) {
    const logger = (await import('../utils/logger.js')).default;
    logger.warn(`[LineHelpers] Line ${line.lineid || 'unknown'} has no name_en, but language is 'en'. Line name will be: ${lineName}`);
  }
  
  // Try to split line name by "-" to get station names
  if (lineName && lineName.includes('-')) {
    const parts = lineName.split('-').map(part => part.trim()).filter(part => part.length > 0);
    
    if (parts.length >= 2) {
      // If direction is provided and valid, use it; otherwise default to 'going'
      const tripDirection = direction && (direction === 'going' || direction === 'return') ? direction : 'going';
      
      // For "going": from = first part, to = second part
      // For "return": from = second part, to = first part
      if (tripDirection === 'going') {
        return { 
          fromName: parts[0], 
          toName: parts[1], 
          language 
        };
      } else if (tripDirection === 'return') {
        return { 
          fromName: parts[1], 
          toName: parts[0], 
          language 
        };
      }
    }
  }
  
  // If line name doesn't have "-" or can't be split, use line name for both
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

