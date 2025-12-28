import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Web-specific responsive breakpoints
    final isWeb = kIsWeb;
    final isDesktop = isWeb && screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    final double basePadding = isWeb 
        ? (isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1200.0 : double.infinity;
    
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
                margin: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: isSmallScreen ? 18.0 : 20.0),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              title: Text(
                t('title'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
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
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(basePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _buildTrackingStatusCard(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
              SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),

              if (_currentPosition != null) ...[
                _buildLocationCard(_currentPosition!, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
              ],

              if (_baseStation != null) ...[
                _buildBaseStationCard(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
              ],

              if (_linePath != null) _buildLinePathCard(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, Color? color, bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: color ?? cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
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

  Widget _buildTrackingStatusCard({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);
    
    return _buildCard(
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                    decoration: BoxDecoration(
                      color: _isTracking 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    ),
                    child: Icon(
                      Icons.location_searching,
                      color: _isTracking ? Colors.green : Colors.grey,
                      size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('trackingStatus'),
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                      Text(
                        _isTracking ? t('active') : t('inactive'),
                        style: TextStyle(
                          color: _isTracking ? Colors.green : textSecondaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: isSmallScreen ? 13.0 : 14.0,
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
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
            decoration: BoxDecoration(
              color: _isTracking 
                  ? Colors.green.withOpacity(0.1) 
                  : _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
                  size: isSmallScreen ? 18.0 : 20.0,
                  color: _isTracking ? Colors.green : textSecondaryColor,
                ),
                SizedBox(width: isSmallScreen ? 8.0 : 10.0),
                Expanded(
                  child: Text(
                    _isTracking ? t('trackingActiveDesc') : t('trackingInactiveDesc'),
                    style: TextStyle(
                      color: _isTracking ? Colors.green.shade700 : textSecondaryColor,
                      fontSize: isSmallScreen ? 12.0 : 13.0,
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

  Widget _buildLocationCard(Position position, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    
    return _buildCard(
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Colors.blue, size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0)),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('currentLocation'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          Row(
            children: [
              Expanded(
                child: _buildDataBox(
                  t('latitude'),
                  position.latitude.toStringAsFixed(5),
                  Icons.explore,
                  Colors.blue,
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Expanded(
                child: _buildDataBox(
                  t('longitude'),
                  position.longitude.toStringAsFixed(5),
                  Icons.explore,
                  Colors.blue,
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          _buildDataBox(
            t('accuracy'),
            '${position.accuracy.toStringAsFixed(1)} ${t('meters')}',
            Icons.gps_fixed,
            Colors.orange,
            fullWidth: true,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildBaseStationCard({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final statusColor = _isAtBaseStation ? Colors.green : Colors.orange;

    return _buildCard(
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.business, color: Colors.purple, size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0)),
                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                  Text(
                    t('baseStation'),
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8.0 : 10.0, 
                  vertical: isSmallScreen ? 4.0 : 6.0
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAtBaseStation ? Icons.check_circle : Icons.near_me,
                      size: isSmallScreen ? 12.0 : 14.0,
                      color: statusColor,
                    ),
                    SizedBox(width: isSmallScreen ? 4.0 : 6.0),
                    Text(
                      _isAtBaseStation ? t('atBase') : t('awayFromBase'),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 10.0 : 12.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          if (_distanceToBaseStation != null) ...[
            _buildDataBox(
              t('distance'),
              '${(_distanceToBaseStation! / 1000).toStringAsFixed(2)} ${t('km')}',
              Icons.straighten,
              Colors.purple,
              fullWidth: true,
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen,
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          ],
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 44.0 : (isMediumScreen ? 46.0 : 48.0),
            child: FilledButton.icon(
              onPressed: _navigateToBaseStation,
              icon: Icon(Icons.navigation, size: isSmallScreen ? 18.0 : 20.0),
              label: Text(
                t('navToBase'),
                style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinePathCard({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);

    return _buildCard(
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: Colors.indigo, size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0)),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('linePath'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          if (_linePath!['distance_meters'] != null) ...[
            _buildDataBox(
              t('routeDistance'),
              '${(_linePath!['distance_meters'] / 1000).toStringAsFixed(2)} ${t('km')}',
              Icons.map,
              Colors.indigo,
              fullWidth: true,
              isSmallScreen: isSmallScreen,
              isMediumScreen: isMediumScreen,
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          ],
          SizedBox(
            width: double.infinity,
            height: isSmallScreen ? 44.0 : (isMediumScreen ? 46.0 : 48.0),
            child: FilledButton.icon(
              onPressed: _navigateAlongLinePath,
              icon: Icon(Icons.turn_right, size: isSmallScreen ? 18.0 : 20.0),
              label: Text(
                t('navLine'),
                style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                ),
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          Row(
            children: [
              Icon(Icons.offline_pin, size: isSmallScreen ? 14.0 : 16.0, color: textSecondaryColor),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Expanded(
                child: Text(
                  t('offlineNote'),
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: isSmallScreen ? 11.0 : 12.0,
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
    {bool fullWidth = false, bool isSmallScreen = false, bool isMediumScreen = false}
  ) {
    final boxColor = _isDarkMode
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade50;
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode ? Colors.white.withOpacity(0.9) : const Color(0xFF546E7A);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
              Icon(icon, size: isSmallScreen ? 14.0 : 16.0, color: color),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Text(
                label,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: isSmallScreen ? 11.0 : 12.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          Text(
            value,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
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
