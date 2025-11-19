import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../pages/driver/driver_home.dart';
import 'select_role_page.dart';

class DriverAdditionalInfoScreen extends StatefulWidget {
  final RegisterFormData formData;
  final bool startArabic;
  const DriverAdditionalInfoScreen({
    super.key,
    required this.formData,
    this.startArabic = true,
  });

  @override
  State<DriverAdditionalInfoScreen> createState() =>
      _DriverAdditionalInfoScreenState();
}

class _DriverAdditionalInfoScreenState
    extends State<DriverAdditionalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _licenseIdController = TextEditingController();

  bool _isArabic = true;
  bool _isLoading = false;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'معلومات السائق',
      'subtitle': 'أدخل معلومات الرخصة للتسجيل كسائق',
      'licenseId': 'رقم الرخصة',
      'enterLicenseId': 'أدخل رقم الرخصة',
      'createAccount': 'إنشاء الحساب',
      'back': 'الرجوع',
    },
    'en': {
      'title': 'Driver Information',
      'subtitle': 'Enter license information to register as a driver',
      'licenseId': 'License ID',
      'enterLicenseId': 'Enter license ID',
      'createAccount': 'Create Account',
      'back': 'Back',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.startArabic;
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
  void dispose() {
    _licenseIdController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'يرجى تصحيح الأخطاء في النموذج'
                : 'Please fix the errors in the form',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        fullname: widget.formData.fullName,
        email: widget.formData.email,
        phone: widget.formData.phone,
        password: widget.formData.password,
        role: 'DRIVER',
        licenseId: _licenseIdController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final success = result['success'] == true || result['success'] == 'true';

      if (success) {
        final message = result['message'] ?? (_isArabic ? 'تم إنشاء الحساب بنجاح' : 'Registration successful');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DriverHomePage()),
                (route) => false,
              );
            }
          });
        }
      } else {
        final errorMessage = result['message'] ?? (_isArabic ? 'فشل إنشاء الحساب' : 'Registration failed');
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'حدث خطأ: ${e.toString()}'
                : 'Error occurred: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
            t('title'),
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
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('subtitle'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _licenseIdController,
                        label: t('licenseId'),
                        hint: t('enterLicenseId'),
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterLicenseId');
                          }
                          if (value.trim().length < 3) {
                            return _isArabic
                                ? 'رقم الرخصة قصير جداً'
                                : 'License ID is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
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
                            onPressed: _isLoading ? null : _handleRegister,
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
                                      Text(t('createAccount')),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.person_add, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          t('back'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(label, hint),
      validator: validator,
      enableInteractiveSelection: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
  ) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white38),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
      ),
    );
  }
}

