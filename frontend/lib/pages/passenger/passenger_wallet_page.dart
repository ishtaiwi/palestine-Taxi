import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../../services/api_service.dart';
import '../../services/stripe_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_home.dart';

class PassengerWalletPage extends StatefulWidget {
  const PassengerWalletPage({super.key});

  @override
  State<PassengerWalletPage> createState() => _PassengerWalletPageState();
}

class _PassengerWalletPageState extends State<PassengerWalletPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false; 
  String? _error;
  Map<String, dynamic>? _wallet;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'محفظتي',
      'balance': 'الرصيد',
      'addBalance': 'إضافة رصيد',
      'enterAmount': 'أدخل المبلغ',
      'add': 'إضافة',
      'cancel': 'إلغاء',
      'transactions': 'المعاملات',
      'noTransactions': 'لا توجد معاملات',
      'refresh': 'تحديث',
      'error': 'حدث خطأ',
      'deposit': 'إيداع',
      'withdrawal': 'سحب',
      'payment': 'دفع',
      'refund': 'استرداد',
      'transfer': 'تحويل',
      'completed': 'مكتمل',
      'pending': 'قيد الانتظار',
      'failed': 'فشل',
    },
    'en': {
      'title': 'My Wallet',
      'balance': 'Balance',
      'addBalance': 'Add Balance',
      'enterAmount': 'Enter Amount',
      'add': 'Add',
      'cancel': 'Cancel',
      'transactions': 'Transactions',
      'noTransactions': 'No transactions',
      'refresh': 'Refresh',
      'error': 'An error occurred',
      'deposit': 'Deposit',
      'withdrawal': 'Withdrawal',
      'payment': 'Payment',
      'refund': 'Refund',
      'transfer': 'Transfer',
      'completed': 'Completed',
      'pending': 'Pending',
      'failed': 'Failed',
    },
  };

  String t(String key) {
    final lang = _isArabic ? 'ar' : 'en';
    return _texts[lang]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvcController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final isArabic = await ApiService.getLanguagePreference();
      await _loadThemePreference();

      
      try {
        await StripeService.initialize();
      } catch (_) {
        
      }

      if (!mounted) return;
      setState(() {
        _isArabic = isArabic;
      });

      await _loadWallet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadWallet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.fetchWallet();
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _wallet = result;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result['message']?.toString() ?? t('error');
            _isLoading = false;
          });
        }
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

  Future<void> _addBalance() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isArabic ? 'يرجى إدخال مبلغ صحيح' : 'Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_cardNumberController.text.length < 16 ||
        _expiryController.text.length < 5 ||
        _cvcController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'يرجى إدخال بيانات بطاقة فيزا / ماستر كارد بشكل كامل'
                : 'Please enter complete card details (Visa/Mastercard).',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final expiryParts = _expiryController.text.split('/');
      if (expiryParts.length != 2) throw Exception('Invalid expiry date');
      
      final month = int.tryParse(expiryParts[0]) ?? 0;
      final year = int.tryParse(expiryParts[1]) ?? 0;
      final fullYear = year < 100 ? 2000 + year : year;

      await Stripe.instance.dangerouslyUpdateCardDetails(CardDetails(
        number: _cardNumberController.text.replaceAll(' ', ''),
        cvc: _cvcController.text,
        expirationMonth: month,
        expirationYear: fullYear,
      ));

      final result = await StripeService.topUpWalletWithCard(amount: amount);
      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic
                  ? 'تمت إضافة الرصيد بنجاح. قد يستغرق التحديث ثوانٍ قليلة.'
                  : 'Balance added successfully. It may take a few seconds to update.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _amountController.clear();
        Navigator.pop(context);
        _loadWallet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? t('error'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddBalanceSheet() async {
    _amountController.clear();
    _cardNumberController.clear();
    _expiryController.clear();
    _cvcController.clear();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final basePadding = isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final titleFontSize = isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0);
    final inputFontSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);

    final isDarkMode = _isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1C2541) : Colors.white;
    final textPrimary = isDarkMode ? const Color(0xFFE8EAF6) : const Color(0xFF1E3A5F);
    final textSecondary = isDarkMode ? const Color(0xFFB0BEC5) : Colors.grey.shade600;
    final inputFill = isDarkMode ? const Color(0xFF0A0E21) : Colors.grey.shade50;
    final border = isDarkMode ? const Color(0xFF2C3E50) : Colors.grey.shade200;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(isSmallScreen ? 20.0 : 24.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + basePadding,
          top: basePadding,
          left: basePadding,
          right: basePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C5F8D).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, 
                    color: Color(0xFF2C5F8D), size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  t('addBalance'),
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 24.0 : 32.0),
            
            Text(
              t('enterAmount'),
              style: TextStyle(
                color: textSecondary,
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6.0 : 8.0),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: textPrimary,
                fontSize: inputFontSize,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputFill,
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '₪',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: inputFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                  borderSide: const BorderSide(color: Color(0xFF2C5F8D), width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16.0 : 20.0, 
                  vertical: isSmallScreen ? 16.0 : 20.0
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 20.0 : 24.0),
            
            Text(
              _isArabic ? 'بيانات البطاقة' : 'Card Details',
              style: TextStyle(
                color: textSecondary,
                fontSize: isSmallScreen ? 12.0 : 14.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6.0 : 8.0),
            Container(
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                border: Border.all(color: border),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12.0 : 16.0, 
                vertical: isSmallScreen ? 3.0 : 4.0
              ),
              child: TextField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                style: TextStyle(
                  color: textPrimary, 
                  fontSize: isSmallScreen ? 14.0 : 16.0
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0000 0000 0000 0000',
                  labelText: _isArabic ? 'رقم البطاقة' : 'Card Number',
                  labelStyle: TextStyle(
                    color: textSecondary,
                    fontSize: isSmallScreen ? 12.0 : 14.0,
                  ),
                  hintStyle: TextStyle(
                    color: textSecondary.withOpacity(0.5),
                    fontSize: isSmallScreen ? 12.0 : 14.0,
                  ),
                  icon: Icon(
                    Icons.credit_card, 
                    color: textSecondary,
                    size: isSmallScreen ? 18.0 : 20.0,
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                      border: Border.all(color: border),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0, 
                      vertical: isSmallScreen ? 3.0 : 4.0
                    ),
                    child: TextField(
                      controller: _expiryController,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(5),
                      ],
                      onChanged: (value) {
                        if (value.length == 2 && !_expiryController.text.contains('/')) {
                          _expiryController.text = '$value/';
                          _expiryController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _expiryController.text.length));
                        }
                      },
                      style: TextStyle(
                        color: textPrimary, 
                        fontSize: isSmallScreen ? 14.0 : 16.0
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'MM/YY',
                        labelText: _isArabic ? 'التاريخ' : 'Expiry',
                        labelStyle: TextStyle(
                          color: textSecondary,
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                        ),
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.5),
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                      border: Border.all(color: border),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0, 
                      vertical: isSmallScreen ? 3.0 : 4.0
                    ),
                    child: TextField(
                      controller: _cvcController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      style: TextStyle(
                        color: textPrimary, 
                        fontSize: isSmallScreen ? 14.0 : 16.0
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '123',
                        labelText: 'CVC',
                        labelStyle: TextStyle(
                          color: textSecondary,
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                        ),
                        hintStyle: TextStyle(
                          color: textSecondary.withOpacity(0.5),
                          fontSize: isSmallScreen ? 12.0 : 14.0,
                        ),
                        suffixIcon: Icon(
                          Icons.lock_outline, 
                          size: isSmallScreen ? 16.0 : 18.0, 
                          color: textSecondary
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Offstage(
              offstage: true,
              child: CardField(
                onCardChanged: (card) {
                },
              ),
            ),
            SizedBox(height: isSmallScreen ? 24.0 : 32.0),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12.0 : 16.0
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                      ),
                    ),
                    child: Text(
                      t('cancel'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _addBalance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F8D),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12.0 : 16.0
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                      ),
                    ),
                    child: Text(
                      t('add'),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final balance = _wallet?['balance'] ?? 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Web-specific responsive breakpoints
    final isWeb = kIsWeb;
    final isDesktop = isWeb && screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    
    // Responsive sizing - enhanced for web
    final double basePadding = isWeb 
        ? (isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    final double titleFontSize = isWeb
        ? (isDesktop ? 24.0 : 22.0)
        : (isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0));
    final double balanceFontSize = isWeb
        ? (isDesktop ? 48.0 : (isTablet ? 44.0 : 42.0))
        : (isSmallScreen ? 32.0 : (isMediumScreen ? 37.0 : 42.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;
    
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0E21) : const Color(0xFFF5F7FA);
    final cardColor = _isDarkMode ? const Color(0xFF1C2541) : Colors.white;
    final textPrimary = _isDarkMode ? const Color(0xFFE8EAF6) : const Color(0xFF1E3A5F);
    final textSecondary = _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF64748B);
    final borderColor = _isDarkMode ? const Color(0xFF2C3E50) : Colors.grey.shade200;

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
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: titleFontSize,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: const IconThemeData(color: Colors.white),
              actionsIconTheme: const IconThemeData(color: Colors.white),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    onPressed: _loadWallet,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadWallet,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: basePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: isSmallScreen ? 16.0 : 20.0),
                        
                        Container(
                          constraints: BoxConstraints(
                            minHeight: isSmallScreen ? 200.0 : (isMediumScreen ? 220.0 : 240.0),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isDarkMode
                                  ? [const Color(0xFF1C2541), const Color(0xFF2C3E50)]
                                  : [const Color(0xFF2C5F8D), const Color(0xFF1E3A5F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: (_isDarkMode ? const Color(0xFF000000) : const Color(0xFF1E3A5F))
                                    .withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -30,
                                top: -30,
                                child: Icon(
                                  Icons.account_balance_wallet,
                                  size: isSmallScreen ? 150.0 : 180.0,
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              Positioned(
                                left: -20,
                                bottom: -20,
                                child: Container(
                                  width: isSmallScreen ? 80.0 : 100.0,
                                  height: isSmallScreen ? 80.0 : 100.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(
                                  isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(
                                                isSmallScreen ? 6.0 : 8.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.account_balance_wallet_outlined,
                                                color: Colors.white, 
                                                size: isSmallScreen ? 18.0 : 20.0,
                                              ),
                                            ),
                                            SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                            Text(
                                              t('balance'),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: isSmallScreen ? 14.0 : 16.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 10.0 : 12.0,
                                            vertical: isSmallScreen ? 5.0 : 6.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.white.withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: isSmallScreen ? 6.0 : 8.0,
                                                height: isSmallScreen ? 6.0 : 8.0,
                                                decoration: const BoxDecoration(
                                                  color: Colors.greenAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                                              Text(
                                                t('available'),
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isSmallScreen ? 11.0 : 12.0,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0),
                                    ),
                                    Text(
                                      '${balance.toStringAsFixed(2)} ₪',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: balanceFontSize,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    SizedBox(
                                      height: isSmallScreen ? 14.0 : (isMediumScreen ? 18.0 : 20.0),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showAddBalanceSheet,
                                        icon: Icon(
                                          Icons.add_card, 
                                          size: isSmallScreen ? 18.0 : 20.0,
                                        ),
                                        label: Text(t('addBalance')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: const Color(0xFF1E3A5F),
                                          padding: EdgeInsets.symmetric(
                                            vertical: isSmallScreen ? 12.0 : 14.0,
                                          ),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              isSmallScreen ? 14.0 : 16.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                            
                            const SizedBox(height: 32),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t('transactions'),
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            
                            if (_isLoading)
                              const Center(child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(),
                              ))
                            else if (_error != null)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else if (_wallet != null && 
                                     _wallet!['transactions'] != null && 
                                     (_wallet!['transactions'] as List).isNotEmpty)
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: (_wallet!['transactions'] as List).length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final transactions = _wallet!['transactions'] as List;
                                  if (index >= transactions.length) return const SizedBox();
                                  
                                  final transaction = transactions[index];
                                  final amount = (transaction['amount'] ?? 0.0).toDouble();
                                  final type = transaction['type']?.toString().toLowerCase() ?? '';
                                  final status = transaction['status']?.toString().toLowerCase() ?? '';
                                  final time = transaction['time']?.toString() ?? '';
                                  
                                  final isIncoming = transaction['towalletid'] == _wallet!['walletid'] && 
                                                    transaction['fromwalletid'] != null;
                                  final isOutgoing = transaction['fromwalletid'] == _wallet!['walletid'];
                                  
                                  String typeLabel = t('transfer');
                                  String typeDescription = '';
                                  IconData typeIcon = Icons.swap_horiz;
                                  Color iconColor = Colors.blue;
                                  Color iconBgColor = Colors.blue.withOpacity(0.1);
                                  
                                  if (type == 'wallet_topup' || type == 'deposit' || (isIncoming && type == 'transfer')) {
                                    typeLabel = _isArabic ? 'شحن رصيد' : 'Top Up';
                                    typeDescription = _isArabic ? 'إضافة رصيد للمحفظة بالبطاقة' : 'Wallet top-up via card';
                                    typeIcon = Icons.arrow_downward_rounded;
                                    iconColor = Colors.green;
                                    iconBgColor = Colors.green.withOpacity(0.1);
                                  } else if (type == 'reservation' || (type == 'payment' && isOutgoing)) {
                                    typeLabel = _isArabic ? 'حجز رحلة' : 'Trip Booking';
                                    // Build description with driver name (trip time shown separately below)
                                    String description = _isArabic ? 'دفع مقابل حجز رحلة' : 'Payment for trip reservation';
                                    if (transaction['driver_name'] != null) {
                                      description += _isArabic
                                        ? ' - السائق: ${transaction['driver_name']}'
                                        : ' - Driver: ${transaction['driver_name']}';
                                    }
                                    typeDescription = description;
                                    typeIcon = Icons.arrow_upward_rounded;
                                    iconColor = Colors.red;
                                    iconBgColor = Colors.red.withOpacity(0.1);
                                  } else if (type == 'refund') {
                                    typeLabel = t('refund');
                                    // Check who cancelled: passenger or driver
                                    final cancelledBy = transaction['external_reference']?.toString();
                                    String description;
                                    
                                    if (cancelledBy == 'cancelled_by_passenger') {
                                      // Passenger cancelled the reservation themselves
                                      description = _isArabic 
                                        ? 'استرداد مبلغ - تم الإلغاء من قبلك'
                                        : 'Refund - Cancelled by you';
                                    } else if (cancelledBy == 'cancelled_by_driver') {
                                      // Driver cancelled/rejected the reservation
                                      description = _isArabic 
                                        ? 'استرداد مبلغ - تم الإلغاء من قبل السائق'
                                        : 'Refund - Cancelled by driver';
                                      if (transaction['driver_name'] != null) {
                                        description += _isArabic
                                          ? ' (${transaction['driver_name']})'
                                          : ' (${transaction['driver_name']})';
                                      }
                                    } else {
                                      // Legacy refunds or unknown cancellation source
                                      description = _isArabic ? 'استرداد مبلغ من حجز ملغي' : 'Refund from cancelled booking';
                                      if (transaction['driver_name'] != null) {
                                        description += _isArabic
                                          ? ' - من السائق: ${transaction['driver_name']}'
                                          : ' - From driver: ${transaction['driver_name']}';
                                      }
                                    }
                                    
                                    typeDescription = description;
                                    typeIcon = Icons.refresh;
                                    iconColor = Colors.green;
                                    iconBgColor = Colors.green.withOpacity(0.1);
                                  } else if (type == 'payment' && isOutgoing) {
                                    typeLabel = t('payment');
                                    typeDescription = _isArabic ? 'دفع' : 'Payment';
                                    typeIcon = Icons.arrow_upward_rounded;
                                    iconColor = Colors.red;
                                    iconBgColor = Colors.red.withOpacity(0.1);
                                  }

                                  
                                  // Helper function to normalize and parse date strings from Supabase
                                  DateTime? _parseDateToLocal(String? dateString) {
                                    if (dateString == null || dateString.isEmpty) return null;
                                    try {
                                      // Normalize to ISO 8601 and strip any offset so we always treat as UTC
                                      // Then convert to local time for display.
                                      String normalized = dateString.toString();
                                      normalized = normalized.replaceFirst(' ', 'T');
                                      // Remove any timezone offset (+HH:MM or -HH:MM) and replace with Z (UTC)
                                      normalized = normalized.replaceFirst(RegExp(r'([+-]\d{2}):?(\d{2})$'), 'Z');
                                      if (!normalized.contains('Z')) {
                                        normalized += 'Z';
                                      }
                                      return DateTime.parse(normalized).toLocal();
                                    } catch (_) {
                                      return null;
                                    }
                                  }

                                  // Format transaction date/time (convert to local time - reservation time)
                                  String transactionDateStr = '';
                                  String transactionTimeStr = '';
                                  DateTime? transactionDateTime;
                                  try {
                                    if (time.isNotEmpty) {
                                      // Normalize and parse to local timezone (reservation date/time)
                                      DateTime? parsedDateTime = _parseDateToLocal(time);
                                      if (parsedDateTime == null) {
                                        // Fallback: try direct parse and convert to local
                                        try {
                                          parsedDateTime = DateTime.parse(time).toLocal();
                                        } catch (e) {
                                          // If all parsing fails, try to parse as UTC and convert
                                          try {
                                            String normalized = time.toString();
                                            if (!normalized.contains('Z') && !normalized.contains('+') && !normalized.contains('-')) {
                                              normalized += 'Z';
                                            }
                                            parsedDateTime = DateTime.parse(normalized).toLocal();
                                          } catch (_) {
                                            // Last resort: use current time (shouldn't happen)
                                            parsedDateTime = DateTime.now();
                                          }
                                        }
                                      }
                                      
                                      // Format the local time
                                      transactionDateTime = parsedDateTime;
                                      transactionDateStr = '${transactionDateTime.day}/${transactionDateTime.month}/${transactionDateTime.year}';
                                      transactionTimeStr = '${transactionDateTime.hour.toString().padLeft(2, '0')}:${transactionDateTime.minute.toString().padLeft(2, '0')}';
                                    }
                                  } catch (e) {
                                    // If all else fails, try one more time with current time
                                    try {
                                      final now = DateTime.now();
                                      transactionDateTime = now;
                                      transactionDateStr = '${now.day}/${now.month}/${now.year}';
                                      transactionTimeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                                    } catch (_) {
                                      transactionDateStr = time; // Last resort: show raw time
                                    }
                                  }

                                  // Format trip date/time if available (convert to local time)
                                  String? tripDateStr;
                                  String? tripTimeStr;
                                  DateTime? tripDateTime;
                                  bool showTripInfo = false;
                                  
                                  if (transaction['trip_datetime'] != null) {
                                    try {
                                      // Normalize and parse to local timezone (like laptop time)
                                      tripDateTime = _parseDateToLocal(transaction['trip_datetime']);
                                      if (tripDateTime == null) {
                                        // Fallback: try direct parse
                                        tripDateTime = DateTime.parse(transaction['trip_datetime']).toLocal();
                                      }
                                      
                                      final tripDateOnly = tripDateTime.toIso8601String().split('T')[0];
                                      final transactionDateOnly = transactionDateTime != null 
                                        ? transactionDateTime.toIso8601String().split('T')[0]
                                        : null;
                                      
                                      // Only show trip date if it's different from transaction date
                                      if (tripDateOnly != transactionDateOnly && transactionDateOnly != null) {
                                        tripDateStr = '${tripDateTime.day}/${tripDateTime.month}/${tripDateTime.year}';
                                        showTripInfo = true;
                                      }
                                      
                                      // Always show trip time if available (it's useful information for payments/refunds)
                                      // Format trip time from trip_datetime in local timezone
                                      tripTimeStr = '${tripDateTime.hour.toString().padLeft(2, '0')}:${tripDateTime.minute.toString().padLeft(2, '0')}';
                                      showTripInfo = true;
                                    } catch (_) {
                                      // If parsing fails, use the trip_time directly if available
                                      if (transaction['trip_time'] != null) {
                                        tripTimeStr = transaction['trip_time'].toString();
                                        showTripInfo = true;
                                      }
                                    }
                                  } else if (transaction['trip_time'] != null) {
                                    // Fallback: use trip_time if trip_datetime is not available
                                    // Try to parse and convert to local time if it's a full datetime string
                                    try {
                                      final parsedTime = _parseDateToLocal(transaction['trip_time']);
                                      if (parsedTime != null) {
                                        tripTimeStr = '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';
                                      } else {
                                        // If it's just a time string (HH:MM), use it directly
                                        tripTimeStr = transaction['trip_time'].toString();
                                      }
                                    } catch (_) {
                                      // If it's just a time string (HH:MM), use it directly
                                      tripTimeStr = transaction['trip_time'].toString();
                                    }
                                    showTripInfo = true;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: iconBgColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(typeIcon, color: iconColor, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                typeLabel,
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (typeDescription.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  typeDescription,
                                                  style: TextStyle(
                                                    color: textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                              const SizedBox(height: 4),
                                              // Transaction date/time
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 12,
                                                    color: textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    transactionDateStr.isNotEmpty && transactionTimeStr.isNotEmpty
                                                      ? '$transactionDateStr $transactionTimeStr'
                                                      : (transactionDateStr.isNotEmpty 
                                                          ? transactionDateStr 
                                                          : (transactionTimeStr.isNotEmpty 
                                                              ? transactionTimeStr 
                                                              : time)), // Fallback to raw time only if all parsing failed
                                                    style: TextStyle(
                                                      color: textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Trip date/time (only if different or has trip time)
                                              if (showTripInfo && (tripDateStr != null || tripTimeStr != null)) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 12,
                                                      color: textSecondary.withOpacity(0.7),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _isArabic
                                                        ? (tripDateStr != null && tripTimeStr != null
                                                            ? 'رحلة: $tripDateStr $tripTimeStr'
                                                            : tripTimeStr != null
                                                                ? 'وقت الرحلة: $tripTimeStr'
                                                                : 'رحلة: $tripDateStr')
                                                        : (tripDateStr != null && tripTimeStr != null
                                                            ? 'Trip: $tripDateStr $tripTimeStr'
                                                            : tripTimeStr != null
                                                                ? 'Trip time: $tripTimeStr'
                                                                : 'Trip: $tripDateStr'),
                                                      style: TextStyle(
                                                        color: textSecondary.withOpacity(0.7),
                                                        fontSize: 11,
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${isIncoming || type == 'deposit' || type == 'refund' ? '+' : '-'}${amount.toStringAsFixed(2)} ₪',
                                              style: TextStyle(
                                                color: isIncoming || type == 'deposit' || type == 'refund' 
                                                  ? Colors.green 
                                                  : Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              t(status),
                                              style: TextStyle(
                                                color: status == 'completed' ? Colors.green : Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, 
                                      size: 64, color: textSecondary.withOpacity(0.3)),
                                    const SizedBox(height: 16),
                                    Text(
                                      t('noTransactions'),
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 80), 
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 3,
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            PassengerBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }
}

