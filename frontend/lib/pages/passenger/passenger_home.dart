import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_trips_page.dart';
import 'passenger_reservations_page.dart';
import 'passenger_wallet_page.dart';
import 'passenger_profile_page.dart';

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
  String? _profileImagePath; 
  final ImagePicker _imagePicker = ImagePicker();

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
      'favoriteTrips': 'الرحلات المفضلة',
      'noFavorites': 'لا توجد رحلات مفضلة حتى الآن',
      'accountInfo': 'معلومات الحساب',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'phone': 'رقم الهاتف',
      'role': 'الدور',
      'passenger': 'المسافر',
      'fromTo': 'من {from} إلى {to}',
      'lastBooked': 'آخر حجز',
      'bookThisTrip': 'احجز هذه الرحلة',
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
      'favoriteTrips': 'Favorite Trips',
      'noFavorites': 'No favorite trips yet',
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

  final List<Map<String, dynamic>> _favoriteTrips = [
    {
      'fromAr': 'نابلس',
      'toAr': 'بيت إيبا',
      'fromEn': 'Nablus',
      'toEn': 'Beit Iba',
      'line': 'Route Nablus - Beit Iba',
      'lastBookedAr': 'قبل 3 أيام',
      'lastBookedEn': '3 days ago',
      'color': Colors.teal,
    },
    {
      'fromAr': 'نابلس',
      'toAr': 'بيت وزن',
      'fromEn': 'Nablus',
      'toEn': 'Beit Wazan',
      'line': 'Route Nablus - Beit Wazan',
      'lastBookedAr': 'قبل أسبوع',
      'lastBookedEn': '1 week ago',
      'color': Colors.deepOrange,
    },
    {
      'fromAr': 'نابلس',
      'toAr': 'عصيرة الشمالية',
      'fromEn': 'Nablus',
      'toEn': 'Asira Al-Shamaliya',
      'line': 'Route Nablus - Asira Al-Shamaliya',
      'lastBookedAr': 'آخر رحلة أمس',
      'lastBookedEn': 'Last trip yesterday',
      'color': Colors.indigo,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemePreference();
    _loadProfileImage();
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

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image_path');
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
        await prefs.setString('profile_image_path', image.path);

        setState(() {
          _profileImagePath = image.path;
        });

        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isArabic ? 'تم تحديث صورة الملف الشخصي' : 'Profile image updated',
              ),
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
      backgroundColor: _isDarkMode
          ? const Color(0xFF1C2541)
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
        appBar: _buildAppBar(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      
                      Container(
                        padding: const EdgeInsets.all(32),
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
                            
                            Row(
                              children: [
                                
                                GestureDetector(
                                  onTap: _pickProfileImage,
                                  child: Stack(
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _userData?['fullname'] ?? t('passenger'),
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
                                    _isArabic
                                        ? 'رحلتك القادمة على بعد نقرة واحدة'
                                        : 'Your next ride is just a tap away',
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
                            
                            Row(
                              children: [
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.route_rounded,
                                    label: _isArabic ? 'رحلات متاحة' : 'Available Trips',
                                    value: '24/7',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildWelcomeStatCard(
                                    icon: Icons.verified_user_rounded,
                                    label: _isArabic ? 'آمن وموثوق' : 'Safe & Secure',
                                    value: '100%',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withAlpha(26),
                              accentColor.withAlpha(13),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: accentColor.withAlpha(51),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.dashboard_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('quickActions'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.book_online_rounded,
                              title: t('myReservations'),
                              color: const Color(0xFF4CAF50),
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
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
                      const SizedBox(height: 14),
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.person_rounded,
                              title: t('profile'),
                              color: const Color(0xFF9C27B0),
                              cardColor: cardColor,
                              textColor: textPrimaryColor,
                              isDarkMode: _isDarkMode,
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
                      const SizedBox(height: 32),

                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFE91E63).withAlpha(26),
                              const Color(0xFFE91E63).withAlpha(13),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE91E63).withAlpha(51),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withAlpha(76),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              t('favoriteTrips'),
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_favoriteTrips.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
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
                                size: 28,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  t('noFavorites'),
                                  style: TextStyle(
                                    color: textSecondaryColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _favoriteTrips
                              .map(
                                (trip) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _buildFavoriteTripCard(
                                    from: _isArabic
                                        ? trip['fromAr'] as String
                                        : trip['fromEn'] as String,
                                    to: _isArabic
                                        ? trip['toAr'] as String
                                        : trip['toEn'] as String,
                                    line: trip['line'] as String,
                                    lastBooked: _isArabic
                                        ? trip['lastBookedAr'] as String
                                        : trip['lastBookedEn'] as String,
                                    accentColor: trip['color'] as Color? ?? Colors.blue,
                                    cardColor: cardColor,
                                    textColor: textPrimaryColor,
                                    textSecondaryColor: textSecondaryColor,
                                    isDarkMode: _isDarkMode,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 28),

                      
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
                            const SizedBox(height: 14),
                            _buildInfoRow(
                              Icons.badge_outlined,
                              t('role'),
                              _userData?['role'] ?? 'PASSENGER',
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
  }) {
    
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

  Widget _buildFavoriteTripCard({
    required String from,
    required String to,
    required String line,
    required String lastBooked,
    required Color accentColor,
    required Color cardColor,
    required Color textColor,
    required Color textSecondaryColor,
    required bool isDarkMode,
  }) {
    final isRtl = _isArabic;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withAlpha(102),
          width: 2,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withAlpha(76),
                      accentColor.withAlpha(51),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
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
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      line,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(51),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: accentColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('fromTo', {'from': from, 'to': to}),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: textSecondaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '${t('lastBooked')}: $lastBooked',
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_on_rounded, size: 20),
              label: Text(
                t('bookThisTrip'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildWelcomeStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            size: 26,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
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
              fontSize: 11,
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

