import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  LocationService._();

  StreamSubscription<Position>? _positionStream;
  Timer? _updateTimer;
  bool _isTracking = false;
  Position? _currentPosition;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;

  /// Stream of position updates (only active when tracking)
  Stream<Position> get positionStream => _positionController.stream;

  /// Check and request location permissions
  Future<bool> checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied by user');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print(
            'Location permission denied forever - user must enable in settings');
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking location permission: $e');
      return false;
    }
  }

  /// Get current location once
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  /// Start background location tracking (updates every 10 seconds)
  Future<bool> startLocationTracking() async {
    if (_isTracking) {
      return true;
    }

    bool hasPermission = await checkLocationPermission();
    if (!hasPermission) {
      return false;
    }

    try {
      // Start listening to position stream
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update when moved 10 meters
        ),
      ).listen(
        (Position position) {
          _currentPosition = position;
          _positionController.add(position); // Broadcast to listeners
          _sendLocationToServer(position);
        },
        onError: (error) {
          print('Location stream error: $error');
          // Try to restart tracking if there's a permission or service error
          if (error.toString().contains('permission') ||
              error.toString().contains('service')) {
            _isTracking = false;
            _saveTrackingState(false);
          }
        },
      );

      // Also send updates every 10 seconds regardless of movement
      _updateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (_currentPosition != null) {
          await _sendLocationToServer(_currentPosition!);
        } else {
          // Try to get current position if we don't have one
          Position? position = await getCurrentLocation();
          if (position != null) {
            await _sendLocationToServer(position);
          }
        }
      });

      _isTracking = true;
      await _saveTrackingState(true);

      // Send initial location
      Position? position = await getCurrentLocation();
      if (position != null) {
        await _sendLocationToServer(position);
      }

      return true;
    } catch (e) {
      print('Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    _isTracking = false;
    await _saveTrackingState(false);
  }

  /// Dispose resources
  void dispose() {
    _positionController.close();
  }

  /// Send location update to server with retry logic
  Future<void> _sendLocationToServer(Position position) async {
    int maxRetries = 3;
    int retryCount = 0;
    Duration retryDelay = const Duration(seconds: 2);

    while (retryCount < maxRetries) {
      try {
        await ApiService.updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          heading: position.heading,
          speed: position.speed,
          accuracy: position.accuracy,
        );
        // Success - reset retry count for next failure
        return;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print(
              'Error sending location to server after $maxRetries attempts: $e');
          // Don't throw - we want tracking to continue even if server updates fail
          return;
        }
        // Exponential backoff: wait longer between retries
        await Future.delayed(retryDelay * retryCount);
      }
    }
  }

  /// Save tracking state to preferences
  Future<void> _saveTrackingState(bool isTracking) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_tracking_enabled', isTracking);
  }

  /// Load tracking state from preferences
  Future<bool> loadTrackingState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('location_tracking_enabled') ?? false;
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}
