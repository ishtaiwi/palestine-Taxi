import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../config/app_config.dart';
import '../../screens/auth/login_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_home.dart';

class PassengerProfilePage extends StatefulWidget {
  const PassengerProfilePage({super.key});

  @override
  State<PassengerProfilePage> createState() => _PassengerProfilePageState();
}

class _PassengerProfilePageState extends State<PassengerProfilePage> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false;
  String? _profileImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الملف الشخصي',
      'accountInfo': 'معلومات الحساب',
      'settings': 'الإعدادات',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'phone': 'رقم الهاتف',
      'role': 'الدور',
      'passenger': 'المسافر',
      'language': 'اللغة',
      'theme': 'المظهر',
      'lightMode': 'الوضع الفاتح',
      'darkMode': 'الوضع الداكن',
      'arabic': 'العربية',
      'english': 'English',
      'logout': 'تسجيل الخروج',
      'logoutConfirm': 'هل أنت متأكد من تسجيل الخروج؟',
      'cancel': 'إلغاء',
      'confirm': 'تأكيد',
      'editProfile': 'تعديل الملف الشخصي',
      'changePhoto': 'تغيير الصورة',
      'profileUpdated': 'تم تحديث صورة الملف الشخصي',
      'failedToUpload': 'فشل تحميل الصورة',
    },
    'en': {
      'title': 'Profile',
      'accountInfo': 'Account Information',
      'settings': 'Settings',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'role': 'Role',
      'passenger': 'Passenger',
      'language': 'Language',
      'theme': 'Theme',
      'lightMode': 'Light Mode',
      'darkMode': 'Dark Mode',
      'arabic': 'العربية',
      'english': 'English',
      'logout': 'Logout',
      'logoutConfirm': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'editProfile': 'Edit Profile',
      'changePhoto': 'Change Photo',
      'profileUpdated': 'Profile image updated',
      'failedToUpload': 'Failed to upload image',
    },
  };

  String t(String key) {
    return _texts[_isArabic ? 'ar' : 'en']![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserData(),
      _loadPreferences(),
      _loadProfileImage(),
    ]);
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await ApiService.getUserData();
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
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
                content: Text(t('profileUpdated')),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  result['message']?.toString() ?? t('failedToUpload'),
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
            content: Text(t('failedToUpload')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
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

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        title: Text(
          t('logout'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          t('logoutConfirm'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t('cancel'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(t('confirm')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.clearAuthData();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0F1419)
        : const Color(0xFFF5F7FA);
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? const Color(0xFFE8EAF6)
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
                          builder: (_) => const PassengerHomePage(),
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
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: accentColor.withOpacity(0.2),
                                child: _userData?['avatar_url'] != null &&
                                        _userData!['avatar_url']
                                            .toString()
                                            .isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          AppConfig.apiBaseUrl
                                                  .replaceFirst('/api', '') +
                                              _userData!['avatar_url']
                                                  .toString(),
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error,
                                              stackTrace) {
                                            return Icon(
                                              Icons.person,
                                              size: 60,
                                              color: accentColor,
                                            );
                                          },
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        size: 60,
                                        color: accentColor,
                                      ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: cardColor,
                                      width: 3,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _pickProfileImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userData?['fullname'] ?? _userData?['name'] ?? '',
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData?['email'] ?? '',
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildSection(
                      title: t('accountInfo'),
                      cardColor: cardColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      accentColor: accentColor,
                      isDarkMode: _isDarkMode,
                      children: [
                        _buildInfoRow(
                          Icons.person_outline,
                          t('name'),
                          _userData?['fullname'] ?? _userData?['name'] ?? '',
                          accentColor,
                          textPrimaryColor,
                          textSecondaryColor,
                          cardColor,
                          _isDarkMode,
                        ),
                        const SizedBox(height: 14),
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
                        if (_userData?['phone'] != null) ...[
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
                        ],
                        const SizedBox(height: 14),
                        _buildInfoRow(
                          Icons.badge_outlined,
                          t('role'),
                          t('passenger'),
                          accentColor,
                          textPrimaryColor,
                          textSecondaryColor,
                          cardColor,
                          _isDarkMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildSection(
                      title: t('settings'),
                      cardColor: cardColor,
                      textPrimaryColor: textPrimaryColor,
                      textSecondaryColor: textSecondaryColor,
                      accentColor: accentColor,
                      isDarkMode: _isDarkMode,
                      children: [
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
                        const Divider(height: 1),
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
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout),
                        label: Text(
                          t('logout'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 4, // Profile is index 4
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            PassengerBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Color cardColor,
    required Color textPrimaryColor,
    required Color textSecondaryColor,
    required Color accentColor,
    required bool isDarkMode,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
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
                  title == _texts[_isArabic ? 'ar' : 'en']!['accountInfo']
                      ? Icons.person
                      : Icons.settings,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
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
                  value,
                  style: TextStyle(
                    color: textPrimaryColor,
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
}

