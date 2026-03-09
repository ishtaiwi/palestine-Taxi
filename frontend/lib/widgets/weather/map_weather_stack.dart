import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';

/// A combined widget that stacks the map and weather widget,
/// where weather expands upwards and shrinks the map dynamically.
class MapWeatherStack extends StatefulWidget {
  final bool isArabic;
  final bool mapLoading;
  final List<Map<String, dynamic>> baseStations;
  final List<Map<String, dynamic>> vehicleLocations;
  final MapController mapController;
  final VoidCallback? onMapTap;

  const MapWeatherStack({
    super.key,
    required this.isArabic,
    required this.mapLoading,
    required this.baseStations,
    required this.vehicleLocations,
    required this.mapController,
    this.onMapTap,
  });

  @override
  State<MapWeatherStack> createState() => _MapWeatherStackState();
}

class _MapWeatherStackState extends State<MapWeatherStack>
    with SingleTickerProviderStateMixin {
  WeatherData? _weatherData;
  bool _isWeatherLoading = true;
  bool _isExpanded = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  // Collapsed weather height (header only, includes border)
  static const double _collapsedHeight = 64.0;
  // Expanded weather content height
  static const double _expandedContentHeight = 176.0;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'vehicleTracking': 'خريطة المركبات',
      'active': 'مركبة',
      'weather': 'الطقس',
      'feelsLike': 'الشعور بـ',
      'humidity': 'الرطوبة',
      'wind': 'الرياح',
      'visibility': 'الرؤية',
      'high': 'أعلى',
      'low': 'أدنى',
      'sunrise': 'الشروق',
      'sunset': 'الغروب',
      'noData': 'لا توجد بيانات',
      'loading': 'جاري التحميل...',
      'retry': 'إعادة المحاولة',
      'kmh': 'كم/س',
      'km': 'كم',
      'simulated': 'محاكاة',
    },
    'en': {
      'vehicleTracking': 'Vehicle Tracking',
      'active': 'active',
      'weather': 'Weather',
      'feelsLike': 'Feels like',
      'humidity': 'Humidity',
      'wind': 'Wind',
      'visibility': 'Visibility',
      'high': 'High',
      'low': 'Low',
      'sunrise': 'Sunrise',
      'sunset': 'Sunset',
      'noData': 'No data',
      'loading': 'Loading...',
      'retry': 'Retry',
      'kmh': 'km/h',
      'km': 'km',
      'simulated': 'Simulated',
    },
  };

  String t(String key) => _texts[widget.isArabic ? 'ar' : 'en']![key] ?? key;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadWeather();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _isWeatherLoading = true;
      _error = null;
    });

    try {
      final data = await WeatherService.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isWeatherLoading = false;
          if (data == null) {
            _error = t('noData');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWeatherLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = AppTheme.isDarkMode;
    final cardColor = isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);
    final textPrimary = isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondary = isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    final borderColor = isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the weather widget height based on expansion state
        final weatherHeight = _collapsedHeight +
            (_expandAnimation.value * _expandedContentHeight);

        // Map takes remaining space
        final mapHeight = constraints.maxHeight - weatherHeight - 8; // 8 for spacing

        return Column(
          children: [
            // Map Card (shrinks when weather expands)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: mapHeight.clamp(150.0, constraints.maxHeight - _collapsedHeight - 8),
              child: _buildMapCard(cardColor, textPrimary, textSecondary, borderColor),
            ),
            const SizedBox(height: 8),
            // Weather Widget (expands upward)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: weatherHeight,
              child: _buildWeatherCard(cardColor, textPrimary, textSecondary, borderColor, isDarkMode),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapCard(
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    LatLng center = widget.baseStations.isNotEmpty
        ? LatLng(
            widget.baseStations[0]['latitude']?.toDouble() ?? 31.9522,
            widget.baseStations[0]['longitude']?.toDouble() ?? 35.2332)
        : widget.vehicleLocations.isNotEmpty
            ? LatLng(
                widget.vehicleLocations[0]['latitude']?.toDouble() ?? 31.9522,
                widget.vehicleLocations[0]['longitude']?.toDouble() ?? 35.2332)
            : const LatLng(31.9522, 35.2332);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.map_rounded, color: Colors.cyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    t('vehicleTracking'),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.vehicleLocations.length} ${t('active')}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: widget.onMapTap,
                    icon: Icon(Icons.open_in_new, color: textSecondary, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.mapLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : FlutterMap(
                      mapController: widget.mapController,
                      options: MapOptions(initialCenter: center, initialZoom: 12.0),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                        MarkerLayer(
                          markers: [
                            ...widget.baseStations.map((station) {
                              return Marker(
                                point: LatLng(
                                  station['latitude']?.toDouble() ?? 0,
                                  station['longitude']?.toDouble() ?? 0,
                                ),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.location_city,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              );
                            }),
                            ...widget.vehicleLocations.map((loc) {
                              final isAtStation = loc['is_at_station'] == true;
                              return Marker(
                                point: LatLng(
                                  loc['latitude']?.toDouble() ?? 0,
                                  loc['longitude']?.toDouble() ?? 0,
                                ),
                                width: 32,
                                height: 32,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isAtStation ? Colors.green : Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isDarkMode,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header (always visible, takes minimum space needed)
          InkWell(
            onTap: _toggleExpanded,
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildWeatherHeader(textPrimary, textSecondary),
            ),
          ),
          // Expanded content (takes remaining space)
          if (_isExpanded || _animationController.value > 0)
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _buildWeatherExpandedContent(
                    textPrimary,
                    textSecondary,
                    isDarkMode,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWeatherHeader(Color textPrimary, Color textSecondary) {
    if (_isWeatherLoading) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Text(t('loading'), style: TextStyle(color: textSecondary, fontSize: 13)),
        ],
      );
    }

    if (_error != null || _weatherData == null) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_off, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? t('noData'),
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: _loadWeather,
            icon: Icon(Icons.refresh, color: textSecondary, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }

    final weather = _weatherData!;
    return Row(
      children: [
        // Weather icon
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getWeatherColor(weather.icon).withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              WeatherService.getWeatherIcon(weather.icon),
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Temperature and city
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${weather.temperature.round()}°C',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      weather.cityName,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _capitalizeFirst(weather.description),
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                  if (weather.isMockData) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t('simulated'),
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Expand/collapse icon
        AnimatedRotation(
          turns: _isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 300),
          child: Icon(Icons.keyboard_arrow_up, color: textSecondary, size: 24),
        ),
      ],
    );
  }

  Widget _buildWeatherExpandedContent(
    Color textPrimary,
    Color textSecondary,
    bool isDarkMode,
  ) {
    if (_weatherData == null) return const SizedBox.shrink();

    final weather = _weatherData!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(color: isDarkMode ? Colors.white12 : Colors.grey.shade300, height: 1),
          const SizedBox(height: 12),
          // Row 1: High/Low and Feels like
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.thermostat_outlined,
                  '${t('high')}: ${weather.tempMax.round()}° / ${t('low')}: ${weather.tempMin.round()}°',
                  textPrimary,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoRow(
                  Icons.device_thermostat,
                  '${t('feelsLike')} ${weather.feelsLike.round()}°C',
                  textPrimary,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Humidity and Wind
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.water_drop_outlined,
                  '${t('humidity')}: ${weather.humidity}%',
                  textPrimary,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoRow(
                  Icons.air,
                  '${t('wind')}: ${(weather.windSpeed * 3.6).round()} ${t('kmh')}',
                  textPrimary,
                  Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 3: Sunrise and Sunset
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.wb_sunny_outlined,
                  '${t('sunrise')}: ${_formatTime(weather.sunrise)}',
                  textPrimary,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoRow(
                  Icons.nights_stay_outlined,
                  '${t('sunset')}: ${_formatTime(weather.sunset)}',
                  textPrimary,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color textPrimary, Color iconColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: textPrimary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getWeatherColor(String iconCode) {
    switch (iconCode.substring(0, 2)) {
      case '01':
        return Colors.amber;
      case '02':
      case '03':
      case '04':
        return Colors.blueGrey;
      case '09':
      case '10':
        return Colors.blue;
      case '11':
        return Colors.deepPurple;
      case '13':
        return Colors.lightBlue;
      case '50':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

