import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';
import 'verify_code_page.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isArabic = true;

  @override
  void initState() {
    super.initState();
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

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'نسيت كلمة المرور؟',
      'subtitle': 'أدخل بريدك الإلكتروني وسنرسل لك رمز تحقق لإعادة تعيين كلمة المرور',
      'email': 'البريد الإلكتروني',
      'enterEmail': 'أدخل بريدك الإلكتروني',
      'sendCode': 'إرسال رمز التحقق',
      'backToLogin': 'العودة لتسجيل الدخول',
    },
    'en': {
      'title': 'Forgot Password?',
      'subtitle': 'Enter your email address and we\'ll send you a verification code to reset your password',
      'email': 'Email Address',
      'enterEmail': 'Enter your email address',
      'sendCode': 'Send Verification Code',
      'backToLogin': 'Back to Login',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.requestPasswordReset(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final success = result['success'] == true;
      final message = result['message'] ??
          (success
              ? (_isArabic
                  ? 'تم إرسال رمز التحقق إلى بريدك الإلكتروني'
                  : 'Verification code sent to your email')
              : (_isArabic
                  ? 'فشل إرسال رمز التحقق'
                  : 'Failed to send verification code'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );

      if (success) {
        String? debugCode = result['debugCode'];
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodeScreen(
              email: _emailController.text.trim(),
              debugCode: debugCode,
            ),
          ),
        );
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && screenWidth > 800;
    
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
              colors: [Color(0xFF050A18), Color(0xFF101932)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 24,
                  vertical: isDesktop ? 16 : 24,
                ),
                child: Container(
                  width: isDesktop ? 480 : double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 480 : double.infinity,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: isDesktop ? 20 : 40),
                      Icon(
                        Icons.lock_outline,
                        size: isDesktop ? 80 : 100,
                        color: Colors.orange.shade400,
                      ),
                      SizedBox(height: isDesktop ? 24 : 32),
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 28 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
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
                            t('title'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t('subtitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                          SizedBox(height: isDesktop ? 20 : 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 16 : null,
                            ),
                            decoration: _inputDecoration(
                              t('email'),
                              t('enterEmail'),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Colors.white70,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return t('enterEmail');
                              }
                              if (!value.contains('@')) {
                                return _isArabic
                                    ? 'صيغة البريد الإلكتروني غير صحيحة'
                                    : 'Invalid email format';
                              }
                              return null;
                            },
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                          ),
                          SizedBox(height: isDesktop ? 24 : 28),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF57C00), Color(0xFFE65100)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _handleSendCode,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.send_outlined),
                                label: Text(
                                  t('sendCode'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isDesktop ? 16 : 20),
                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                t('backToLogin'),
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

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    Widget? prefixIcon,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white24),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFF57C00)),
      ),
      prefixIcon: prefixIcon,
    );
  }
}

