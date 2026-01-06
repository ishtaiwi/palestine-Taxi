import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_side_menu/flutter_side_menu.dart';
import '../../services/api_service.dart';
import '../../services/supabase_realtime_service.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/reports/revenue_chart.dart';
import '../../widgets/reports/trip_chart.dart';
import 'admin_schedules_page.dart';
import 'admin_lines_page.dart';
import 'admin_users_page.dart';
import 'admin_vehicles_page.dart';
import 'admin_trips_page.dart';
import 'admin_payments_page.dart';
import 'admin_predictions_page.dart';
import 'admin_map_page.dart';
import 'admin_base_station_page.dart';
import 'admin_reports_page.dart';
import 'admin_settings_page.dart';
import 'admin_driver_approvals_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false;
  Map<String, dynamic>? _predictionInsights;
  bool _insightsLoading = true;

  List<Map<String, dynamic>> _vehicleLocations = [];
  List<Map<String, dynamic>> _baseStations = [];
  bool _mapLoading = false;
  final MapController _mapController = MapController();

  Map<String, dynamic>? _dashboardStats;
  Map<String, dynamic>? _revenueStats;
  Map<String, dynamic>? _revenueChartData;
  Map<String, dynamic>? _tripChartData;
  bool _statsLoading = false;
  final SideMenuController _sideMenuController = SideMenuController();
  Timer? _refreshTimer;

  // System health state
  Map<String, dynamic>? _systemHealth;
  DateTime? _lastHealthCheck;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'لوحة التحكم',
      'welcome': 'مرحباً',
      'manageSystem': 'إدارة النظام الكاملة',
      'systemManagement': 'إدارة النظام',
      'users': 'المستخدمين',
      'lines': 'الخطوط',
      'vehicles': 'المركبات',
      'trips': 'الرحلات',
      'schedules': 'الجداول',
      'payments': 'المدفوعات',
      'reports': 'التقارير',
      'generalStats': 'الإحصائيات العامة',
      'reservations': 'الحجوزات',
      'revenue': 'الإيرادات',
      'accountInfo': 'معلومات الحساب',
      'email': 'البريد الإلكتروني',
      'role': 'الدور',
      'admin': 'المدير',
      'logout': 'تسجيل الخروج',
      'aiPredictions': 'توقعات الذكاء الاصطناعي',
      'vehicleMap': 'خريطة المركبات',
      'baseStations': 'محطات القاعدة',
      'settings': 'الإعدادات',
      'analytics': 'التحليلات',
      'map': 'الخريطة',
    },
    'en': {
      'title': 'Admin Dashboard',
      'welcome': 'Welcome',
      'manageSystem': 'Full system management',
      'systemManagement': 'System Management',
      'users': 'Users',
      'lines': 'Lines',
      'vehicles': 'Vehicles',
      'trips': 'Trips',
      'schedules': 'Schedules',
      'payments': 'Payments',
      'reports': 'Reports',
      'generalStats': 'General Statistics',
      'reservations': 'Reservations',
      'revenue': 'Revenue',
      'accountInfo': 'Account Information',
      'email': 'Email',
      'role': 'Role',
      'admin': 'Admin',
      'logout': 'Logout',
      'aiPredictions': 'AI Predictions',
      'vehicleMap': 'Vehicle Map',
      'baseStations': 'Base Stations',
      'settings': 'Settings',
      'analytics': 'Analytics',
      'map': 'Map',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key] ?? key;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadUserData();
    _loadPredictionInsights();
    _loadMapData();
    _subscribeToRealtimeUpdates();
    _loadDashboardStats();
    _loadSystemHealth();

    // Periodically refresh dashboard data so cards and charts stay up-to-date.
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      // Silent refresh: update data without toggling loading spinners on cards.
      _loadDashboardStats(silent: true);
      _loadPredictionInsights(silent: true);
      _loadMapData(silent: true);
      _loadSystemHealth();
    });
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SupabaseRealtimeService.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await ApiService.getUserData();
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _userData = userData;
      _isLoading = false;
      _isArabic = isArabic;
    });
  }

  Future<void> _loadMapData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _mapLoading = true;
      });
    }

    try {
      final locationsResult = await ApiService.getAllVehicleLocations();
      if (locationsResult['success'] == true) {
        final locationsList = locationsResult['locations'];
        if (locationsList is List) {
          setState(() {
            _vehicleLocations = locationsList
                .whereType<Map<String, dynamic>>()
                .map((loc) => Map<String, dynamic>.from(loc))
                .toList();
          });
        }
      }

      final stationsResult =
          await ApiService.getAllBaseStations(isActive: true);
      if (stationsResult['success'] == true) {
        final stationsList = stationsResult['stations'];
        if (stationsList is List) {
          setState(() {
            _baseStations = stationsList
                .whereType<Map<String, dynamic>>()
                .map((station) => Map<String, dynamic>.from(station))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading map data: $e');
    } finally {
      if (!silent) {
        setState(() {
          _mapLoading = false;
        });
      }
    }
  }

  void _subscribeToRealtimeUpdates() {
    SupabaseRealtimeService.subscribeToVehicleLocations((update) {
      if (mounted) {
        setState(() {
          final vehicleid = update['vehicleid'];
          final index = _vehicleLocations.indexWhere(
            (loc) => loc['vehicleid'] == vehicleid,
          );
          if (index >= 0) {
            _vehicleLocations[index] = update;
          } else {
            _vehicleLocations.add(update);
          }
        });
      }
    });
  }

  Future<void> _loadDashboardStats({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _statsLoading = true;
      });
    }

    try {
      // Basic aggregated stats for the quick cards and summaries
      final stats = await ApiService.getDashboardStats();
      // Aggregated revenue analytics (includes totalRevenue, totalTransactions, etc.)
      final revenue = await ApiService.getRevenueAnalytics();

      // Time series data for charts (last 30 days)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final revenueSeries = await ApiService.getRevenueTimeSeries(
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
        groupBy: 'day',
      );

      final tripSeries = await ApiService.getTripStatistics(
        startDate: startDate.toIso8601String(),
        endDate: endDate.toIso8601String(),
      );

      setState(() {
        _dashboardStats = stats;
        _revenueStats = revenue;
        _revenueChartData = revenueSeries;
        _tripChartData = tripSeries;
        if (!silent) {
          _statsLoading = false;
        }
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (!silent) {
        setState(() {
          _statsLoading = false;
        });
      }
    }
  }

  Future<void> _loadSystemHealth() async {
    try {
      final health = await ApiService.getSystemHealth();
      if (mounted) {
        setState(() {
          _systemHealth = health;
          _lastHealthCheck = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _systemHealth = {
            'success': false,
            'apiHealthy': false,
            'dbHealthy': false,
            'message': e.toString(),
          };
          _lastHealthCheck = DateTime.now();
        });
      }
    }
  }

  Future<void> _loadPredictionInsights({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _insightsLoading = true;
      });
    }

    try {
      final insights = await ApiService.getPredictionInsightsAdmin(limit: 3);

      if (insights['success'] == true) {
        setState(() {
          _predictionInsights = insights['data'] ?? insights;
          if (!silent) {
            _insightsLoading = false;
          }
        });
      } else {
        setState(() {
          _predictionInsights = {
            'topLines': [],
            'model': null,
            'errorMessage': insights['message'] ?? 'Failed to load insights'
          };
          if (!silent) {
            _insightsLoading = false;
          }
        });
      }
    } catch (error) {
      setState(() {
        _predictionInsights = {
          'topLines': [],
          'model': null,
          'errorMessage': error.toString()
        };
        if (!silent) {
          _insightsLoading = false;
        }
      });
    }
  }

  Future<void> _switchLanguage(bool arabic) async {
    await ApiService.saveLanguagePreference(arabic);
    setState(() {
      _isArabic = arabic;
    });
  }

  Future<void> _handleLogout() async {
    await ApiService.clearAuthData();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541) // Dark card color for better integration
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        t('title'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            AppTheme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          onPressed: () async {
            await AppTheme.toggleTheme();
            setState(() {
              _isDarkMode = AppTheme.isDarkMode;
            });
          },
          tooltip: _isDarkMode ? 'Light Mode' : 'Dark Mode',
        ),
        IconButton(
          icon: Icon(
            _isArabic ? Icons.language : Icons.translate,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          onPressed: () => _switchLanguage(!_isArabic),
          tooltip: _isArabic ? 'English' : 'العربية',
        ),
        IconButton(
          icon: Icon(
            Icons.logout_rounded,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          onPressed: _handleLogout,
          tooltip: t('logout'),
        ),
        SizedBox(width: isSmallScreen ? 4.0 : 8.0),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isSmallScreen ? 16.0 : 20.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding =
        isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);
    final cardColor =
        _isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);
    final textPrimaryColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktopLayout =
                        ResponsiveBreakpoints.isDesktopWidth(
                                constraints.maxWidth) &&
                            kIsWeb;

                    if (isDesktopLayout) {
                      // Wide, web/desktop layout: PC-specific design with sidebar and rich content.
                      return _buildDesktopDashboardLayout(
                        basePadding: basePadding,
                        cardColor: cardColor,
                        textPrimaryColor: textPrimaryColor,
                        textSecondaryColor: textSecondaryColor,
                      );
                    }

                    // Default mobile / tablet layout (current behavior)
                    return _buildMobileDashboardLayout(
                      basePadding: basePadding,
                      cardColor: cardColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    );
                  },
                ),
              ),
      ),
    );
  }

  /// Original single-column layout used for phones and tablets.
  Widget _buildMobileDashboardLayout({
    required double basePadding,
    required Color cardColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    const adminPrimaryColor = Color(0xFF7B1FA2);

    return SingleChildScrollView(
      padding: EdgeInsets.all(basePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(
                isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF8E24AA), // Purple 600
                  Color(0xFF4A148C), // Purple 900
                  Color(0xFF8E24AA),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(
                  isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B1FA2).withAlpha(102),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width:
                          isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
                      height:
                          isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: isSmallScreen ? 2.0 : 3.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(77),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(50),
                            Colors.white.withAlpha(20),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: isSmallScreen
                            ? 30.0
                            : (isMediumScreen ? 35.0 : 40.0),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t('welcome'),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isSmallScreen
                                  ? 14.0
                                  : (isMediumScreen ? 15.0 : 16.0),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                          Text(
                            _userData?['fullname'] ?? t('admin'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSmallScreen
                                  ? 18.0
                                  : (isMediumScreen ? 21.0 : 24.0),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                          Text(
                            t('manageSystem'),
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: isSmallScreen
                                  ? 12.0
                                  : (isMediumScreen ? 13.0 : 14.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                    height:
                        isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
                Row(
                  children: [
                    Expanded(
                      child: _buildWelcomeStatCard(
                        icon: Icons.people_rounded,
                        label: t('users'),
                        value: _statsLoading
                            ? '-'
                            : (_dashboardStats?['totalUsers']?.toString() ??
                                '0'),
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildWelcomeStatCard(
                        icon: Icons.directions_bus_rounded,
                        label: t('trips'),
                        value: _statsLoading
                            ? '-'
                            : (_dashboardStats?['totalTrips']?.toString() ??
                                '0'),
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildWelcomeStatCard(
                        icon: Icons.attach_money_rounded,
                        label: t('revenue'),
                        value: _statsLoading
                            ? '-'
                            : _formatRevenue(_revenueStats?['totalRevenue']),
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
              height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
          _buildSectionCard(
            title: t('systemManagement'),
            icon: Icons.dashboard_rounded,
            color: adminPrimaryColor,
            cardColor: cardColor,
            textPrimaryColor: textPrimaryColor,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.people_outline_rounded,
                        title: t('users'),
                        color: Colors.blue,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminUsersPage())),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.route_rounded,
                        title: t('lines'),
                        color: Colors.green,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminLinesPage())),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.directions_car_filled_rounded,
                        title: t('vehicles'),
                        color: Colors.orange,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminVehiclesPage())),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.directions_bus_filled_rounded,
                        title: t('trips'),
                        color: Colors.purple,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminTripsPage())),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.schedule_rounded,
                        title: t('schedules'),
                        color: Colors.indigo,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminSchedulesPage())),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.payment_rounded,
                        title: t('payments'),
                        color: Colors.teal,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminPaymentsPage())),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.bar_chart_rounded,
                        title: t('reports'),
                        color: Colors.red,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminReportsPage())),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.verified_user_rounded,
                        title:
                            _isArabic ? 'موافقة السائقين' : 'Driver Approvals',
                        color: Colors.amber,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AdminDriverApprovalsPage())),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.trending_up_rounded,
                        title: t('aiPredictions'),
                        color: Colors.deepOrange,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminPredictionsPage())),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.location_city_rounded,
                        title: t('baseStations'),
                        color: Colors.brown,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminBaseStationPage())),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        icon: Icons.settings_rounded,
                        title: t('settings'),
                        color: Colors.grey,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminSettingsPage())),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
              height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
          _buildVehicleTrackingMap(
              cardColor, textPrimaryColor, textSecondaryColor,
              isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(
              height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
          _buildPredictionSummaryCard(
              cardColor, textPrimaryColor, textSecondaryColor,
              isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(
              height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
          _buildSectionCard(
            title: t('accountInfo'),
            icon: Icons.person_outline_rounded,
            color: adminPrimaryColor,
            cardColor: cardColor,
            textPrimaryColor: textPrimaryColor,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.email_outlined,
                  t('email'),
                  _userData?['email'] ?? '',
                  adminPrimaryColor,
                  textPrimaryColor,
                  textSecondaryColor,
                  cardColor,
                  _isDarkMode,
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                ),
                SizedBox(height: isSmallScreen ? 10.0 : 14.0),
                _buildInfoRow(
                  Icons.badge_outlined,
                  t('role'),
                  _userData?['role'] ?? 'ADMIN',
                  adminPrimaryColor,
                  textPrimaryColor,
                  textSecondaryColor,
                  cardColor,
                  _isDarkMode,
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop / web layout: PC-specific dashboard with sidebar navigation,
  /// rich map and reports area. Main content scrolls vertically to avoid
  /// overflow while sidebar stays compact.
  Widget _buildDesktopDashboardLayout({
    required double basePadding,
    required Color cardColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
  }) {
    return Row(
      children: [
        // Collapsible side menu for system management navigation
        SideMenu(
          controller: _sideMenuController,
          mode: SideMenuMode.auto,
          hasResizer: true,
          minWidth: 56,
          maxWidth: 260,
          backgroundColor:
              _isDarkMode ? const Color(0xFF101426) : const Color(0xFFE3E7EE),
          builder: (data) => SideMenuData(
            header: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 120;
                final Color labelColor =
                    _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);

                if (isCompact) {
                  // Compact mode: only show the icon, like other menu items.
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(
                      Icons.dashboard_rounded,
                      color: labelColor,
                    ),
                  );
                }

                // Expanded mode: icon + "System Management" text.
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.dashboard_rounded,
                        color: labelColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t('systemManagement'),
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            items: [
              SideMenuItemDataTile(
                isSelected: false,
                title: t('users'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.people_outline_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('lines'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.route_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLinesPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('vehicles'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.directions_car_filled_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminVehiclesPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('trips'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.directions_bus_filled_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminTripsPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('schedules'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.schedule_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSchedulesPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('payments'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.payment_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPaymentsPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('reports'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.bar_chart_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: _isArabic ? 'موافقة السائقين' : 'Driver Approvals',
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.verified_user_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminDriverApprovalsPage(),
                  ),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('aiPredictions'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.trending_up_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminPredictionsPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('baseStations'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.location_city_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminBaseStationPage()),
                ),
              ),
              SideMenuItemDataTile(
                isSelected: false,
                title: t('settings'),
                titleStyle: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87),
                icon: Icon(Icons.settings_rounded,
                    color: _isDarkMode ? Colors.white70 : Colors.black54),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
                ),
              ),
            ],
            footer: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 120;
                final String name = _userData?['fullname'] ?? t('admin');
                final String email = _userData?['email'] ?? '';
                final String initials = name.isNotEmpty
                    ? name
                        .trim()
                        .split(' ')
                        .map((p) => p.isNotEmpty ? p[0] : '')
                        .take(2)
                        .join()
                    : 'A';

                final Color avatarBg =
                    _isDarkMode ? Colors.white24 : const Color(0xFF1E3A5F);
                final Color avatarFg =
                    _isDarkMode ? Colors.white : Colors.white;

                final Widget avatar = CircleAvatar(
                  radius: 18,
                  backgroundColor: avatarBg,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );

                if (isCompact) {
                  // Compact: only show the avatar centered at the bottom.
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: avatar),
                  );
                }

                // Expanded: show a small user info card.
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? Colors.white.withAlpha(20)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        avatar,
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : const Color(0xFF1E3A5F),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : const Color(0xFF546E7A),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Main content area
        Expanded(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Stats grid (all 8 cards in one row)
                  _buildStatsGrid(
                      cardColor, textPrimaryColor, textSecondaryColor),
                  const SizedBox(height: 8),
                  // Main content: Map on left (2 rows), right side has cards
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Map spanning 2 rows
                      Expanded(
                        flex: 3,
                        child: _buildLargeMapCard(
                          cardColor,
                          textPrimaryColor,
                          textSecondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: Column with Status/Activity + Charts
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            // Row 1: System Status | Activity | AI Insights
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildSystemStatusCard(
                                    cardColor,
                                    textPrimaryColor,
                                    textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildRecentActivityCard(
                                    cardColor,
                                    textPrimaryColor,
                                    textSecondaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    children: [
                                      _buildCompactAiInsightsCard(
                                        cardColor,
                                        textPrimaryColor,
                                        textSecondaryColor,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildServerHealthCard(
                                        cardColor,
                                        textPrimaryColor,
                                        textSecondaryColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Row 2: Revenue + Trips charts
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildMiniChartCard(
                                    title: t('revenue'),
                                    icon: Icons.attach_money_rounded,
                                    color: Colors.green,
                                    cardColor: cardColor,
                                    textPrimaryColor: textPrimaryColor,
                                    child: _buildCompactRevenueChart(
                                        textPrimaryColor, textSecondaryColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMiniChartCard(
                                    title: t('trips'),
                                    icon: Icons.directions_bus_filled_rounded,
                                    color: Colors.purple,
                                    cardColor: cardColor,
                                    textPrimaryColor: textPrimaryColor,
                                    child: _buildCompactTripChart(
                                        textPrimaryColor, textSecondaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textPrimaryColor,
    required Widget child,
    Widget? headerAction,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Container(
      padding:
          EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 16.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(
          color:
              _isDarkMode ? Colors.white.withAlpha(38) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                    decoration: BoxDecoration(
                      color: color.withAlpha(51),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size:
                          isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 14.0),
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize:
                          isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          SizedBox(
              height: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 12.0)),
          child,
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final bgColor = _isDarkMode ? const Color(0xFF1C2541) : Colors.white;
    final borderColor =
        _isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0),
            horizontal: isSmallScreen ? 8.0 : 12.0),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(
                  isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0)),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withAlpha(50),
                  width: 1,
                ),
              ),
              child: Icon(icon,
                  color: color,
                  size: isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0)),
            ),
            SizedBox(height: isSmallScreen ? 8.0 : 12.0),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : AppTheme.textPrimary,
                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStatCard({
    required IconData icon,
    required String label,
    required String value,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0),
          horizontal: isSmallScreen ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(
          color: Colors.white.withAlpha(77),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
          ),
          SizedBox(height: isSmallScreen ? 4.0 : 6.0),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(217),
              fontSize: isSmallScreen ? 9.0 : (isMediumScreen ? 9.5 : 10.0),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    Color accentColor,
    Color textPrimaryColor,
    Color textSecondaryColor,
    Color cardColor,
    bool isDarkMode, {
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Container(
      padding:
          EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      decoration: BoxDecoration(
        color:
            isDarkMode ? Colors.white.withAlpha(13) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 14.0),
        border: Border.all(
          color: isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(38),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            ),
            child: Icon(icon,
                color: accentColor,
                size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
          ),
          SizedBox(width: isSmallScreen ? 12.0 : 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: isSmallScreen ? 12.0 : 13.0,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 4.0 : 6.0),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize:
                        isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Stats grid with 2 rows of 4 cards each
  Widget _buildStatsGrid(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final stats = [
      {
        'icon': Icons.people_rounded,
        'label': t('users'),
        'value': _dashboardStats?['totalUsers']?.toString() ?? '0',
        'color': Colors.blue
      },
      {
        'icon': Icons.person_outline_rounded,
        'label': _isArabic ? 'السائقين' : 'Drivers',
        'value': _dashboardStats?['totalDrivers']?.toString() ?? '0',
        'color': Colors.orange
      },
      {
        'icon': Icons.people_alt_rounded,
        'label': _isArabic ? 'الركاب' : 'Passengers',
        'value': _dashboardStats?['totalPassengers']?.toString() ?? '0',
        'color': Colors.teal
      },
      {
        'icon': Icons.directions_bus_rounded,
        'label': t('trips'),
        'value': _dashboardStats?['totalTrips']?.toString() ?? '0',
        'color': Colors.purple
      },
      {
        'icon': Icons.directions_car_filled_rounded,
        'label': t('vehicles'),
        'value': _dashboardStats?['totalVehicles']?.toString() ?? '0',
        'color': Colors.indigo
      },
      {
        'icon': Icons.route_rounded,
        'label': t('lines'),
        'value': _dashboardStats?['totalLines']?.toString() ?? '0',
        'color': Colors.green
      },
      {
        'icon': Icons.calendar_today_rounded,
        'label': t('reservations'),
        'value': _dashboardStats?['totalReservations']?.toString() ?? '0',
        'color': Colors.cyan
      },
      {
        'icon': Icons.attach_money_rounded,
        'label': t('revenue'),
        'value': _formatRevenue(_revenueStats?['totalRevenue']),
        'color': Colors.amber
      },
    ];

    return Row(
      children: stats
          .map((s) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildMiniStatCard(
                    icon: s['icon'] as IconData,
                    label: s['label'] as String,
                    value: _statsLoading ? '-' : s['value'] as String,
                    color: s['color'] as Color,
                    cardColor: cardColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMiniStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              _isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(color: textSecondary, fontSize: 8),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLargeMapCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    LatLng center = _baseStations.isNotEmpty
        ? LatLng(_baseStations[0]['latitude']?.toDouble() ?? 31.9522,
            _baseStations[0]['longitude']?.toDouble() ?? 35.2332)
        : _vehicleLocations.isNotEmpty
            ? LatLng(_vehicleLocations[0]['latitude']?.toDouble() ?? 31.9522,
                _vehicleLocations[0]['longitude']?.toDouble() ?? 35.2332)
            : const LatLng(31.9522, 35.2332);

    // Height to match 2 rows: 250 + 8 + 270 = 528
    return Container(
      height: 528,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    child: const Icon(Icons.map_rounded,
                        color: Colors.cyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isArabic ? 'خريطة المركبات' : 'Vehicle Tracking',
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_vehicleLocations.length} ${_isArabic ? 'مركبة' : 'active'}',
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminMapPage())),
                    icon:
                        Icon(Icons.open_in_new, color: textSecondary, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _mapLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : FlutterMap(
                      mapController: _mapController,
                      options:
                          MapOptions(initialCenter: center, initialZoom: 12.0),
                      children: [
                        TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                        MarkerLayer(
                          markers: [
                            ..._baseStations.map((station) {
                              return Marker(
                                point: LatLng(
                                    station['latitude']?.toDouble() ?? 0,
                                    station['longitude']?.toDouble() ?? 0),
                                width: 36,
                                height: 36,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.blue.withAlpha(100),
                                          blurRadius: 8)
                                    ],
                                  ),
                                  child: const Icon(Icons.location_city,
                                      color: Colors.white, size: 18),
                                ),
                              );
                            }),
                            ..._vehicleLocations.map((loc) {
                              final isAtStation = loc['is_at_station'] == true;
                              return Marker(
                                point: LatLng(loc['latitude']?.toDouble() ?? 0,
                                    loc['longitude']?.toDouble() ?? 0),
                                width: 30,
                                height: 30,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        isAtStation ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                          color: (isAtStation
                                                  ? Colors.green
                                                  : Colors.red)
                                              .withAlpha(100),
                                          blurRadius: 8)
                                    ],
                                  ),
                                  child: const Icon(Icons.local_taxi,
                                      color: Colors.white, size: 14),
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

  Widget _buildCompactAiInsightsCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final topLines = (_predictionInsights?['topLines'] as List<dynamic>?) ?? [];

    return Container(
      height: 121,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withAlpha(30),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: Colors.deepOrange, size: 12),
              ),
              const SizedBox(width: 6),
              Text(
                _isArabic ? 'توقعات الذكاء' : 'AI Insights',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _insightsLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : topLines.isEmpty
                    ? Center(
                        child: Text(
                          _isArabic ? 'لا توجد بيانات' : 'No data',
                          style: TextStyle(color: textSecondary, fontSize: 9),
                        ),
                      )
                    : ListView.builder(
                        itemCount: topLines.length.clamp(0, 2),
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final data = topLines[index] as Map<String, dynamic>;
                          final utilization =
                              ((data['avgUtilization'] ?? 0) as num)
                                  .toStringAsFixed(0);
                          final lineName =
                              ((data['buckets'] as List?)?.isNotEmpty == true)
                                  ? (data['buckets'][0]['line']?['linename'] ??
                                      'Line ${index + 1}')
                                  : 'Line ${index + 1}';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(Icons.route,
                                    color: Colors.deepOrange, size: 12),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(lineName,
                                      style: TextStyle(
                                          color: textPrimary, fontSize: 10),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getUtilizationColor(
                                            double.tryParse(utilization) ?? 0)
                                        .withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('$utilization%',
                                      style: TextStyle(
                                          color: _getUtilizationColor(
                                              double.tryParse(utilization) ??
                                                  0),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerHealthCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    // Real health data from API endpoint
    final apiHealthy = _systemHealth?['apiHealthy'] ?? false;
    final dbHealthy = _systemHealth?['dbHealthy'] ?? false;
    final realtimeHealthy =
        _vehicleLocations.isNotEmpty || _baseStations.isNotEmpty;
    final lastUpdate = _lastHealthCheck ?? DateTime.now();

    return Container(
      height: 121,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(30),
                  borderRadius: BorderRadius.circular(5),
                ),
                child:
                    const Icon(Icons.dns_rounded, color: Colors.teal, size: 12),
              ),
              const SizedBox(width: 6),
              Text(
                _isArabic ? 'صحة النظام' : 'System Health',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHealthRow(Icons.api, _isArabic ? 'API' : 'API',
                    apiHealthy, textPrimary, textSecondary),
                _buildHealthRow(
                    Icons.storage,
                    _isArabic ? 'قاعدة البيانات' : 'Database',
                    dbHealthy,
                    textPrimary,
                    textSecondary),
                _buildHealthRow(
                    Icons.wifi,
                    _isArabic ? 'الوقت الفعلي' : 'Realtime',
                    realtimeHealthy,
                    textPrimary,
                    textSecondary),
              ],
            ),
          ),
          Text(
            '${_isArabic ? 'آخر تحديث:' : 'Updated:'} ${lastUpdate.hour.toString().padLeft(2, '0')}:${lastUpdate.minute.toString().padLeft(2, '0')}:${lastUpdate.second.toString().padLeft(2, '0')}',
            style: TextStyle(color: textSecondary, fontSize: 8),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(IconData icon, String label, bool healthy,
      Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, size: 12, color: textSecondary),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: TextStyle(color: textPrimary, fontSize: 10))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (healthy ? Colors.green : Colors.red).withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(healthy ? Icons.check_circle : Icons.error,
                  size: 10, color: healthy ? Colors.green : Colors.red),
              const SizedBox(width: 3),
              Text(
                healthy
                    ? (_isArabic ? 'جيد' : 'OK')
                    : (_isArabic ? 'خطأ' : 'Error'),
                style: TextStyle(
                    color: healthy ? Colors.green : Colors.red,
                    fontSize: 9,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final activeVehicles = _vehicleLocations.length;
    final activeStations = _baseStations.length;
    final completedTrips = _dashboardStats?['completedTrips'] ?? 0;
    final cancelledTrips = _dashboardStats?['cancelledTrips'] ?? 0;
    final totalTrips = _dashboardStats?['totalTrips'] ?? 1;
    final successRate = totalTrips > 0
        ? ((completedTrips / totalTrips) * 100).toStringAsFixed(1)
        : '0';

    return Container(
      height: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.monitor_heart_rounded,
                    color: Colors.blue, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                _isArabic ? 'حالة النظام' : 'System Status',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusRow(
                    Icons.directions_car,
                    _isArabic ? 'المركبات النشطة' : 'Active Vehicles',
                    '$activeVehicles',
                    Colors.green,
                    textPrimary,
                    textSecondary),
                _buildStatusRow(
                    Icons.location_city,
                    _isArabic ? 'المحطات' : 'Stations',
                    '$activeStations',
                    Colors.blue,
                    textPrimary,
                    textSecondary),
                _buildStatusRow(
                    Icons.check_circle,
                    _isArabic ? 'نسبة النجاح' : 'Success Rate',
                    '$successRate%',
                    Colors.teal,
                    textPrimary,
                    textSecondary),
                _buildStatusRow(
                    Icons.cancel,
                    _isArabic ? 'الرحلات الملغاة' : 'Cancelled',
                    '$cancelledTrips',
                    Colors.red,
                    textPrimary,
                    textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value, Color color,
      Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(color: textSecondary, fontSize: 11))),
        Text(value,
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentActivityCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final confirmedRes = _dashboardStats?['confirmedReservations'] ?? 0;
    final totalRes = _dashboardStats?['totalReservations'] ?? 0;
    final pendingRes = totalRes - confirmedRes;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.timeline_rounded,
                    color: Colors.purple, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                _isArabic ? 'النشاط الأخير' : 'Activity',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActivityItem(
                    Icons.book_online,
                    _isArabic ? 'حجوزات مؤكدة' : 'Confirmed',
                    '$confirmedRes',
                    Colors.green,
                    textPrimary,
                    textSecondary),
                _buildActivityItem(
                    Icons.pending_actions,
                    _isArabic ? 'حجوزات معلقة' : 'Pending',
                    '$pendingRes',
                    Colors.orange,
                    textPrimary,
                    textSecondary),
                _buildActivityItem(
                    Icons.person_add,
                    _isArabic ? 'مستخدمين جدد' : 'New Users',
                    _dashboardStats?['totalUsers']?.toString() ?? '0',
                    Colors.blue,
                    textPrimary,
                    textSecondary),
                _buildActivityItem(
                    Icons.verified_user,
                    _isArabic ? 'سائقين معتمدين' : 'Verified Drivers',
                    _dashboardStats?['totalDrivers']?.toString() ?? '0',
                    Colors.teal,
                    textPrimary,
                    textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String label, String value,
      Color color, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(4)),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(color: textSecondary, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
        Text(value,
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
      ],
    );
  }

  Widget _buildMiniChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textPrimaryColor,
    required Widget child,
  }) {
    return Container(
      height: 270,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isDarkMode
                ? Colors.white.withAlpha(25)
                : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildCompactRevenueChart(Color textPrimary, Color textSecondary) {
    final totalRevenue = _revenueStats?['totalRevenue'] ?? 0;
    final totalTransactions = _revenueStats?['totalTransactions'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(_formatRevenue(totalRevenue),
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(_isArabic ? 'إجمالي' : 'Total',
                    style: TextStyle(color: textSecondary, fontSize: 8)),
              ],
            ),
            Column(
              children: [
                Text('$totalTransactions',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(_isArabic ? 'معاملة' : 'Trans.',
                    style: TextStyle(color: textSecondary, fontSize: 8)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        RevenueChart(
          data: _revenueChartData ?? const {},
          isArabic: _isArabic,
          showSummary: false,
        ),
      ],
    );
  }

  Widget _buildCompactTripChart(Color textPrimary, Color textSecondary) {
    final totalTrips = _dashboardStats?['totalTrips'] ?? 0;
    final completed = _dashboardStats?['completedTrips'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('$totalTrips',
                    style: TextStyle(
                        color: Colors.purple.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text(_isArabic ? 'إجمالي' : 'Total',
                    style: TextStyle(color: textSecondary, fontSize: 8)),
              ],
            ),
            Column(
              children: [
                Text('$completed',
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(_isArabic ? 'مكتمل' : 'Done',
                    style: TextStyle(color: textSecondary, fontSize: 8)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        TripTimeSeriesChart(
          data: _tripChartData ?? const {},
          isArabic: _isArabic,
        ),
      ],
    );
  }

  Color _getUtilizationColor(double value) {
    if (value >= 80) return Colors.red;
    if (value >= 50) return Colors.orange;
    return Colors.green;
  }

  Widget _buildVehicleTrackingMap(
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    LatLng center = _baseStations.isNotEmpty
        ? LatLng(
            _baseStations[0]['latitude']?.toDouble() ?? 31.9522,
            _baseStations[0]['longitude']?.toDouble() ?? 35.2332,
          )
        : _vehicleLocations.isNotEmpty
            ? LatLng(
                _vehicleLocations[0]['latitude']?.toDouble() ?? 31.9522,
                _vehicleLocations[0]['longitude']?.toDouble() ?? 35.2332,
              )
            : const LatLng(31.9522, 35.2332);

    return _buildSectionCard(
      title: _isArabic ? 'تتبع المركبات' : 'Vehicle Tracking',
      icon: Icons.map_rounded,
      color: Colors.cyan,
      cardColor: cardColor,
      textPrimaryColor: textPrimary,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      headerAction: IconButton(
        icon: Icon(
          Icons.open_in_full,
          color: textSecondary,
          size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminMapPage(),
            ),
          );
        },
        tooltip: _isArabic ? 'عرض كامل' : 'Full View',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: isSmallScreen ? 200.0 : (isMediumScreen ? 220.0 : 140.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withAlpha(25)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              child: _mapLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 12.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName:
                              'com.example.taxi_palestine_app',
                        ),
                        MarkerLayer(
                          markers: _baseStations.map((station) {
                            final lat = station['latitude']?.toDouble() ?? 0.0;
                            final lng = station['longitude']?.toDouble() ?? 0.0;
                            final markerSize = isSmallScreen
                                ? 35.0
                                : (isMediumScreen ? 40.0 : 45.0);
                            final iconSize = isSmallScreen
                                ? 18.0
                                : (isMediumScreen ? 21.0 : 24.0);
                            return Marker(
                              point: LatLng(lat, lng),
                              width: markerSize,
                              height: markerSize,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(230),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: isSmallScreen ? 1.5 : 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withAlpha(128),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.location_city,
                                  color: Colors.white,
                                  size: iconSize,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        MarkerLayer(
                          markers: _vehicleLocations.map((location) {
                            final lat = location['latitude']?.toDouble() ?? 0.0;
                            final lng =
                                location['longitude']?.toDouble() ?? 0.0;
                            final isAtStation =
                                location['is_at_station'] == true;
                            final markerColor =
                                isAtStation ? Colors.green : Colors.red;
                            final vehicleMarkerSize = isSmallScreen
                                ? 40.0
                                : (isMediumScreen ? 45.0 : 50.0);
                            final vehicleIconSize = isSmallScreen
                                ? 22.0
                                : (isMediumScreen ? 25.0 : 28.0);
                            return Marker(
                              point: LatLng(lat, lng),
                              width: vehicleMarkerSize,
                              height: vehicleMarkerSize,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: markerColor.withAlpha(230),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: isSmallScreen ? 2.0 : 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: markerColor.withAlpha(153),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.local_taxi,
                                  color: Colors.white,
                                  size: vehicleIconSize,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionSummaryCard(
    Color cardColor,
    Color textPrimary,
    Color textSecondary, {
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final model = _predictionInsights?['model'] as Map<String, dynamic>?;
    final topLines = (_predictionInsights?['topLines'] as List<dynamic>?) ?? [];

    return _buildSectionCard(
      title: _isArabic ? 'تحليلات الطلب' : 'AI Demand Insights',
      icon: Icons.trending_up_rounded,
      color: Colors.deepOrange,
      cardColor: cardColor,
      textPrimaryColor: textPrimary,
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 200),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_insightsLoading)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                    child: const CircularProgressIndicator(),
                  ),
                )
              else if (topLines.isEmpty)
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    _isArabic
                        ? 'لا توجد بيانات كافية بعد لتوليد التوقعات'
                        : 'No demand signals yet. Predictions will appear after bookings accumulate.',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                    ),
                  ),
                )
              else
                Column(
                  children: topLines.take(3).map((line) {
                    final data = line as Map<String, dynamic>;
                    final utilization = ((data['avgUtilization'] ?? 0) as num)
                        .toStringAsFixed(2);
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 4.0 : 0.0,
                        vertical: isSmallScreen ? 4.0 : 8.0,
                      ),
                      leading: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withAlpha(26),
                          borderRadius:
                              BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                        ),
                        child: Icon(
                          Icons.directions_transit,
                          color: Colors.deepOrange,
                          size: isSmallScreen
                              ? 18.0
                              : (isMediumScreen ? 20.0 : 22.0),
                        ),
                      ),
                      title: Text(
                        ((data['buckets'] as List?)?.isNotEmpty == true)
                            ? (data['buckets'][0]['line']?['linename'] ??
                                'Line')
                            : 'Line',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen
                              ? 13.0
                              : (isMediumScreen ? 14.0 : 15.0),
                        ),
                      ),
                      subtitle: Text(
                        '${_isArabic ? 'نسبة الإشغال' : 'Avg utilization'} $utilization',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: isSmallScreen ? 12.0 : 13.0,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              SizedBox(height: isSmallScreen ? 10.0 : 12.0),
              if (!_insightsLoading && model != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 4.0 : 0.0),
                  child: Text(
                    '${_isArabic ? 'آخر تدريب' : 'Last trained'}: ${_formatTimestamp(model['lastTrainedAt'])}',
                    style: TextStyle(
                      color: textSecondary.withOpacity(0.7),
                      fontSize: isSmallScreen ? 11.0 : 12.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '-';
    try {
      String normalized = value.toString();
      normalized = normalized.replaceFirst(' ', 'T');
      normalized = normalized.replaceFirst(RegExp(r'\+00:?00?$'), 'Z');
      if (!normalized.contains('Z') &&
          !normalized.contains('+') &&
          !normalized.contains('-')) {
        normalized += 'Z';
      }
      final parsed = DateTime.tryParse(normalized)?.toLocal();
      if (parsed == null) return value.toString();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
          '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return value.toString();
    }
  }

  String _formatRevenue(dynamic value) {
    if (value == null) return '0';
    final amount = (value is num) ? value : double.tryParse(value.toString());
    if (amount == null) return '0';
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
