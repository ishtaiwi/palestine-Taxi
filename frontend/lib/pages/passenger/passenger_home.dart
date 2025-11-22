import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../screens/auth/login_page.dart';
import 'passenger_trips_page.dart';
import 'passenger_reservations_page.dart';
import 'passenger_wallet_page.dart';

class PassengerHomePage extends StatefulWidget {
  const PassengerHomePage({super.key});

  @override
  State<PassengerHomePage> createState() => _PassengerHomePageState();
}

class _PassengerHomePageState extends State<PassengerHomePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الصفحة الرئيسية - مسافر',
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
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
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
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF57C00), Color(0xFFE65100)],
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
                                    '${t('welcome')}, ${_userData?['fullname'] ?? t('passenger')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    t('bookNow'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 48,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        t('quickActions'),
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
                              icon: Icons.directions_bus,
                              title: t('viewTrips'),
                              color: Colors.blue,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.book_online,
                              title: t('myReservations'),
                              color: Colors.green,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.account_balance_wallet,
                              title: t('myWallet'),
                              color: Colors.orange,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.person,
                              title: t('profile'),
                              color: Colors.purple,
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text(
                        t('favoriteTrips'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_favoriteTrips.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white38),
                          ),
                          child: Text(
                            t('noFavorites'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _favoriteTrips
                              .map(
                                (trip) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
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
                                    accentColor:
                                        trip['color'] as Color? ?? Colors.blue,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white38),
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
                              Icons.phone,
                              t('phone'),
                              _userData?['phone'] ?? '',
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              Icons.badge,
                              t('role'),
                              _userData?['role'] ?? 'PASSENGER',
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
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
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
                  color: Colors.white,
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

  Widget _buildFavoriteTripCard({
    required String from,
    required String to,
    required String line,
    required String lastBooked,
    required Color accentColor,
  }) {
    final isRtl = _isArabic;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1),
                ),
                child: Text(
                  line,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.favorite,
                color: accentColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t('fromTo', {'from': from, 'to': to}),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${t('lastBooked')}: $lastBooked',
            style: const TextStyle(
              color: Colors.white, // نص أبيض على خلفية غامقة
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.flash_on, size: 18),
              label: Text(
                t('bookThisTrip'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

