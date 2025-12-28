import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? valueColor, bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white.withOpacity(0.9)
        : const Color(0xFF546E7A);
    final accentColor = Colors.orange;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 12.0),
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : (isMediumScreen ? 12.0 : 14.0)),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
            ),
            child: Icon(icon, color: accentColor, size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0)),
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
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                Text(
                  value ?? t('unknown'),
                  style: TextStyle(
                    color: valueColor ?? textPrimaryColor,
                    fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
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

  Widget _buildSection(String title, Widget child, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final accentColor = Colors.orange;
    
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
      margin: EdgeInsets.only(bottom: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
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

  Widget _buildSettingsSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white.withOpacity(0.9)
        : const Color(0xFF546E7A);
    final accentColor = Colors.orange;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
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
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                ),
                child: Icon(
                  Icons.settings,
                  color: accentColor,
                  size: isSmallScreen ? 18.0 : 20.0,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('settings'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          _buildSettingTile(
            icon: Icons.language,
            title: t('language'),
            subtitle: _isArabic ? t('arabic') : t('english'),
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
            onTap: () {
              final screenWidth = MediaQuery.of(context).size.width;
              final isSmallScreenDialog = screenWidth < 360;
              final isMediumScreenDialog = screenWidth >= 360 && screenWidth < 400;
              
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: cardColor,
                  titlePadding: EdgeInsets.all(isSmallScreenDialog ? 16.0 : (isMediumScreenDialog ? 18.0 : 20.0)),
                  contentPadding: EdgeInsets.all(isSmallScreenDialog ? 12.0 : 16.0),
                  title: Text(
                    t('language'),
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreenDialog ? 18.0 : (isMediumScreenDialog ? 20.0 : 22.0),
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreenDialog ? 8.0 : 16.0,
                          vertical: isSmallScreenDialog ? 4.0 : 8.0,
                        ),
                        title: Text(
                          t('arabic'),
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: isSmallScreenDialog ? 14.0 : 16.0,
                          ),
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreenDialog ? 8.0 : 16.0,
                          vertical: isSmallScreenDialog ? 4.0 : 8.0,
                        ),
                        title: Text(
                          t('english'),
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: isSmallScreenDialog ? 14.0 : 16.0,
                          ),
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
          _buildSettingTile(
            icon: _isDarkMode ? Icons.light_mode : Icons.dark_mode,
            title: t('theme'),
            subtitle: _isDarkMode ? t('darkMode') : t('lightMode'),
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
        ),
        child: Icon(icon, color: accentColor, size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0)),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textPrimaryColor,
          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: textSecondaryColor,
          fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right,
            color: textSecondaryColor,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
      onTap: onTap,
    );
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
    final double basePadding = isWeb 
        ? (isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1200.0 : double.infinity;
    
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white.withOpacity(0.9)
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
                margin: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: isSmallScreen ? 18.0 : 20.0),
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
              actions: [
                Container(
                  margin: EdgeInsets.only(right: isSmallScreen ? 4.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded, size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
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
                          
                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxContentWidth),
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(basePadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                _buildSection(
                                  t('driverInfo'),
                                  Column(
                                    children: [
                                      _buildInfoRow(
                                    Icons.person,
                                    t('name'),
                                    user?['fullname']?.toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  _buildInfoRow(
                                    Icons.email,
                                    t('email'),
                                    user?['email']?.toString(),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  if (user?['phone'] != null)
                                    _buildInfoRow(
                                      Icons.phone,
                                      t('phone'),
                                      user?['phone']?.toString(),
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                  if (driver?['licenseid'] != null)
                                    _buildInfoRow(
                                      Icons.card_membership,
                                      t('licenseId'),
                                      driver?['licenseid']?.toString(),
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                  _buildInfoRow(
                                    Icons.assessment,
                                    t('status'),
                                    _getStatusText(driver?['status']?.toString()),
                                    valueColor: _getStatusColor(driver?['status']?.toString()),
                                    isSmallScreen: isSmallScreen,
                                    isMediumScreen: isMediumScreen,
                                  ),
                                  if (driver?['rating'] != null)
                                    _buildInfoRow(
                                      Icons.star,
                                      t('rating'),
                                      '${driver?['rating']}/5.0',
                                      valueColor: Colors.orange,
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                ],
                              ),
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                            ),

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
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                    _buildInfoRow(
                                      Icons.attach_money,
                                      '${t('price')} (${t('base')})',
                                      '${line['baseprice'] ?? 0} ₪',
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                    ),
                                    if (line['distance'] != null)
                                      _buildInfoRow(
                                        Icons.straighten,
                                        '${t('distance')} (km)',
                                        '${line['distance']}',
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                    if (line['estduration'] != null)
                                      _buildInfoRow(
                                        Icons.access_time,
                                        '${t('duration')} (min)',
                                        '${line['estduration']}',
                                        isSmallScreen: isSmallScreen,
                                        isMediumScreen: isMediumScreen,
                                      ),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                                        child: Text(
                                          t('noLine'),
                                          style: TextStyle(
                                            color: _isDarkMode ? Colors.white : Colors.grey.shade600,
                                            fontSize: isSmallScreen ? 13.0 : 14.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                            ),

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
                                            isSmallScreen: isSmallScreen,
                                            isMediumScreen: isMediumScreen,
                                          ),
                                          _buildInfoRow(
                                            Icons.event_seat,
                                            t('seatLayout'),
                                            v['seatlayout']?.toString() ?? t('unknown'),
                                            isSmallScreen: isSmallScreen,
                                            isMediumScreen: isMediumScreen,
                                          ),
                                          _buildInfoRow(
                                            Icons.confirmation_number,
                                            t('seatNumber'),
                                            v['seatnum']?.toString() ?? t('unknown'),
                                            isSmallScreen: isSmallScreen,
                                            isMediumScreen: isMediumScreen,
                                          ),
                                          if (vehicles.length > 1 && vehicles.indexOf(vehicle) < vehicles.length - 1)
                                            SizedBox(height: isSmallScreen ? 24.0 : 32.0),
                                        ],
                                      );
                                    }),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                                        child: Text(
                                          t('noVehicle'),
                                          style: TextStyle(
                                            color: _isDarkMode ? Colors.white : Colors.grey.shade600,
                                            fontSize: isSmallScreen ? 13.0 : 14.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                      ],
                                    ],
                                  ),
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                                SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),

                                _buildSettingsSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                                  ],
                                ),
                              ),
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

