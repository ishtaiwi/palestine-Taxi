import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../services/location_service.dart';
import '../../services/navigation_service.dart';
import '../../services/api_service.dart';

class DriverLocationTrackingPage extends StatefulWidget {
  const DriverLocationTrackingPage({super.key});

  @override
  State<DriverLocationTrackingPage> createState() =>
      _DriverLocationTrackingPageState();
}

class _DriverLocationTrackingPageState
    extends State<DriverLocationTrackingPage> {
  final LocationService _locationService = LocationService.instance;
  bool _isTracking = false;
  bool _isAtBaseStation = false;
  Position? _currentPosition;
  Map<String, dynamic>? _baseStation;
  Map<String, dynamic>? _linePath;
  String? _lineid;
  double? _distanceToBaseStation;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Check if tracking was enabled
    final wasTracking = await _locationService.loadTrackingState();
    if (wasTracking) {
      await _startTracking();
    }

    // Get driver's line
    final userData = await ApiService.getUserData();
    if (userData != null && userData['driver'] != null) {
      final driver = userData['driver'] as Map<String, dynamic>;
      _lineid = driver['lineid']?.toString();

      if (_lineid != null) {
        // Load line path
        final pathResult = await ApiService.getLinePath(_lineid!);
        if (pathResult['success'] == true) {
          setState(() {
            _linePath = pathResult['path'];
          });
        }
      }
    }

    // Load base stations
    final stationsResult = await ApiService.getAllBaseStations(isActive: true);
    if (stationsResult['success'] == true &&
        stationsResult['stations'] != null) {
      final stations = stationsResult['stations'] as List;
      if (stations.isNotEmpty) {
        setState(() {
          _baseStation = stations[0] as Map<String, dynamic>;
        });
      }
    }

    // Get current location
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentPosition = position;
      });
      _checkBaseStationStatus(position);
    }
  }

  Future<void> _startTracking() async {
    final hasPermission = await _locationService.checkLocationPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for tracking'),
          ),
        );
      }
      return;
    }

    final started = await _locationService.startLocationTracking();
    if (started) {
      setState(() {
        _isTracking = true;
      });

      // Listen to position updates
      _positionSubscription =
          _locationService.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _checkBaseStationStatus(position);
        }
      });
    }
  }

  Future<void> _stopTracking() async {
    await _locationService.stopLocationTracking();
    if (mounted) {
      setState(() {
        _isTracking = false;
      });
    }
  }

  void _checkBaseStationStatus(Position position) {
    if (_baseStation != null) {
      final stationLat = _baseStation!['latitude']?.toDouble() ?? 0.0;
      final stationLng = _baseStation!['longitude']?.toDouble() ?? 0.0;
      final radius = _baseStation!['geofence_radius_meters']?.toInt() ?? 100;

      final distance = NavigationService.calculateDistanceToBaseStation(
        currentLat: position.latitude,
        currentLng: position.longitude,
        stationLat: stationLat,
        stationLng: stationLng,
      );

      setState(() {
        _distanceToBaseStation = distance;
        _isAtBaseStation = distance <= radius;
      });
    }
  }

  Future<void> _navigateToBaseStation() async {
    if (_baseStation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Base station not found')),
      );
      return;
    }

    final success = await NavigationService.navigateToBaseStation(
      latitude: _baseStation!['latitude']?.toDouble() ?? 0.0,
      longitude: _baseStation!['longitude']?.toDouble() ?? 0.0,
      name: _baseStation!['name']?.toString(),
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation app')),
      );
    }
  }

  Future<void> _navigateAlongLinePath() async {
    if (_lineid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No line assigned')),
      );
      return;
    }

    List<Map<String, dynamic>>? waypoints;
    if (_linePath != null && _linePath!['waypoints'] != null) {
      waypoints = (_linePath!['waypoints'] as List)
          .map((wp) => Map<String, dynamic>.from(wp))
          .toList();
    }

    final success = await NavigationService.navigateAlongLinePath(
      lineid: _lineid!,
      waypoints: waypoints,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracking'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tracking status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Location Tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Switch(
                          value: _isTracking,
                          onChanged: (value) {
                            if (value) {
                              _startTracking();
                            } else {
                              _stopTracking();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isTracking
                          ? 'Tracking active - Location updates every 10 seconds'
                          : 'Tracking inactive',
                      style: TextStyle(
                        color: _isTracking ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Current location card
            if (_currentPosition != null)
              Builder(
                builder: (context) {
                  final position = _currentPosition!;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Latitude: ${position.latitude}'),
                          Text('Longitude: ${position.longitude}'),
                          Text(
                              'Accuracy: ${position.accuracy.toStringAsFixed(1)}m'),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),

            // Base station status card
            if (_baseStation != null)
              Card(
                color: _isAtBaseStation ? Colors.green.shade50 : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isAtBaseStation
                                ? Icons.check_circle
                                : Icons.location_on,
                            color:
                                _isAtBaseStation ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isAtBaseStation
                                ? 'At Base Station'
                                : 'Not at Base Station',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isAtBaseStation
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (_distanceToBaseStation != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Distance: ${(_distanceToBaseStation! / 1000).toStringAsFixed(2)} km',
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _navigateToBaseStation,
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to Base Station'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Line path navigation card
            if (_linePath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Line Path Navigation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_linePath!['distance_meters'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Route Distance: ${(_linePath!['distance_meters'] / 1000).toStringAsFixed(2)} km',
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _navigateAlongLinePath,
                        icon: const Icon(Icons.route),
                        label: const Text('Navigate Along Line Path'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Note: Path is cached for offline navigation',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel position subscription but don't stop tracking - let it run in background
    _positionSubscription?.cancel();
    super.dispose();
  }
}
