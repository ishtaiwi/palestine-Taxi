import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_trips_page.dart';
import 'passenger_reservations_page.dart';
import 'passenger_wallet_page.dart';
import 'passenger_profile_page.dart';
import 'passenger_notifications_page.dart';
import '../../widgets/notification_badge.dart';
import '../../services/notification_service.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false; 
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _favoriteLines = [];
  int _unreadNotificationCount = 0;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الصفحة الرئيسية - مسافر',
      'home': 'الرئيسية',
      'welcome': 'مرحباً',
      'bookNow': 'احجز رحلتك الآن',
      'quickActions': 'إجراءات سريعة',
      'viewTrips': 'استعرض الرحلات',
      'myReservations': 'حجوزاتي',
      'myWallet': 'محفظتي',
      'profile': 'الملف الشخصي',
      'favoriteLines': 'الخطوط المفضلة',
      'noFavorites': 'لا توجد خطوط مفضلة حتى الآن',
      'accountInfo': 'معلومات الحساب',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'phone': 'رقم الهاتف',
      'role': 'الدور',
      'passenger': 'المسافر',
      'fromTo': 'من {from} إلى {to}',
      'lastBooked': 'آخر حجز',
      'viewTripsForLine': 'عرض الرحلات لهذا الخط',
      'logout': 'تسجيل الخروج',
    },
    'en': {
      'title': 'Home - Passenger',
      'home': 'Home',
      'welcome': 'Welcome',
      'bookNow': 'Book your trip now',
      'quickActions': 'Quick Actions',
      'viewTrips': 'View Trips',
      'myReservations': 'My Reservations',
      'myWallet': 'My Wallet',
      'profile': 'Profile',
      'favoriteLines': 'Favorite Lines',
      'noFavorites': 'No favorite lines yet',
      'accountInfo': 'Account Information',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'role': 'Role',
      'passenger': 'Passenger',
      'fromTo': 'From {from} to {to}',
      'lastBooked': 'Last booked',
      'bookThisTrip': 'Book this trip',
      'logout': 'Logout',
    },
  };

  String t(String key, [Map<String, String>? replacements]) {
    String text = _texts[_isArabic ? 'ar' : 'en']![key] ?? key;
    if (replacements != null) {
      replacements.forEach((key, value) {
        text = text.replaceAll('{$key}', value);
      });
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemePreference();
    _loadProfileImage();
    _loadFavoriteLines();
    _initializeNotifications();
    _loadUnreadCount();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService().initialize();
      NotificationService().setOnNotificationTap((data) {
        // Show notification dialog when push notification is tapped
        final isArabic = _isArabic;
        final title = data['title'] as String? ?? (isArabic ? 'إشعار' : 'Notification');
        final body = data['body'] as String? ?? (isArabic ? 'إشعار جديد' : 'New notification');
        
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isArabic ? 'إغلاق' : 'Close'),
                ),
              ],
            );
          },
        );
        
        // Handle notification tap navigation based on data['action']
        if (data['action'] == 'view_reservation' && data['bookingid'] != null) {
          // Navigate to reservation details
          // Navigator.push(...);
        } else if (data['action'] == 'view_trip' && data['tripid'] != null) {
          // Navigate to trip details
          // Navigator.push(...);
        }
      });
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await ApiService.getUnreadCount();
      if (result['success'] == true && mounted) {
        setState(() {
          _unreadNotificationCount = result['count'] as int? ?? 0;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _loadUserData() async {
    final userData = await ApiService.getUserData();
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _userData = userData;
      _isLoading = false;
      _isArabic = isArabic;
      _favoriteLines = [];
    });
    await _loadFavoriteLines();
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadProfileImage() async {
    final userData = await ApiService.getUserData();
    if (mounted) {
      setState(() {
        _userData = userData;
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
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );
        }

        final result = await ApiService.uploadProfileImage(image.path);

        if (mounted) {
          Navigator.of(context).pop(); // close loading
        }

        if (mounted) {
          if (result['success'] == true) {
            await _loadUserData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isArabic
                      ? 'تم تحديث صورة الملف الشخصي'
                      : 'Profile image updated',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result['message']?.toString() ??
                      (_isArabic
                          ? 'فشل تحميل الصورة'
                          : 'Failed to upload image'),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic ? 'فشل تحميل الصورة' : 'Failed to upload image',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _loadFavoriteLines() async {
    try {
      final reservations = await ApiService.fetchPassengerReservations();
      if (!mounted || reservations.isEmpty) {
        if (mounted) {
          setState(() {
            _favoriteLines = [];
          });
        }
        return;
      }

      final Map<String, Map<String, dynamic>> lineStats = {};

      for (final reservation in reservations) {
        final status = reservation['status']?.toString() ?? '';
        if (status == 'cancelled' || status == 'no_show') continue;

        final trip = reservation['trip'] as Map<String, dynamic>?;
        final line =
            trip?['line'] as Map<String, dynamic>? ?? reservation['line'] as Map<String, dynamic>?;
        if (line == null) continue;

        final lineId = line['lineid']?.toString();
        if (lineId == null) continue;

        final nameAr = (line['name_ar']?.toString() ??
                line['linename']?.toString() ??
                line['name_en']?.toString() ??
                '')
            .trim();
        final nameEn = (line['name_en']?.toString() ??
                line['linename']?.toString() ??
                line['name_ar']?.toString() ??
                '')
            .trim();

        Map<String, String> _splitRoute(String name) {
          final parts = name.split(RegExp(r'[-–]'));
          if (parts.length >= 2) {
            return {
              'from': parts.first.trim(),
              'to': parts.sublist(1).join('-').trim(),
            };
          }
          return {
            'from': name,
            'to': '',
          };
        }

        final arSplit = nameAr.isNotEmpty ? _splitRoute(nameAr) : {'from': '', 'to': ''};
        final enSplit = nameEn.isNotEmpty ? _splitRoute(nameEn) : {'from': '', 'to': ''};

        DateTime? bookedAt;
        final createdStr = reservation['created_at']?.toString() ??
            reservation['createdAt']?.toString() ??
            reservation['bookingtime']?.toString();
        if (createdStr != null) {
          try {
            bookedAt = DateTime.parse(createdStr);
          } catch (_) {
            bookedAt = null;
          }
        }

        final key = lineId;
        final current = lineStats[key];
        if (current == null) {
          lineStats[key] = {
            'lineId': lineId,
            'fromAr': arSplit['from'] ?? '',
            'toAr': arSplit['to'] ?? '',
            'fromEn': enSplit['from'] ?? '',
            'toEn': enSplit['to'] ?? '',
            'lineName': nameEn.isNotEmpty ? nameEn : nameAr,
            'count': 1,
            'lastBookedAt': bookedAt,
          };
        } else {
          current['count'] = (current['count'] as int) + 1;
          final existingDate = current['lastBookedAt'] as DateTime?;
          if (bookedAt != null &&
              (existingDate == null || bookedAt.isAfter(existingDate))) {
            current['lastBookedAt'] = bookedAt;
          }
        }
      }

      if (!mounted) return;

      final statsList = lineStats.values.toList()
        ..sort((a, b) {
          final countA = a['count'] as int? ?? 0;
          final countB = b['count'] as int? ?? 0;
          final cmpCount = countB.compareTo(countA);
          if (cmpCount != 0) return cmpCount;

          final dateA = a['lastBookedAt'] as DateTime?;
          final dateB = b['lastBookedAt'] as DateTime?;

          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

      final topFavorites = statsList.take(3).map((stat) {
        final lastBookedAt = stat['lastBookedAt'] as DateTime?;
        final lastBookedText = lastBookedAt != null
            ? _formatRelativeTime(lastBookedAt)
            : (_isArabic ? 'غير متوفر' : 'Not available');

        return {
          'lineId': stat['lineId'] as String? ?? '',
          'fromAr': stat['fromAr'] as String? ?? '',
          'toAr': stat['toAr'] as String? ?? '',
          'fromEn': stat['fromEn'] as String? ?? '',
          'toEn': stat['toEn'] as String? ?? '',
          'line': stat['lineName'] as String? ?? '',
          'lastBookedAr': lastBookedText,
          'lastBookedEn': lastBookedText,
          'color': Colors.indigo, // default; can later be customized per line
        };
      }).toList();

      setState(() {
        _favoriteLines = topFavorites;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _favoriteLines = [];
        });
      }
    }
  }


  Future<void> _handleLogout() async {
    await ApiService.clearAuthData();
    setState(() {
      _favoriteLines = [];
    });
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    // Refresh unread count when app bar is built
    _loadUnreadCount();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return AppBar(
      backgroundColor: _isDarkMode
          ? const Color(0xFF1C2541)
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        t('title'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0),
        ),
      ),
      actions: [
        NotificationBadge(
          count: _unreadNotificationCount,
          child: IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PassengerNotificationsPage(),
                ),
              ).then((_) => _loadUnreadCount());
            },
            tooltip: 'Notifications',
          ),
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
    final double iconSize = isWeb
        ? (isDesktop ? 28.0 : 24.0)
        : (isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;

    
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
        appBar: _buildAppBar(context),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(basePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      
                      Container(
                        padding: EdgeInsets.all(cardPadding),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2C5F8D), 
                              Color(0xFF1E3A5F), 
                              Color(0xFF2C5F8D), 
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 28.0),
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
                            
                            Row(
                              children: [
                                
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Stack(
                                    children: [
                                      
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
                                        child: _userData?['avatar_url'] != null &&
                                                _userData!['avatar_url']
                                                    .toString()
                                                    .isNotEmpty
                                            ? Image.network(
                                                AppConfig.apiBaseUrl
                                                        .replaceFirst('/api', '') +
                                                    _userData!['avatar_url']
                                                        .toString(),
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return _buildDefaultAvatar();
                                                },
                                              )
                                            : _buildDefaultAvatar(),
                                      ),
                                      ),
                                      
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
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                      
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _userData?['fullname'] ?? t('passenger'),
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
                                          SizedBox(width: isSmallScreen ? 4.0 : 8.0),
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
                            SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                            
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
                            SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                            
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
                                    size: iconSize,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                                Expanded(
                                  child: Text(
                                    _isArabic
                                        ? 'رحلتك القادمة على بعد نقرة واحدة'
                                        : 'Your next ride is just a tap away',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 15.0),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 14.0 : 20.0),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.route_rounded,
                                    label: _isArabic ? 'رحلات متاحة' : 'Available Trips',
                                    value: '24/7',
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.verified_user_rounded,
                                    label: _isArabic ? 'آمن وموثوق' : 'Safe & Secure',
                                    value: '100%',
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20.0 : 32.0),

                      
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12.0 : 16.0, 
                          vertical: isSmallScreen ? 10.0 : 12.0
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withAlpha(26),
                              accentColor.withAlpha(13),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                          border: Border.all(
                            color: accentColor.withAlpha(51),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.dashboard_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 18.0 : 22.0,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                            Text(
                              t('quickActions'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 14.0 : 20.0),
                      // Use Grid for web, Rows for mobile
                      isWeb && (isDesktop || isTablet)
                          ? GridView.count(
                              crossAxisCount: isDesktop ? 4 : 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16.0,
                              mainAxisSpacing: 16.0,
                              childAspectRatio: isDesktop ? 1.1 : 1.0,
                              children: [
                                _buildActionCard(
                                  icon: Icons.directions_bus_rounded,
                                  title: t('viewTrips'),
                                  color: const Color(0xFF2196F3),
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
                                        builder: (_) => const PassengerTripsPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.book_online_rounded,
                                  title: t('myReservations'),
                                  color: const Color(0xFF4CAF50),
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
                                        builder: (_) => const PassengerReservationsPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  title: t('myWallet'),
                                  color: const Color(0xFFFF9800),
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
                                        builder: (_) => const PassengerWalletPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildActionCard(
                                  icon: Icons.person_rounded,
                                  title: t('profile'),
                                  color: const Color(0xFF9C27B0),
                                  cardColor: cardColor,
                                  textColor: textPrimaryColor,
                                  isDarkMode: _isDarkMode,
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                  isWeb: isWeb,
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PassengerProfilePage(),
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
                                        icon: Icons.directions_bus_rounded,
                                        title: t('viewTrips'),
                                        color: const Color(0xFF2196F3),
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
                                              builder: (_) => const PassengerTripsPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.book_online_rounded,
                                        title: t('myReservations'),
                                        color: const Color(0xFF4CAF50),
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
                                              builder: (_) => const PassengerReservationsPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 10.0 : 14.0),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.account_balance_wallet_rounded,
                                        title: t('myWallet'),
                                        color: const Color(0xFFFF9800),
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
                                              builder: (_) => const PassengerWalletPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                                    Expanded(
                                      child: _buildActionCard(
                                        icon: Icons.person_rounded,
                                        title: t('profile'),
                                        color: const Color(0xFF9C27B0),
                                        cardColor: cardColor,
                                        textColor: textPrimaryColor,
                                        isDarkMode: _isDarkMode,
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                        isWeb: isWeb,
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const PassengerProfilePage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      SizedBox(height: isSmallScreen ? 20.0 : 32.0),

                      
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12.0 : 16.0, 
                          vertical: isSmallScreen ? 10.0 : 12.0
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE91E63).withAlpha(26),
                              const Color(0xFFE91E63).withAlpha(13),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                          border: Border.all(
                            color: const Color(0xFFE91E63).withAlpha(51),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: isSmallScreen ? 18.0 : 22.0,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                            Text(
                              t('favoriteLines'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 14.0 : 20.0),
                      if (_favoriteLines.isEmpty)
                        Container(
                          padding: EdgeInsets.all(isWeb ? (isDesktop ? 32.0 : 24.0) : (isSmallScreen ? 16.0 : 24.0)),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(isWeb ? (isDesktop ? 20.0 : 18.0) : (isSmallScreen ? 16.0 : 20.0)),
                            border: Border.all(
                              color: _isDarkMode
                                  ? Colors.white.withAlpha(38)
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(13),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.favorite_border_rounded,
                                color: textSecondaryColor,
                                size: isWeb ? (isDesktop ? 32.0 : 28.0) : (isSmallScreen ? 22.0 : 28.0),
                              ),
                              SizedBox(width: isWeb ? (isDesktop ? 20.0 : 16.0) : (isSmallScreen ? 12.0 : 16.0)),
                              Expanded(
                                child: Text(
                                  t('noFavorites'),
                                  style: TextStyle(
                                    color: textSecondaryColor,
                                    fontSize: isWeb ? (isDesktop ? 18.0 : 16.0) : (isSmallScreen ? 13.0 : 15.0),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        isWeb && (isDesktop || isTablet)
                            ? GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: isDesktop ? 3 : 2,
                                  crossAxisSpacing: 16.0,
                                  mainAxisSpacing: 16.0,
                                  childAspectRatio: isDesktop ? 1.1 : 1.0,
                                ),
                                itemCount: _favoriteLines.length,
                                itemBuilder: (context, index) {
                                  final line = _favoriteLines[index];
                                  return _buildFavoriteLineCard(
                                    context: context,
                                    lineId: line['lineId'] as String? ?? '',
                                    from: _isArabic
                                        ? line['fromAr'] as String
                                        : line['fromEn'] as String,
                                    to: _isArabic
                                        ? line['toAr'] as String
                                        : line['toEn'] as String,
                                    lineName: line['line'] as String,
                                    lastBooked: _isArabic
                                        ? line['lastBookedAr'] as String
                                        : line['lastBookedEn'] as String,
                                    accentColor: line['color'] as Color? ?? Colors.blue,
                                    cardColor: cardColor,
                                    textColor: textPrimaryColor,
                                    textSecondaryColor: textSecondaryColor,
                                    isDarkMode: _isDarkMode,
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                    isWeb: isWeb,
                                  );
                                },
                              )
                            : Column(
                                children: _favoriteLines
                                    .map(
                                      (line) => Padding(
                                        padding: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 14.0),
                                        child: _buildFavoriteLineCard(
                                          context: context,
                                          lineId: line['lineId'] as String? ?? '',
                                          from: _isArabic
                                              ? line['fromAr'] as String
                                              : line['fromEn'] as String,
                                          to: _isArabic
                                              ? line['toAr'] as String
                                              : line['toEn'] as String,
                                          lineName: line['line'] as String,
                                          lastBooked: _isArabic
                                              ? line['lastBookedAr'] as String
                                              : line['lastBookedEn'] as String,
                                          accentColor: line['color'] as Color? ?? Colors.blue,
                                          cardColor: cardColor,
                                          textColor: textPrimaryColor,
                                          textSecondaryColor: textSecondaryColor,
                                          isDarkMode: _isDarkMode,
                                          isSmallScreen: isSmallScreen,
                                          isMediumScreen: isMediumScreen,
                                          isWeb: isWeb,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      SizedBox(height: isSmallScreen ? 20.0 : 28.0),

                      
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 24.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
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
                                  padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                                  decoration: BoxDecoration(
                                    color: accentColor.withAlpha(51),
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                  ),
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    color: accentColor,
                                    size: iconSize,
                                  ),
                                ),
                                SizedBox(width: isSmallScreen ? 10.0 : 14.0),
                                Text(
                                  t('accountInfo'),
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 14.0 : 20.0),
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
                            SizedBox(height: isSmallScreen ? 10.0 : 14.0),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              t('role'),
                              _userData?['role'] ?? 'PASSENGER',
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
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 2, 
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            PassengerBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
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
    
    final Color lightShade = Color.lerp(color, Colors.white, 0.15)!;
    final Color darkShade = Color.lerp(color, Colors.black, 0.2)!;

    Widget cardContent = Container(
        padding: EdgeInsets.symmetric(
          vertical: isWeb 
              ? (isSmallScreen ? 24.0 : 32.0)
              : (isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)), 
          horizontal: isWeb 
              ? (isSmallScreen ? 18.0 : 24.0)
              : (isSmallScreen ? 14.0 : (isMediumScreen ? 18.0 : 22.0))
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
          borderRadius: BorderRadius.circular(isSmallScreen ? 18.0 : 24.0),
          boxShadow: [
            
            BoxShadow(
              color: color.withAlpha(128),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
            
            BoxShadow(
              color: color.withAlpha(64),
              blurRadius: 30,
              spreadRadius: -5,
              offset: const Offset(0, 15),
            ),
            
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
            
            Container(
              padding: EdgeInsets.all(isWeb 
                  ? (isSmallScreen ? 20.0 : 24.0)
                  : (isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0))),
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
      borderRadius: BorderRadius.circular(isSmallScreen ? 18.0 : 24.0),
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
        color: isDarkMode
            ? Colors.white.withAlpha(13)
            : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 14.0),
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
            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
            decoration: BoxDecoration(
              color: accentColor.withAlpha(38),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            ),
            child: Icon(
              icon, 
              color: accentColor, 
              size: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0)
            ),
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
                    fontSize: isSmallScreen ? 11.0 : 13.0,
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

  Widget _buildFavoriteLineCard({
    required BuildContext context,
    required String lineId,
    required String from,
    required String to,
    required String lineName,
    required String lastBooked,
    required Color accentColor,
    required Color cardColor,
    required Color textColor,
    required Color textSecondaryColor,
    required bool isDarkMode,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
    bool isWeb = false,
  }) {
    final isRtl = _isArabic;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = isWeb && screenWidth >= 1200;

    return Container(
      padding: EdgeInsets.all(isWeb 
          ? (isDesktop ? 28.0 : 24.0)
          : (isSmallScreen ? 16.0 : (isMediumScreen ? 19.0 : 22.0))),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isWeb 
            ? (isDesktop ? 24.0 : 20.0)
            : (isSmallScreen ? 16.0 : 20.0)),
        border: Border.all(
          color: accentColor.withAlpha(102),
          width: isSmallScreen ? 1.5 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(38),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12.0 : 16.0, 
                  vertical: isSmallScreen ? 7.0 : 9.0
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withAlpha(76),
                      accentColor.withAlpha(51),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 25.0),
                  border: Border.all(
                    color: accentColor.withAlpha(128),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route_rounded,
                      color: accentColor,
                      size: isSmallScreen ? 14.0 : 16.0,
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    Text(
                      lineName,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 11.0 : 13.0,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: accentColor,
                  size: isSmallScreen ? 16.0 : 20.0,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 18.0),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: accentColor,
                size: isSmallScreen ? 16.0 : 20.0,
              ),
              SizedBox(width: isSmallScreen ? 8.0 : 10.0),
              Expanded(
                child: Text(
                  t('fromTo', {'from': from, 'to': to}),
                  style: TextStyle(
                    color: textColor,
                    fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.5 : 17.0),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: textSecondaryColor,
                size: isSmallScreen ? 14.0 : 18.0,
              ),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Text(
                '${t('lastBooked')}: $lastBooked',
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: isSmallScreen ? 12.0 : 14.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 18.0),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PassengerTripsPage(initialLineId: lineId),
                  ),
                );
              },
              icon: Icon(Icons.route_rounded, size: isSmallScreen ? 16.0 : 20.0),
              label: Text(
                t('viewTripsForLine'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 13.0 : 15.0,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12.0 : 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 14.0),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays <= 0) {
      return _isArabic ? 'اليوم' : 'Today';
    } else if (difference.inDays == 1) {
      return _isArabic ? 'أمس' : 'Yesterday';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return _isArabic ? 'قبل $days أيام' : '$days days ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return _isArabic
          ? 'قبل $weeks أسبوع'
          : weeks == 1
              ? '1 week ago'
              : '$weeks weeks ago';
    }
  }

  
  Widget _buildWelcomeStatCard({
    required IconData icon,
    required String label,
    required String value,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : 14.0),
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
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 23.0 : 26.0),
          ),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0),
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
              fontSize: isSmallScreen ? 9.0 : 11.0,
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

  
  Widget _buildDefaultAvatar() {
    const accentColor = Color(0xFFF57C00);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor,
            accentColor.withAlpha(204),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

