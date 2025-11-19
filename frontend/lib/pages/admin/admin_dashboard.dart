import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;

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
          title: Text(t('title')),
          backgroundColor: const Color(0xFF0B132B),
          actions: [
            IconButton(
              icon: Icon(_isArabic ? Icons.language : Icons.translate),
              onPressed: () => _switchLanguage(!_isArabic),
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
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
                      // Welcome Section
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

                      // Management Cards
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
                                // TODO: Navigate to users management
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
                                // TODO: Navigate to lines management
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
                                // TODO: Navigate to vehicles management
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
                                // TODO: Navigate to trips management
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
                              icon: Icons.payment,
                              title: t('payments'),
                              color: Colors.teal,
                              onTap: () {
                                // TODO: Navigate to payments
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.bar_chart,
                              title: t('reports'),
                              color: Colors.red,
                              onTap: () {
                                // TODO: Navigate to reports
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Statistics Card
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
                              childAspectRatio: 2.5,
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

                      // User Info
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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

