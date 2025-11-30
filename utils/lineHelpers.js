/**
 * Get line name based on language preference
 * @param {object} line - Line object
 * @param {string} language - Language code ('ar' or 'en')
 * @returns {string} - Line name in the specified language
 */
export const getLineName = (line, language = 'ar') => {
  if (!line) return '';
  
  // Priority: name_ar/name_en > linename
  if (language === 'ar' || language === 'arabic') {
    return line.name_ar || line.linename || line.name_en || '';
  } else {
    return line.name_en || line.linename || line.name_ar || '';
  }
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

