import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_book_trip_page.dart';
import 'passenger_home.dart';
import 'passenger_future_reservation_page.dart';
import 'package:taxi_palestine_app/utils/server_time_sync.dart';

class PassengerTripsPage extends StatefulWidget {
  final String? initialLineId;

  const PassengerTripsPage({super.key, this.initialLineId});

  @override
  State<PassengerTripsPage> createState() => _PassengerTripsPageState();
}

class _PassengerTripsPageState extends State<PassengerTripsPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false; // Light mode as default
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _lines = [];
  bool _isLineDropdownOpen = false;
  String? _selectedLineId;

  final TextEditingController _lineSearchController = TextEditingController();
  String _lineSearchQuery = '';

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الرحلات المتاحة',
      'subtitle': 'اختر رحلة واحجز مقعدك',
      'noTrips': 'لا توجد رحلات متاحة حالياً',
      'filterByLine': 'فلترة حسب الخط',
      'filterByDate': 'فلترة حسب التاريخ',
      'allLines': 'جميع الخطوط',
      'searchLine': 'بحث باسم الخط',
      'departure': 'موعد الانطلاق',
      'availableSeats': 'المقاعد المتاحة',
      'available': 'متاح',
      'notAvailable': 'غير متاح',
      'price': 'السعر',
      'bookNow': 'احجز الآن',
      'bookFuture': 'احجز مسبقاً',
      'refresh': 'تحديث',
      'error': 'حدث خطأ',
      'loading': 'جاري التحميل...',
      'tripNotOpenedYet': 'الحجز متاح فقط في الوقت المحدد',
      'tripOpensAt': 'الحجز متاح من الساعة',
      'tripHasDriver': 'الرحلة لديها سائق',
    },
    'en': {
      'title': 'Available Trips',
      'subtitle': 'Select a trip and book your seat',
      'noTrips': 'No trips available at the moment',
      'filterByLine': 'Filter by Line',
      'filterByDate': 'Filter by Date',
      'allLines': 'All Lines',
      'searchLine': 'Search by line name',
      'departure': 'Departure Time',
      'availableSeats': 'Available Seats',
      'available': 'Available',
      'notAvailable': 'Not Available',
      'price': 'Price',
      'bookNow': 'Book Now',
      'bookFuture': 'Book Future',
      'refresh': 'Refresh',
      'error': 'An error occurred',
      'loading': 'Loading...',
      'tripNotOpenedYet': 'Booking is only available at the specified time',
      'tripOpensAt': 'Booking opens at',
      'tripHasDriver': 'Trip has driver',
    },
  };

  String t(String key) {
    final lang = _isArabic ? 'ar' : 'en';
    final texts = _texts[lang];
    if (texts == null || !texts.containsKey(key)) {
      return key; // Return key as fallback
    }
    return texts[key]!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLineId != null) {
      _selectedLineId = widget.initialLineId;
    }
    _initialize();
  }

  @override
  void dispose() {
    _lineSearchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadThemePreference();
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
    await _loadLines();
    await _loadTrips();
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadLines() async {
    try {
      final lines = await ApiService.fetchActiveLines();
      if (mounted) {
        setState(() {
          _lines = lines;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trips = await ApiService.fetchUpcomingTrips(
        lineid: _selectedLineId,
      );
      
      if (mounted) {
        setState(() {
          _trips = trips;
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


  String _getLineNameById(String lineId) {
    try {
      final line = _lines.firstWhere(
        (l) => l['lineid']?.toString() == lineId,
        orElse: () => {},
      );
      if (line.isEmpty) return _isArabic ? 'غير معروف' : 'Unknown';

      return _isArabic
          ? (line['name_ar']?.toString() ??
              line['linename']?.toString() ??
              line['name_en']?.toString() ??
              (_isArabic ? 'غير معروف' : 'Unknown'))
          : (line['name_en']?.toString() ??
              line['linename']?.toString() ??
              line['name_ar']?.toString() ??
              (_isArabic ? 'غير معروف' : 'Unknown'));
    } catch (_) {
      return _isArabic ? 'غير معروف' : 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
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
    final double cardPadding = isWeb
        ? (isDesktop ? 24.0 : (isTablet ? 20.0 : 18.0))
        : (isSmallScreen ? 14.0 : (isMediumScreen ? 18.0 : 20.0));
    final double titleFontSize = isWeb
        ? (isDesktop ? 24.0 : 22.0)
        : (isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0));
    final double iconSize = isWeb
        ? (isDesktop ? 28.0 : 24.0)
        : (isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;

    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color(0xFFECF0F3); // Soft blue-gray background

    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC); // Off-white with cool tint

    final textPrimary = _isDarkMode
        ? const Color(0xFFE8EAF6)
        : const Color(0xFF1E3A5F); // Dark navy for light mode

    final textSecondary = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A); // Medium gray-blue

    final appBarColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFF2C5F8D); // Professional blue

    const accentColor = Color(0xFFF57C00); // Orange accent

    final List<Map<String, dynamic>> filteredLines = _lines.where((line) {
      if (_lineSearchQuery.isEmpty) return true;

      final lineName = _isArabic
          ? (line['name_ar']?.toString() ??
              line['linename']?.toString() ??
              line['name_en']?.toString() ??
              '')
          : (line['name_en']?.toString() ??
              line['linename']?.toString() ??
              line['name_ar']?.toString() ??
              '');

      return lineName.toLowerCase().contains(_lineSearchQuery.toLowerCase());
    }).toList();

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
                    onPressed: _loadTrips,
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
                  Container(
                    padding: EdgeInsets.all(basePadding),
                decoration: BoxDecoration(
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _isLineDropdownOpen = !_isLineDropdownOpen;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? const Color(0xFF1E3A5F).withAlpha(77)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isDarkMode
                                    ? const Color(0xFF2C5F8D)
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12.0 : 16.0, 
                                vertical: isSmallScreen ? 12.0 : 14.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.directions_bus_rounded,
                                  color: _isDarkMode
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF1E3A5F),
                                  size: iconSize,
                                ),
                                SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        t('filterByLine'),
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedLineId == null
                                            ? t('allLines')
                                            : _getLineNameById(
                                                _selectedLineId!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: isSmallScreen ? 14.0 : 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? const Color(0xFF2C5F8D)
                                            .withOpacity(0.5)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _isLineDropdownOpen
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: textPrimary,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isLineDropdownOpen) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? const Color(0xFF1E3A5F).withAlpha(200)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isDarkMode
                                    ? const Color(0xFF2C5F8D)
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: TextField(
                                    controller: _lineSearchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _lineSearchQuery = value.trim();
                                      });
                                    },
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: t('searchLine'),
                                      hintStyle: TextStyle(
                                        color: textSecondary.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: _isDarkMode
                                            ? const Color(0xFF64B5F6)
                                            : const Color(0xFF1E3A5F),
                                        size: 20,
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: _isDarkMode
                                          ? const Color(0xFF1C2541)
                                          : Colors.grey.shade50,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _isDarkMode
                                              ? const Color(0xFF2C5F8D)
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _isDarkMode
                                              ? const Color(0xFF64B5F6)
                                              : const Color(0xFF1E3A5F),
                                          width: 1.5,
                                        ),
                                      ),
                                      suffixIcon: _lineSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: textSecondary,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _lineSearchQuery = '';
                                                  _lineSearchController.clear();
                                                });
                                              },
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 260, // fits under button
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: filteredLines.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final isSelected =
                                            _selectedLineId == null;
                                        return ListTile(
                                          leading: Icon(
                                            Icons.all_inclusive,
                                            color: isSelected
                                                ? (_isDarkMode
                                                    ? const Color(0xFF64B5F6)
                                                    : const Color(0xFF1E3A5F))
                                                : textSecondary,
                                          ),
                                          title: Text(
                                            t('allLines'),
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? (_isDarkMode
                                                      ? Colors.white
                                                      : const Color(0xFF1E3A5F))
                                                  : textPrimary,
                                            ),
                                          ),
                                          trailing: isSelected
                                              ? Icon(
                                                  Icons.check_circle_rounded,
                                                  color: _isDarkMode
                                                      ? const Color(0xFF64B5F6)
                                                      : const Color(0xFF1E3A5F),
                                                )
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _selectedLineId = null;
                                              _isLineDropdownOpen = false;
                                              _lineSearchQuery = '';
                                              _lineSearchController.clear();
                                            });
                                            _loadTrips();
                                          },
                                        );
                                      }

                                      final line =
                                          filteredLines[index - 1]; // offset
                                      final lineId = line['lineid']?.toString();
                                      final lineName = _isArabic
                                          ? (line['name_ar']?.toString() ??
                                              line['linename']?.toString() ??
                                              line['name_en']?.toString() ??
                                              '')
                                          : (line['name_en']?.toString() ??
                                              line['linename']?.toString() ??
                                              line['name_ar']?.toString() ??
                                              '');
                                      final isSelected =
                                          _selectedLineId == lineId;

                                      return ListTile(
                                        leading: Icon(
                                          Icons.directions_bus,
                                          color: isSelected
                                              ? (_isDarkMode
                                                  ? const Color(0xFF64B5F6)
                                                  : const Color(0xFF1E3A5F))
                                              : textSecondary,
                                        ),
                                        title: Text(
                                          lineName.isEmpty
                                              ? (_isArabic
                                                  ? 'غير معروف'
                                                  : 'Unknown')
                                              : lineName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? (_isDarkMode
                                                    ? Colors.white
                                                    : const Color(0xFF1E3A5F))
                                                : textPrimary,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: _isDarkMode
                                                    ? const Color(0xFF64B5F6)
                                                    : const Color(0xFF1E3A5F),
                                              )
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedLineId = lineId;
                                            _isLineDropdownOpen = false;
                                          });
                                          _loadTrips();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PassengerFutureReservationPage(),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _loadTrips();
                          }
                        });
                      },
                      icon: Icon(Icons.calendar_today, size: isSmallScreen ? 18.0 : 20.0),
                      label: Text(
                        _isArabic ? 'حجز مستقبلي' : 'Future Reservation',
                        style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF57C00),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16.0 : 20.0,
                          vertical: isSmallScreen ? 12.0 : 16.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadTrips,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C5F8D),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(t('refresh'),
                                      style:
                                          const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : _trips.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions_bus,
                                        color: textSecondary, size: 64),
                                    const SizedBox(height: 16),
                                    Text(
                                      t('noTrips'),
                                      style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )
                            : isWeb && (isDesktop || isTablet)
                                ? GridView.builder(
                                    padding: EdgeInsets.all(basePadding),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: isDesktop ? 3 : 2,
                                      crossAxisSpacing: 16.0,
                                      mainAxisSpacing: 16.0,
                                      childAspectRatio: isDesktop ? 0.85 : 0.9,
                                    ),
                                    itemCount: _trips.length,
                                    itemBuilder: (context, index) {
                                      return _buildTripCard(_trips[index], isSmallScreen, isMediumScreen, isWeb);
                                    },
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.all(basePadding),
                                    itemCount: _trips.length,
                                    itemBuilder: (context, index) {
                                      return _buildTripCard(_trips[index], isSmallScreen, isMediumScreen, isWeb);
                                    },
                                  ),
                ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 0, // View Trips is index 0
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            PassengerBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, bool isSmallScreen, bool isMediumScreen, bool isWeb) {
    final line = trip['line'] as Map<String, dynamic>? ?? {};
    final lineName = _isArabic
        ? (line['name_ar']?.toString() ??
            line['linename']?.toString() ??
            line['name_en']?.toString() ??
            '')
        : (line['name_en']?.toString() ??
            line['linename']?.toString() ??
            line['name_ar']?.toString() ??
            '');
    final deptime = trip['deptime']?.toString() ?? '';
    final availableseats = trip['availableseats'] ?? 0;
    final baseprice = line['baseprice'] ?? 0.0;
    final tripid = trip['tripid']?.toString() ?? '';
    final status = trip['status']?.toString() ?? '';
    // Use backend-computed flags instead of calculating locally
    // Backend handles all timezone logic and returns boolean flags
    final canBookInstantBackend = trip['canBookInstant'] as bool? ?? false;
    
    // Check if trip has an assigned driver
    final vehicleid = trip['vehicleid'];
    final assignedDriverid = trip['assigned_driverid'];
    final hasAssignedDriver = vehicleid != null || assignedDriverid != null;

    // Parse UTC times for display only (convert to device local timezone)
    // Supabase returns timestamps like "2025-12-23 21:00:00+00" - normalize to ISO format
    DateTime? departureTime;
    try {
      if (deptime.isNotEmpty) {
        // Normalize Supabase timestamp format to ISO 8601
        String normalized = deptime.toString();
        // Replace space with T
        normalized = normalized.replaceFirst(' ', 'T');
        // Replace +00 or +00:00 with Z (UTC indicator)
        normalized = normalized.replaceFirst(RegExp(r'\+00:?00?$'), 'Z');
        // If no timezone, assume UTC
        if (!normalized.contains('Z') &&
            !normalized.contains('+') &&
            !normalized.contains('-')) {
          normalized += 'Z';
        }
        departureTime = DateTime.parse(normalized).toLocal();
      }
    } catch (e) {
      // Ignore parse errors
      debugPrint('Error parsing deptime: $deptime, error: $e');
    }

    DateTime? tripOpeningTime;
    final tripOpeningTimeStr = trip['trip_opening_time']?.toString();
    if (tripOpeningTimeStr != null && tripOpeningTimeStr.isNotEmpty) {
      try {
        // Normalize Supabase timestamp format to ISO 8601
        String normalized = tripOpeningTimeStr;
        normalized = normalized.replaceFirst(' ', 'T');
        normalized = normalized.replaceFirst(RegExp(r'\+00:?00?$'), 'Z');
        if (!normalized.contains('Z') &&
            !normalized.contains('+') &&
            !normalized.contains('-')) {
          normalized += 'Z';
        }
        tripOpeningTime = DateTime.parse(normalized).toLocal();
      } catch (e) {
        // Ignore parse errors
        debugPrint(
            'Error parsing trip_opening_time: $tripOpeningTimeStr, error: $e');
      }
    }

    final isScheduled = status == 'scheduled' || status == 'open';

    // Use backend flag for instant booking (backend already checked status, opening time, and seats)
    final canBookInstant = canBookInstantBackend;

    final canBookFuture = isScheduled;

    final cardColor =
        _isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);

    final textPrimary =
        _isDarkMode ? const Color(0xFFE8EAF6) : const Color(0xFF1E3A5F);

    final borderColor =
        _isDarkMode ? const Color(0xFF2C3E50) : Colors.grey.shade200;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12.0 : 18.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57C00).withAlpha(51),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                              ),
                              child: Icon(
                                Icons.directions_bus,
                                color: const Color(0xFFF57C00),
                                size: isSmallScreen ? 16.0 : 20.0,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                            Expanded(
                              child: Text(
                                lineName,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                color: const Color(0xFF1E3A5F),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                departureTime != null
                                    ? '${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}'
                                    : deptime,
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10.0 : 14.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF57C00),
                          Color(0xFFE65100),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF57C00).withAlpha(102),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${baseprice.toStringAsFixed(2)} ₪',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 19.0 : 22.0),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          t('price'),
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: isSmallScreen ? 9.0 : 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: canBookFuture
                          ? Colors.green.withAlpha(51)
                          : Colors.red.withAlpha(51),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canBookFuture
                            ? Colors.green.withAlpha(102)
                            : Colors.red.withAlpha(102),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canBookFuture ? Icons.check_circle : Icons.cancel,
                          color: canBookFuture ? Colors.green : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canBookFuture ? t('available') : t('notAvailable'),
                          style: TextStyle(
                            color: canBookFuture ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Show if trip has assigned driver (only for open trips)
                  if (canBookInstant && hasAssignedDriver)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(51),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withAlpha(102),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.drive_eta_rounded,
                            color: Colors.green,
                            size: isSmallScreen ? 16 : 18,
                          ),
                          SizedBox(width: isSmallScreen ? 4 : 6),
                          Text(
                            t('tripHasDriver'),
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 10 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 18.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (canBookInstant) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PassengerBookTripPage(tripId: tripid),
                            ),
                          ).then((_) => _loadTrips());
                        } else {
                          DateTime? openingTime;
                          if (tripOpeningTime != null) {
                            openingTime = tripOpeningTime;
                          } else if (departureTime != null) {
                            openingTime = departureTime
                                .subtract(const Duration(minutes: 45));
                          }

                          String message;
                          if (openingTime != null) {
                            final hour =
                                openingTime.hour.toString().padLeft(2, '0');
                            final minute =
                                openingTime.minute.toString().padLeft(2, '0');
                            message = '${t('tripOpensAt')} $hour:$minute';
                          } else {
                            message = t('tripNotOpenedYet');
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        canBookInstant ? Icons.flash_on : Icons.schedule,
                        size: isSmallScreen ? 16.0 : 18.0,
                      ),
                      label: Text(t('bookNow'), style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: canBookInstant
                            ? Colors.white
                            : Colors.orange.withOpacity(0.8),
                        backgroundColor: canBookInstant
                            ? Colors.blue
                            : Colors.orange.withOpacity(0.1),
                        side: BorderSide(
                          color: canBookInstant
                              ? Colors.white70
                              : Colors.orange.withOpacity(0.5),
                          width: canBookInstant ? 1.5 : 2,
                        ),
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.0 : 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canBookFuture
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PassengerBookTripPage(
                                    tripId: tripid,
                                    lineId: line['lineid']?.toString(),
                                    bookingType: 'future',
                                    scheduledTripTime: deptime,
                                  ),
                                ),
                              ).then((_) => _loadTrips());
                            }
                          : null,
                      icon: Icon(Icons.calendar_today, size: isSmallScreen ? 16.0 : 18.0),
                      label: Text(t('bookFuture'), style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0)),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF57C00),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10.0 : 14.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                        ),
                        elevation: 4,
                      ),
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
}
