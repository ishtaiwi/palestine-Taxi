import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
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
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFf57c00),
          brightness: Brightness.light,
          primary: const Color(0xFFf57c00),
          secondary: const Color(0xFF0B132B),
        ),
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[50],
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFf57c00),
          brightness: Brightness.dark,
          primary: const Color(0xFFf57c00),
          secondary: const Color(0xFF0B132B),
          surface: const Color(0xFF101931),
        ),
        scaffoldBackgroundColor: const Color(0xFF060A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF060A1A),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      // Add localization support for DatePicker and other Material widgets
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ar', ''), // Arabic
      ],
      // Start with a small router that decides whether to go to login
      // or directly into the appropriate dashboard based on saved session.
      // Use onGenerateRoute to handle initial route for terminal mode
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle routes
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const _StartupRouter());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/passenger':
            return MaterialPageRoute(builder: (_) => const PassengerHomePage());
          case '/driver':
            return MaterialPageRoute(builder: (_) => const DriverHomePage());
          case '/admin':
            return MaterialPageRoute(
                builder: (_) => const AdminDashboardPage());
          default:
            return MaterialPageRoute(builder: (_) => const _StartupRouter());
        }
      },
    );
  }
}

/// Small wrapper that checks for a saved session and routes accordingly.
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  bool _isLoading = true;
  Widget? _targetPage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Try to get cached user first
    Map<String, dynamic>? user = await ApiService.getUserData();

    // If there is a token but no cached user, try to refresh from backend
    if (user == null) {
      final profileResult = await ApiService.getProfile();
      if (profileResult['success'] == true) {
        user = profileResult['user'] as Map<String, dynamic>?;
      }
    }

    if (!mounted) return;

    Widget target;
    if (user != null) {
      final role = user['role']?.toString().toUpperCase();
      if (role == 'PASSENGER') {
        target = const PassengerHomePage();
      } else if (role == 'DRIVER') {
        target = const DriverHomePage();
      } else if (role == 'ADMIN') {
        target = const AdminDashboardPage();
      } else {
        target = const LoginScreen();
      }
    } else {
      target = const LoginScreen();
    }

    setState(() {
      _targetPage = target;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _targetPage!;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive breakpoints for mobile
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final isLargeScreen = screenWidth >= 400 && screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = kIsWeb && screenWidth >= 900;

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
                diameter: isDesktop
                    ? 400
                    : (isTablet
                        ? 320
                        : (isLargeScreen ? 280 : (isMediumScreen ? 260 : 240))),
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
                diameter: isDesktop
                    ? 450
                    : (isTablet
                        ? 340
                        : (isLargeScreen ? 300 : (isMediumScreen ? 280 : 260))),
                colors: [
                  const Color(0xFF00B4D8).withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop
                        ? 24
                        : (isTablet
                            ? 32
                            : (isLargeScreen
                                ? 24
                                : (isMediumScreen ? 20 : 16))),
                    vertical: isDesktop
                        ? 16
                        : (isTablet
                            ? 24
                            : (isLargeScreen
                                ? 20
                                : (isMediumScreen ? 16 : 12))),
                  ),
                  child: Container(
                    width: isDesktop ? 480 : double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 480 : double.infinity,
                      minHeight: screenHeight * 0.8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                        SizedBox(
                          height: isDesktop
                              ? 16
                              : (isTablet
                                  ? 20
                                  : (isLargeScreen
                                      ? 18
                                      : (isMediumScreen ? 16 : 12))),
                        ),
                        Image.asset(
                          'images/logo-PM-removebg-preview.png',
                          width: isDesktop
                              ? 160
                              : (isTablet
                                  ? 150
                                  : (isLargeScreen
                                      ? 140
                                      : (isMediumScreen ? 130 : 120))),
                          height: isDesktop
                              ? 160
                              : (isTablet
                                  ? 150
                                  : (isLargeScreen
                                      ? 140
                                      : (isMediumScreen ? 130 : 120))),
                          fit: BoxFit.contain,
                        ),
                        SizedBox(
                          height: isDesktop
                              ? 12
                              : (isTablet
                                  ? 16
                                  : (isLargeScreen
                                      ? 14
                                      : (isMediumScreen ? 12 : 10))),
                        ),
                        _FormCard(
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
                          isDesktop: isDesktop,
                          isTablet: isTablet,
                          isLargeScreen: isLargeScreen,
                          isMediumScreen: isMediumScreen,
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ),
                  ),
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

        final userData = result['user'] as Map<String, dynamic>?;
        final userRole = userData?['role']?.toString().toUpperCase();

        _emailController.clear();
        _passwordController.clear();

        if (!mounted) return;

        if (userRole == 'PASSENGER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PassengerHomePage()),
          );
        } else if (userRole == 'DRIVER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DriverHomePage()),
          );
        } else if (userRole == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isArabic ? 'الدور غير معروف' : 'Unknown role',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    final currentLabel = isArabic ? 'AR' : 'EN';
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'ar') {
          onArabic();
        } else {
          onEnglish();
        }
      },
      offset: Offset(0, isSmallScreen ? 35.0 : 40.0),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
      ),
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
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10.0 : 12.0,
          vertical: isSmallScreen ? 5.0 : 6.0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F6),
          borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 24.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: isSmallScreen ? 8.0 : 10.0,
              offset: Offset(0, isSmallScreen ? 3.0 : 4.0),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: isSmallScreen ? 16.0 : 18.0,
              color: Colors.grey.shade800,
            ),
            SizedBox(width: isSmallScreen ? 5.0 : 6.0),
            Text(
              currentLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
                letterSpacing: 0.4,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
            SizedBox(width: isSmallScreen ? 3.0 : 4.0),
            Icon(
              Icons.keyboard_arrow_down,
              size: isSmallScreen ? 16.0 : 18.0,
              color: Colors.grey.shade600,
            ),
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
  final bool isDesktop;
  final bool isTablet;
  final bool isLargeScreen;
  final bool isMediumScreen;
  final bool isSmallScreen;

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
    this.isDesktop = false,
    this.isTablet = false,
    this.isLargeScreen = false,
    this.isMediumScreen = false,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate responsive padding
    final cardPadding = isDesktop
        ? 28.0
        : (isTablet
            ? 26.0
            : (isLargeScreen ? 24.0 : (isMediumScreen ? 20.0 : 18.0)));

    // Calculate responsive font sizes
    final welcomeFontSize = isDesktop
        ? 18.0
        : (isTablet
            ? 17.0
            : (isLargeScreen ? 16.0 : (isMediumScreen ? 15.0 : 14.0)));

    final titleFontSize = isDesktop
        ? 32.0
        : (isTablet
            ? 28.0
            : (isLargeScreen ? 26.0 : (isMediumScreen ? 24.0 : 22.0)));

    final bodyFontSize = isDesktop
        ? 16.0
        : (isTablet
            ? 15.0
            : (isLargeScreen ? 15.0 : (isMediumScreen ? 14.0 : 13.0)));

    final inputPadding = isDesktop
        ? 20.0
        : (isTablet
            ? 18.0
            : (isLargeScreen ? 16.0 : (isMediumScreen ? 16.0 : 14.0)));

    final verticalInputPadding = isDesktop
        ? 18.0
        : (isTablet
            ? 16.0
            : (isLargeScreen ? 16.0 : (isMediumScreen ? 15.0 : 14.0)));

    return Container(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(isDesktop ? 28 : (isTablet ? 26 : 24)),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isDesktop ? 30 : (isTablet ? 25 : 20),
            offset: Offset(0, isDesktop ? 18 : (isTablet ? 15 : 12)),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('welcome'),
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: welcomeFontSize,
                ),
              ),
              SizedBox(height: isSmallScreen ? 3.0 : 4.0),
              Text(
                t('login'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                      color: Colors.black87,
                    ),
              ),
              SizedBox(
                height: isDesktop
                    ? 24
                    : (isTablet
                        ? 22
                        : (isLargeScreen ? 20 : (isMediumScreen ? 18 : 16))),
              ),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(
                  fontSize: bodyFontSize,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: t('email'),
                  hintText: t('enterEmail'),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: inputPadding,
                    vertical: verticalInputPadding,
                  ),
                  labelStyle: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : bodyFontSize,
                    color: Colors.black54,
                  ),
                  hintStyle: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : bodyFontSize,
                    color: Colors.black45,
                  ),
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
              SizedBox(
                height: isDesktop
                    ? 18
                    : (isTablet
                        ? 17
                        : (isLargeScreen ? 16 : (isMediumScreen ? 15 : 14))),
              ),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                style: TextStyle(
                  fontSize: bodyFontSize,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: t('password'),
                  hintText: t('enterPassword'),
                  prefixIcon: Icon(
                    Icons.lock_outline,
                    size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                      size:
                          isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0),
                    ),
                    onPressed: togglePassword,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: inputPadding,
                    vertical: verticalInputPadding,
                  ),
                  labelStyle: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : bodyFontSize,
                    color: Colors.black54,
                  ),
                  hintStyle: TextStyle(
                    fontSize: isSmallScreen ? 13.0 : bodyFontSize,
                    color: Colors.black45,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return t('enterPassword');
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 6.0 : 8.0),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop
                          ? 12
                          : (isTablet
                              ? 10
                              : (isLargeScreen ? 8 : (isMediumScreen ? 7 : 6))),
                      vertical: isDesktop
                          ? 8
                          : (isTablet
                              ? 6
                              : (isLargeScreen ? 4 : (isMediumScreen ? 4 : 3))),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    t('forgot'),
                    style: TextStyle(
                      fontSize: isDesktop
                          ? 15
                          : (isTablet
                              ? 14
                              : (isLargeScreen
                                  ? 14
                                  : (isMediumScreen ? 13 : 12))),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: isDesktop
                    ? 20
                    : (isTablet
                        ? 18
                        : (isLargeScreen ? 16 : (isMediumScreen ? 14 : 12))),
              ),
              FilledButton(
                onPressed: isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isDesktop
                        ? 16
                        : (isTablet
                            ? 16
                            : (isLargeScreen
                                ? 15
                                : (isMediumScreen ? 14 : 13))),
                  ),
                  textStyle: TextStyle(
                    fontSize: isDesktop
                        ? 17
                        : (isTablet
                            ? 16
                            : (isLargeScreen
                                ? 16
                                : (isMediumScreen ? 15 : 14))),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        height: isSmallScreen ? 18.0 : 20.0,
                        width: isSmallScreen ? 18.0 : 20.0,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(t('ctaLogin')),
              ),
              SizedBox(height: isSmallScreen ? 8.0 : 10.0),
              OutlinedButton(
                onPressed: onRegister,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isDesktop
                        ? 16
                        : (isTablet
                            ? 16
                            : (isLargeScreen
                                ? 15
                                : (isMediumScreen ? 14 : 13))),
                  ),
                ),
                child: Text(
                  t('ctaRegister'),
                  style: TextStyle(
                    fontSize: isDesktop
                        ? 16
                        : (isTablet
                            ? 15
                            : (isLargeScreen
                                ? 15
                                : (isMediumScreen ? 14 : 13))),
                  ),
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
