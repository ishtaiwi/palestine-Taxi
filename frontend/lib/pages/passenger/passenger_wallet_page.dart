import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
  bool _isDarkMode = false; // Light mode as default
  String? _error;
  Map<String, dynamic>? _wallet;
  final TextEditingController _amountController = TextEditingController();

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
    final isArabic = await ApiService.getLanguagePreference();
    await _loadThemePreference();
    setState(() {
      _isArabic = isArabic;
    });
    await _loadWallet();
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

    try {
      final result = await ApiService.addWalletBalance(amount);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('addBalance')),
              backgroundColor: Colors.green,
            ),
          );
          _amountController.clear();
          Navigator.pop(context);
          _loadWallet();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddBalanceDialog() async {
    _amountController.clear();

    // Theme-aware colors for dialog
    final dialogBgColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : Colors.white;

    final textPrimary = _isDarkMode
        ? const Color(0xFFE8EAF6)
        : const Color(0xFF1E3A5F);

    final textSecondary = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : Colors.grey.shade700;

    final fillColor = _isDarkMode
        ? const Color(0xFF1E3A5F).withAlpha(77)
        : Colors.grey.shade50;

    final borderColor = _isDarkMode
        ? const Color(0xFF2C5F8D)
        : Colors.grey.shade300;

    final focusedBorderColor = _isDarkMode
        ? const Color(0xFF64B5F6)
        : const Color(0xFF1E3A5F);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: textPrimary, size: 24),
            const SizedBox(width: 12),
            Text(
              t('addBalance'),
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: t('enterAmount'),
            labelStyle: TextStyle(color: textSecondary),
            prefixText: '₪ ',
            prefixStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: focusedBorderColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t('cancel'),
              style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _addBalance();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              t('add'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final balance = _wallet?['balance'] ?? 0.0;

    // Theme-aware colors
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color(0xFFECF0F3);

    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);

    final textPrimary = _isDarkMode
        ? const Color(0xFFE8EAF6)
        : const Color(0xFF1E3A5F);

    final textSecondary = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : Colors.grey.shade600;

    final appBarColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFF2C5F8D);

    final borderColor = _isDarkMode
        ? const Color(0xFF2C3E50)
        : Colors.grey.shade200;

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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadWallet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C5F8D),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(t('refresh'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Balance Card
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF4CAF50),
                                  Color(0xFF2E7D32),
                                  Color(0xFF1B5E20),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withAlpha(102),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(51),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t('balance'),
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(230),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${balance.toStringAsFixed(2)} ₪',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: _showAddBalanceDialog,
                                    icon: const Icon(Icons.add_circle_outline, size: 22),
                                    label: Text(
                                      t('addBalance'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2E7D32),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Transactions Section
                          Text(
                            t('transactions'),
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Transactions List
                          if (_wallet?['transactions'] != null && 
                              (_wallet!['transactions'] as List).isNotEmpty) ...[
                            ...(_wallet!['transactions'] as List).map((transaction) {
                              final amount = (transaction['amount'] ?? 0.0).toDouble();
                              final type = transaction['type']?.toString().toLowerCase() ?? '';
                              final status = transaction['status']?.toString().toLowerCase() ?? '';
                              final time = transaction['time']?.toString() ?? '';
                              
                              // Determine if it's incoming or outgoing
                              final isIncoming = transaction['towalletid'] == _wallet!['walletid'] && 
                                                transaction['fromwalletid'] != null;
                              final isOutgoing = transaction['fromwalletid'] == _wallet!['walletid'];
                              
                              // Get transaction type label
                              String typeLabel = t('transfer');
                              IconData typeIcon = Icons.swap_horiz;
                              Color typeColor = Colors.blue;
                              
                              if (type == 'deposit' || (isIncoming && type == 'transfer')) {
                                typeLabel = t('deposit');
                                typeIcon = Icons.add_circle;
                                typeColor = Colors.green;
                              } else if (type == 'payment' || isOutgoing) {
                                typeLabel = t('payment');
                                typeIcon = Icons.payment;
                                typeColor = Colors.orange;
                              } else if (type == 'refund') {
                                typeLabel = t('refund');
                                typeIcon = Icons.undo;
                                typeColor = Colors.green;
                              }
                              
                              // Get status color
                              Color statusColor = Colors.grey;
                              if (status == 'completed') {
                                statusColor = Colors.green;
                              } else if (status == 'pending') {
                                statusColor = Colors.orange;
                              } else if (status == 'failed') {
                                statusColor = Colors.red;
                              }
                              
                              // Format date
                              String formattedDate = '';
                              if (time.isNotEmpty) {
                                try {
                                  final dateTime = DateTime.parse(time);
                                  if (_isArabic) {
                                    formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                                  } else {
                                    formattedDate = '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                                  }
                                } catch (e) {
                                  formattedDate = time;
                                }
                              }
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(13),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: typeColor.withAlpha(51),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        typeIcon,
                                        color: typeColor,
                                        size: 24,
                                      ),
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
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: textSecondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withAlpha(51),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            t(status),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long, color: textSecondary, size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    t('noTransactions'),
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 3, // My Wallet is index 3
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

