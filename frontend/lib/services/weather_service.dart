import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class WeatherData {
  final String cityName;
  final String description;
  final String icon;
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double windSpeed;
  final int cloudiness;
  final int visibility;
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime fetchedAt;
  final bool isMockData;

  WeatherData({
    required this.cityName,
    required this.description,
    required this.icon,
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.cloudiness,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.fetchedAt,
    this.isMockData = false,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;
    final clouds = json['clouds'] as Map<String, dynamic>;
    final sys = json['sys'] as Map<String, dynamic>;

    return WeatherData(
      cityName: json['name'] ?? '',
      description: weather['description'] ?? '',
      icon: weather['icon'] ?? '01d',
      temperature: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      tempMin: (main['temp_min'] as num).toDouble(),
      tempMax: (main['temp_max'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      cloudiness: clouds['all'] as int,
      visibility: json['visibility'] as int? ?? 10000,
      sunrise:
          DateTime.fromMillisecondsSinceEpoch((sys['sunrise'] as int) * 1000),
      sunset:
          DateTime.fromMillisecondsSinceEpoch((sys['sunset'] as int) * 1000),
      fetchedAt: DateTime.now(),
      isMockData: json['isMockData'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': cityName,
      'weather': [
        {'description': description, 'icon': icon}
      ],
      'main': {
        'temp': temperature,
        'feels_like': feelsLike,
        'temp_min': tempMin,
        'temp_max': tempMax,
        'humidity': humidity,
      },
      'wind': {'speed': windSpeed},
      'clouds': {'all': cloudiness},
      'visibility': visibility,
      'sys': {
        'sunrise': sunrise.millisecondsSinceEpoch ~/ 1000,
        'sunset': sunset.millisecondsSinceEpoch ~/ 1000,
      },
      'fetchedAt': fetchedAt.toIso8601String(),
      'isMockData': isMockData,
    };
  }

  /// Get the OpenWeatherMap icon URL
  String get iconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';

  /// Check if weather data is still fresh (within cache duration)
  bool get isFresh {
    final cacheMinutes = 15;
    return DateTime.now().difference(fetchedAt).inMinutes < cacheMinutes;
  }
}

class WeatherService {
  static const String _cacheKey = 'weather_cache';
  static const String _cityKey = 'weather_city';
  static const String _apiCallCountKey = 'weather_api_call_count';
  static const String _apiCallDateKey = 'weather_api_call_date';
  static const String _defaultCity = 'Ramallah';

  /// Maximum API calls per day to prevent unexpected charges
  static const int _maxDailyApiCalls = 1000;

  static WeatherData? _cachedData;

  /// Get the configured city name
  static Future<String> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey) ?? _defaultCity;
  }

  /// Set the city name for weather
  static Future<void> setCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
    // Clear cache when city changes
    _cachedData = null;
    await prefs.remove(_cacheKey);
  }

  /// Check if we can make another API call today
  static Future<bool> _canMakeApiCall() async {
    final prefs = await SharedPreferences.getInstance();
    final today =
        DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
    final savedDate = prefs.getString(_apiCallDateKey);

    if (savedDate != today) {
      // New day, reset counter
      await prefs.setString(_apiCallDateKey, today);
      await prefs.setInt(_apiCallCountKey, 0);
      return true;
    }

    final callCount = prefs.getInt(_apiCallCountKey) ?? 0;
    return callCount < _maxDailyApiCalls;
  }

  /// Increment the API call counter
  static Future<void> _incrementApiCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_apiCallDateKey);

    if (savedDate != today) {
      await prefs.setString(_apiCallDateKey, today);
      await prefs.setInt(_apiCallCountKey, 1);
    } else {
      final currentCount = prefs.getInt(_apiCallCountKey) ?? 0;
      await prefs.setInt(_apiCallCountKey, currentCount + 1);
    }
  }

  /// Get the remaining API calls for today
  static Future<int> getRemainingApiCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_apiCallDateKey);

    if (savedDate != today) {
      return _maxDailyApiCalls;
    }

    final callCount = prefs.getInt(_apiCallCountKey) ?? 0;
    return _maxDailyApiCalls - callCount;
  }

  /// Fetch current weather data
  static Future<WeatherData?> getCurrentWeather(
      {bool forceRefresh = false}) async {
    final city = await getCity();

    // Check memory cache first
    if (!forceRefresh && _cachedData != null && _cachedData!.isFresh) {
      return _cachedData;
    }

    // Check persistent cache
    if (!forceRefresh) {
      final cachedData = await _loadFromCache();
      if (cachedData != null && cachedData.isFresh) {
        _cachedData = cachedData;
        return cachedData;
      }
    }

    // Check API key
    final apiKey = AppConfig.openWeatherApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_OPENWEATHERMAP_API_KEY') {
      // No API key configured, return mock data
      return _getMockWeatherData(city);
    }

    // Check daily limit
    final canCall = await _canMakeApiCall();
    if (!canCall) {
      // Daily limit reached, return cached or mock data
      final cachedData = await _loadFromCache();
      if (cachedData != null) {
        return cachedData;
      }
      return _getMockWeatherData(city);
    }

    // Fetch fresh data from API
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?q=$city'
        '&appid=$apiKey'
        '&units=metric',
      );

      final response = await http.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        // Increment call count on successful API call
        await _incrementApiCallCount();

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final weatherData = WeatherData.fromJson(json);

        // Update caches
        _cachedData = weatherData;
        await _saveToCache(weatherData);

        return weatherData;
      } else {
        // API error, return cached or mock data
        final cachedData = await _loadFromCache();
        if (cachedData != null) {
          return cachedData;
        }
        return _getMockWeatherData(city);
      }
    } catch (e) {
      // Network error, return cached or mock data
      if (_cachedData != null) {
        return _cachedData;
      }
      final cachedData = await _loadFromCache();
      if (cachedData != null) {
        return cachedData;
      }
      return _getMockWeatherData(city);
    }
  }

  /// Generate mock weather data for fallback
  static WeatherData _getMockWeatherData(String city) {
    final random = Random();
    final now = DateTime.now();
    final hour = now.hour;

    // Seasonal temperature adjustment (Palestine climate)
    final month = now.month;
    double baseTemp;
    if (month >= 6 && month <= 8) {
      // Summer: 25-35°C
      baseTemp = 25 + random.nextDouble() * 10;
    } else if (month >= 12 || month <= 2) {
      // Winter: 8-18°C
      baseTemp = 8 + random.nextDouble() * 10;
    } else {
      // Spring/Fall: 15-25°C
      baseTemp = 15 + random.nextDouble() * 10;
    }

    // Time of day adjustment
    if (hour >= 6 && hour < 12) {
      baseTemp -= 2; // Morning cooler
    } else if (hour >= 12 && hour < 18) {
      baseTemp += 3; // Afternoon warmer
    } else {
      baseTemp -= 4; // Night cooler
    }

    // Weather conditions based on season
    final List<Map<String, String>> conditions;
    if (month >= 11 || month <= 3) {
      // Rainy season
      conditions = [
        {'desc': 'partly cloudy', 'icon': '02d'},
        {'desc': 'cloudy', 'icon': '03d'},
        {'desc': 'overcast clouds', 'icon': '04d'},
        {'desc': 'light rain', 'icon': '10d'},
        {'desc': 'scattered clouds', 'icon': '03d'},
      ];
    } else {
      // Dry season
      conditions = [
        {'desc': 'clear sky', 'icon': '01d'},
        {'desc': 'few clouds', 'icon': '02d'},
        {'desc': 'sunny', 'icon': '01d'},
        {'desc': 'partly cloudy', 'icon': '02d'},
      ];
    }

    // Adjust icon for night time
    final condition = conditions[random.nextInt(conditions.length)];
    String icon = condition['icon']!;
    if (hour < 6 || hour >= 19) {
      icon = icon.replaceAll('d', 'n'); // Night icon
    }

    // Calculate sunrise/sunset (approximate for Palestine)
    final sunrise = DateTime(now.year, now.month, now.day,
        5 + (month > 6 ? 1 : 0), 30 + random.nextInt(30));
    final sunset = DateTime(now.year, now.month, now.day,
        17 + (month > 3 && month < 10 ? 2 : 0), 30 + random.nextInt(30));

    return WeatherData(
      cityName: city,
      description: condition['desc']!,
      icon: icon,
      temperature: double.parse(baseTemp.toStringAsFixed(1)),
      feelsLike: double.parse(
          (baseTemp + (random.nextDouble() * 4 - 2)).toStringAsFixed(1)),
      tempMin: double.parse(
          (baseTemp - 3 - random.nextDouble() * 2).toStringAsFixed(1)),
      tempMax: double.parse(
          (baseTemp + 3 + random.nextDouble() * 2).toStringAsFixed(1)),
      humidity: 40 + random.nextInt(40), // 40-80%
      windSpeed: 1.0 + random.nextDouble() * 5, // 1-6 m/s
      cloudiness: random.nextInt(80), // 0-80%
      visibility: 8000 + random.nextInt(4000), // 8-12 km
      sunrise: sunrise,
      sunset: sunset,
      fetchedAt: now,
      isMockData: true,
    );
  }

  /// Load weather data from persistent cache
  static Future<WeatherData?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson != null) {
        final json = jsonDecode(cacheJson) as Map<String, dynamic>;
        // Reconstruct with fetchedAt from cache
        final fetchedAt = json['fetchedAt'] != null
            ? DateTime.parse(json['fetchedAt'] as String)
            : DateTime.now().subtract(const Duration(hours: 1));

        final data = WeatherData.fromJson(json);
        // Create new instance with correct fetchedAt
        return WeatherData(
          cityName: data.cityName,
          description: data.description,
          icon: data.icon,
          temperature: data.temperature,
          feelsLike: data.feelsLike,
          tempMin: data.tempMin,
          tempMax: data.tempMax,
          humidity: data.humidity,
          windSpeed: data.windSpeed,
          cloudiness: data.cloudiness,
          visibility: data.visibility,
          sunrise: data.sunrise,
          sunset: data.sunset,
          fetchedAt: fetchedAt,
          isMockData: data.isMockData,
        );
      }
    } catch (e) {
      // Ignore cache errors
    }
    return null;
  }

  /// Save weather data to persistent cache
  static Future<void> _saveToCache(WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
    } catch (e) {
      // Ignore cache errors
    }
  }

  /// Get weather condition icon based on icon code
  static String getWeatherIcon(String iconCode) {
    // Map OpenWeatherMap icon codes to emoji/text representation
    switch (iconCode.substring(0, 2)) {
      case '01':
        return '☀️'; // clear sky
      case '02':
        return '⛅'; // few clouds
      case '03':
        return '☁️'; // scattered clouds
      case '04':
        return '☁️'; // broken clouds
      case '09':
        return '🌧️'; // shower rain
      case '10':
        return '🌦️'; // rain
      case '11':
        return '⛈️'; // thunderstorm
      case '13':
        return '❄️'; // snow
      case '50':
        return '🌫️'; // mist
      default:
        return '🌤️';
    }
  }

  /// Get a list of common cities for selection
  static List<Map<String, String>> getCityOptions() {
    return [
      {'name': 'Ramallah', 'nameAr': 'رام الله'},
      {'name': 'Jerusalem', 'nameAr': 'القدس'},
      {'name': 'Nablus', 'nameAr': 'نابلس'},
      {'name': 'Hebron', 'nameAr': 'الخليل'},
      {'name': 'Bethlehem', 'nameAr': 'بيت لحم'},
      {'name': 'Gaza', 'nameAr': 'غزة'},
      {'name': 'Jenin', 'nameAr': 'جنين'},
      {'name': 'Jericho', 'nameAr': 'أريحا'},
      {'name': 'Tulkarm', 'nameAr': 'طولكرم'},
      {'name': 'Qalqilya', 'nameAr': 'قلقيلية'},
    ];
  }
}
