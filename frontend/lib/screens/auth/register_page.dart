import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'select_role_page.dart';

class RegisterScreen extends StatefulWidget {
  final bool startArabic;
  const RegisterScreen({super.key, this.startArabic = true});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isArabic = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إنشاء حساب جديد',
      'subtitle': 'سجّل بياناتك للانضمام للخدمة',
      'firstName': 'الاسم الأول',
      'lastName': 'اسم العائلة',
      'phone': 'رقم الهاتف',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'confirmPassword': 'تأكيد كلمة المرور',
      'next': 'التالي',
      'alreadyHaveAccount': 'لديك حساب بالفعل؟',
      'login': 'تسجيل الدخول',
      'enterFirstName': 'أدخل اسمك الأول',
      'enterLastName': 'أدخل اسم العائلة',
      'enterPhone': 'أدخل رقم الهاتف',
      'enterEmail': 'أدخل بريدك الإلكتروني',
      'enterPassword': 'أدخل كلمة المرور',
      'confirmPasswordHint': 'أعد إدخال كلمة المرور',
    },
    'en': {
      'title': 'Create New Account',
      'subtitle': 'Fill the form to join the service',
      'firstName': 'First name',
      'lastName': 'Last name',
      'phone': 'Phone number',
      'email': 'Email address',
      'password': 'Password',
      'confirmPassword': 'Confirm password',
      'next': 'Next',
      'alreadyHaveAccount': 'Already have an account?',
      'login': 'Sign in',
      'enterFirstName': 'Enter your first name',
      'enterLastName': 'Enter your last name',
      'enterPhone': 'Enter your phone number',
      'enterEmail': 'Enter your email',
      'enterPassword': 'Enter your password',
      'confirmPasswordHint': 'Re-enter your password',
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
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

    final formData = RegisterFormData(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectRoleScreen(
          formData: formData,
          startArabic: _isArabic,
        ),
      ),
    );
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
                        controller: _firstNameController,
                        label: t('firstName'),
                        hint: t('enterFirstName'),
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterFirstName');
                          }
                          if (value.trim().length < 2) {
                            return _isArabic
                                ? 'الاسم يجب أن يكون حرفين على الأقل'
                                : 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _lastNameController,
                        label: t('lastName'),
                        hint: t('enterLastName'),
                        keyboardType: TextInputType.name,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterLastName');
                          }
                          if (value.trim().length < 2) {
                            return _isArabic
                                ? 'اسم العائلة يجب أن يكون حرفين على الأقل'
                                : 'Last name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: t('phone'),
                        hint: t('enterPhone'),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterPhone');
                          }
                          final phoneRegex = RegExp(r'^[0-9+\-\s()]+$');
                          if (!phoneRegex.hasMatch(value.trim())) {
                            return _isArabic
                                ? 'رقم الهاتف غير صحيح'
                                : 'Invalid phone number';
                          }
                          if (value.trim().length < 9) {
                            return _isArabic
                                ? 'رقم الهاتف قصير جداً'
                                : 'Phone number is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: t('email'),
                        hint: t('enterEmail'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterEmail');
                          }
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                          );
                          if (!emailRegex.hasMatch(value.trim())) {
                            return _isArabic
                                ? 'البريد الإلكتروني غير صحيح'
                                : 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _passwordController,
                        label: t('password'),
                        hint: t('enterPassword'),
                        obscure: _obscurePassword,
                        toggle: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        onChanged: () {
                          if (_confirmPasswordController.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return t('enterPassword');
                          }
                          if (value.length < 6) {
                            return _isArabic
                                ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                : 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: t('confirmPassword'),
                        hint: t('confirmPasswordHint'),
                        obscure: _obscureConfirmPassword,
                        toggle: () => setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        }),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return t('confirmPasswordHint');
                          }
                          final currentPassword = _passwordController.text;
                          if (value != currentPassword) {
                            return _isArabic
                                ? 'كلمة المرور غير متطابقة'
                                : 'Passwords do not match';
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
                            onPressed: _handleNext,
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(t('next')),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            '${t('alreadyHaveAccount')} ${t('login')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
    String? Function(String?)? validator,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(
        label,
        hint,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: toggle,
        ),
      ),
      validator: validator,
      onChanged: onChanged != null ? (_) => onChanged() : null,
      autovalidateMode: AutovalidateMode.onUserInteraction, // Show validation errors as user types
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    Widget? suffixIcon,
  }) {
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
      suffixIcon: suffixIcon,
    );
  }
}

