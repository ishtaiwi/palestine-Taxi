import supabase from '../config/dbcon.js';

const CONFIG_KEY_TIMEZONE = 'timezone_offset';
const DEFAULT_TIMEZONE_OFFSET = 2; // UTC+2 (Palestine) as default

class AppConfig {
  /**
   * Get timezone offset from database
   * @returns {Promise<number>} Timezone offset in hours (e.g., 2 for UTC+2, -5 for UTC-5)
   */
  static async getTimezoneOffset() {
    try {
      const { data, error } = await supabase
        .from('app_config')
        .select('value')
        .eq('key', CONFIG_KEY_TIMEZONE)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.warn('[AppConfig] Error fetching timezone offset:', error);
        return DEFAULT_TIMEZONE_OFFSET;
      }

      if (data && data.value !== null && data.value !== undefined) {
        return parseInt(data.value, 10);
      }

      // If no config exists, return default and create it
      await this.setTimezoneOffset(DEFAULT_TIMEZONE_OFFSET);
      return DEFAULT_TIMEZONE_OFFSET;
    } catch (error) {
      console.warn('[AppConfig] Error in getTimezoneOffset:', error);
      return DEFAULT_TIMEZONE_OFFSET;
    }
  }

  /**
   * Set timezone offset in database
   * @param {number} offset - Timezone offset in hours (e.g., 2 for UTC+2, -5 for UTC-5)
   * @returns {Promise<boolean>} Success status
   */
  static async setTimezoneOffset(offset) {
    try {
      // Validate offset is a number between -12 and 14 (valid timezone range)
      const numOffset = parseInt(offset, 10);
      if (isNaN(numOffset) || numOffset < -12 || numOffset > 14) {
        throw new Error(`Invalid timezone offset: ${offset}. Must be between -12 and 14.`);
      }

      // Check if config exists
      const { data: existing } = await supabase
        .from('app_config')
        .select('id')
        .eq('key', CONFIG_KEY_TIMEZONE)
        .maybeSingle();

      if (existing) {
        // Update existing config
        const { error } = await supabase
          .from('app_config')
          .update({
            value: numOffset.toString(),
            updated_at: new Date().toISOString(),
          })
          .eq('key', CONFIG_KEY_TIMEZONE);

        if (error) throw error;
      } else {
        // Create new config
        const { error } = await supabase
          .from('app_config')
          .insert({
            key: CONFIG_KEY_TIMEZONE,
            value: numOffset.toString(),
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          });

        if (error) throw error;
      }

      return true;
    } catch (error) {
      console.error('[AppConfig] Error setting timezone offset:', error);
      throw error;
    }
  }

  /**
   * Get all app configuration
   * @returns {Promise<Map<string, any>>} Configuration map
   */
  static async getAllConfig() {
    try {
      const { data, error } = await supabase
        .from('app_config')
        .select('key, value');

      if (error) throw error;

      const config = {};
      (data || []).forEach(item => {
        config[item.key] = item.value;
      });

      return config;
    } catch (error) {
      console.error('[AppConfig] Error getting all config:', error);
      throw error;
    }
  }
}

export default AppConfig;

