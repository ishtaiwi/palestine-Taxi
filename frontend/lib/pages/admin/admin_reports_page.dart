import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';
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
  bool _isArabic = true;

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
      'title': 'التقارير',
      'revenue': 'الإيرادات',
      'bookings': 'الحجوزات',
      'trips': 'الرحلات',
      'users': 'المستخدمين',
      'vehicles': 'المركبات',
      'lines': 'أداء الخطوط',
    },
    'en': {
      'title': 'Reports',
      'revenue': 'Revenue',
      'bookings': 'Bookings',
      'trips': 'Trips',
      'users': 'Users',
      'vehicles': 'Vehicles',
      'lines': 'Line Performance',
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
      final groupBy = ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getRevenueTimeSeries(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
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
      final groupBy = ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getBookingTimeSeries(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
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
      final groupBy = ReportDataProcessor.determineGroupBy(_startDate, _endDate);
      final data = await ApiService.getUserGrowth(
        startDate: _startDate.toIso8601String(),
        endDate: _endDate.toIso8601String(),
        groupBy: groupBy,
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

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          t('title'),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
          ),
        ),
        backgroundColor: AppTheme.isDarkMode
            ? const Color(0xFF1C2541)
            : AppTheme.appBarColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(isSmallScreen ? 16.0 : 20.0),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: isSmallScreen ? 2.5 : 3.0,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0)
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal, 
            fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0)
          ),
          labelPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 10.0 : (isMediumScreen ? 12.0 : 16.0)
          ),
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
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(basePadding),
              child: DateRangePicker(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeChanged: _onDateRangeChanged,
                isArabic: _isArabic,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRevenueTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildBookingTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildTripTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildUserTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildVehicleTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildLineTab(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
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
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          ChartCard(
            title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
            icon: Icons.pie_chart_rounded,
            isLoading: _revenueLoading,
            errorMessage: _revenueError,
            onRetry: _loadRevenueData,
            child: _revenueData != null
                ? RevenueByLineChart(
                    data: _revenueData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
          ChartCard(
            title: _isArabic ? 'الحجوزات بمرور الوقت' : 'Bookings Over Time',
            icon: Icons.calendar_month_rounded,
            isLoading: _bookingLoading,
            errorMessage: _bookingError,
            onRetry: _loadBookingData,
            child: _bookingData != null
                ? BookingTimeSeriesChart(
                    data: _bookingData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'الحجوزات حسب الحالة' : 'Bookings by Status',
            icon: Icons.donut_large_rounded,
            isLoading: _bookingLoading,
            errorMessage: _bookingError,
            onRetry: _loadBookingData,
            child: _bookingData != null
                ? BookingByStatusChart(
                    data: _bookingData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTripTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
          ChartCard(
            title: _isArabic ? 'الرحلات بمرور الوقت' : 'Trips Over Time',
            icon: Icons.route_rounded,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? TripTimeSeriesChart(
                    data: _tripData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'حالة الرحلات' : 'Trip Status',
            icon: Icons.data_usage_rounded,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? TripStatusChart(
                    data: _tripData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'متوسط الاستخدام' : 'Average Utilization',
            icon: Icons.speed_rounded,
            isLoading: _tripLoading,
            errorMessage: _tripError,
            onRetry: _loadTripData,
            child: _tripData != null
                ? UtilizationGaugeChart(
                    data: _tripData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
          ChartCard(
            title: _isArabic ? 'نمو المستخدمين' : 'User Growth',
            icon: Icons.group_add_rounded,
            isLoading: _userLoading,
            errorMessage: _userError,
            onRetry: _loadUserData,
            child: _userData != null
                ? UserGrowthChart(
                    data: _userData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'المستخدمين حسب الدور' : 'Users by Role',
            icon: Icons.people_alt_rounded,
            isLoading: _userLoading,
            errorMessage: _userError,
            onRetry: _loadUserData,
            child: _userData != null
                ? UserByRoleChart(
                    data: _userData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
          ChartCard(
            title: _isArabic ? 'استخدام المركبات' : 'Vehicle Utilization',
            icon: Icons.directions_bus_rounded,
            isLoading: _vehicleLoading,
            errorMessage: _vehicleError,
            onRetry: _loadVehicleData,
            child: _vehicleData != null
                ? VehicleUtilizationChart(
                    data: _vehicleData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'حالة المركبات' : 'Vehicle Status',
            icon: Icons.local_shipping_rounded,
            isLoading: _vehicleLoading,
            errorMessage: _vehicleError,
            onRetry: _loadVehicleData,
            child: _vehicleData != null
                ? VehicleStatusChart(
                    data: _vehicleData!,
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineTab({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      child: Column(
        children: [
          ChartCard(
            title: _isArabic ? 'الإيرادات حسب الخط' : 'Revenue by Line',
            icon: Icons.show_chart_rounded,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LinePerformanceChart(
                    data: _lineData!,
                    metric: 'revenue',
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'الحجوزات حسب الخط' : 'Bookings by Line',
            icon: Icons.bar_chart_rounded,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LinePerformanceChart(
                    data: _lineData!,
                    metric: 'bookings',
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          ChartCard(
            title: _isArabic ? 'الاستخدام حسب الخط' : 'Utilization by Line',
            icon: Icons.stacked_line_chart_rounded,
            isLoading: _lineLoading,
            errorMessage: _lineError,
            onRetry: _loadLineData,
            child: _lineData != null
                ? LinePerformanceChart(
                    data: _lineData!,
                    metric: 'utilization',
                    isArabic: _isArabic,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

