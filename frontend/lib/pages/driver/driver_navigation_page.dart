import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';

/// Represents a turn-by-turn navigation instruction
class NavigationInstruction {
  final String type; // 'straight', 'left', 'right', 'slight_left', 'slight_right', 'u_turn', 'destination'
  final double distance; // meters to this maneuver
  final String streetName;
  final LatLng location;

  NavigationInstruction({
    required this.type,
    required this.distance,
    required this.streetName,
    required this.location,
  });

  IconData get icon {
    switch (type) {
      case 'left':
        return Icons.turn_left;
      case 'right':
        return Icons.turn_right;
      case 'slight_left':
        return Icons.turn_slight_left;
      case 'slight_right':
        return Icons.turn_slight_right;
      case 'u_turn':
        return Icons.u_turn_left;
      case 'destination':
        return Icons.flag;
      default:
        return Icons.straight;
    }
  }
}

class DriverNavigationPage extends StatefulWidget {
  final String tripId;
  final String lineId;
  final String lineName;

  const DriverNavigationPage({
    super.key,
    required this.tripId,
    required this.lineId,
    required this.lineName,
  });

  @override
  State<DriverNavigationPage> createState() => _DriverNavigationPageState();
}

class _DriverNavigationPageState extends State<DriverNavigationPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false;
  String? _error;

  // Route data
  List<LatLng> _routePoints = [];
  List<LatLng> _waypoints = [];
  double _totalDistance = 0;
  double _remainingDistance = 0;

  // Driver location and heading
  LatLng? _driverLocation;
  double _heading = 0; // Driver's heading in degrees
  double _speed = 0; // Speed in m/s
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  bool _navigationMode = true; // True = driving view, False = overview

  // Turn-by-turn navigation
  List<NavigationInstruction> _instructions = [];
  int _currentInstructionIndex = 0;
  double _distanceToNextTurn = 0;

  // Map settings
  LatLng _center = const LatLng(31.9522, 35.2332);
  double _drivingZoom = 18.0;
  double _overviewZoom = 14.0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الملاحة',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'noRoute': 'لا يوجد مسار محدد لهذا الخط',
      'distance': 'المسافة',
      'remaining': 'المتبقي',
      'km': 'كم',
      'meters': 'م',
      'endTrip': 'إنهاء الرحلة',
      'confirmEnd': 'هل أنت متأكد من إنهاء هذه الرحلة؟',
      'yes': 'نعم',
      'no': 'لا',
      'tripEnded': 'تم إنهاء الرحلة',
      'locationError': 'فشل الحصول على الموقع',
      'enableLocation': 'يرجى تفعيل خدمة الموقع',
      'startPoint': 'نقطة البداية',
      'endPoint': 'نقطة النهاية',
      'yourLocation': 'موقعك الحالي',
      'recenter': 'توسيط الخريطة',
      'straight': 'استمر مباشرة',
      'left': 'انعطف يساراً',
      'right': 'انعطف يميناً',
      'slightLeft': 'انحرف يساراً',
      'slightRight': 'انحرف يميناً',
      'uTurn': 'استدر للخلف',
      'destination': 'الوجهة أمامك',
      'speed': 'السرعة',
      'kmh': 'كم/س',
      'eta': 'الوصول',
      'min': 'دقيقة',
      'overview': 'نظرة عامة',
      'resume': 'استئناف',
      'arrived': 'وصلت!',
      'inMeters': 'في {distance} م',
      'inKm': 'في {distance} كم',
      'then': 'ثم',
    },
    'en': {
      'title': 'Navigation',
      'loading': 'Loading...',
      'error': 'Error',
      'noRoute': 'No route defined for this line',
      'distance': 'Distance',
      'remaining': 'Remaining',
      'km': 'km',
      'meters': 'm',
      'endTrip': 'End Trip',
      'confirmEnd': 'Are you sure you want to end this trip?',
      'yes': 'Yes',
      'no': 'No',
      'tripEnded': 'Trip ended',
      'locationError': 'Failed to get location',
      'enableLocation': 'Please enable location services',
      'startPoint': 'Start Point',
      'endPoint': 'End Point',
      'yourLocation': 'Your Location',
      'recenter': 'Recenter Map',
      'straight': 'Continue straight',
      'left': 'Turn left',
      'right': 'Turn right',
      'slightLeft': 'Bear left',
      'slightRight': 'Bear right',
      'uTurn': 'Make a U-turn',
      'destination': 'Destination ahead',
      'speed': 'Speed',
      'kmh': 'km/h',
      'eta': 'ETA',
      'min': 'min',
      'overview': 'Overview',
      'resume': 'Resume',
      'arrived': 'You have arrived!',
      'inMeters': 'In {distance} m',
      'inKm': 'In {distance} km',
      'then': 'Then',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key] ?? key;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    await AppTheme.init();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
        _isDarkMode = AppTheme.isDarkMode;
      });
    }
    await _loadRoute();
    await _startLocationTracking();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getLinePath(widget.lineId);
      
      if (result['success'] == true && result['path'] != null) {
        final path = result['path'];
        final waypoints = path['waypoints'] as List?;
        final polyline = path['polyline'] as String?;
        final distance = path['distance_meters'] as num?;

        if (waypoints != null && waypoints.isNotEmpty) {
          _waypoints = waypoints.map((wp) {
            final lat = wp['lat']?.toDouble() ?? wp['latitude']?.toDouble() ?? 0.0;
            final lng = wp['lng']?.toDouble() ?? wp['longitude']?.toDouble() ?? 0.0;
            return LatLng(lat, lng);
          }).toList();

          // Decode polyline if available
          if (polyline != null && polyline.isNotEmpty) {
            _routePoints = RoutingService.decodePolyline(polyline);
          } else {
            _routePoints = _waypoints;
          }

          _totalDistance = distance?.toDouble() ?? 0;
          _remainingDistance = _totalDistance;

          // Generate turn-by-turn instructions from waypoints
          _generateInstructions();

          // Center on first waypoint
          if (_waypoints.isNotEmpty) {
            _center = _waypoints.first;
          }

          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = t('noRoute');
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = t('noRoute');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Generate turn-by-turn instructions from route points
  void _generateInstructions() {
    _instructions.clear();
    if (_routePoints.length < 2) return;

    const Distance distanceCalc = Distance();

    for (int i = 0; i < _routePoints.length - 1; i++) {
      final current = _routePoints[i];
      final next = _routePoints[i + 1];
      
      // Calculate distance to next point
      final dist = distanceCalc.as(LengthUnit.Meter, current, next);

      // Calculate bearing/direction change
      String type = 'straight';
      if (i > 0) {
        final prev = _routePoints[i - 1];
        final prevBearing = _calculateBearing(prev, current);
        final nextBearing = _calculateBearing(current, next);
        final turnAngle = _normalizeAngle(nextBearing - prevBearing);

        if (turnAngle > 150 || turnAngle < -150) {
          type = 'u_turn';
        } else if (turnAngle > 45) {
          type = 'right';
        } else if (turnAngle < -45) {
          type = 'left';
        } else if (turnAngle > 20) {
          type = 'slight_right';
        } else if (turnAngle < -20) {
          type = 'slight_left';
        }
      }

      // Only add instruction if there's a turn or significant distance
      if (type != 'straight' || i == 0 || dist > 200) {
        _instructions.add(NavigationInstruction(
          type: type,
          distance: dist,
          streetName: '', // Would need reverse geocoding for street names
          location: current,
        ));
      }
    }

    // Add destination instruction
    if (_routePoints.isNotEmpty) {
      _instructions.add(NavigationInstruction(
        type: 'destination',
        distance: 0,
        streetName: widget.lineName,
        location: _routePoints.last,
      ));
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLon = (end.longitude - start.longitude) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    return math.atan2(y, x) * 180 / math.pi;
  }

  double _normalizeAngle(double angle) {
    while (angle > 180) angle -= 360;
    while (angle < -180) angle += 360;
    return angle;
  }

  Future<void> _startLocationTracking() async {
    try {
      // Check permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('enableLocation')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      // Get initial position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
          _heading = position.heading;
          _speed = position.speed;
          _isTracking = true;
          _center = _driverLocation!;
        });
        _updateNavigation();
      }

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Update every 5 meters for smoother navigation
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _driverLocation = LatLng(position.latitude, position.longitude);
            _heading = position.heading;
            _speed = position.speed;
            _updateNavigation();
            
            if (_navigationMode && _driverLocation != null) {
              _mapController.moveAndRotate(
                _driverLocation!,
                _drivingZoom,
                -_heading, // Rotate map to match heading (north-up = 0, so we negate)
              );
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('locationError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateNavigation() {
    if (_driverLocation == null || _routePoints.isEmpty) return;

    const Distance distanceCalc = Distance();

    // Find the closest point on the route
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, _driverLocation!, _routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    // Calculate remaining distance from closest point to end
    double remaining = 0;
    for (int i = closestIndex; i < _routePoints.length - 1; i++) {
      remaining += distanceCalc.as(LengthUnit.Meter, _routePoints[i], _routePoints[i + 1]);
    }
    _remainingDistance = remaining;

    // Update current instruction
    if (_instructions.isNotEmpty) {
      for (int i = _instructions.length - 1; i >= 0; i--) {
        final d = distanceCalc.as(LengthUnit.Meter, _driverLocation!, _instructions[i].location);
        if (d < 30 && i > _currentInstructionIndex) {
          // We've passed this instruction
          _currentInstructionIndex = i;
        }
      }

      // Calculate distance to next turn
      if (_currentInstructionIndex < _instructions.length - 1) {
        _distanceToNextTurn = distanceCalc.as(
          LengthUnit.Meter,
          _driverLocation!,
          _instructions[_currentInstructionIndex + 1].location,
        );
      } else {
        _distanceToNextTurn = distanceCalc.as(
          LengthUnit.Meter,
          _driverLocation!,
          _instructions.last.location,
        );
      }
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} ${t('km')}';
    }
    return '${meters.toStringAsFixed(0)} ${t('meters')}';
  }

  String _formatDistanceShort(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}';
    }
    return meters.toStringAsFixed(0);
  }

  String _getInstructionText(String type) {
    switch (type) {
      case 'left': return t('left');
      case 'right': return t('right');
      case 'slight_left': return t('slightLeft');
      case 'slight_right': return t('slightRight');
      case 'u_turn': return t('uTurn');
      case 'destination': return t('destination');
      default: return t('straight');
    }
  }

  int _calculateETA() {
    // Estimate based on average speed of 40 km/h in city
    final avgSpeedMps = 40 * 1000 / 3600; // 40 km/h in m/s
    return (_remainingDistance / avgSpeedMps / 60).ceil(); // minutes
  }

  Future<void> _endTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          t('endTrip'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
          ),
        ),
        content: Text(
          t('confirmEnd'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t('no'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(t('yes')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.endTrip(widget.tripId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('tripEnded')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate trip ended
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleNavigationMode() {
    setState(() {
      _navigationMode = !_navigationMode;
    });

    if (_navigationMode && _driverLocation != null) {
      _mapController.moveAndRotate(_driverLocation!, _drivingZoom, -_heading);
    } else if (_routePoints.isNotEmpty) {
      // Show overview - fit all route points
      _mapController.moveAndRotate(
        _routePoints[_routePoints.length ~/ 2],
        _overviewZoom,
        0, // North up
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: _isDarkMode ? const Color(0xFF0A0E21) : Colors.grey[100],
        body: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _buildNavigationView(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _isDarkMode
              ? [const Color(0xFF1C2541), const Color(0xFF0A0E21)]
              : [const Color(0xFF1E3A5F), const Color(0xFF2D5A87)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              t('loading'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _isDarkMode
              ? [const Color(0xFF1C2541), const Color(0xFF0A0E21)]
              : [const Color(0xFF1E3A5F), const Color(0xFF2D5A87)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Back button
              Align(
                alignment: _isArabic ? Alignment.topRight : Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.route_outlined,
                      size: 100,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _error ?? t('error'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _loadRoute,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white24,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(_isArabic ? 'إعادة المحاولة' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationView() {
    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _drivingZoom,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && _navigationMode) {
                // User manually moved map, switch to overview mode
                setState(() {
                  _navigationMode = false;
                });
              }
            },
          ),
          children: [
            // Dark mode tile layer
            TileLayer(
              urlTemplate: _isDarkMode
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.taxi_palestine_app',
            ),
            // Route polyline - completed portion (grey)
            if (_routePoints.length >= 2 && _driverLocation != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _getCompletedRoute(),
                    strokeWidth: 8,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                ],
              ),
            // Route polyline - remaining portion (bright color)
            if (_routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _getRemainingRoute(),
                    strokeWidth: 8,
                    color: _isDarkMode 
                        ? const Color(0xFF00E5FF) // Bright cyan for dark mode
                        : const Color(0xFF4285F4), // Google blue for light mode
                  ),
                ],
              ),
            // Waypoint markers
            MarkerLayer(
              markers: _buildWaypointMarkers(),
            ),
            // Driver location marker
            if (_driverLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _driverLocation!,
                    width: 70,
                    height: 70,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final markerColor = _isDarkMode 
                            ? const Color(0xFF00E5FF) // Bright cyan for dark mode
                            : const Color(0xFF4285F4); // Google blue for light mode
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: markerColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Center(
                        child: Transform.rotate(
                          angle: _heading * math.pi / 180,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isDarkMode 
                                  ? const Color(0xFF00E5FF) 
                                  : const Color(0xFF4285F4),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: _isDarkMode 
                                      ? const Color(0xFF00E5FF).withOpacity(0.5)
                                      : Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Top navigation instruction card
        if (_instructions.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildInstructionCard(),
          ),

        // Speed indicator (left side)
        if (_isTracking)
          Positioned(
            left: 16,
            bottom: 220,
            child: _buildSpeedIndicator(),
          ),

        // Navigation mode toggle & recenter (right side)
        Positioned(
          right: 16,
          bottom: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recenter button
              if (!_navigationMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: const Color(0xFF4285F4),
                    onPressed: _toggleNavigationMode,
                    child: const Icon(Icons.navigation, color: Colors.white),
                  ),
                ),
              // Overview toggle
              FloatingActionButton.small(
                heroTag: 'overview',
                backgroundColor: _isDarkMode ? const Color(0xFF1C2541) : Colors.white,
                onPressed: _toggleNavigationMode,
                child: Icon(
                  _navigationMode ? Icons.zoom_out_map : Icons.near_me,
                  color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
        ),

        // Bottom info panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomPanel(),
        ),
      ],
    );
  }

  List<LatLng> _getCompletedRoute() {
    if (_driverLocation == null || _routePoints.isEmpty) return [];

    const Distance distanceCalc = Distance();
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, _driverLocation!, _routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    return _routePoints.sublist(0, closestIndex + 1);
  }

  List<LatLng> _getRemainingRoute() {
    if (_driverLocation == null || _routePoints.isEmpty) return _routePoints;

    const Distance distanceCalc = Distance();
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final d = distanceCalc.as(LengthUnit.Meter, _driverLocation!, _routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    if (closestIndex >= _routePoints.length - 1) return [];
    
    // Include driver location at start for smooth connection
    return [_driverLocation!, ..._routePoints.sublist(closestIndex)];
  }

  List<Marker> _buildWaypointMarkers() {
    final markers = <Marker>[];

    // Start point
    if (_waypoints.isNotEmpty) {
      markers.add(Marker(
        point: _waypoints.first,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.trip_origin, color: Colors.white, size: 18),
        ),
      ));
    }

    // End point
    if (_waypoints.length > 1) {
      markers.add(Marker(
        point: _waypoints.last,
        width: 50,
        height: 50,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.flag, color: Colors.white, size: 22),
        ),
      ));
    }

    return markers;
  }

  Widget _buildInstructionCard() {
    if (_instructions.isEmpty) return const SizedBox.shrink();

    final currentInstruction = _currentInstructionIndex < _instructions.length - 1
        ? _instructions[_currentInstructionIndex + 1]
        : _instructions.last;
    
    final nextInstruction = _currentInstructionIndex < _instructions.length - 2
        ? _instructions[_currentInstructionIndex + 2]
        : null;

    final bool isArrived = currentInstruction.type == 'destination' && _distanceToNextTurn < 50;

    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isArrived
              ? const LinearGradient(
                  colors: [Color(0xFF34A853), Color(0xFF1E8E3E)],
                )
              : _isDarkMode
                  ? const LinearGradient(
                      colors: [Color(0xFF0D3B66), Color(0xFF006D77)], // Dark teal gradient
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2D5A87)],
                    ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _isDarkMode 
                  ? const Color(0xFF00E5FF).withOpacity(0.2)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main instruction
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  // Turn icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _isDarkMode 
                          ? const Color(0xFF00E5FF).withOpacity(0.3) 
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: _isDarkMode 
                          ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1)
                          : null,
                    ),
                    child: Icon(
                      isArrived ? Icons.check_circle : currentInstruction.icon,
                      color: _isDarkMode ? const Color(0xFF00E5FF) : Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Instruction text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Distance to turn
                        Text(
                          isArrived ? t('arrived') : _formatDistance(_distanceToNextTurn),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Turn instruction
                        Text(
                          _getInstructionText(currentInstruction.type),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Next instruction preview
            if (nextInstruction != null && !isArrived)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      t('then'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      nextInstruction.icon,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getInstructionText(nextInstruction.type),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator() {
    final speedKmh = (_speed * 3.6).round(); // Convert m/s to km/h

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$speedKmh',
            style: TextStyle(
              color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            t('kmh'),
            style: TextStyle(
              color: _isDarkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    final eta = _calculateETA();

    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Trip info row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoColumn(
                    icon: Icons.schedule,
                    value: '$eta',
                    label: t('min'),
                    color: _isDarkMode ? const Color(0xFF00E5FF) : const Color(0xFF4285F4),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: _isDarkMode ? Colors.white24 : Colors.grey[300],
                  ),
                  _buildInfoColumn(
                    icon: Icons.straighten,
                    value: _formatDistanceShort(_remainingDistance),
                    label: _remainingDistance >= 1000 ? t('km') : t('meters'),
                    color: Colors.orange,
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: _isDarkMode ? Colors.white24 : Colors.grey[300],
                  ),
                  _buildInfoColumn(
                    icon: Icons.flag,
                    value: _formatDistanceShort(_totalDistance),
                    label: _totalDistance >= 1000 ? t('km') : t('meters'),
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // End trip button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _endTrip,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.stop_circle, size: 24),
                  label: Text(
                    t('endTrip'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: _isDarkMode ? Colors.white54 : Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
