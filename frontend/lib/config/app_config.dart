class AppConfig {
  static const String apiBaseUrl = 'http://192.168.1.10:3000/api';
  static const Duration requestTimeout = Duration(seconds: 30);
  static String get healthCheckUrl => 'http://10.0.2.2:3000/health';
}
