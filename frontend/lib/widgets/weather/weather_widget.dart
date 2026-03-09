import 'package:flutter/material.dart';
import '../../services/weather_service.dart';
import '../../theme/app_theme.dart';

class WeatherWidget extends StatefulWidget {
  final bool isArabic;
  final bool isSmallScreen;
  final bool isMediumScreen;
  final bool isDesktop;

  const WeatherWidget({
    super.key,
    this.isArabic = false,
    this.isSmallScreen = false,
    this.isMediumScreen = false,
    this.isDesktop = false,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget>
    with SingleTickerProviderStateMixin {
  WeatherData? _weatherData;
  bool _isLoading = true;
  bool _isExpanded = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'weather': 'الطقس',
      'feelsLike': 'الشعور بـ',
      'humidity': 'الرطوبة',
      'wind': 'الرياح',
      'visibility': 'الرؤية',
      'high': 'أعلى',
      'low': 'أدنى',
      'sunrise': 'الشروق',
      'sunset': 'الغروب',
      'noData': 'لا توجد بيانات طقس',
      'loading': 'جاري التحميل...',
      'apiKeyMissing': 'مفتاح API مفقود',
      'retry': 'إعادة المحاولة',
      'kmh': 'كم/س',
      'km': 'كم',
      'simulated': 'محاكاة',
    },
    'en': {
      'weather': 'Weather',
      'feelsLike': 'Feels like',
      'humidity': 'Humidity',
      'wind': 'Wind',
      'visibility': 'Visibility',
      'high': 'High',
      'low': 'Low',
      'sunrise': 'Sunrise',
      'sunset': 'Sunset',
      'noData': 'No weather data',
      'loading': 'Loading...',
      'apiKeyMissing': 'API key missing',
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
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await WeatherService.getCurrentWeather();
      if (mounted) {
        setState(() {
          _weatherData = data;
          _isLoading = false;
          if (data == null) {
            _error = t('noData');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
    final cardColor =
        isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);
    final textPrimary =
        isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondary =
        isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);

    // Match map card styling on desktop (border radius 12, lighter border)
    final borderRadius = widget.isDesktop ? 12.0 : (widget.isSmallScreen ? 12.0 : 16.0);
    final padding = widget.isDesktop ? 12.0 : (widget.isSmallScreen ? 12.0 : 16.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Collapsed / Header section
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: _buildCollapsedContent(
                textPrimary,
                textSecondary,
                isDarkMode,
              ),
            ),
          ),
          // Expanded content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildExpandedContent(
              textPrimary,
              textSecondary,
              isDarkMode,
              cardColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent(
    Color textPrimary,
    Color textSecondary,
    bool isDarkMode,
  ) {
    if (_isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            t('loading'),
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ],
      );
    }

    if (_error != null || _weatherData == null) {
      return Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: textSecondary,
            size: widget.isSmallScreen ? 24 : 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? t('noData'),
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
          ),
          IconButton(
            onPressed: _loadWeather,
            icon: Icon(Icons.refresh, color: textSecondary, size: 20),
            tooltip: t('retry'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      );
    }

    final weather = _weatherData!;
    final iconSize = widget.isSmallScreen ? 32.0 : (widget.isDesktop ? 36.0 : 40.0);

    return Row(
      children: [
        // Weather icon
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: _getWeatherColor(weather.icon).withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              WeatherService.getWeatherIcon(weather.icon),
              style: TextStyle(fontSize: iconSize * 0.6),
            ),
          ),
        ),
        SizedBox(width: widget.isSmallScreen ? 10 : 14),
        // Temperature and city
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${weather.temperature.round()}°C',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: widget.isSmallScreen ? 18 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      weather.cityName,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: widget.isSmallScreen ? 12 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    _capitalizeFirst(weather.description),
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: widget.isSmallScreen ? 11 : 13,
                    ),
                  ),
                  if (weather.isMockData) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orange.withAlpha(80)),
                      ),
                      child: Text(
                        t('simulated'),
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: widget.isSmallScreen ? 9 : 10,
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
          child: Icon(
            Icons.keyboard_arrow_down,
            color: textSecondary,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(
    Color textPrimary,
    Color textSecondary,
    bool isDarkMode,
    Color cardColor,
  ) {
    if (_weatherData == null) return const SizedBox.shrink();

    final weather = _weatherData!;
    final padding = widget.isSmallScreen ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, padding),
      child: Column(
        children: [
          Divider(
            color: isDarkMode ? Colors.white12 : Colors.grey.shade300,
            height: 1,
          ),
          SizedBox(height: widget.isSmallScreen ? 12 : 16),
          // Temperature range
          _buildInfoRow(
            Icons.thermostat_outlined,
            '${t('high')}: ${weather.tempMax.round()}° / ${t('low')}: ${weather.tempMin.round()}°',
            textPrimary,
            textSecondary,
            Colors.orange,
          ),
          SizedBox(height: widget.isSmallScreen ? 8 : 12),
          // Feels like
          _buildInfoRow(
            Icons.device_thermostat,
            '${t('feelsLike')} ${weather.feelsLike.round()}°C',
            textPrimary,
            textSecondary,
            Colors.red,
          ),
          SizedBox(height: widget.isSmallScreen ? 8 : 12),
          // Two columns for details
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.water_drop_outlined,
                  '${t('humidity')}: ${weather.humidity}%',
                  textPrimary,
                  textSecondary,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoRow(
                  Icons.air,
                  '${t('wind')}: ${(weather.windSpeed * 3.6).round()} ${t('kmh')}',
                  textPrimary,
                  textSecondary,
                  Colors.teal,
                ),
              ),
            ],
          ),
          SizedBox(height: widget.isSmallScreen ? 8 : 12),
          // Visibility
          _buildInfoRow(
            Icons.visibility_outlined,
            '${t('visibility')}: ${(weather.visibility / 1000).toStringAsFixed(1)} ${t('km')}',
            textPrimary,
            textSecondary,
            Colors.purple,
          ),
          SizedBox(height: widget.isSmallScreen ? 8 : 12),
          // Sunrise and sunset
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  Icons.wb_sunny_outlined,
                  '${t('sunrise')}: ${_formatTime(weather.sunrise)}',
                  textPrimary,
                  textSecondary,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInfoRow(
                  Icons.nights_stay_outlined,
                  '${t('sunset')}: ${_formatTime(weather.sunset)}',
                  textPrimary,
                  textSecondary,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color textPrimary,
    Color textSecondary,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: widget.isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontSize: widget.isSmallScreen ? 12 : 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getWeatherColor(String iconCode) {
    switch (iconCode.substring(0, 2)) {
      case '01':
        return Colors.amber; // clear
      case '02':
      case '03':
      case '04':
        return Colors.blueGrey; // clouds
      case '09':
      case '10':
        return Colors.blue; // rain
      case '11':
        return Colors.deepPurple; // thunderstorm
      case '13':
        return Colors.lightBlue; // snow
      case '50':
        return Colors.grey; // mist
      default:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

