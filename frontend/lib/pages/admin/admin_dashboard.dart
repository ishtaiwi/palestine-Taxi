import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/supabase_realtime_service.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
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
  bool _statsLoading = false;

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
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  @override
  void dispose() {
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

  Future<void> _loadMapData() async {
    setState(() {
      _mapLoading = true;
    });

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
      setState(() {
        _mapLoading = false;
      });
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

  Future<void> _loadDashboardStats() async {
    setState(() {
      _statsLoading = true;
    });

    try {
      final stats = await ApiService.getDashboardStats();
      final revenue = await ApiService.getRevenueAnalytics();

      setState(() {
        _dashboardStats = stats;
        _revenueStats = revenue;
        _statsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      setState(() {
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadPredictionInsights() async {
    setState(() {
      _insightsLoading = true;
    });

    try {
      final insights = await ApiService.getPredictionInsightsAdmin(limit: 3);

      if (insights['success'] == true) {
        setState(() {
          _predictionInsights = insights['data'] ?? insights;
          _insightsLoading = false;
        });
      } else {
        setState(() {
          _predictionInsights = {
            'topLines': [],
            'model': null,
            'errorMessage': insights['message'] ?? 'Failed to load insights'
          };
          _insightsLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _predictionInsights = {
          'topLines': [],
          'model': null,
          'errorMessage': error.toString()
        };
        _insightsLoading = false;
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
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);
    final cardColor =
        _isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);
    final textPrimaryColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    const adminPrimaryColor = Color(0xFF7B1FA2); // Purple for Admin

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: _buildAppBar(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(basePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
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
                          borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0)),
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
                                  width: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
                                  height: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
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
                                    size: isSmallScreen ? 30.0 : (isMediumScreen ? 35.0 : 40.0),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('welcome'),
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                                      Text(
                                        _userData?['fullname'] ?? t('admin'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 21.0 : 24.0),
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
                                          fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.people_rounded,
                                    label: t('users'),
                                    value: _statsLoading
                                        ? '-'
                                        : (_dashboardStats?['totalUsers']
                                                ?.toString() ??
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
                                        : (_dashboardStats?['totalTrips']
                                                ?.toString() ??
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
                                        : _formatRevenue(
                                            _revenueStats?['totalRevenue']),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),

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
                                            builder: (_) =>
                                                const AdminUsersPage())),
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
                                            builder: (_) =>
                                                const AdminLinesPage())),
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
                                            builder: (_) =>
                                                const AdminVehiclesPage())),
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
                                            builder: (_) =>
                                                const AdminTripsPage())),
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
                                            builder: (_) =>
                                                const AdminSchedulesPage())),
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
                                            builder: (_) =>
                                                const AdminPaymentsPage())),
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
                                            builder: (_) =>
                                                const AdminReportsPage())),
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
                                    title: _isArabic ? 'موافقة السائقين' : 'Driver Approvals',
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
                                            builder: (_) =>
                                                const AdminPredictionsPage())),
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
                                            builder: (_) =>
                                                const AdminBaseStationPage())),
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
                                            builder: (_) =>
                                                const AdminSettingsPage())),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),

                      _buildVehicleTrackingMap(
                          cardColor, textPrimaryColor, textSecondaryColor, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),

                      SizedBox(height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),

                      _buildPredictionSummaryCard(
                          cardColor, textPrimaryColor, textSecondaryColor, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),

                      SizedBox(height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),

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
                ),
              ),
      ),
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
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
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
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 14.0),
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          SizedBox(height: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
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
          horizontal: isSmallScreen ? 8.0 : 12.0
        ),
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
              padding: EdgeInsets.all(isSmallScreen ? 8.0 : (isMediumScreen ? 10.0 : 12.0)),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withAlpha(50),
                  width: 1,
                ),
              ),
              child: Icon(
                icon, 
                color: color, 
                size: isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0)
              ),
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
        horizontal: isSmallScreen ? 6.0 : 8.0
      ),
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
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
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
            child: Icon(icon, color: accentColor, size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
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
                    fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
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

  Widget _buildVehicleTrackingMap(
      Color cardColor, Color textPrimary, Color textSecondary, {
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
            height: isSmallScreen ? 240.0 : (isMediumScreen ? 280.0 : 320.0),
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
                            final markerSize = isSmallScreen ? 35.0 : (isMediumScreen ? 40.0 : 45.0);
                            final iconSize = isSmallScreen ? 18.0 : (isMediumScreen ? 21.0 : 24.0);
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
                            final vehicleMarkerSize = isSmallScreen ? 40.0 : (isMediumScreen ? 45.0 : 50.0);
                            final vehicleIconSize = isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0);
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
      Color cardColor, Color textPrimary, Color textSecondary, {
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
                final utilization =
                    ((data['avgUtilization'] ?? 0) as num).toStringAsFixed(2);
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4.0 : 0.0,
                    vertical: isSmallScreen ? 4.0 : 8.0,
                  ),
                  leading: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withAlpha(26),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                    ),
                    child: Icon(
                      Icons.directions_transit,
                      color: Colors.deepOrange,
                      size: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                    ),
                  ),
                  title: Text(
                    ((data['buckets'] as List?)?.isNotEmpty == true)
                        ? (data['buckets'][0]['line']?['linename'] ?? 'Line')
                        : 'Line',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
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
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 4.0 : 0.0),
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
