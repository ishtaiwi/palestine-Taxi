import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import 'reset_password_page.dart';

class VerifyCodeScreen extends StatefulWidget {
  final String email;
  final String? debugCode;

  const VerifyCodeScreen({
    super.key,
    required this.email,
    this.debugCode,
  });

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isArabic = true;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    // الحقول تبقى فارغة - المستخدم يدخل الرمز يدوياً
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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'أدخل رمز التحقق',
      'subtitle': 'لقد أرسلنا رمز تحقق مكون من 6 أرقام إلى بريدك الإلكتروني',
      'verify': 'التحقق من الرمز',
      'resend': 'إعادة إرسال الرمز',
      'changeEmail': 'تغيير البريد الإلكتروني',
      'backToLogin': 'العودة لتسجيل الدخول',
    },
    'en': {
      'title': 'Enter Verification Code',
      'subtitle': 'We\'ve sent a 6-digit code to your email',
      'verify': 'Verify Code',
      'resend': 'Resend Code',
      'changeEmail': 'Change Email',
      'backToLogin': 'Back to Login',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  String get _code {
    return _controllers.map((c) => c.text).join();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'يرجى إدخال رمز التحقق كاملاً (6 أرقام)'
                : 'Please enter the full 6-digit code',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyResetCode(
        email: widget.email,
        code: _code,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final success = result['success'] == true;
      final message = result['message'] ??
          (success
              ? (_isArabic
                  ? 'تم التحقق من الرمز بنجاح'
                  : 'Code verified successfully')
              : (_isArabic
                  ? 'رمز التحقق غير صحيح أو منتهي الصلاحية'
                  : 'Invalid or expired verification code'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: Duration(seconds: success ? 2 : 4),
        ),
      );

      if (success) {
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: widget.email,
              code: _code,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.lock_outline,
                    size: 100,
                    color: Colors.orange.shade400,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        const SizedBox(height: 8),
                        Text(
                          widget.email,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.orange.shade300,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 32),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 45,
                                height: 60,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  textAlign: TextAlign.center,
                                  textDirection: TextDirection.ltr,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    signed: false,
                                    decimal: false,
                                  ),
                                  maxLength: 1,
                                  textInputAction: index < 5 
                                      ? TextInputAction.next 
                                      : TextInputAction.done,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                  ],
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: '',
                                    hintStyle: const TextStyle(fontSize: 0),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          const BorderSide(color: Colors.white24),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFF57C00),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.all(0),
                                  ),
                                  onChanged: (value) => _onChanged(index, value),
                                  onTap: () {
                                    if (_controllers[index].text.isEmpty) {
                                      _controllers[index].selection =
                                          TextSelection.collapsed(offset: 0);
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: FilledButton.icon(
                              onPressed: _isLoading ? null : _handleVerify,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                t('verify'),
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
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                t('changeEmail'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (route) => route.isFirst),
                              child: Text(
                                t('backToLogin'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
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
    );
  }
}

