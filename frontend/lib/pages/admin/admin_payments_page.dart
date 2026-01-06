import 'package:flutter/material.dart' hide TextDirection;
import 'package:flutter/material.dart' as material show TextDirection;
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _filteredPayments = [];
  bool _isLoading = true;
  bool _isArabic = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة المدفوعات',
      'payments': 'المدفوعات',
      'noPayments': 'لا توجد مدفوعات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'amount': 'المبلغ',
      'method': 'الطريقة',
      'status': 'الحالة',
      'time': 'الوقت',
      'pending': 'قيد الانتظار',
      'completed': 'مكتمل',
      'failed': 'فشل',
      'search': 'بحث...',
      'filterAll': 'الكل',
      'transactionId': 'رقم المعاملة',
    },
    'en': {
      'title': 'Payments Management',
      'payments': 'Payments',
      'noPayments': 'No payments found',
      'loading': 'Loading...',
      'error': 'Error',
      'amount': 'Amount',
      'method': 'Method',
      'status': 'Status',
      'time': 'Time',
      'pending': 'Pending',
      'completed': 'Completed',
      'failed': 'Failed',
      'search': 'Search...',
      'filterAll': 'All',
      'transactionId': 'Transaction ID',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _loadLanguagePreference();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final payments = await ApiService.getAllPayments();
      setState(() {
        _payments = payments;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _applyFilter() {
    _filteredPayments = _payments.where((payment) {
      final method = (payment['method'] ?? '').toString().toLowerCase();
      final status = (payment['status'] ?? '').toString().toLowerCase();
      final amount = (payment['amount'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty ||
          method.contains(_searchQuery) ||
          amount.contains(_searchQuery);

      final matchesStatus =
          _statusFilter == null || status == _statusFilter?.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      // Normalize Supabase timestamp format to ISO 8601 and convert to local time
      // Supabase returns: "2025-12-23 21:00:00+00" -> convert to: "2025-12-23T21:00:00Z"
      String normalized = dateString.toString();
      // Replace space with T
      normalized = normalized.replaceFirst(' ', 'T');
      // Replace +00 or +00:00 with Z (UTC indicator)
      normalized = normalized.replaceFirst(RegExp(r'\+00:?00?$'), 'Z');
      // If no timezone indicator, assume UTC
      if (!normalized.contains('Z') &&
          !normalized.contains('+') &&
          !normalized.contains('-')) {
        normalized += 'Z';
      }
      // Parse as UTC and convert to local timezone for display
      final date = DateTime.parse(normalized).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      debugPrint(
          'Error parsing date in admin payments: $dateString, error: $e');
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return t('completed');
      case 'pending':
        return t('pending');
      case 'failed':
        return t('failed');
      default:
        return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection =
        _isArabic ? material.TextDirection.rtl : material.TextDirection.ltr;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(context),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.appBarColor))
            : Column(
                children: [
                  _buildSearchBar(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildFilterSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  Expanded(
                    child: _filteredPayments.isEmpty
                        ? _buildEmptyState(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                        : ListView.separated(
                            padding: EdgeInsets.all(basePadding),
                            itemCount: _filteredPayments.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                            itemBuilder: (context, index) =>
                                _buildPaymentCard(
                                  _filteredPayments[index],
                                  isSmallScreen: isSmallScreen,
                                  isMediumScreen: isMediumScreen,
                                ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541) // Dark card color for better integration
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded, 
          color: Colors.white,
          size: isSmallScreen ? 18.0 : 20.0,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        t('title'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isArabic ? Icons.language : Icons.translate,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          onPressed: () {
            setState(() {
              _isArabic = !_isArabic;
              ApiService.saveLanguagePreference(_isArabic);
            });
          },
        ),
        SizedBox(width: isSmallScreen ? 4.0 : 8.0),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isSmallScreen ? 16.0 : 20.0),
        ),
      ),
    );
  }

  Widget _buildSearchBar({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        isSmallScreen ? 16.0 : 20.0, 
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        0
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: isSmallScreen ? 14.0 : 16.0,
        ),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
          prefixIcon: Icon(
            Icons.search_rounded, 
            color: AppTheme.textSecondary,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0, 
            vertical: isSmallScreen ? 12.0 : 15.0
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded, 
                    color: AppTheme.textSecondary,
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0), 
        horizontal: isSmallScreen ? 12.0 : 16.0
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, t('filterAll'), isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('completed', t('completed'), color: Colors.green, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('pending', t('pending'), color: Colors.orange, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('failed', t('failed'), color: Colors.red, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? status, String label, {Color? color, bool isSmallScreen = false, bool isMediumScreen = false}) {
    final isSelected = _statusFilter == status;
    final activeColor = color ?? AppTheme.appBarColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = status;
          _applyFilter();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
          vertical: isSmallScreen ? 6.0 : 8.0
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
          border: Border.all(
            color: isSelected
                ? activeColor
                : AppTheme.textSecondary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final status = payment['status']?.toString();
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          right: _isArabic
              ? BorderSide(color: statusColor, width: isSmallScreen ? 3.0 : 4.0)
              : BorderSide.none,
          left: !_isArabic
              ? BorderSide(color: statusColor, width: isSmallScreen ? 3.0 : 4.0)
              : BorderSide.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isSmallScreen ? 40.0 : (isMediumScreen ? 44.0 : 48.0),
                    height: isSmallScreen ? 40.0 : (isMediumScreen ? 44.0 : 48.0),
                    decoration: BoxDecoration(
                      color: AppTheme.isDarkMode
                          ? Colors.blueAccent.withOpacity(0.2)
                          : AppTheme.appBarColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.payments_rounded,
                      color: AppTheme.isDarkMode
                          ? Colors.blueAccent
                          : AppTheme.appBarColor,
                      size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${payment['amount'] ?? 0} ILS',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8.0 : 10.0, 
                                vertical: isSmallScreen ? 3.0 : 4.0
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                              ),
                              child: Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                        Row(
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: isSmallScreen ? 12.0 : 14.0, 
                              color: AppTheme.textSecondary
                            ),
                            SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                            Text(
                              payment['method']?.toString().toUpperCase() ??
                                  'CASH',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                            Icon(
                              Icons.access_time_rounded,
                              size: isSmallScreen ? 12.0 : 14.0, 
                              color: AppTheme.textSecondary
                            ),
                            SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                            Text(
                              _formatDate(payment['time']?.toString()),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 24.0 : (isMediumScreen ? 27.0 : 30.0)),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.payments_outlined,
              size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
              color: AppTheme.isDarkMode
                  ? Colors.white24
                  : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            t('noPayments'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
