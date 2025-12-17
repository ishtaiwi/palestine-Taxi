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

  // Map tracking state
  List<Map<String, dynamic>> _vehicleLocations = [];
  List<Map<String, dynamic>> _baseStations = [];
  bool _mapLoading = false;
  final MapController _mapController = MapController();

  // Statistics state
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
      // Load vehicle locations
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

      // Load base stations
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541) // Dark card color for better integration
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        t('title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            AppTheme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            color: Colors.white,
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
          ),
          onPressed: () => _switchLanguage(!_isArabic),
          tooltip: _isArabic ? 'English' : 'العربية',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          onPressed: _handleLogout,
          tooltip: t('logout'),
        ),
        const SizedBox(width: 8),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    // Theme-aware colors
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
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gradient Header
                      Container(
                        padding: const EdgeInsets.all(32),
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
                          borderRadius: BorderRadius.circular(28),
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
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
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
                                  child: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t('welcome'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _userData?['fullname'] ?? t('admin'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t('manageSystem'),
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Stats Row
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
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.directions_bus_rounded,
                                    label: t('trips'),
                                    value: _statsLoading
                                        ? '-'
                                        : (_dashboardStats?['totalTrips']
                                                ?.toString() ??
                                            '0'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.attach_money_rounded,
                                    label: t('revenue'),
                                    value: _statsLoading
                                        ? '-'
                                        : _formatRevenue(
                                            _revenueStats?['totalRevenue']),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // System Management Card
                      _buildSectionCard(
                        title: t('systemManagement'),
                        icon: Icons.dashboard_rounded,
                        color: adminPrimaryColor,
                        cardColor: cardColor,
                        textPrimaryColor: textPrimaryColor,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.people_outline_rounded,
                                    title: t('users'),
                                    color: Colors.blue,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminUsersPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.route_rounded,
                                    title: t('lines'),
                                    color: Colors.green,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminLinesPage())),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.directions_car_filled_rounded,
                                    title: t('vehicles'),
                                    color: Colors.orange,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminVehiclesPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.directions_bus_filled_rounded,
                                    title: t('trips'),
                                    color: Colors.purple,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminTripsPage())),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.schedule_rounded,
                                    title: t('schedules'),
                                    color: Colors.indigo,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminSchedulesPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.payment_rounded,
                                    title: t('payments'),
                                    color: Colors.teal,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminPaymentsPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.bar_chart_rounded,
                                    title: t('reports'),
                                    color: Colors.red,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminReportsPage())),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.trending_up_rounded,
                                    title: t('aiPredictions'),
                                    color: Colors.deepOrange,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminPredictionsPage())),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionCard(
                                    icon: Icons.location_city_rounded,
                                    title: t('baseStations'),
                                    color: Colors.brown,
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const AdminBaseStationPage())),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Map Section
                      _buildVehicleTrackingMap(
                          cardColor, textPrimaryColor, textSecondaryColor),

                      const SizedBox(height: 32),

                      // Analytics Section
                      _buildPredictionSummaryCard(
                          cardColor, textPrimaryColor, textSecondaryColor),

                      const SizedBox(height: 32),

                      // Account Info
                      _buildSectionCard(
                        title: t('accountInfo'),
                        icon: Icons.person_outline_rounded,
                        color: adminPrimaryColor,
                        cardColor: cardColor,
                        textPrimaryColor: textPrimaryColor,
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
                            ),
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              t('role'),
                              _userData?['role'] ?? 'ADMIN',
                              adminPrimaryColor,
                              textPrimaryColor,
                              textSecondaryColor,
                              cardColor,
                              _isDarkMode,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode ? Colors.white.withAlpha(38) : Colors.grey.shade200,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (headerAction != null) headerAction,
            ],
          ),
          const SizedBox(height: 24),
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
  }) {
    // Determine background color based on theme
    final bgColor = _isDarkMode ? const Color(0xFF1C2541) : Colors.white;
    final borderColor =
        _isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withAlpha(50),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isDarkMode ? Colors.white : AppTheme.textPrimary,
                fontSize: 13,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(16),
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
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withAlpha(217),
              fontSize: 10,
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
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withAlpha(13) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode ? Colors.white.withAlpha(25) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(38),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
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
      Color cardColor, Color textPrimary, Color textSecondary) {
    // Determine center point
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
      headerAction: IconButton(
        icon: Icon(
          Icons.open_in_full,
          color: textSecondary,
          size: 20,
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
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withAlpha(25)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                        // Base station markers
                        MarkerLayer(
                          markers: _baseStations.map((station) {
                            final lat = station['latitude']?.toDouble() ?? 0.0;
                            final lng = station['longitude']?.toDouble() ?? 0.0;
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 45,
                              height: 45,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(230),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withAlpha(128),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_city,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Vehicle markers
                        MarkerLayer(
                          markers: _vehicleLocations.map((location) {
                            final lat = location['latitude']?.toDouble() ?? 0.0;
                            final lng =
                                location['longitude']?.toDouble() ?? 0.0;
                            final isAtStation =
                                location['is_at_station'] == true;
                            final markerColor =
                                isAtStation ? Colors.green : Colors.red;
                            return Marker(
                              point: LatLng(lat, lng),
                              width: 50,
                              height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: markerColor.withAlpha(230),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: markerColor.withAlpha(153),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_taxi,
                                  color: Colors.white,
                                  size: 28,
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
      Color cardColor, Color textPrimary, Color textSecondary) {
    final model = _predictionInsights?['model'] as Map<String, dynamic>?;
    final topLines = (_predictionInsights?['topLines'] as List<dynamic>?) ?? [];

    return _buildSectionCard(
      title: _isArabic ? 'تحليلات الطلب' : 'AI Demand Insights',
      icon: Icons.trending_up_rounded,
      color: Colors.deepOrange,
      cardColor: cardColor,
      textPrimaryColor: textPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_insightsLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (topLines.isEmpty)
            Text(
              _isArabic
                  ? 'لا توجد بيانات كافية بعد لتوليد التوقعات'
                  : 'No demand signals yet. Predictions will appear after bookings accumulate.',
              style: TextStyle(color: textSecondary),
            )
          else
            Column(
              children: topLines.take(3).map((line) {
                final data = line as Map<String, dynamic>;
                final utilization =
                    ((data['avgUtilization'] ?? 0) as num).toStringAsFixed(2);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_transit,
                        color: Colors.deepOrange),
                  ),
                  title: Text(
                    ((data['buckets'] as List?)?.isNotEmpty == true)
                        ? (data['buckets'][0]['line']?['linename'] ?? 'Line')
                        : 'Line',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    '${_isArabic ? 'نسبة الإشغال' : 'Avg utilization'} $utilization',
                    style: TextStyle(color: textSecondary),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          if (!_insightsLoading && model != null)
            Text(
              '${_isArabic ? 'آخر تدريب' : 'Last trained'}: ${_formatTimestamp(model['lastTrainedAt'])}',
              style: TextStyle(
                  color: textSecondary.withOpacity(0.7), fontSize: 12),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
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
