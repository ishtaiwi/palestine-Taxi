import dotenv from 'dotenv';
dotenv.config();
import { createClient } from '@supabase/supabase-js';
import logger from '../utils/logger.js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

let supabase = null;
let isConnected = false;

if (supabaseUrl && supabaseKey) {
  supabase = createClient(supabaseUrl, supabaseKey);
} else {
  logger.warn('Warning: Supabase configuration missing. Database operations will fail.');
}


export const testConnection = async () => {
  if (!supabase) {
    return {
      connected: false,
      error: 'Supabase client not initialized. Check your .env file.',
    };
  }

  try {
    
    const { data, error } = await supabase
      .from('user')
      .select('count')
      .limit(1);

    if (error) {
      
      if (error.code === '42P01' || error.message.includes('relation') || error.message.includes('does not exist')) {
        logger.warn('Database connected but table "user" does not exist. Please create the database schema.');
        isConnected = true;
        return {
          connected: true,
          warning: 'Database connected but schema may be incomplete.',
          error: error.message,
        };
      }
      
      isConnected = false;
      return {
        connected: false,
        error: error.message,
      };
    }

    isConnected = true;
    logger.info('✅ Database connection successful!');
    return {
      connected: true,
      message: 'Database connection successful',
    };
  } catch (error) {
    isConnected = false;
    logger.error('❌ Database connection failed:', error.message);
    return {
      connected: false,
      error: error.message,
    };
  }
};


export const getConnectionStatus = () => {
  return {
    connected: isConnected,
    configured: !!(supabaseUrl && supabaseKey),
    url: supabaseUrl ? `${supabaseUrl.substring(0, 30)}...` : 'Not configured',
  };
};

export default supabase;
