import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import '../../config/app_config.dart';
import 'driver_queue_page.dart';
import 'driver_trips_page.dart';
import 'driver_vehicle_page.dart';
import 'driver_profile_page.dart';
import 'driver_wallet_page.dart';
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
  bool _isTracking = false;
  final LocationService _locationService = LocationService.instance;

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
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadProfileImage();
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
    await _loadThemePreference();
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

  Widget _buildNetworkImage() {
    final avatarUrl = _userData?['avatar_url']?.toString() ?? 
                     _userData?['avatarUrl']?.toString();
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final imageUrl = AppConfig.apiBaseUrl.replaceFirst('/api', '') + avatarUrl;
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
          );
        },
      );
    }
    return _buildDefaultAvatar();
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

  Future<void> _switchLanguage(bool arabic) async {
    await ApiService.saveLanguagePreference(arabic);
    setState(() {
      _isArabic = arabic;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Web-specific responsive breakpoints
    final isWeb = kIsWeb;
    final isDesktop = isWeb && screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    
    // Responsive sizing - enhanced for web
    final double basePadding = isWeb 
        ? (isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    final double cardPadding = isWeb
        ? (isDesktop ? 40.0 : (isTablet ? 32.0 : 28.0))
        : (isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 32.0));
    final double avatarSize = isWeb
        ? (isDesktop ? 100.0 : (isTablet ? 90.0 : 80.0))
        : (isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;

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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
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
                    margin: EdgeInsets.only(right: isSmallScreen ? 4.0 : 8.0),
                    padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                    child: Stack(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
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
                  margin: EdgeInsets.only(right: isSmallScreen ? 4.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.logout_rounded, size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(basePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Professional Welcome Card - Driver Version
                      Container(
                        padding: EdgeInsets.all(cardPadding),
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
                                        width: avatarSize,
                                        height: avatarSize,
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
                                        ),
                                        child: ClipOval(
                                          child: _profileImagePath != null
                                              ? Image.file(
                                                  File(_profileImagePath!),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    // Fallback to network image if local fails
                                                    return _buildNetworkImage();
                                                  },
                                                )
                                              : _buildNetworkImage(),
                                        ),
                                      ),
                                      // Camera Icon Overlay
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
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
                                              width: isSmallScreen ? 1.5 : 2.0,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                                // Greeting Text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isArabic ? 'مرحباً بك!' : 'Hello!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0),
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                                      // User name with waving hand icon
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _userData?['fullname'] ??
                                                  t('driver'),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0),
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.3,
                                                height: 1.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                                          Icon(
                                            Icons.waving_hand_rounded,
                                            color: Colors.amber,
                                            size: isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
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
                            SizedBox(height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
                            // Driver Message with Car Icon
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(26),
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                  ),
                                  child: Icon(
                                    Icons.local_taxi_rounded,
                                    color: Colors.white,
                                    size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                                Expanded(
                                  child: Text(
                                    t('driverMessage'),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
                            // Quick Stats Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildQuickStat(
                                  icon: Icons.access_time_rounded,
                                  label: t('available247'),
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                                Container(
                                  width: 1,
                                  height: isSmallScreen ? 16.0 : 20.0,
                                  color: Colors.white.withAlpha(77),
                                ),
                                _buildQuickStat(
                                  icon: Icons.verified_user_rounded,
                                  label: t('safeSecure'),
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),

                      // Section Header - Quick Actions
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12.0 : 16.0, 
                            vertical: isSmallScreen ? 10.0 : 12.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600.withAlpha(26),
                              Colors.orange.shade700.withAlpha(13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
                              size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                            ),
                            SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                            Text(
                              t('actions'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),

                      // Action Cards Grid
                      isWeb && (isDesktop || isTablet)
                          ? GridView.count(
                              crossAxisCount: isDesktop ? 5 : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                              childAspectRatio: isDesktop ? 1.0 : 1.0,
                              children: [
                                _buildActionCard(
                                  icon: Icons.list_alt_rounded,
                                  title: t('myTrips'),
                                  color: Colors.blue,
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriverTripsPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.check_circle_rounded,
                                  title: t('checkin'),
                                  color: Colors.teal,
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriverQueuePage(),
                                      ),
                                    ).then(
                                        (_) => _queueKey.currentState?.refresh());
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.directions_car_rounded,
                                  title: t('myVehicle'),
                                  color: Colors.orange,
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriverVehiclePage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  title: _isArabic ? 'محفظتي' : 'Wallet',
                                  color: Colors.green,
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriverWalletPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.person_rounded,
                                  title: t('profile'),
                                  color: Colors.purple,
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DriverProfilePage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            )
                          : Column(
                              children: [
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
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
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
                                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.check_circle_rounded,
                                        title: t('checkin'),
                                        color: Colors.teal,
                                        cardColor: cardColor,
                                        textColor: textPrimaryColor,
                                        isDarkMode: _isDarkMode,
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const DriverQueuePage(),
                                            ),
                                          ).then(
                                              (_) => _queueKey.currentState?.refresh());
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
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
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
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
                                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.account_balance_wallet_rounded,
                                        title: _isArabic ? 'محفظتي' : 'Wallet',
                                        color: Colors.green,
                                        cardColor: cardColor,
                                        textColor: textPrimaryColor,
                                        isDarkMode: _isDarkMode,
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const DriverWalletPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.person_rounded,
                                        title: t('profile'),
                                        color: Colors.purple,
                                        cardColor: cardColor,
                                        textColor: textPrimaryColor,
                                        isDarkMode: _isDarkMode,
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
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
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Container(), // Empty space to maintain layout
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      SizedBox(height: isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),

                      // Section Header - Driver Queue
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 12.0 : 16.0, 
                            vertical: isSmallScreen ? 10.0 : 12.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600.withAlpha(26),
                              Colors.blue.shade700.withAlpha(13),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
                                  size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                                ),
                                SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                Text(
                                  t('queueTitle'),
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 4.0 : 6.0),
                            Padding(
                              padding: EdgeInsets.only(left: isSmallScreen ? 30.0 : 36.0),
                              child: Text(
                                t('queueSubtitle'),
                                style: TextStyle(
                                  color: textPrimaryColor.withAlpha(179),
                                  fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),

                      // Driver Queue Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
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
                      SizedBox(height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),

                      // Section Header - Statistics
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                              isSmallScreen: isSmallScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 10.0 : 14.0),
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
                                isSmallScreen: isSmallScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            if (_userData?['phone'] != null)
                              SizedBox(height: isSmallScreen ? 10.0 : 14.0),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              t('role'),
                              _userData?['role'] ?? 'DRIVER',
                              accentColor,
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white.withAlpha(230),
          size: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0),
        ),
        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(230),
            fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
    bool isWeb = false,
  }) {
    // Create a lighter and darker shade for gradient
    final Color lightShade = Color.lerp(color, Colors.white, 0.15)!;
    final Color darkShade = Color.lerp(color, Colors.black, 0.2)!;

    Widget cardContent = Container(
        padding: EdgeInsets.symmetric(
          vertical: isWeb 
              ? (isSmallScreen ? 24.0 : 32.0)
              : (isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)), 
          horizontal: isWeb 
              ? (isSmallScreen ? 18.0 : 24.0)
              : (isSmallScreen ? 16.0 : (isMediumScreen ? 19.0 : 22.0))
        ),
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
          borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 24.0),
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
              padding: EdgeInsets.all(isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0)),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(64),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha(102),
                  width: isSmallScreen ? 2.0 : 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withAlpha(51),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: isWeb 
                  ? (isSmallScreen ? 38.0 : 44.0)
                  : (isSmallScreen ? 28.0 : (isMediumScreen ? 33.0 : 38.0))),
            ),
            SizedBox(height: isWeb 
                ? (isSmallScreen ? 15.0 : 20.0)
                : (isSmallScreen ? 12.0 : (isMediumScreen ? 15.0 : 18.0))),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isWeb 
                    ? (isSmallScreen ? 15.5 : 17.0)
                    : (isSmallScreen ? 12.0 : (isMediumScreen ? 13.5 : 15.5)),
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
      );

    // Wrap with hover effects for web
    Widget interactiveCard = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 24.0),
      child: cardContent,
    );

    if (isWeb) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: interactiveCard,
        ),
      );
    }

    return interactiveCard;
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
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
            child: Icon(icon, color: accentColor, size: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0)),
          ),
          SizedBox(width: isSmallScreen ? 12.0 : 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: isSmallScreen ? 11.0 : 12.0,
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
}
