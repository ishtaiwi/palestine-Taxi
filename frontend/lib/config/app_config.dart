class AppConfig {

  static const String apiBaseUrl = 'http://10.0.2.2:3000/api'; // Android Emulator
  
  // Timeout للـ requests
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Health check endpoint
  static String get healthCheckUrl => 'http://10.0.2.2:3000/health';
}

