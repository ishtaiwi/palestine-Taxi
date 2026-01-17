import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_side_menu/flutter_side_menu.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';
import '../../utils/responsive_layout.dart';
import '../../widgets/reports/chart_card.dart';
import '../../widgets/reports/date_range_picker.dart';
import '../../widgets/reports/revenue_chart.dart';
import '../../widgets/reports/booking_chart.dart';
import '../../widgets/reports/trip_chart.dart';
import '../../widgets/reports/user_chart.dart';
import '../../widgets/reports/vehicle_chart.dart';
import '../../widgets/reports/line_chart.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SideMenuController _sideMenuController = SideMenuController();
  bool _isArabic = true;
  bool _comparePrevious = true;
  int _selectedTabIndex = 0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();

  // Revenue data
  Map<String, dynamic>? _revenueData;
  bool _revenueLoading = false;
  String? _revenueError;

  // Booking data
  Map<String, dynamic>? _bookingData;
  bool _bookingLoading = false;
  String? _bookingError;

  // Trip data
  Map<String, dynamic>? _tripData;
  bool _tripLoading = false;
  String? _tripError;

  // User data
  Map<String, dynamic>? _userData;
  bool _userLoading = false;
  String? _userError;

  // Vehicle data
  Map<String, dynamic>? _vehicleData;
  bool _vehicleLoading = false;
  String? _vehicleError;

  // Line data
  Map<String, dynamic>? _lineData;
  bool _lineLoading = false;
  String? _lineError;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'التقارير والإحصائيات',
      'revenue': 'الإيرادات',
      'bookings': 'الحجوزات',
      'trips': 'الرحلات',
      'users': 'المستخدمين',
      'vehicles': 'المركبات',
      'lines': 'أداء الخطوط',
      'compare': 'مقارنة بالفترة السابقة',
      'analytics': 'التحليلات',
      'overview': 'نظرة عامة',
    },
    'en': {
      'title': 'Reports & Analytics',
      'revenue': 'Revenue',
      'bookings': 'Bookings',
      'trips': 'Trips',
      'users': 'Users',
      'vehicles': 'Vehicles',
      'lines': 'Line Performance',
      'compare': 'Compare with previous period',
      'analytics': 'Analytics',
      'overview': 'Overview',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init().then((_) {
      if (mounted) setState(() {});
    });
    _loadLanguagePreference();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadRevenueData(),
      _loadBookingData(),
      _loadTripData(),
      _loadUserData(),
      _loadVehicleData(),
      _loadLineData(),
    ]);
  }

  Future<void> _loadRevenueData() async {
    setState(() {
      _revenueLoading = true;
      _revenueError = null;
    });

    try {
      final groupBy =
          ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getRevenueTimeSeries(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _revenueData = data;
        _revenueLoading = false;
      });
    } catch (e) {
      setState(() {
        _revenueError = e.toString();
        _revenueLoading = false;
      });
    }
  }

  Future<void> _loadBookingData() async {
    setState(() {
      _bookingLoading = true;
      _bookingError = null;
    });

    try {
      final groupBy =
          ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getBookingTimeSeries(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _bookingData = data;
        _bookingLoading = false;
      });
    } catch (e) {
      setState(() {
        _bookingError = e.toString();
        _bookingLoading = false;
      });
    }
  }

  Future<void> _loadTripData() async {
    setState(() {
      _tripLoading = true;
      _tripError = null;
    });

    try {
      final data = await ApiService.getTripStatistics(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _tripData = data;
        _tripLoading = false;
      });
    } catch (e) {
      setState(() {
        _tripError = e.toString();
        _tripLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _userLoading = true;
      _userError = null;
    });

    try {
      final groupBy =
          ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getUserGrowth(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _userData = data;
        _userLoading = false;
      });
    } catch (e) {
      setState(() {
        _userError = e.toString();
        _userLoading = false;
      });
    }
  }

  Future<void> _loadVehicleData() async {
    setState(() {
      _vehicleLoading = true;
      _vehicleError = null;
    });

    try {
      final data = await ApiService.getVehicleUtilization(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _vehicleData = data;
        _vehicleLoading = false;
      });
    } catch (e) {
      setState(() {
        _vehicleError = e.toString();
        _vehicleLoading = false;
      });
    }
  }

  Future<void> _loadLineData() async {
    setState(() {
      _lineLoading = true;
      _lineError = null;
    });

    try {
      final data = await ApiService.getLinePerformance(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        comparePrevious: _comparePrevious,
      );
      setState(() {
        _lineData = data;
        _lineLoading = false;
      });
    } catch (e) {
      setState(() {
        _lineError = e.toString();
        _lineLoading = false;
      });
    }
  }

  void _onDateRangeChanged(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadAllData();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTabIndex = index;
      _tabController.animateTo(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final isDark = AppTheme.isDarkMode;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0E21) : const Color(0xFFECF0F3),
        appBar: _buildAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                ResponsiveBreakpoints.isDesktopWidth(constraints.maxWidth) &&
                    kIsWeb;

            if (isDesktop) {
              return _buildDesktopLayout(isDark);
            }
            return _buildMobileLayout(isDark);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = AppTheme.isDarkMode;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      backgroundColor:
          isDark ? const Color(0xFF1C2541) : const Color(0xFF2C5F8D),
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        // Compare toggle button
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 18,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 6),
              Text(
                _isArabic ? 'مقارنة' : 'Compare',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: _comparePrevious,
                onChanged: (value) {
                  setState(() => _comparePrevious = value);
                  _loadAllData();
                },
                activeColor: Colors.greenAccent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  /// Desktop layout with side navigation
  Widget _buildDesktopLayout(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1C2541) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondary =
        isDark ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);

    return Row(
      children: [
        // Side menu for report navigation
        SideMenu(
          controller: _sideMenuController,
          mode: SideMenuMode.auto,
          hasResizer: true,
          minWidth: 60,
          maxWidth: 220,
          backgroundColor:
              isDark ? const Color(0xFF101426) : const Color(0xFFE3E7EE),
          builder: (data) => SideMenuData(
            header: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 120;
                final labelColor =
                    isDark ? Colors.white : const Color(0xFF1E3A5F);

                if (isCompact) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Icon(Icons.bar_chart_rounded, color: labelColor),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.shade400,
                              Colors.purple.shade700
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('analytics'),
                          style: TextStyle(
                            color: labelColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            items: [
              _buildSideMenuItem(
                  0, Icons.attach_money_rounded, t('revenue'), Colors.green),
              _buildSideMenuItem(
                  1, Icons.book_online_rounded, t('bookings'), Colors.blue),
              _buildSideMenuItem(
                  2, Icons.route_rounded, t('trips'), Colors.purple),
              _buildSideMenuItem(
                  3, Icons.people_rounded, t('users'), Colors.orange),
              _buildSideMenuItem(
                  4, Icons.directions_bus_rounded, t('vehicles'), Colors.teal),
              _buildSideMenuItem(
                  5, Icons.timeline_rounded, t('lines'), Colors.red),
            ],
            footer: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 120) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_startDate.day}/${_startDate.month} - ${_endDate.day}/${_endDate.month}',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Main content area
        Expanded(
          child: Column(
            children: [
              // Date range header
              _buildDesktopHeader(cardColor, textPrimary, textSecondary),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _buildDesktopContent(
                      cardColor, textPrimary, textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  SideMenuItemDataTile _buildSideMenuItem(
      int index, IconData icon, String title, Color color) {
    final isDark = AppTheme.isDarkMode;
    final isSelected = _selectedTabIndex == index;

    return SideMenuItemDataTile(
      isSelected: isSelected,
      title: title,
      titleStyle: TextStyle(
        color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      icon: Icon(
        icon,
        color: isSelected ? color : (isDark ? Colors.white54 : Colors.black54),
      ),
      selectedIcon: Icon(icon, color: color),
      highlightSelectedColor: color.withOpacity(0.15),
      onTap: () => _onTabChanged(index),
    );
  }

  Widget _buildDesktopHeader(
      Color cardColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.isDarkMode ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Current report title (compact)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getTabColor(_selectedTabIndex).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_getTabIconData(_selectedTabIndex),
                color: _getTabColor(_selectedTabIndex), size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            _getTabTitle(_selectedTabIndex),
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),

          // Compact date range picker
          Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _onDateRangeChanged,
              isArabic: _isArabic,
              isCompact: true,
            ),
          ),

          const SizedBox(width: 8),

          // Refresh button
          IconButton(
            onPressed: _loadAllData,
            icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 20),
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTabIconData(int index) {
    final icons = [
      Icons.attach_money_rounded,
      Icons.book_online_rounded,
      Icons.route_rounded,
      Icons.people_rounded,
      Icons.directions_bus_rounded,
      Icons.timeline_rounded,
    ];
    return icons[index];
  }

  Color _getTabColor(int index) {
    final colors = [
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.red,
    ];
    return colors[index];
  }

  String _getTabTitle(int index) {
    final titles = [
      t('revenue'),
      t('bookings'),
      t('trips'),
      t('users'),
      t('vehicles'),
      t('lines')
    ];
    return titles[index];
  }

  Widget _buildDesktopContent(
      Color cardColor, Color textPrimary, Color textSecondary) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildRevenueDesktop(cardColor, textPrimary);
      case 1:
        return _buildBookingDesktop(cardColor, textPrimary);
      case 2:
        return _buildTripDesktop(cardColor, textPrimary);
      case 3:
        return _buildUserDesktop(cardColor, textPrimary);
      case 4:
        return _buildVehicleDesktop(cardColor, textPrimary);
      case 5:
        return _buildLineDesktop(cardColor, textPrimary);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDesktopCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
    bool isLoading = false,
    String? errorMessage,
    VoidCallback? onRetry,
  }) {
    final isDark = AppTheme.isDarkMode;
    final cardColor = isDark ? const Color(0xFF1C2541) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1E3A5F);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Content
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (errorMessage != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load',
                    style: TextStyle(color: textPrimary, fontSize: 12),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            child,
        ],
      ),
    );
  }

  // Desktop content builders - Compact layout
  Widget _buildRevenueDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildDesktopCard(
            title: _isArabic ? 'الإيرادات بمرور الوقت' : 'Revenue Over Time',
            icon: Icons.trending_up_rounded,
            accentColor: Colors.green,
            isLoading: _revenueLoading,
            errorMessage: _revenueError,
            onRetry: _loadRevenueData,
            child: _revenueData != null
                ? RevenueChart(
                    data: _revenueData!,
                    isArabic: _isArabic,
                    showComparison: _comparePrevious)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildDesktopCard(
            title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
            icon: Icons.pie_chart_rounded,
            accentColor: Colors.teal,
            isLoading: _revenueLoading,
            errorMessage: _revenueError,
            onRetry: _loadRevenueData,
            child: _revenueData != null
                ? RevenueByLineChart(data: _revenueData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildDesktopCard(
            title: _isArabic ? 'الحجوزات بمرور الوقت' : 'Bookings Over Time',
            icon: Icons.calendar_month_rounded,
            accentColor: Colors.blue,
            isLoading: _bookingLoading,
            errorMessage: _bookingError,
            onRetry: _loadBookingData,
            child: _bookingData != null
                ? BookingTimeSeriesChart(
                    data: _bookingData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildDesktopCard(
            title: _isArabic ? 'الحجوزات حسب الحالة' : 'Bookings by Status',
            icon: Icons.donut_large_rounded,
            accentColor: Colors.indigo,
            isLoading: _bookingLoading,
            errorMessage: _bookingError,
            onRetry: _loadBookingData,
            child: _bookingData != null
                ? BookingByStatusChart(data: _bookingData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildTripDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildDesktopCard(
            title: _isArabic ? 'الرحلات بمرور الوقت' : 'Trips Over Time',
            icon: Icons.route_rounded,
            accentColor: Colors.purple,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? TripTimeSeriesChart(data: _tripData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDesktopCard(
            title: _isArabic ? 'حالة الرحلات' : 'Trip Status',
            icon: Icons.data_usage_rounded,
            accentColor: Colors.deepPurple,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? TripStatusChart(
                    data: _tripData!, isArabic: _isArabic, showAsDonut: true)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDesktopCard(
            title: _isArabic ? 'الاستخدام' : 'Utilization',
            icon: Icons.speed_rounded,
            accentColor: Colors.orange,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? UtilizationGaugeChart(
                    data: _tripData!,
                    isArabic: _isArabic,
                    showTrend: _comparePrevious)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildUserDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildDesktopCard(
            title: _isArabic ? 'نمو المستخدمين' : 'User Growth',
            icon: Icons.group_add_rounded,
            accentColor: Colors.orange,
            isLoading: _userLoading,
            errorMessage: _userError,
            onRetry: _loadUserData,
            child: _userData != null
                ? UserGrowthChart(data: _userData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildDesktopCard(
            title: _isArabic ? 'المستخدمين حسب الدور' : 'Users by Role',
            icon: Icons.people_alt_rounded,
            accentColor: Colors.deepOrange,
            isLoading: _userLoading,
            errorMessage: _userError,
            onRetry: _loadUserData,
            child: _userData != null
                ? UserByRoleChart(data: _userData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildDesktopCard(
            title: _isArabic ? 'استخدام المركبات' : 'Vehicle Utilization',
            icon: Icons.directions_bus_rounded,
            accentColor: Colors.teal,
            isLoading: _vehicleLoading,
            errorMessage: _vehicleError,
            onRetry: _loadVehicleData,
            child: _vehicleData != null
                ? VehicleUtilizationChart(
                    data: _vehicleData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildDesktopCard(
            title: _isArabic ? 'حالة المركبات' : 'Vehicle Status',
            icon: Icons.local_shipping_rounded,
            accentColor: Colors.cyan,
            isLoading: _vehicleLoading,
            errorMessage: _vehicleError,
            onRetry: _loadVehicleData,
            child: _vehicleData != null
                ? VehicleStatusChart(data: _vehicleData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildLineDesktop(Color cardColor, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDesktopCard(
            title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
            icon: Icons.show_chart_rounded,
            accentColor: Colors.green,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LinePerformanceChart(
                    data: _lineData!,
                    metric: 'revenue',
                    isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDesktopCard(
            title: _isArabic ? 'الحجوزات حسب الخط' : 'Bookings by Line',
            icon: Icons.bar_chart_rounded,
            accentColor: Colors.blue,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LinePerformanceChart(
                    data: _lineData!,
                    metric: 'bookings',
                    isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDesktopCard(
            title: _isArabic ? 'ترتيب الخطوط' : 'Line Rankings',
            icon: Icons.leaderboard_rounded,
            accentColor: Colors.amber,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LineRankingTable(data: _lineData!, isArabic: _isArabic)
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Mobile layout with tabs
  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: isDark ? const Color(0xFF1C2541) : const Color(0xFF2C5F8D),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(text: t('revenue')),
              Tab(text: t('bookings')),
              Tab(text: t('trips')),
              Tab(text: t('users')),
              Tab(text: t('vehicles')),
              Tab(text: t('lines')),
            ],
          ),
        ),

        // Date range
        Padding(
          padding: const EdgeInsets.all(16),
          child: DateRangePicker(
            startDate: _startDate,
            endDate: _endDate,
            onDateRangeChanged: _onDateRangeChanged,
            isArabic: _isArabic,
          ),
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRevenueTab(),
              _buildBookingTab(),
              _buildTripTab(),
              _buildUserTab(),
              _buildVehicleTab(),
              _buildLineTab(),
            ],
          ),
        ),
      ],
    );
  }

  // Mobile tab builders (simplified versions)
  Widget _buildRevenueTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'الإيرادات بمرور الوقت' : 'Revenue Over Time',
        icon: Icons.trending_up_rounded,
        isLoading: _revenueLoading,
        errorMessage: _revenueError,
        onRetry: _loadRevenueData,
        child: _revenueData != null
            ? RevenueChart(
                data: _revenueData!,
                isArabic: _isArabic,
                showComparison: _comparePrevious)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
        icon: Icons.pie_chart_rounded,
        isLoading: _revenueLoading,
        errorMessage: _revenueError,
        onRetry: _loadRevenueData,
        child: _revenueData != null
            ? RevenueByLineChart(data: _revenueData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildBookingTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'الحجوزات بمرور الوقت' : 'Bookings Over Time',
        icon: Icons.calendar_month_rounded,
        isLoading: _bookingLoading,
        errorMessage: _bookingError,
        onRetry: _loadBookingData,
        child: _bookingData != null
            ? BookingTimeSeriesChart(data: _bookingData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'الحجوزات حسب الحالة' : 'Bookings by Status',
        icon: Icons.donut_large_rounded,
        isLoading: _bookingLoading,
        errorMessage: _bookingError,
        onRetry: _loadBookingData,
        child: _bookingData != null
            ? BookingByStatusChart(data: _bookingData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildTripTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'الرحلات بمرور الوقت' : 'Trips Over Time',
        icon: Icons.route_rounded,
        isLoading: _tripLoading,
        errorMessage: _tripError,
        onRetry: _loadTripData,
        child: _tripData != null
            ? TripTimeSeriesChart(data: _tripData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'حالة الرحلات' : 'Trip Status',
        icon: Icons.data_usage_rounded,
        isLoading: _tripLoading,
        errorMessage: _tripError,
        onRetry: _loadTripData,
        child: _tripData != null
            ? TripStatusChart(
                data: _tripData!, isArabic: _isArabic, showAsDonut: true)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'متوسط الاستخدام' : 'Utilization',
        icon: Icons.speed_rounded,
        isLoading: _tripLoading,
        errorMessage: _tripError,
        onRetry: _loadTripData,
        child: _tripData != null
            ? UtilizationGaugeChart(
                data: _tripData!,
                isArabic: _isArabic,
                showTrend: _comparePrevious)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildUserTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'نمو المستخدمين' : 'User Growth',
        icon: Icons.group_add_rounded,
        isLoading: _userLoading,
        errorMessage: _userError,
        onRetry: _loadUserData,
        child: _userData != null
            ? UserGrowthChart(data: _userData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'المستخدمين حسب الدور' : 'Users by Role',
        icon: Icons.people_alt_rounded,
        isLoading: _userLoading,
        errorMessage: _userError,
        onRetry: _loadUserData,
        child: _userData != null
            ? UserByRoleChart(data: _userData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildVehicleTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'استخدام المركبات' : 'Vehicle Utilization',
        icon: Icons.directions_bus_rounded,
        isLoading: _vehicleLoading,
        errorMessage: _vehicleError,
        onRetry: _loadVehicleData,
        child: _vehicleData != null
            ? VehicleUtilizationChart(data: _vehicleData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'حالة المركبات' : 'Vehicle Status',
        icon: Icons.local_shipping_rounded,
        isLoading: _vehicleLoading,
        errorMessage: _vehicleError,
        onRetry: _loadVehicleData,
        child: _vehicleData != null
            ? VehicleStatusChart(data: _vehicleData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildLineTab() {
    return _buildMobileTabContent([
      ChartCard(
        title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
        icon: Icons.show_chart_rounded,
        isLoading: _lineLoading,
        errorMessage: _lineError,
        onRetry: _loadLineData,
        child: _lineData != null
            ? LinePerformanceChart(
                data: _lineData!, metric: 'revenue', isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'الحجوزات حسب الخط' : 'Bookings by Line',
        icon: Icons.bar_chart_rounded,
        isLoading: _lineLoading,
        errorMessage: _lineError,
        onRetry: _loadLineData,
        child: _lineData != null
            ? LinePerformanceChart(
                data: _lineData!, metric: 'bookings', isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
      ChartCard(
        title: _isArabic ? 'ترتيب الخطوط' : 'Line Rankings',
        icon: Icons.leaderboard_rounded,
        isLoading: _lineLoading,
        errorMessage: _lineError,
        onRetry: _loadLineData,
        child: _lineData != null
            ? LineRankingTable(data: _lineData!, isArabic: _isArabic)
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _buildMobileTabContent(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: children
            .expand((child) => [child, const SizedBox(height: 16)])
            .take(children.length * 2 - 1)
            .toList(),
      ),
    );
  }
}
