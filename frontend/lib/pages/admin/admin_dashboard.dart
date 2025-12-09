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

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
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
      'schedules': 'الجداول ',
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
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init().then((_) {
      if (mounted) setState(() {});
    });
    _loadUserData();
    _loadPredictionInsights();
    _loadMapData();
    _subscribeToRealtimeUpdates();
    _loadDashboardStats();
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
      print('Error loading map data: $e');
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
      print('Error loading dashboard stats: $e');
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

      debugPrint('[AdminDashboard] getPredictionInsightsAdmin => $insights');

      if (insights['success'] == true) {
        setState(() {
          _predictionInsights = insights['data'] ?? insights;
          _insightsLoading = false;
        });
      } else {
        // Normalize a predictable structure so UI can show an empty state + error
        setState(() {
          _predictionInsights = {
            'topLines': [],
            'model': null,
            'errorMessage': insights['message'] ?? 'Failed to load insights'
          };
          _insightsLoading = false;
        });

        debugPrint(
            '[AdminDashboard] prediction insights failed: ${insights['message']}');
      }
    } catch (error, stack) {
      debugPrint('[AdminDashboard] exception loading insights: $error\n$stack');
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

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            t('title'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.appBarColor,
          elevation: 2,
          iconTheme: IconThemeData(
            color: AppTheme.textPrimary,
          ),
          actionsIconTheme: IconThemeData(
            color: AppTheme.textPrimary,
          ),
          actions: [
            IconButton(
              icon: Icon(
                AppTheme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: AppTheme.textPrimary,
              ),
              onPressed: () async {
                await AppTheme.toggleTheme();
                if (mounted) setState(() {});
              },
              tooltip: AppTheme.isDarkMode ? 'Light Mode' : 'Dark Mode',
            ),
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: AppTheme.textPrimary,
              ),
              onPressed: () => _switchLanguage(!_isArabic),
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
            IconButton(
              icon: Icon(
                Icons.logout,
                color: AppTheme.textPrimary,
              ),
              onPressed: _handleLogout,
              tooltip: t('logout'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t('welcome')}, ${_userData?['fullname'] ?? t('admin')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t('manageSystem'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                              size: 48,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t('systemManagement'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.people,
                              title: t('users'),
                              color: Colors.blue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminUsersPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.route,
                              title: t('lines'),
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminLinesPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.directions_car,
                              title: t('vehicles'),
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminVehiclesPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.directions_bus,
                              title: t('trips'),
                              color: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminTripsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.schedule,
                              title: t('schedules'),
                              color: Colors.indigo,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminSchedulesPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.payment,
                              title: t('payments'),
                              color: Colors.teal,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminPaymentsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.bar_chart,
                              title: t('reports'),
                              color: Colors.red,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.trending_up,
                              title: _isArabic
                                  ? 'توقعات الذكاء الاصطناعي'
                                  : 'AI Predictions',
                              color: Colors.deepOrange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminPredictionsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.map,
                              title:
                                  _isArabic ? 'خريطة المركبات' : 'Vehicle Map',
                              color: Colors.cyan,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AdminMapPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.location_city,
                              title:
                                  _isArabic ? 'محطات القاعدة' : 'Base Stations',
                              color: Colors.brown,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminBaseStationPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('generalStats'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2,
                              children: [
                                _buildStatCard(
                                  t('users'),
                                  _statsLoading
                                      ? '-'
                                      : (_dashboardStats?['totalUsers']
                                              ?.toString() ??
                                          '0'),
                                  Icons.people,
                                  Colors.blue,
                                ),
                                _buildStatCard(
                                  t('trips'),
                                  _statsLoading
                                      ? '-'
                                      : (_dashboardStats?['totalTrips']
                                              ?.toString() ??
                                          '0'),
                                  Icons.directions_bus,
                                  Colors.green,
                                ),
                                _buildStatCard(
                                  t('reservations'),
                                  _statsLoading
                                      ? '-'
                                      : (_dashboardStats?['totalReservations']
                                              ?.toString() ??
                                          '0'),
                                  Icons.book_online,
                                  Colors.orange,
                                ),
                                _buildStatCard(
                                  t('revenue'),
                                  _statsLoading
                                      ? '-'
                                      : _formatRevenue(
                                          _revenueStats?['totalRevenue']),
                                  Icons.attach_money,
                                  Colors.purple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildVehicleTrackingMap(),
                      const SizedBox(height: 16),
                      _buildPredictionSummaryCard(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('accountInfo'),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.email,
                              t('email'),
                              _userData?['email'] ?? '',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.badge,
                              t('role'),
                              _userData?['role'] ?? 'ADMIN',
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

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionSummaryCard() {
    final model = _predictionInsights?['model'] as Map<String, dynamic>?;
    final topLines = (_predictionInsights?['topLines'] as List<dynamic>?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getCardBorder(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'تحليلات الطلب' : 'AI Demand Insights',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_insightsLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (topLines.isEmpty)
            Text(
              _isArabic
                  ? 'لا توجد بيانات كافية بعد لتوليد التوقعات'
                  : 'No demand signals yet. Predictions will appear after bookings accumulate.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            Column(
              children: topLines.take(3).map((line) {
                final data = line as Map<String, dynamic>;
                final utilization =
                    ((data['avgUtilization'] ?? 0) as num).toStringAsFixed(2);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.directions_transit,
                      color: Colors.lightBlueAccent),
                  title: Text(
                    ((data['buckets'] as List?)?.isNotEmpty == true)
                        ? (data['buckets'][0]['line']?['linename'] ?? 'Line')
                        : 'Line',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_isArabic ? 'نسبة الإشغال' : 'Avg utilization'} $utilization',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          if (!_insightsLoading && model != null)
            Text(
              '${_isArabic ? 'آخر تدريب' : 'Last trained'}: ${_formatTimestamp(model['lastTrainedAt'])}',
              style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7), fontSize: 12),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTrackingMap() {
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.getCardBackground(0.08),
            AppTheme.getCardBackground(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.getCardBorder(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.getShadowColor(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.map,
                        color: Colors.cyan,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _isArabic ? 'تتبع المركبات' : 'Vehicle Tracking',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.open_in_full,
                        color: Colors.white,
                        size: 18,
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
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.getCardBorder(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.getShadowColor(0.5),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        // Base station markers with better styling
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
                                  color: Colors.blue.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withValues(alpha: 0.5),
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
                        // Vehicle markers with better styling
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
                                  color: markerColor.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: markerColor.withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Icon(
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
          const SizedBox(height: 12),
          // Improved legend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.getCardBackground(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppTheme.getCardBorder(0.1),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMapLegendItem(
                  Icons.local_taxi,
                  Colors.red,
                  _isArabic ? 'في الطريق' : 'On Route',
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildMapLegendItem(
                  Icons.local_taxi,
                  Colors.green,
                  _isArabic ? 'في المحطة' : 'At Station',
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _buildMapLegendItem(
                  Icons.location_city,
                  Colors.blue,
                  _isArabic ? 'محطة' : 'Station',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
