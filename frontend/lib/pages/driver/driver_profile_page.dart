import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import 'driver_home.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false;
  String? _error;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الملف الشخصي',
      'profileInfo': 'معلومات الملف الشخصي',
      'driverInfo': 'معلومات السائق',
      'personalInfo': 'المعلومات الشخصية',
      'vehicleInfo': 'معلومات المركبة',
      'lineInfo': 'معلومات الخط',
      'statistics': 'الإحصائيات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'refresh': 'تحديث',
      'retry': 'إعادة المحاولة',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'phone': 'الهاتف',
      'licenseId': 'رقم الرخصة',
      'status': 'الحالة',
      'rating': 'التقييم',
      'line': 'الخط',
      'vehicle': 'المركبة',
      'plateNumber': 'رقم اللوحة',
      'seatLayout': 'نوع المقاعد',
      'seatNumber': 'عدد المقاعد',
      'hasVehicle': 'يوجد مركبة',
      'noVehicle': 'لا توجد مركبة',
      'hasLine': 'يوجد خط',
      'noLine': 'لا يوجد خط',
      'unknown': 'غير معروف',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'pending': 'قيد الانتظار',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
      'settings': 'الإعدادات',
      'language': 'اللغة',
      'theme': 'المظهر',
      'lightMode': 'الوضع الفاتح',
      'darkMode': 'الوضع الداكن',
      'arabic': 'العربية',
      'english': 'English',
      'accountInfo': 'معلومات الحساب',
    },
    'en': {
      'title': 'Profile',
      'profileInfo': 'Profile Information',
      'driverInfo': 'Driver Information',
      'personalInfo': 'Personal Information',
      'vehicleInfo': 'Vehicle Information',
      'lineInfo': 'Line Information',
      'statistics': 'Statistics',
      'loading': 'Loading...',
      'error': 'Error',
      'refresh': 'Refresh',
      'retry': 'Retry',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'licenseId': 'License ID',
      'status': 'Status',
      'rating': 'Rating',
      'line': 'Line',
      'vehicle': 'Vehicle',
      'plateNumber': 'Plate Number',
      'seatLayout': 'Seat Layout',
      'seatNumber': 'Seat Number',
      'hasVehicle': 'Has Vehicle',
      'noVehicle': 'No Vehicle',
      'hasLine': 'Has Line',
      'noLine': 'No Line',
      'unknown': 'Unknown',
      'active': 'Active',
      'inactive': 'Inactive',
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'price': 'Price',
      'base': 'Base',
      'distance': 'Distance',
      'duration': 'Duration',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'lightMode': 'Light Mode',
      'darkMode': 'Dark Mode',
      'arabic': 'العربية',
      'english': 'English',
      'accountInfo': 'Account Information',
    },
  };

  String t(String key) {
    final textMap = _texts[_isArabic ? 'ar' : 'en'];
    if (textMap == null) return key;
    return textMap[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadProfile();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    await AppTheme.init();
    setState(() {
      _isArabic = isArabic;
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getDriverProfile();
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTheme() async {
    await AppTheme.toggleTheme();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _switchLanguage(bool arabic) async {
    await ApiService.saveLanguagePreference(arabic);
    setState(() {
      _isArabic = arabic;
    });
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'approved':
        return Colors.green;
      case 'inactive':
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return t('active');
      case 'inactive':
        return t('inactive');
      case 'pending':
        return t('pending');
      case 'approved':
        return t('approved');
      case 'rejected':
        return t('rejected');
      default:
        return status ?? t('unknown');
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? valueColor}) {
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white70
        : const Color(0xFF546E7A);
    final accentColor = Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? t('unknown'),
                  style: TextStyle(
                    color: valueColor ?? textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final accentColor = Colors.orange;
    
    // Determine icon based on title
    IconData sectionIcon;
    if (title == t('driverInfo')) {
      sectionIcon = Icons.person;
    } else if (title == t('lineInfo')) {
      sectionIcon = Icons.alt_route;
    } else if (title == t('vehicleInfo')) {
      sectionIcon = Icons.directions_car;
    } else {
      sectionIcon = Icons.info;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  sectionIcon,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white70
        : const Color(0xFF546E7A);
    final accentColor = Colors.orange;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.settings,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                t('settings'),
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
          // Language Setting
          _buildSettingTile(
            icon: Icons.language,
            title: t('language'),
            subtitle: _isArabic ? t('arabic') : t('english'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: cardColor,
                  title: Text(
                    t('language'),
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(
                          t('arabic'),
                          style: TextStyle(color: textPrimaryColor),
                        ),
                        leading: Radio<bool>(
                          value: true,
                          groupValue: _isArabic,
                          onChanged: (value) {
                            Navigator.pop(context);
                            _switchLanguage(true);
                          },
                          activeColor: accentColor,
                        ),
                      ),
                      ListTile(
                        title: Text(
                          t('english'),
                          style: TextStyle(color: textPrimaryColor),
                        ),
                        leading: Radio<bool>(
                          value: false,
                          groupValue: _isArabic,
                          onChanged: (value) {
                            Navigator.pop(context);
                            _switchLanguage(false);
                          },
                          activeColor: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            textPrimaryColor: textPrimaryColor,
            textSecondaryColor: textSecondaryColor,
            accentColor: accentColor,
          ),
          Divider(
            height: 1,
            color: _isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.shade300,
          ),
          // Theme Setting
          _buildSettingTile(
            icon: _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            title: t('theme'),
            subtitle: _isDarkMode ? t('darkMode') : t('lightMode'),
            onTap: _toggleTheme,
            textPrimaryColor: textPrimaryColor,
            textSecondaryColor: textSecondaryColor,
            accentColor: accentColor,
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) => _toggleTheme(),
              activeColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color accentColor,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accentColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: textSecondaryColor,
          fontSize: 14,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: textSecondaryColor,
          ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
    // Theme-aware colors
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white70
        : const Color(0xFF546E7A);

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
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverHomePage(),
                        ),
                      );
                    }
                  },
                ),
              ),
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
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: _loadProfile,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          t('error'),
                          style: TextStyle(color: textPrimaryColor, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? t('error'),
                          style: TextStyle(color: textSecondaryColor, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(t('retry')),
                        ),
                      ],
                    ),
                  )
                : _profileData == null
                    ? Center(
                        child: Text(
                          t('error'),
                          style: TextStyle(color: textSecondaryColor),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          if (_profileData == null) {
                            return Center(
                              child: Text(
                                t('error'),
                                style: TextStyle(color: textSecondaryColor),
                              ),
                            );
                          }
                          
                          final driver = _profileData?['driver'] as Map<String, dynamic>?;
                          final user = driver?['user'] as Map<String, dynamic>?;
                          final line = _profileData?['line'] as Map<String, dynamic>?;
                          final vehicles = _profileData?['vehicles'] as List<dynamic>?;
                          final hasVehicle = _profileData?['hasVehicle'] == true;
                          final hasLine = _profileData?['hasLine'] == true;
                          
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Driver Information
                                _buildSection(
                                  t('driverInfo'),
                                  Column(
                                    children: [
                                      _buildInfoRow(
                                    Icons.person,
                                    t('name'),
                                    user?['fullname']?.toString(),
                                  ),
                                  _buildInfoRow(
                                    Icons.email,
                                    t('email'),
                                    user?['email']?.toString(),
                                  ),
                                  if (user?['phone'] != null)
                                    _buildInfoRow(
                                      Icons.phone,
                                      t('phone'),
                                      user?['phone']?.toString(),
                                    ),
                                  if (driver?['licenseid'] != null)
                                    _buildInfoRow(
                                      Icons.card_membership,
                                      t('licenseId'),
                                      driver?['licenseid']?.toString(),
                                    ),
                                  _buildInfoRow(
                                    Icons.assessment,
                                    t('status'),
                                    _getStatusText(driver?['status']?.toString()),
                                    valueColor: _getStatusColor(driver?['status']?.toString()),
                                  ),
                                  if (driver?['rating'] != null)
                                    _buildInfoRow(
                                      Icons.star,
                                      t('rating'),
                                      '${driver?['rating']}/5.0',
                                      valueColor: Colors.orange,
                                    ),
                                ],
                              ),
                            ),

                                // Line Information
                                _buildSection(
                                  t('lineInfo'),
                                  Column(
                                    children: [
                                      if (hasLine && line != null) ...[
                                    _buildInfoRow(
                                      Icons.alt_route,
                                      t('line'),
                                      _isArabic
                                          ? (line['name_ar']?.toString() ?? 
                                             line['linename']?.toString() ?? 
                                             line['name_en']?.toString() ?? 
                                             t('unknown'))
                                          : (line['name_en']?.toString() ?? 
                                             line['linename']?.toString() ?? 
                                             line['name_ar']?.toString() ?? 
                                             t('unknown')),
                                    ),
                                    _buildInfoRow(
                                      Icons.attach_money,
                                      '${t('price')} (${t('base')})',
                                      '${line['baseprice'] ?? 0} ₪',
                                    ),
                                    if (line['distance'] != null)
                                      _buildInfoRow(
                                        Icons.straighten,
                                        '${t('distance')} (km)',
                                        '${line['distance']}',
                                      ),
                                    if (line['estduration'] != null)
                                      _buildInfoRow(
                                        Icons.access_time,
                                        '${t('duration')} (min)',
                                        '${line['estduration']}',
                                      ),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          t('noLine'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                                // Vehicle Information
                                _buildSection(
                                  t('vehicleInfo'),
                                  Column(
                                    children: [
                                      if (hasVehicle && vehicles != null && vehicles.isNotEmpty) ...[
                                    ...vehicles.map((vehicle) {
                                      final v = vehicle as Map<String, dynamic>;
                                      return Column(
                                        children: [
                                          _buildInfoRow(
                                            Icons.directions_car,
                                            t('plateNumber'),
                                            v['plateno']?.toString() ?? t('unknown'),
                                          ),
                                          _buildInfoRow(
                                            Icons.event_seat,
                                            t('seatLayout'),
                                            v['seatlayout']?.toString() ?? t('unknown'),
                                          ),
                                          _buildInfoRow(
                                            Icons.confirmation_number,
                                            t('seatNumber'),
                                            v['seatnum']?.toString() ?? t('unknown'),
                                          ),
                                          if (vehicles.length > 1 && vehicles.indexOf(vehicle) < vehicles.length - 1)
                                            const Divider(color: Colors.white24, height: 32),
                                        ],
                                      );
                                    }),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          t('noVehicle'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Settings Section
                                _buildSettingsSection(),
                              ],
                            ),
                          );
                        },
                      ),
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 4, // Profile is index 4
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            DriverBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }
}

