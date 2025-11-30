import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_page.dart';
import 'admin_schedules_page.dart';
import 'admin_lines_page.dart';
import 'admin_users_page.dart';
import 'admin_vehicles_page.dart';
import 'admin_trips_page.dart';
import 'admin_payments_page.dart';
import 'admin_predictions_page.dart';

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
    _loadUserData();
    _loadPredictionInsights();
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
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF1E3A5F), // لون فاتح أكثر
          elevation: 2,
          iconTheme: const IconThemeData(
            color: Colors.white, // أيقونات بيضاء
          ),
          actionsIconTheme: const IconThemeData(
            color: Colors.white, // أيقونات الأزرار بيضاء
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: Colors.white,
              ),
              onPressed: () => _switchLanguage(!_isArabic),
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
            IconButton(
              icon: const Icon(
                Icons.logout,
                color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
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
                              style: const TextStyle(
                                color: Colors.white,
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
                                  '0',
                                  Icons.people,
                                  Colors.blue,
                                ),
                                _buildStatCard(
                                  t('trips'),
                                  '0',
                                  Icons.directions_bus,
                                  Colors.green,
                                ),
                                _buildStatCard(
                                  t('reservations'),
                                  '0',
                                  Icons.book_online,
                                  Colors.orange,
                                ),
                                _buildStatCard(
                                  t('revenue'),
                                  '0',
                                  Icons.attach_money,
                                  Colors.purple,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                              style: const TextStyle(
                                color: Colors.white,
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
              style: const TextStyle(
                color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white70,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isArabic ? 'تحليلات الطلب' : 'AI Demand Insights',
            style: const TextStyle(
              color: Colors.white,
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
              style: const TextStyle(color: Colors.white70),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${_isArabic ? 'نسبة الإشغال' : 'Avg utilization'} $utilization',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          if (!_insightsLoading && model != null)
            Text(
              '${_isArabic ? 'آخر تدريب' : 'Last trained'}: ${_formatTimestamp(model['lastTrainedAt'])}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
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
}
