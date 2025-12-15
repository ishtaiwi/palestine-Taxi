import 'package:flutter/material.dart';
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
  CardFieldInputDetails? _cardDetails;

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

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _amountController.dispose();
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

    if (_cardDetails == null || !_cardDetails!.complete) {
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
    _cardDetails = null;

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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            Text(
              t('enterAmount'),
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: textPrimary,
                fontSize: 24,
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF2C5F8D), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              _isArabic ? 'بيانات البطاقة' : 'Card Details',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: CardField(
                onCardChanged: (card) {
                  setState(() {
                    _cardDetails = card;
                  });
                },
                style: TextStyle(color: textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0000 0000 0000 0000',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      t('cancel'),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _addBalance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5F8D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      t('add'),
                      style: const TextStyle(
                        fontSize: 16,
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
    
    
    final backgroundColor = _isDarkMode ? const Color(0xFF0A0E21) : const Color(0xFFF5F7FA);
    final cardColor = _isDarkMode ? const Color(0xFF1C2541) : Colors.white;
    final textPrimary = _isDarkMode ? const Color(0xFFE8EAF6) : const Color(0xFF1E3A5F);
    final textSecondary = _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF64748B);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isDarkMode
                        ? [const Color(0xFF1C2541), const Color(0xFF0A0E21)]
                        : [const Color(0xFF2C5F8D), const Color(0xFF1E3A5F)],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -50,
                      right: -50,
                      child: CircleAvatar(
                        radius: 100,
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: CircleAvatar(
                        radius: 80,
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            
            SafeArea(
              child: Column(
                children: [
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
                            onPressed: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PassengerHomePage()),
                                );
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t('title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 24, color: Colors.white),
                            onPressed: _loadWallet,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadWallet,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32).withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: -20,
                                    top: -20,
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      size: 150,
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              t('balance'),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          '${balance.toStringAsFixed(2)} ₪',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _showAddBalanceSheet,
                                            icon: const Icon(Icons.add, size: 20),
                                            label: Text(t('addBalance')),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: const Color(0xFF2E7D32),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
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
                            else if (_wallet?['transactions'] != null && (_wallet!['transactions'] as List).isNotEmpty)
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: (_wallet!['transactions'] as List).length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final transaction = (_wallet!['transactions'] as List)[index];
                                  final amount = (transaction['amount'] ?? 0.0).toDouble();
                                  final type = transaction['type']?.toString().toLowerCase() ?? '';
                                  final status = transaction['status']?.toString().toLowerCase() ?? '';
                                  final time = transaction['time']?.toString() ?? '';
                                  
                                  final isIncoming = transaction['towalletid'] == _wallet!['walletid'] && 
                                                    transaction['fromwalletid'] != null;
                                  final isOutgoing = transaction['fromwalletid'] == _wallet!['walletid'];
                                  
                                  
                                  String typeLabel = t('transfer');
                                  IconData typeIcon = Icons.swap_horiz;
                                  Color iconColor = Colors.blue;
                                  Color iconBgColor = Colors.blue.withOpacity(0.1);
                                  
                                  if (type == 'deposit' || (isIncoming && type == 'transfer')) {
                                    typeLabel = t('deposit');
                                    typeIcon = Icons.arrow_downward_rounded;
                                    iconColor = Colors.green;
                                    iconBgColor = Colors.green.withOpacity(0.1);
                                  } else if (type == 'payment' || isOutgoing) {
                                    typeLabel = t('payment');
                                    typeIcon = Icons.arrow_upward_rounded;
                                    iconColor = Colors.red;
                                    iconBgColor = Colors.red.withOpacity(0.1);
                                  } else if (type == 'refund') {
                                    typeLabel = t('refund');
                                    typeIcon = Icons.refresh;
                                    iconColor = Colors.green;
                                    iconBgColor = Colors.green.withOpacity(0.1);
                                  }

                                  
                                  String dateStr = '';
                                  try {
                                    if (time.isNotEmpty) {
                                      final dt = DateTime.parse(time);
                                      dateStr = '${dt.day}/${dt.month}/${dt.year}';
                                    }
                                  } catch (_) {
                                    dateStr = time;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
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
                                              const SizedBox(height: 4),
                                              Text(
                                                dateStr,
                                                style: TextStyle(
                                                  color: textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
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
          ],
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

