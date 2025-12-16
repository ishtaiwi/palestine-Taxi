import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../screens/auth/login_page.dart';
import 'driver_queue_page.dart';
import 'driver_trips_page.dart';
import 'driver_vehicle_page.dart';
import 'driver_profile_page.dart';
import 'driver_location_tracking_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> with WidgetsBindingObserver {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isTracking = false;
  final LocationService _locationService = LocationService.instance;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'لوحة السائق',
      'welcome': 'مرحباً',
      'manageTrips': 'إدارة رحلاتك ومركبتك',
      'actions': 'الإجراءات',
      'myTrips': 'رحلاتي',
      'checkin': 'Check-in',
      'myVehicle': 'مركبتي',
      'profile': 'الملف الشخصي',
      'statistics': 'الإحصائيات',
      'queueTitle': 'دور السائقين',
      'queueSubtitle': 'احجز دورك وشاهد ترتيب السائقين على خطك',
      'todayTrips': 'رحلات اليوم',
      'passengers': 'الركاب',
      'rating': 'التقييم',
      'accountInfo': 'معلومات الحساب',
      'email': 'البريد الإلكتروني',
      'role': 'الدور',
      'driver': 'السائق',
      'logout': 'تسجيل الخروج',
    },
    'en': {
      'title': 'Driver Dashboard',
      'welcome': 'Welcome',
      'manageTrips': 'Manage your trips and vehicle',
      'actions': 'Actions',
      'myTrips': 'My Trips',
      'checkin': 'Check-in',
      'myVehicle': 'My Vehicle',
      'profile': 'Profile',
      'statistics': 'Statistics',
      'queueTitle': 'Driver Queue',
      'queueSubtitle': 'Join the line and track other drivers on your route',
      'todayTrips': 'Today\'s Trips',
      'passengers': 'Passengers',
      'rating': 'Rating',
      'accountInfo': 'Account Information',
      'email': 'Email',
      'role': 'Role',
      'driver': 'Driver',
      'logout': 'Logout',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Restart tracking when app resumes
      _checkAndStartTracking();
    }
  }

  Future<void> _loadUserData() async {
    final userData = await ApiService.getUserData();
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _userData = userData;
      _isLoading = false;
      _isArabic = isArabic;
    });
    
    // Auto-start location tracking for drivers
    if (userData != null && userData['role'] == 'DRIVER') {
      await _checkAndStartTracking();
    }
  }

  Future<void> _checkAndStartTracking() async {
    if (!mounted) return;
    
    // Check if tracking is already active
    if (_locationService.isTracking) {
      setState(() {
        _isTracking = true;
      });
      return;
    }

    // Try to start tracking
    final started = await _locationService.startLocationTracking();
    if (mounted) {
      setState(() {
        _isTracking = started;
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
    // Stop location tracking on logout
    await _locationService.stopLocationTracking();
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
            backgroundColor: const Color(0xFF1E3A5F), // خلفية فاتحة أكثر
            foregroundColor: Colors.white,
            elevation: 2,
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
          actions: [
            // Tracking status indicator
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DriverLocationTrackingPage(),
                  ),
                );
                // Refresh tracking status when returning from tracking page
                if (mounted) {
                  setState(() {
                    _isTracking = _locationService.isTracking;
                  });
                }
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 24,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isTracking ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
              icon: const Icon(Icons.logout, color: Colors.white),
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
                            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
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
                                    '${t('welcome')}, ${_userData?['fullname'] ?? t('driver')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t('manageTrips'),
                                    style: const TextStyle(
                                      color: Colors.white, // نص أبيض على خلفية غامقة
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.drive_eta,
                              color: Colors.white,
                              size: 48,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        t('actions'),
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
                              icon: Icons.list_alt,
                              title: t('myTrips'),
                              color: Colors.blue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverTripsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.check_circle,
                              title: t('checkin'),
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverQueuePage(),
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
                              title: t('myVehicle'),
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverVehiclePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.person,
                              title: t('profile'),
                              color: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverProfilePage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text(
                        t('queueTitle'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t('queueSubtitle'),
                        style: const TextStyle(
                          color: Colors.white, // نص أبيض على خلفية غامقة
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DriverQueuePage(
                          embedded: true,
                          isArabicOverride: _isArabic,
                        ),
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
                              t('statistics'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  t('todayTrips'),
                                  '0',
                                  Colors.blue,
                                ),
                                _buildStatItem(
                                  t('passengers'),
                                  '0',
                                  Colors.green,
                                ),
                                _buildStatItem(
                                  t('rating'),
                                  '4.5',
                                  Colors.orange,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
                              _userData?['role'] ?? 'DRIVER',
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white, // نص أبيض على خلفية غامقة
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white, // نص أبيض على خلفية غامقة
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

