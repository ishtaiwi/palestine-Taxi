import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../pages/passenger/passenger_home.dart';
import 'driver_additional_info_page.dart';

class RegisterFormData {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;

  const RegisterFormData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
  });

  String get fullName => '$firstName $lastName'.trim();
}

class SelectRoleScreen extends StatefulWidget {
  final RegisterFormData formData;
  final bool startArabic;
  const SelectRoleScreen({
    super.key,
    required this.formData,
    this.startArabic = true,
  });

  @override
  State<SelectRoleScreen> createState() => _SelectRoleScreenState();
}

class _SelectRoleScreenState extends State<SelectRoleScreen> {
  bool _isArabic = true;
  bool _isLoading = false;
  String? _selectedRole;

  List<_RoleOption> get _roles => [
        _RoleOption(
          role: 'PASSENGER',
          titleAr: 'مسافر',
          titleEn: 'Passenger',
          descriptionAr: 'احجز رحلاتك بسهولة بين المدينة وقراها',
          descriptionEn: 'Book rides within the city and nearby villages',
          icon: Icons.person_pin_circle,
          accentColor: Colors.orange,
        ),
        _RoleOption(
          role: 'DRIVER',
          titleAr: 'سائق',
          titleEn: 'Driver',
          descriptionAr: 'تسلم الرحلات، تابع الحجوزات، وشاهد أرباحك',
          descriptionEn: 'Accept trips, manage reservations, and track earnings',
          icon: Icons.directions_bus_filled,
          accentColor: Colors.blue,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _isArabic = widget.startArabic;
    _selectedRole = 'PASSENGER';
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
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
    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _isArabic ? 'اختر نوع الحساب' : 'Choose Account Type',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: () => _switchLanguage(!_isArabic),
              icon: Icon(_isArabic ? Icons.language : Icons.translate),
              color: Colors.white,
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1528), Color(0xFF1A2F4A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic
                        ? 'اختر الدور الأنسب لك لإكمال إنشاء الحساب'
                        : 'Select the role that matches how you will use the app.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._roles.map(
                    (role) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildRoleCard(role),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF57C00), Color(0xFFE65100)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF57C00).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleCompleteRegistration,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_isArabic ? 'إكمال التسجيل' : 'Complete Registration'),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle_outline, size: 20),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(
                      _isArabic ? 'الرجوع لتعديل البيانات' : 'Back to edit details',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(_RoleOption option) {
    final isSelected = _selectedRole == option.role;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedRole = option.role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? option.accentColor.withOpacity(0.2)
              : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: isSelected ? option.accentColor : Colors.white38,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: option.accentColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: option.accentColor.withOpacity(0.25),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: option.accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                option.icon,
                color: option.accentColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic ? option.titleAr : option.titleEn,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isArabic ? option.descriptionAr : option.descriptionEn,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: option.accentColor,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCompleteRegistration() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic ? 'يرجى اختيار الدور' : 'Please select a role',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedRole == 'PASSENGER') {
      setState(() => _isLoading = true);

      try {
        print('[SelectRolePage] Starting passenger registration...');
        final result = await ApiService.register(
          fullname: widget.formData.fullName,
          email: widget.formData.email,
          phone: widget.formData.phone,
          password: widget.formData.password,
          role: 'PASSENGER',
        );

        print('[SelectRolePage] Registration result: $result');
        
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Check for success - be more flexible in checking
        final hasToken = result['token'] != null;
        final hasUser = result['user'] != null;
        final explicitSuccess = result['success'] == true || result['success'] == 'true';
        final success = explicitSuccess || (hasToken && hasUser);
        
        print('[SelectRolePage] Success check:');
        print('  - explicitSuccess: $explicitSuccess');
        print('  - hasToken: $hasToken');
        print('  - hasUser: $hasUser');
        print('  - final success: $success');
        
        if (success) {
          final message = result['message'] ?? (_isArabic ? 'تم إنشاء الحساب بنجاح' : 'Registration successful');
          
          print('[SelectRolePage] Registration successful, navigating to PassengerHomePage...');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            
            // Navigate immediately without delay
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                print('[SelectRolePage] Navigating to PassengerHomePage...');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const PassengerHomePage()),
                  (route) => false,
                );
              }
            });
          }
        } else {
          final errorMessage = result['message'] ?? 
                             result['error'] ?? 
                             (_isArabic ? 'فشل إنشاء الحساب' : 'Registration failed');
          print('[SelectRolePage] Registration failed: $errorMessage');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e, stackTrace) {
        print('[SelectRolePage] Exception during registration:');
        print('  - Error: $e');
        print('  - Stack trace: $stackTrace');
        
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        String errorMessage = _isArabic ? 'حدث خطأ أثناء التسجيل' : 'An error occurred during registration';
        if (e.toString().contains('TimeoutException')) {
          errorMessage = _isArabic ? 'انتهت مهلة الاتصال' : 'Connection timeout';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = _isArabic ? 'لا يمكن الاتصال بالخادم' : 'Cannot connect to server';
        } else {
          errorMessage = _isArabic ? 'خطأ: ${e.toString()}' : 'Error: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } else if (_selectedRole == 'DRIVER') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverAdditionalInfoScreen(
            formData: widget.formData,
            startArabic: _isArabic,
          ),
        ),
      );
    }
  }
}

class _RoleOption {
  final String role;
  final String titleAr;
  final String titleEn;
  final String descriptionAr;
  final String descriptionEn;
  final IconData icon;
  final Color accentColor;

  const _RoleOption({
    required this.role,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.icon,
    required this.accentColor,
  });
}

