import appConfig from '../config/app.js';

const logLevels = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3,
};

const currentLogLevel = appConfig.nodeEnv === 'production' ? logLevels.INFO : logLevels.DEBUG;

const logger = {
  error: (...args) => {
    if (currentLogLevel >= logLevels.ERROR) {
      console.error('[ERROR]', new Date().toISOString(), ...args);
    }
  },
  
  warn: (...args) => {
    if (currentLogLevel >= logLevels.WARN) {
      console.warn('[WARN]', new Date().toISOString(), ...args);
    }
  },
  
  info: (...args) => {
    if (currentLogLevel >= logLevels.INFO) {
      console.info('[INFO]', new Date().toISOString(), ...args);
    }
  },
  
  debug: (...args) => {
    if (currentLogLevel >= logLevels.DEBUG) {
      console.debug('[DEBUG]', new Date().toISOString(), ...args);
    }
  },
};

export default logger;

