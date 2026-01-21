import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AppConfig {
  static const Duration requestTimeout = Duration(seconds: 30);

  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:3000';
    }

    return 'http://10.0.2.2:3000';
  }

  static String get apiBaseUrl => '$_baseUrl/api';
  static String get healthCheckUrl => '$_baseUrl/health';

  static const String stripePublishableKey =
      'pk_test_51SeYBkCWl8uf2393FACw8wAn1BMUkcJnGDTj4Zvp7wVOgAJrun1n9qEv3oy35K5HcdWycE7saXK6VrCRFj3nlC9A00kSSaMgTY';

  static const String openWeatherApiKey = 'YOUR_OPENWEATHERMAP_API_KEY';
}
