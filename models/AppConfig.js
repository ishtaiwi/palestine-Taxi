import supabase from '../config/dbcon.js';
import { CONFIG_KEY_QUEUE_LOCATION_VALIDATION } from '../utils/constants.js';

const CONFIG_KEY_TIMEZONE = 'timezone_offset';
const DEFAULT_TIMEZONE_OFFSET = 2;
const DEFAULT_QUEUE_LOCATION_VALIDATION = true;

class AppConfig {
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

      await this.setTimezoneOffset(DEFAULT_TIMEZONE_OFFSET);
      return DEFAULT_TIMEZONE_OFFSET;
    } catch (error) {
      console.warn('[AppConfig] Error in getTimezoneOffset:', error);
      return DEFAULT_TIMEZONE_OFFSET;
    }
  }

  static async setTimezoneOffset(offset) {
    try {
      const numOffset = parseInt(offset, 10);
      if (isNaN(numOffset) || numOffset < -12 || numOffset > 14) {
        throw new Error(`Invalid timezone offset: ${offset}. Must be between -12 and 14.`);
      }

      const { data: existing } = await supabase
        .from('app_config')
        .select('id')
        .eq('key', CONFIG_KEY_TIMEZONE)
        .maybeSingle();

      if (existing) {
        const { error } = await supabase
          .from('app_config')
          .update({
            value: numOffset.toString(),
            updated_at: new Date().toISOString(),
          })
          .eq('key', CONFIG_KEY_TIMEZONE);

        if (error) throw error;
      } else {
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

  static async getQueueLocationValidationEnabled() {
    try {
      const { data, error } = await supabase
        .from('app_config')
        .select('value')
        .eq('key', CONFIG_KEY_QUEUE_LOCATION_VALIDATION)
        .maybeSingle();

      if (error && error.code !== 'PGRST116') {
        console.warn('[AppConfig] Error fetching queue location validation setting:', error);
        return DEFAULT_QUEUE_LOCATION_VALIDATION;
      }

      if (data && data.value !== null && data.value !== undefined) {
        return data.value === 'true' || data.value === true;
      }

      await this.setQueueLocationValidationEnabled(DEFAULT_QUEUE_LOCATION_VALIDATION);
      return DEFAULT_QUEUE_LOCATION_VALIDATION;
    } catch (error) {
      console.warn('[AppConfig] Error in getQueueLocationValidationEnabled:', error);
      return DEFAULT_QUEUE_LOCATION_VALIDATION;
    }
  }

  static async setQueueLocationValidationEnabled(enabled) {
    try {
      const boolValue = enabled === true || enabled === 'true' || enabled === 1 || enabled === '1';
      const valueStr = boolValue.toString();

      const { data: existing } = await supabase
        .from('app_config')
        .select('id')
        .eq('key', CONFIG_KEY_QUEUE_LOCATION_VALIDATION)
        .maybeSingle();

      if (existing) {
        const { error } = await supabase
          .from('app_config')
          .update({
            value: valueStr,
            updated_at: new Date().toISOString(),
          })
          .eq('key', CONFIG_KEY_QUEUE_LOCATION_VALIDATION);

        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('app_config')
          .insert({
            key: CONFIG_KEY_QUEUE_LOCATION_VALIDATION,
            value: valueStr,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          });

        if (error) throw error;
      }

      return true;
    } catch (error) {
      console.error('[AppConfig] Error setting queue location validation:', error);
      throw error;
    }
  }
}

export default AppConfig;

