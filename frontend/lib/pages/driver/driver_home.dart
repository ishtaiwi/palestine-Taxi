import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
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

class _DriverHomePageState extends State<DriverHomePage>
    with WidgetsBindingObserver {
  final GlobalKey<DriverQueuePageState> _queueKey =
      GlobalKey<DriverQueuePageState>();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false; // Light mode as default
  String? _profileImagePath; // Local path to profile image
  final ImagePicker _imagePicker = ImagePicker();

  final LocationService _locationService = LocationService.instance;
  bool _isTracking = false;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'لوحة السائق',
      'greeting': 'مرحباً بك',
      'hello': 'مرحباً',
      'welcome': 'مرحباً',
      'welcomeMessage': 'أهلاً وسهلاً بك في لوحة السائق',
      'driverMessage': 'رحلتك القادمة في انتظارك',
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
      'phone': 'الهاتف',
      'role': 'الدور',
      'driver': 'السائق',
      'logout': 'تسجيل الخروج',
      'available247': 'متاح 24/7',
      'safeSecure': 'آمن وموثوق',
      'imageUploadSuccess': 'تم تحميل الصورة بنجاح',
      'imageUploadFailed': 'فشل تحميل الصورة',
    },
    'en': {
      'title': 'Driver Dashboard',
      'greeting': 'Welcome',
      'hello': 'Hello',
      'welcome': 'Welcome',
      'welcomeMessage': 'Welcome to your Driver Dashboard',
      'driverMessage': 'Your next trip is waiting for you',
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
      'phone': 'Phone',
      'role': 'Role',
      'driver': 'Driver',
      'logout': 'Logout',
      'available247': 'Available 24/7',
      'safeSecure': 'Safe & Secure',
      'imageUploadSuccess': 'Image uploaded successfully',
      'imageUploadFailed': 'Failed to upload image',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfileImage();
  }

  Future<void> _loadUserData() async {
    final userData = await ApiService.getUserData();
    final isArabic = await ApiService.getLanguagePreference();
    await _loadThemePreference();
    setState(() {
      _userData = userData;
      _isLoading = false;
      _isArabic = isArabic;
    });
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }


  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('driver_profile_image');
    if (imagePath != null && File(imagePath).existsSync()) {
      setState(() {
        _profileImagePath = imagePath;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('driver_profile_image', image.path);

        setState(() {
          _profileImagePath = image.path;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('imageUploadSuccess')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('imageUploadFailed')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.orange.shade600,
            Colors.orange.shade800,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 40,
          color: Colors.white.withAlpha(230),
        ),
      ),
    );
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

    // Theme-aware colors
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    const accentColor = Color(0xFFF57C00);

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
              title: Text(
                t('title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
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
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 22),
                    onPressed: _handleLogout,
                    tooltip: t('logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Professional Welcome Card - Driver Version
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2C5F8D), // Professional blue
                              Color(0xFF1E3A5F), // Dark navy
                              Color(0xFF2C5F8D), // Professional blue
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2C5F8D).withAlpha(102),
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
                            // Greeting Row with Profile Image
                            Row(
                              children: [
                                // Profile Image with Upload
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Stack(
                                    children: [
                                      // Profile Image Container
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
                                        ),
                                        child: ClipOval(
                                          child: _profileImagePath != null
                                              ? Image.file(
                                                  File(_profileImagePath!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return _buildDefaultAvatar();
                                                  },
                                                )
                                              : _buildDefaultAvatar(),
                                        ),
                                      ),
                                      // Camera Icon Overlay
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                accentColor,
                                                accentColor.withAlpha(204),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Greeting Text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isArabic ? 'مرحباً بك!' : 'Hello!',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // User name with waving hand icon
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _userData?['fullname'] ?? t('driver'),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.waving_hand_rounded,
                                            color: Colors.amber,
                                            size: 28,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Divider
                            Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withAlpha(0),
                                    Colors.white.withAlpha(102),
                                    Colors.white.withAlpha(0),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Driver Message with Car Icon
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(26),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.local_taxi_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    t('driverMessage'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Quick Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickStat(
                                  icon: Icons.access_time_rounded,
                                  label: t('available247'),
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.white.withAlpha(77),
                                ),
                                _buildQuickStat(
                                  icon: Icons.verified_user_rounded,
                                  label: t('safeSecure'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Header - Quick Actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600.withAlpha(26),
                              Colors.orange.shade700.withAlpha(13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade600.withAlpha(77),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: Colors.orange.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('actions'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Cards Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.list_alt_rounded,
                              title: t('myTrips'),
                              color: Colors.blue,
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.check_circle_rounded,
                              title: t('checkin'),
                              color: Colors.green,
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DriverQueuePage(),
                                  ),
                                ).then((_) => _queueKey.currentState?.refresh());
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.directions_car_rounded,
                              title: t('myVehicle'),
                              color: Colors.orange,
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.person_rounded,
                              title: t('profile'),
                              color: Colors.purple,
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
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
                      const SizedBox(height: 32),

                      // Section Header - Driver Queue
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600.withAlpha(26),
                              Colors.blue.shade700.withAlpha(13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.shade600.withAlpha(77),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.queue_rounded,
                                  color: Colors.blue.shade600,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  t('queueTitle'),
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 36),
                              child: Text(
                                t('queueSubtitle'),
                                style: TextStyle(
                                  color: textPrimaryColor.withAlpha(179),
                                  fontSize: 13,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Driver Queue Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isDarkMode
                                ? const Color(0xFF2C3E50)
                                : const Color(0xFFD1D9E0),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(13),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.blue.withAlpha(26),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: DriverQueuePage(
                          key: _queueKey,
                          embedded: true,
                          isArabicOverride: _isArabic,
                          isDarkModeOverride: _isDarkMode,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Header - Statistics
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade600.withAlpha(26),
                              Colors.purple.shade700.withAlpha(13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.shade600.withAlpha(77),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.purple.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('statistics'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Statistics Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.purple.shade600,
                              Colors.purple.shade700,
                              Colors.purple.shade800,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withAlpha(102),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withAlpha(51),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              t('todayTrips'),
                              '0',
                              Colors.white,
                              Icons.local_taxi_rounded,
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white.withAlpha(77),
                            ),
                            _buildStatItem(
                              t('passengers'),
                              '0',
                              Colors.white,
                              Icons.people_rounded,
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white.withAlpha(77),
                            ),
                            _buildStatItem(
                              t('rating'),
                              '4.5',
                              Colors.white,
                              Icons.star_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Account Info Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isDarkMode
                                ? Colors.white.withAlpha(38)
                                : Colors.grey.shade200,
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
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: accentColor.withAlpha(51),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: accentColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  t('accountInfo'),
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildInfoRow(
                              Icons.email_outlined,
                              t('email'),
                              _userData?['email'] ?? '',
                              accentColor,
                              textPrimaryColor,
                              textSecondaryColor,
                              cardColor,
                              _isDarkMode,
                            ),
                            const SizedBox(height: 14),
                            if (_userData?['phone'] != null)
                              _buildInfoRow(
                                Icons.phone_outlined,
                                t('phone'),
                                _userData?['phone'] ?? '',
                                accentColor,
                                textPrimaryColor,
                                textSecondaryColor,
                                cardColor,
                                _isDarkMode,
                              ),
                            if (_userData?['phone'] != null) const SizedBox(height: 14),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              t('role'),
                              _userData?['role'] ?? 'DRIVER',
                              accentColor,
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
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 2, // Home is index 2
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            DriverBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildQuickStat({
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withAlpha(230),
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(230),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    // Create a lighter and darker shade for gradient
    final Color lightShade = Color.lerp(color, Colors.white, 0.15)!;
    final Color darkShade = Color.lerp(color, Colors.black, 0.2)!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              lightShade,
              color,
              darkShade,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Main colored shadow
            BoxShadow(
              color: color.withAlpha(128),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            // Secondary shadow for depth
            BoxShadow(
              color: color.withAlpha(64),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 15),
            ),
            // Dark shadow for contrast
            BoxShadow(
              color: Colors.black.withAlpha(51),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container with glow effect
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(64),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha(102),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withAlpha(51),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                height: 1.3,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                  Shadow(
                    color: Colors.black12,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        // Icon with glow effect
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(77),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withAlpha(51),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withAlpha(230),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ],
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
        color: isDarkMode
            ? Colors.white.withAlpha(13)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withAlpha(25)
              : Colors.grey.shade200,
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
}

