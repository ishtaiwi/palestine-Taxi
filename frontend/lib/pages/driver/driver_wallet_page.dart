import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import 'driver_home.dart';

class DriverWalletPage extends StatefulWidget {
  const DriverWalletPage({super.key});

  @override
  State<DriverWalletPage> createState() => _DriverWalletPageState();
}

class _DriverWalletPageState extends State<DriverWalletPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false;
  String? _error;
  Map<String, dynamic>? _wallet;
  List<dynamic>? _transactions;
  Map<String, dynamic>? _summary;
  String _selectedPeriod = 'all'; // today, thisWeek, thisMonth, all

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'محفظتي',
      'balance': 'الرصيد',
      'totalEarnings': 'إجمالي الأرباح',
      'todayEarnings': 'أرباح اليوم',
      'monthEarnings': 'أرباح الشهر',
      'transactions': 'المعاملات',
      'noTransactions': 'لا توجد معاملات',
      'refresh': 'تحديث',
      'error': 'حدث خطأ',
      'earnings': 'أرباح',
      'fromTrip': 'من رحلة',
      'completed': 'مكتمل',
      'pending': 'قيد الانتظار',
      'failed': 'فشل',
      'today': 'اليوم',
      'thisWeek': 'هذا الأسبوع',
      'thisMonth': 'هذا الشهر',
      'all': 'الكل',
      'tripDetails': 'تفاصيل الرحلة',
      'passengers': 'الركاب',
      'paymentMethod': 'طريقة الدفع',
      'amount': 'المبلغ',
      'date': 'التاريخ',
      'loading': 'جاري التحميل...',
    },
    'en': {
      'title': 'My Wallet',
      'balance': 'Balance',
      'totalEarnings': 'Total Earnings',
      'todayEarnings': 'Today\'s Earnings',
      'monthEarnings': 'Month Earnings',
      'transactions': 'Transactions',
      'noTransactions': 'No transactions',
      'refresh': 'Refresh',
      'error': 'An error occurred',
      'earnings': 'Earnings',
      'fromTrip': 'From Trip',
      'completed': 'Completed',
      'pending': 'Pending',
      'failed': 'Failed',
      'today': 'Today',
      'thisWeek': 'This Week',
      'thisMonth': 'This Month',
      'all': 'All',
      'tripDetails': 'Trip Details',
      'passengers': 'Passengers',
      'paymentMethod': 'Payment Method',
      'amount': 'Amount',
      'date': 'Date',
      'loading': 'Loading...',
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

  Future<void> _initialize() async {
    try {
      final isArabic = await ApiService.getLanguagePreference();
      await _loadThemePreference();

      if (!mounted) return;
      setState(() {
        _isArabic = isArabic;
      });

      await _loadWallet();
      await _loadTransactions();
      await _loadSummary();
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
      final result = await ApiService.fetchDriverWallet();
      if (mounted) {
        setState(() {
          _wallet = result;
          _isLoading = false;
        });
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

  Future<void> _loadTransactions() async {
    try {
      final result = await ApiService.fetchDriverTransactions(
        period: _selectedPeriod == 'all' ? null : _selectedPeriod,
      );
      if (mounted) {
        setState(() {
          _transactions = result['transactions'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _transactions = [];
          _error = e.toString();
          _isLoading = false;
        });
        print('Error loading transactions: $e');
      }
    }
  }

  Future<void> _loadSummary() async {
    try {
      final result = await ApiService.fetchDriverEarningsSummary();
      if (mounted) {
        setState(() {
          _summary = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _summary = {
            'today': 0.0,
            'thisWeek': 0.0,
            'thisMonth': 0.0,
            'total': 0.0,
            'balance': 0.0,
          };
        });
        print('Error loading summary: $e');
      }
    }
  }

  Future<void> _refresh() async {
    await _loadWallet();
    await _loadTransactions();
    await _loadSummary();
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadTransactions();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      if (_isArabic) {
        return '${date.day}/${date.month}/${date.year}';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final balance = _wallet?['balance']?.toDouble() ?? 0.0;
    final todayEarnings = _summary?['today']?.toDouble() ?? 0.0;
    final monthEarnings = _summary?['thisMonth']?.toDouble() ?? 0.0;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    final double titleFontSize = isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0);
    final double balanceFontSize = isSmallScreen ? 32.0 : (isMediumScreen ? 37.0 : 42.0);
    
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
                          builder: (_) => const DriverHomePage(),
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
                    onPressed: _refresh,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: basePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isSmallScreen ? 16.0 : 20.0),
                  
                  // Balance Card
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
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
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
                                    padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
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
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
                          Text(
                            '${balance.toStringAsFixed(2)} ₪',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: balanceFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                          // Summary Row
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryItem(
                                  t('todayEarnings'),
                                  todayEarnings,
                                  Icons.today,
                                  isSmallScreen,
                                  isMediumScreen,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryItem(
                                  t('monthEarnings'),
                                  monthEarnings,
                                  Icons.calendar_month,
                                  isSmallScreen,
                                  isMediumScreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Period Filter
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        _buildPeriodButton(t('today'), 'today', isSmallScreen),
                        _buildPeriodButton(t('thisWeek'), 'thisWeek', isSmallScreen),
                        _buildPeriodButton(t('thisMonth'), 'thisMonth', isSmallScreen),
                        _buildPeriodButton(t('all'), 'all', isSmallScreen),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Transactions Header
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
                  
                  // Transactions List
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
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
                  else if (_transactions != null && _transactions!.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _transactions!.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final transaction = _transactions![index];
                        final amount = (transaction['amount'] ?? 0.0).toDouble();
                        final status = transaction['status']?.toString().toLowerCase() ?? '';
                        final time = transaction['time']?.toString() ?? transaction['created_at']?.toString() ?? '';
                        final trip = transaction['trip'] as Map<String, dynamic>?;
                        final reservation = transaction['reservation'] as Map<String, dynamic>?;
                        final bookingTime = reservation?['bookedat']?.toString() ?? trip?['reservations']?[0]?['bookedat']?.toString() ?? time;
                        
                        return _buildTransactionCard(
                          transaction,
                          amount,
                          status,
                          time,
                          trip,
                          reservation,
                          bookingTime,
                          cardColor,
                          textPrimary,
                          textSecondary,
                          borderColor,
                          isSmallScreen,
                        );
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 64,
                            color: textSecondary.withOpacity(0.3),
                          ),
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
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 4,
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            DriverBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, IconData icon, bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.8), size: isSmallScreen ? 18.0 : 20.0),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: isSmallScreen ? 11.0 : 12.0,
            ),
          ),
          SizedBox(height: isSmallScreen ? 4.0 : 6.0),
          Text(
            '${value.toStringAsFixed(2)} ₪',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 14.0 : 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period, bool isSmallScreen) {
    final isSelected = _selectedPeriod == period;
    final textPrimary = _isDarkMode ? const Color(0xFFE8EAF6) : const Color(0xFF1E3A5F);
    final accentColor = const Color(0xFFF57C00);
    
    return Expanded(
      child: InkWell(
        onTap: () => _onPeriodChanged(period),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8.0 : 10.0),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : textPrimary,
              fontSize: isSmallScreen ? 11.0 : 12.0,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(
    Map<String, dynamic> transaction,
    double amount,
    String status,
    String time,
    Map<String, dynamic>? trip,
    Map<String, dynamic>? reservation,
    String bookingTime,
    Color cardColor,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
    bool isSmallScreen,
  ) {
    final accentColor = const Color(0xFFF57C00);
    
    // Get passenger name and booking details
    final passengerName = reservation?['passenger']?['user']?['fullname']?.toString() ?? 
                         trip?['reservations']?[0]?['passenger']?['user']?['fullname']?.toString() ?? 
                         '';
    final tripDeptime = trip?['deptime']?.toString() ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.attach_money, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('earnings'),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (passengerName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        passengerName,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(bookingTime),
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (tripDeptime.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(tripDeptime),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
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
                    '+${amount.toStringAsFixed(2)} ₪',
                    style: TextStyle(
                      color: Colors.green,
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
          if (trip != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.route, size: 16, color: textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip['line']?['linename']?.toString() ?? '',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tripDeptime.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateTime(tripDeptime),
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final day = date.day;
      final month = date.month;
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      if (_isArabic) {
        return '$day/$month/$year $hour:$minute';
      } else {
        return '$month/$day/$year $hour:$minute';
      }
    } catch (_) {
      return dateStr;
    }
  }
}
