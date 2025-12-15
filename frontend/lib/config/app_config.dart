class AppConfig {
  static const String apiBaseUrl = 'http://192.168.1.10:3000/api';
  static const Duration requestTimeout = Duration(seconds: 30);
  static String get healthCheckUrl => 'http://10.0.2.2:3000/health';

  
  static const String stripePublishableKey = 'pk_test_51SeYBkCWl8uf2393FACw8wAn1BMUkcJnGDTj4Zvp7wVOgAJrun1n9qEv3oy35K5HcdWycE7saXK6VrCRFj3nlC9A00kSSaMgTY';
}
