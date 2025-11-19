import 'package:flutter/material.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../../services/api_service.dart';
import '../../pages/passenger/passenger_home.dart';
import '../../pages/driver/driver_home.dart';
import '../../pages/admin/admin_dashboard.dart';

class TaxiPalestineApp extends StatelessWidget {
  const TaxiPalestineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pal Taxi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFf57c00),
          primary: const Color(0xFFf57c00),
          secondary: const Color(0xFF0B132B),
        ),
        scaffoldBackgroundColor: const Color(0xFF060A1A),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/passenger': (context) => const PassengerHomePage(),
        '/driver': (context) => const DriverHomePage(),
        '/admin': (context) => const AdminDashboardPage(),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isArabic = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'appTitle': 'Pal Taxi',
      'welcome': 'مرحباً بك من جديد',
      'login': 'تسجيل الدخول',
      'email': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'forgot': 'نسيت كلمة المرور؟',
      'enterEmail': 'أدخل بريدك الإلكتروني',
      'enterPassword': 'أدخل كلمة المرور',
      'ctaLogin': 'دخول',
      'ctaRegister': 'إنشاء حساب مسافر',
      'trust': 'موثوق من النقابات الفلسطينية',
    },
    'en': {
      'appTitle': 'Pal Taxi',
      'welcome': 'Welcome back',
      'login': 'Sign In',
      'email': 'Email address',
      'password': 'Password',
      'forgot': 'Forgot password?',
      'enterEmail': 'Enter your email',
      'enterPassword': 'Enter your password',
      'ctaLogin': 'Sign in',
      'ctaRegister': 'Create passenger account',
      'trust': 'Trusted by Palestinian unions',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  Future<void> _switchLanguage(bool arabic) async {
    if (_isArabic != arabic) {
      await ApiService.saveLanguagePreference(arabic);
      setState(() {
        _isArabic = arabic;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF040814), Color(0xFF101931)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -120,
              left: -60,
              child: _GlowCircle(
                diameter: 260,
                colors: [
                  Colors.orange.withOpacity(0.35),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              right: -120,
              child: _GlowCircle(
                diameter: 280,
                colors: [
                  const Color(0xFF00B4D8).withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: _isArabic
                            ? [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _LanguageToggle(
                                    isArabic: _isArabic,
                                    onArabic: () => _switchLanguage(true),
                                    onEnglish: () => _switchLanguage(false),
                                  ),
                                ),
                                const Spacer(),
                                const _PalestineFlag(),
                              ]
                            : [
                                const _PalestineFlag(),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _LanguageToggle(
                                    isArabic: _isArabic,
                                    onArabic: () => _switchLanguage(true),
                                    onEnglish: () => _switchLanguage(false),
                                  ),
                                ),
                              ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -8),
                          child: Image.asset(
                            'images/logo-PM-removebg-preview.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Transform.translate(
                      offset: const Offset(0, -20),
                      child: _FormCard(
                        formKey: _formKey,
                        isLoading: _isLoading,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        togglePassword: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        t: t,
                        onSubmit: _handleLogin,
                        onForgotPassword: _handleForgotPassword,
                        onRegister: _openRegisterScreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRegisterScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(startArabic: _isArabic),
      ),
    );
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      _emailController.text = result;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'تم إنشاء الحساب بنجاح، يرجى تسجيل الدخول'
                : 'Account created, please sign in',
          ),
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // Login نجح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic
                  ? (result['message'] ?? 'تم تسجيل الدخول بنجاح')
                  : (result['message'] ?? 'Login successful'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate حسب Role
        final user = result['user'] as Map<String, dynamic>?;
        final role = user?['role']?.toString().toUpperCase();

        // إعادة تعيين الحقول
        _emailController.clear();
        _passwordController.clear();

        // Navigation حسب الدور
        if (!mounted) return;

        if (role == 'PASSENGER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PassengerHomePage()),
          );
        } else if (role == 'DRIVER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverHomePage()),
          );
        } else if (role == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        } else {
          // Default fallback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isArabic
                    ? 'الدور غير معروف'
                    : 'Unknown role',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        // Login فشل
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic
                  ? (result['message'] ?? 'فشل تسجيل الدخول')
                  : (result['message'] ?? 'Login failed'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
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
                ? 'حدث خطأ غير متوقع: ${e.toString()}'
                : 'An unexpected error occurred: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _LanguageToggle extends StatelessWidget {
  final bool isArabic;
  final VoidCallback onArabic;
  final VoidCallback onEnglish;

  const _LanguageToggle({
    required this.isArabic,
    required this.onArabic,
    required this.onEnglish,
  });

  @override
  Widget build(BuildContext context) {
    final currentLabel = isArabic ? 'AR' : 'EN';
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'ar') {
          onArabic();
        } else {
          onEnglish();
        }
      },
      offset: const Offset(0, 40),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              Icon(Icons.public, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              const Text('English'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'ar',
          child: Row(
            children: [
              Icon(Icons.translate, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              const Text('العربية'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 18, color: Colors.grey.shade800),
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback togglePassword;
  final Future<void> Function() onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;
  final String Function(String key) t;

  const _FormCard({
    required this.formKey,
    required this.isLoading,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.togglePassword,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onRegister,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('welcome'),
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('login'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: t('email'),
                  hintText: t('enterEmail'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('enterEmail');
                  }
                  if (!value.contains('@')) {
                    return 'Invalid email format';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: t('password'),
                  hintText: t('enterPassword'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: togglePassword,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('enterPassword');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  child: Text(t('forgot')),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(t('ctaLogin')),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRegister,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(t('ctaRegister')),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t('trust'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _GlowCircle({required this.diameter, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _PalestineFlag extends StatefulWidget {
  const _PalestineFlag();

  @override
  State<_PalestineFlag> createState() => _PalestineFlagState();
}

class _PalestineFlagState extends State<_PalestineFlag>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(
      begin: -3.0,
      end: 3.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Container(
            width: 56,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(_glowAnimation.value * 0.5),
                  blurRadius: 8 + (_glowAnimation.value * 4),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CustomPaint(
              painter: _PalestineFlagPainter(
                glowIntensity: _glowAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PalestineFlagPainter extends CustomPainter {
  final double glowIntensity;

  const _PalestineFlagPainter({this.glowIntensity = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(glowIntensity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, -2, size.width + 4, size.height + 4),
        const Radius.circular(4),
      ),
      glowPaint,
    );

    final stripeHeight = size.height / 3;
    final stripeColors = [
      const Color(0xFF000000),
      const Color(0xFFFFFFFF),
      const Color(0xFF007A3D),
    ];

    for (var i = 0; i < stripeColors.length; i++) {
      final paint = Paint()..color = stripeColors[i];
      canvas.drawRect(
        Rect.fromLTWH(0, stripeHeight * i, size.width, stripeHeight),
        paint,
      );
    }

    final trianglePaint = Paint()..color = const Color(0xFFCE1126);
    final trianglePath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.45, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(trianglePath, trianglePaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.2 + (glowIntensity * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PalestineFlagPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity;
}

