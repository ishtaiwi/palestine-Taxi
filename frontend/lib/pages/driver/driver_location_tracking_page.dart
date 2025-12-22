import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../services/location_service.dart';
import '../../services/navigation_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

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
  bool _isArabic = true;
  bool _isDarkMode = false;
  Position? _currentPosition;
  Map<String, dynamic>? _baseStation;
  Map<String, dynamic>? _linePath;
  String? _lineid;
  double? _distanceToBaseStation;
  StreamSubscription<Position>? _positionSubscription;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'تتبع الموقع',
      'trackingStatus': 'حالة التتبع',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'trackingActiveDesc': 'يتم تحديث الموقع كل 10 ثوانٍ',
      'trackingInactiveDesc': 'تتبع الموقع متوقف حالياً',
      'currentLocation': 'الموقع الحالي',
      'latitude': 'خط العرض',
      'longitude': 'خط الطول',
      'accuracy': 'الدقة',
      'meters': 'متر',
      'baseStation': 'المحطة الرئيسية',
      'atBase': 'في المحطة',
      'awayFromBase': 'بعيد عن المحطة',
      'distance': 'المسافة',
      'km': 'كم',
      'navToBase': 'توجيه للمحطة',
      'linePath': 'مسار الخط',
      'routeDistance': 'مسافة المسار',
      'navLine': 'توجيه عبر المسار',
      'offlineNote': 'ملاحظة: المسار محفوظ للتوجيه بدون إنترنت',
      'notFound': 'غير موجود',
      'permissionError': 'يلزم إذن الموقع للتتبع',
      'navError': 'تعذر فتح تطبيق الخرائط',
      'noLineError': 'لم يتم تعيين خط',
      'baseStationError': 'لم يتم العثور على محطة',
    },
    'en': {
      'title': 'Location Tracking',
      'trackingStatus': 'Tracking Status',
      'active': 'Active',
      'inactive': 'Inactive',
      'trackingActiveDesc': 'Location updates every 10 seconds',
      'trackingInactiveDesc': 'Tracking is currently off',
      'currentLocation': 'Current Location',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'accuracy': 'Accuracy',
      'meters': 'm',
      'baseStation': 'Base Station',
      'atBase': 'At Base',
      'awayFromBase': 'Away',
      'distance': 'Distance',
      'km': 'km',
      'navToBase': 'Navigate to Base',
      'linePath': 'Line Path',
      'routeDistance': 'Route Distance',
      'navLine': 'Navigate Route',
      'offlineNote': 'Note: Path is cached for offline navigation',
      'notFound': 'Not Found',
      'permissionError': 'Location permission required',
      'navError': 'Could not open maps app',
      'noLineError': 'No line assigned',
      'baseStationError': 'Base station not found',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final isArabic = await ApiService.getLanguagePreference();
    await AppTheme.init();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
        _isDarkMode = AppTheme.isDarkMode;
      });
    }

    final wasTracking = await _locationService.loadTrackingState();
    if (wasTracking) {
      await _startTracking();
    }

    final userData = await ApiService.getUserData();
    if (userData != null && userData['driver'] != null) {
      final driver = userData['driver'] as Map<String, dynamic>;
      _lineid = driver['lineid']?.toString();

      if (_lineid != null) {
        final pathResult = await ApiService.getLinePath(_lineid!);
        if (pathResult['success'] == true) {
          setState(() {
            _linePath = pathResult['path'];
          });
        }
      }
    }

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
          SnackBar(
            content: Text(t('permissionError')),
            backgroundColor: Colors.red,
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
        SnackBar(content: Text(t('baseStationError'))),
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
        SnackBar(content: Text(t('navError'))),
      );
    }
  }

  Future<void> _navigateAlongLinePath() async {
    if (_lineid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('noLineError'))),
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
        SnackBar(content: Text(t('navError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                        const Color(0xFF1C2541),
                        const Color(0xFF2C3E50),
                        const Color(0xFF1C2541),
                      ]
                    : [
                        const Color(0xFF2C5F8D),
                        const Color(0xFF1E3A5F),
                        const Color(0xFF2C5F8D),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Text(
                t('title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTrackingStatusCard(),
              const SizedBox(height: 20),

              if (_currentPosition != null) ...[
                _buildLocationCard(_currentPosition!),
                const SizedBox(height: 20),
              ],

              if (_baseStation != null) ...[
                _buildBaseStationCard(),
                const SizedBox(height: 20),
              ],

              if (_linePath != null) _buildLinePathCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? color}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTrackingStatusCard() {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);
    
    return _buildCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isTracking 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_searching,
                      color: _isTracking ? Colors.green : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('trackingStatus'),
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isTracking ? t('active') : t('inactive'),
                        style: TextStyle(
                          color: _isTracking ? Colors.green : textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _isTracking,
                activeColor: Colors.green,
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isTracking 
                  ? Colors.green.withOpacity(0.1) 
                  : _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isTracking 
                    ? Colors.green.withOpacity(0.3) 
                    : _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: _isTracking ? Colors.green : textSecondaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isTracking ? t('trackingActiveDesc') : t('trackingInactiveDesc'),
                    style: TextStyle(
                      color: _isTracking ? Colors.green.shade700 : textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Position position) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              Text(
                t('currentLocation'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildDataBox(
                  t('latitude'),
                  position.latitude.toStringAsFixed(5),
                  Icons.explore,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDataBox(
                  t('longitude'),
                  position.longitude.toStringAsFixed(5),
                  Icons.explore,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDataBox(
            t('accuracy'),
            '${position.accuracy.toStringAsFixed(1)} ${t('meters')}',
            Icons.gps_fixed,
            Colors.orange,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBaseStationCard() {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final statusColor = _isAtBaseStation ? Colors.green : Colors.orange;

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: Colors.purple, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    t('baseStation'),
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAtBaseStation ? Icons.check_circle : Icons.near_me,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAtBaseStation ? t('atBase') : t('awayFromBase'),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_distanceToBaseStation != null) ...[
            _buildDataBox(
              t('distance'),
              '${(_distanceToBaseStation! / 1000).toStringAsFixed(2)} ${t('km')}',
              Icons.straighten,
              Colors.purple,
              fullWidth: true,
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _navigateToBaseStation,
              icon: const Icon(Icons.navigation),
              label: Text(t('navToBase')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinePathCard() {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: Colors.indigo, size: 24),
              const SizedBox(width: 12),
              Text(
                t('linePath'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_linePath!['distance_meters'] != null) ...[
            _buildDataBox(
              t('routeDistance'),
              '${(_linePath!['distance_meters'] / 1000).toStringAsFixed(2)} ${t('km')}',
              Icons.map,
              Colors.indigo,
              fullWidth: true,
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _navigateAlongLinePath,
              icon: const Icon(Icons.turn_right),
              label: Text(t('navLine')),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.offline_pin, size: 16, color: textSecondaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('offlineNote'),
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataBox(
    String label, 
    String value, 
    IconData icon, 
    Color color,
    {bool fullWidth = false}
  ) {
    final boxColor = _isDarkMode
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade50;
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
