import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import 'driver_home.dart';
import 'driver_navigation_page.dart';
import 'qr_scanner_page.dart';

class DriverTripsPage extends StatefulWidget {
  const DriverTripsPage({super.key});

  @override
  State<DriverTripsPage> createState() => _DriverTripsPageState();
}

class _DriverTripsPageState extends State<DriverTripsPage> {
  bool _isArabic = true;
  bool _isDarkMode = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  final Map<String, List<Map<String, dynamic>>> _reservations = {};
  final Set<String> _loadingReservations = {};
  final Set<String> _mutatingReservations = {};

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'رحلاتي',
      'subtitle': 'تابع رحلاتك القادمة وطلبات الركاب',
      'noTrips': 'لا توجد رحلات قادمة حالياً',
      'departure': 'موعد الانطلاق',
      'line': 'الخط',
      'status': 'الحالة',
      'seats': 'المقاعد المتاحة',
      'bookings': 'الحجوزات',
      'reservations': 'طلبات الحجز',
      'passenger': 'الراكب',
      'seat': 'المقعد',
      'accept': 'قبول',
      'reject': 'رفض',
      'checkin': 'تأكيد الصعود',
      'pending': 'بانتظار تأكيدك',
      'approved': 'تمت الموافقة',
      'rejected': 'مرفوض',
      'none': 'لا توجد طلبات حالياً',
      'refresh': 'تحديث',
      'checkinQR': 'مسح QR Code',
      'startTrip': 'بدء الرحلة',
      'endTrip': 'إنهاء الرحلة',
      'assignedDriver': 'السائق المخصص',
      'distributedPassengers': 'الركاب الموزعين',
      'enterBookingId': 'أدخل رقم الحجز',
      'checked_in': 'تم الصعود',
      'navigate': 'الملاحة',
    },
    'en': {
      'title': 'My Trips',
      'subtitle': 'Track upcoming trips and passenger requests',
      'noTrips': 'No upcoming trips yet',
      'departure': 'Departure',
      'line': 'Line',
      'status': 'Status',
      'seats': 'Seats left',
      'bookings': 'Bookings',
      'reservations': 'Seat requests',
      'passenger': 'Passenger',
      'seat': 'Seat',
      'accept': 'Approve',
      'reject': 'Reject',
      'checkin': 'Check-in',
      'pending': 'Waiting for your approval',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'none': 'No reservations yet',
      'refresh': 'Refresh',
      'checkinQR': 'Scan QR Code',
      'startTrip': 'Start Trip',
      'endTrip': 'End Trip',
      'assignedDriver': 'Assigned Driver',
      'distributedPassengers': 'Distributed Passengers',
      'enterBookingId': 'Enter Booking ID',
      'checked_in': 'Checked In',
      'navigate': 'Navigate',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  // Get direction label with station names from line name
  // Line name format: "station1-station2" (e.g., "nablus-beit iba")
  String _getDirectionLabel(String direction, Map<String, dynamic>? line) {
    if (line == null) {
      // Fallback to default labels if line not available
      return direction == 'going'
          ? (_isArabic ? 'ذهاب' : 'Going')
          : (_isArabic ? 'عودة' : 'Return');
    }

    // Get line name (prefer name_ar for Arabic, name_en for English, fallback to linename)
    String? lineName;
    if (_isArabic) {
      lineName = line['name_ar']?.toString() ??
          line['linename']?.toString() ??
          line['name_en']?.toString();
    } else {
      lineName = line['name_en']?.toString() ??
          line['linename']?.toString() ??
          line['name_ar']?.toString();
    }

    if (lineName == null || lineName.isEmpty) {
      // Fallback to default labels if line name not available
      return direction == 'going'
          ? (_isArabic ? 'ذهاب' : 'Going')
          : (_isArabic ? 'عودة' : 'Return');
    }

    // Split line name by "-" to get station names
    final parts = lineName
        .split('-')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      // If line name doesn't have "-" separator, fallback to default labels
      return direction == 'going'
          ? (_isArabic ? 'ذهاب' : 'Going')
          : (_isArabic ? 'عودة' : 'Return');
    }

    // First part is the first station, second part is the second station
    final firstStation = parts[0];
    final secondStation = parts[1];

    String fromStation, toStation;
    if (direction == 'going') {
      // Going: From first station to second station
      fromStation = firstStation;
      toStation = secondStation;
    } else {
      // Returning: From second station to first station
      fromStation = secondStation;
      toStation = firstStation;
    }

    // Format: "From [station1] to [station2]"
    return _isArabic
        ? 'من $fromStation إلى $toStation'
        : 'From $fromStation to $toStation';
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    await AppTheme.init();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
        _isDarkMode = AppTheme.isDarkMode;
      });
    }
    await _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trips = await ApiService.fetchDriverTrips(upcomingOnly: true);
      if (!mounted) return;
      setState(() {
        _trips = trips;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReservations(String tripId) async {
    if (_loadingReservations.contains(tripId)) {
      return;
    }

    setState(() {
      _loadingReservations.add(tripId);
    });

    final result = await ApiService.fetchDriverTripReservations(tripId);
    if (!mounted) return;

    setState(() {
      _loadingReservations.remove(tripId);
      if (result['success'] == true) {
        final reservations = (result['reservations'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _reservations[tripId] = reservations;
      } else if (result['message'] != null) {
        _error = result['message'].toString();
      }
    });
  }

  Future<void> _updateReservationStatus(
      String tripId, String bookingId, String action) async {
    setState(() {
      _mutatingReservations.add(bookingId);
    });

    final result = await ApiService.updateDriverReservationStatus(
      tripId: tripId,
      bookingId: bookingId,
      action: action,
    );

    if (!mounted) return;

    setState(() {
      _mutatingReservations.remove(bookingId);
      if (result['success'] == true && result['reservation'] is Map) {
        final updated = Map<String, dynamic>.from(result['reservation']);
        final list = _reservations[tripId];
        if (list != null) {
          final index =
              list.indexWhere((item) => item['bookingid'] == bookingId);
          if (index != -1) {
            list[index] = updated;
          }
        }
        // Reload trips to get updated seat counts
        _loadTrips();
        // Reload reservations for this trip
        _loadReservations(tripId);
      } else if (result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'].toString())),
        );
      }
    });
  }

  Future<void> _checkInReservation(String bookingId) async {
    try {
      final result = await ApiService.checkInReservation(bookingId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('checkin')),
              backgroundColor: Colors.green,
            ),
          );
          // Reload trips to get updated seat counts
          _loadTrips();
          // Reload reservations
          for (final tripId in _reservations.keys) {
            _loadReservations(tripId);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCheckInDialog(String tripId) async {
    final controller = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        titlePadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          t('checkin'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
          decoration: InputDecoration(
            labelText: t('enterBookingId'),
            labelStyle: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
            hintText: 'Booking ID',
            hintStyle: TextStyle(
              color: Colors.white54,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              borderSide: const BorderSide(color: Colors.white54),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              borderSide: const BorderSide(color: Colors.white54),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              final bookingId = controller.text.trim();
              if (bookingId.isNotEmpty) {
                Navigator.pop(context);
                _checkInReservation(bookingId);
              }
            },
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16.0 : 20.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              t('checkin'),
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startTrip(String tripId, Map<String, dynamic> trip) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        titlePadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          t('startTrip'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: Text(
          _isArabic
              ? 'هل أنت متأكد من بدء هذه الرحلة؟'
              : 'Are you sure you want to start this trip?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16.0 : 20.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
            ),
            child: Text(
              t('startTrip'),
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.startTrip(tripId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('startTrip')),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to navigation page
          final line = trip['line'] as Map<String, dynamic>? ?? {};
          final lineId = line['lineid']?.toString() ?? '';
          final lineName = _isArabic
              ? (line['name_ar']?.toString() ??
                  line['linename']?.toString() ??
                  line['name_en']?.toString() ??
                  '')
              : (line['name_en']?.toString() ??
                  line['linename']?.toString() ??
                  line['name_ar']?.toString() ??
                  '');

          if (lineId.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverNavigationPage(
                  tripId: tripId,
                  lineId: lineId,
                  lineName: lineName,
                ),
              ),
            ).then((_) => _loadTrips());
          } else {
            _loadTrips();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endTrip(String tripId) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        titlePadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          t('endTrip'),
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: Text(
          _isArabic
              ? 'هل أنت متأكد من إنهاء هذه الرحلة؟'
              : 'Are you sure you want to end this trip?',
          style: TextStyle(
            color: Colors.white70,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _isArabic ? 'إلغاء' : 'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16.0 : 20.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
            ),
            child: Text(
              t('endTrip'),
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.endTrip(tripId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('endTrip')),
              backgroundColor: Colors.green,
            ),
          );
          _loadTrips();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    // Theme-aware colors
    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);

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
                  fontSize:
                      isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
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
                  margin: EdgeInsets.only(right: isSmallScreen ? 4.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded,
                        size: isSmallScreen
                            ? 20.0
                            : (isMediumScreen ? 21.0 : 22.0)),
                    onPressed: _loadTrips,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 0, // My Trips is index 0
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            DriverBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;

    // Web-specific responsive breakpoints
    final isWeb = kIsWeb;
    final isDesktop = isWeb && screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    final double basePadding = isWeb
        ? (isDesktop ? 32.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0));

    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Theme-aware colors
    final textPrimaryColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(
              isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize:
                      isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              FilledButton.tonal(
                onPressed: _loadTrips,
                child: Text(t('refresh')),
              ),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Center(
        child: Text(
          t('noTrips'),
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadTrips,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: isWeb && (isDesktop || isTablet) && _trips.isNotEmpty
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(basePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('subtitle'),
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: isWeb
                              ? (isDesktop ? 16.0 : 15.0)
                              : (isSmallScreen
                                  ? 12.0
                                  : (isMediumScreen ? 13.0 : 14.0)),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      Wrap(
                        spacing: 16.0,
                        runSpacing: 16.0,
                        children: _trips
                            .map((trip) => SizedBox(
                                  width: isDesktop
                                      ? (maxContentWidth - 64) / 2
                                      : double.infinity,
                                  child: _buildTripTile(trip,
                                      isSmallScreen: isSmallScreen,
                                      isMediumScreen: isMediumScreen,
                                      isWeb: isWeb),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(basePadding),
                  children: [
                    Text(
                      t('subtitle'),
                      style: TextStyle(
                        color: textSecondaryColor,
                        fontSize: isSmallScreen
                            ? 12.0
                            : (isMediumScreen ? 13.0 : 14.0),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                    ..._trips.map((trip) => _buildTripTile(trip,
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                        isWeb: isWeb)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTripTile(Map<String, dynamic> trip,
      {bool isSmallScreen = false,
      bool isMediumScreen = false,
      bool isWeb = false}) {
    final tripId = trip['tripid']?.toString() ?? '';
    final line = trip['line'] as Map<String, dynamic>? ?? {};
    final departureTime = _formatDateTime(trip['deptime']);
    final status = trip['status']?.toString() ?? 'scheduled';

    final cardColor =
        _isDarkMode ? const Color(0xFF1C2541) : const Color(0xFFFAFBFC);
    final textPrimaryColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    final borderColor = _isDarkMode ? Colors.white24 : Colors.grey.shade300;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white.withOpacity(0.04) : cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: borderColor),
      ),
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) {
            _loadReservations(tripId);
          }
        },
        collapsedIconColor: textPrimaryColor,
        iconColor: Colors.orange,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getDirectionLabel(
                  trip['direction']?.toString() ?? 'going', line),
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 2.0 : 4.0),
            Text(
              '${t('departure')}: $departureTime',
              style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: isSmallScreen ? 11.0 : 12.0),
            ),
            SizedBox(height: isSmallScreen ? 1.0 : 2.0),
            Text(
              '${t('status')}: $status',
              style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: isSmallScreen ? 11.0 : 12.0),
            ),
          ],
        ),
        childrenPadding: EdgeInsets.all(
            isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
        children: [
          _buildTripStatsRow(trip,
              isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          // Assigned Driver Info
          if (trip['assigned_driverid'] != null) ...[
            SizedBox(height: isSmallScreen ? 10.0 : 12.0),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person,
                      color: Colors.blue, size: isSmallScreen ? 18.0 : 20.0),
                  SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                  Text(
                    t('assignedDriver'),
                    style: TextStyle(
                      color:
                          _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
                      fontSize:
                          isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          // Trip Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QRScannerPage(tripId: tripId),
                      ),
                    ).then((_) => _loadReservations(tripId));
                  },
                  icon: Icon(
                    Icons.qr_code_scanner,
                    size: isSmallScreen ? 18.0 : 20.0,
                  ),
                  label: Text(
                    t('checkinQR'),
                    style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isDarkMode ? Colors.white : Colors.green,
                    side: const BorderSide(color: Colors.green),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8.0 : 12.0,
                      vertical: isSmallScreen ? 10.0 : 12.0,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              if (status == 'open' ||
                  status == 'scheduled' ||
                  status == 'delayed')
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _startTrip(tripId, trip),
                    icon: Icon(
                      Icons.play_arrow,
                      size: isSmallScreen ? 18.0 : 20.0,
                    ),
                    label: Text(
                      t('startTrip'),
                      style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 12.0,
                        vertical: isSmallScreen ? 10.0 : 12.0,
                      ),
                    ),
                  ),
                ),
              if (status == 'in_progress') ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final lineData =
                          trip['line'] as Map<String, dynamic>? ?? {};
                      final lineId = lineData['lineid']?.toString() ?? '';
                      final lineName = _isArabic
                          ? (lineData['name_ar']?.toString() ??
                              lineData['linename']?.toString() ??
                              lineData['name_en']?.toString() ??
                              '')
                          : (lineData['name_en']?.toString() ??
                              lineData['linename']?.toString() ??
                              lineData['name_ar']?.toString() ??
                              '');

                      if (lineId.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverNavigationPage(
                              tripId: tripId,
                              lineId: lineId,
                              lineName: lineName,
                            ),
                          ),
                        ).then((_) => _loadTrips());
                      }
                    },
                    icon: Icon(
                      Icons.navigation,
                      size: isSmallScreen ? 18.0 : 20.0,
                    ),
                    label: Text(
                      t('navigate'),
                      style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 12.0,
                        vertical: isSmallScreen ? 10.0 : 12.0,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _endTrip(tripId),
                    icon: Icon(
                      Icons.stop,
                      size: isSmallScreen ? 18.0 : 20.0,
                    ),
                    label: Text(
                      t('endTrip'),
                      style: TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 12.0,
                        vertical: isSmallScreen ? 10.0 : 12.0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          _buildReservationsSection(tripId,
              isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        ],
      ),
    );
  }

  Widget _buildTripStatsRow(Map<String, dynamic> trip,
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final availSeats = trip['availableseats']?.toString() ?? '--';
    final totalBookings = trip['totalbookings']?.toString() ?? '0';

    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    final cardBgColor =
        _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100;
    final borderColor = _isDarkMode ? Colors.white10 : Colors.grey.shade300;

    Widget buildStat(String label, String value) {
      return Expanded(
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: isSmallScreen ? 11.0 : 12.0,
                ),
              ),
              SizedBox(height: isSmallScreen ? 3.0 : 4.0),
              Text(
                value,
                style: TextStyle(
                  color: Colors.orange,
                  fontSize:
                      isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildStat(t('seats'), availSeats),
        SizedBox(width: isSmallScreen ? 10.0 : 12.0),
        buildStat(t('bookings'), totalBookings),
      ],
    );
  }

  Widget _buildReservationsSection(String tripId,
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final loading = _loadingReservations.contains(tripId);
    final reservations = _reservations[tripId];

    if (loading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('reservations'),
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF1E3A5F),
            fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: isSmallScreen ? 10.0 : 12.0),
        if (reservations == null)
          Text(
            t('none'),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : const Color(0xFF546E7A),
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          )
        else if (reservations.isEmpty)
          Text(
            t('none'),
            style: TextStyle(
              color: _isDarkMode ? Colors.white : const Color(0xFF546E7A),
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          )
        else
          Column(
            children: reservations.map((reservation) {
              return _buildReservationCard(tripId, reservation,
                  isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen);
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildReservationCard(
    String tripId,
    Map<String, dynamic> reservation, {
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final passenger = reservation['passenger'] as Map<String, dynamic>? ?? {};
    final user = passenger['user'] as Map<String, dynamic>? ?? {};
    final status = reservation['status']?.toString() ?? '';
    final driverStatus = reservation['driver_status']?.toString() ?? 'pending';
    final bookingId = reservation['bookingid']?.toString() ?? '';
    final isMutating = _mutatingReservations.contains(bookingId);
    final seat = reservation['seatlocation']?.toString() ?? '-';

    String driverStatusText;
    Color driverStatusColor;
    switch (driverStatus) {
      case 'approved':
        driverStatusText = t('approved');
        driverStatusColor = Colors.greenAccent;
        break;
      case 'rejected':
        driverStatusText = t('rejected');
        driverStatusColor = Colors.redAccent;
        break;
      default:
        driverStatusText = t('pending');
        driverStatusColor = Colors.orangeAccent;
    }

    final isCheckedIn = status == 'checked_in';
    final isCancelled = status == 'cancelled' || status == 'no_show';

    final cardBgColor = isCancelled
        ? (_isDarkMode ? Colors.red.withOpacity(0.1) : Colors.red.shade50)
        : (_isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50);
    final textPrimaryColor =
        _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final textSecondaryColor =
        _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF546E7A);
    final borderColor = _isDarkMode ? Colors.white12 : Colors.grey.shade300;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 12.0),
      padding:
          EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: Text(
                  (user['fullname']?.toString().isNotEmpty ?? false)
                      ? user['fullname'].toString()[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize:
                        isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 18.0),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['fullname']?.toString() ?? t('passenger'),
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: isSmallScreen
                            ? 14.0
                            : (isMediumScreen ? 15.0 : 16.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                    Text(
                      '${t('seat')}: $seat',
                      style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: isSmallScreen ? 11.0 : 12.0),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8.0 : 10.0,
                  vertical: isSmallScreen ? 3.0 : 4.0,
                ),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? Colors.redAccent.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                ),
                child: Text(
                  isCancelled
                      ? (_isArabic ? 'ملغي' : 'Cancelled')
                      : status,
                  style: TextStyle(
                    color: isCancelled
                        ? Colors.redAccent
                        : textSecondaryColor,
                    fontSize: isSmallScreen ? 11.0 : 12.0,
                    fontWeight: isCancelled ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 10.0 : 12.0,
                vertical: isSmallScreen ? 4.0 : 6.0),
            decoration: BoxDecoration(
              color: driverStatusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
            ),
            child: Text(
              driverStatusText,
              style: TextStyle(
                color: driverStatusColor,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 11.0 : 12.0,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          Wrap(
            spacing: isSmallScreen ? 8.0 : 12.0,
            runSpacing: isSmallScreen ? 6.0 : 8.0,
            children: [
              if (driverStatus != 'rejected' && status != 'cancelled')
                FilledButton.tonal(
                  onPressed: isMutating
                      ? null
                      : () =>
                          _updateReservationStatus(tripId, bookingId, 'reject'),
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0,
                      vertical: isSmallScreen ? 8.0 : 10.0,
                    ),
                  ),
                  child: isMutating
                      ? SizedBox(
                          height: isSmallScreen ? 14.0 : 16.0,
                          width: isSmallScreen ? 14.0 : 16.0,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          t('reject'),
                          style:
                              TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                        ),
                ),
              if (driverStatus == 'approved' && status != 'checked_in' && status != 'cancelled' && status != 'no_show')
                FilledButton.tonal(
                  onPressed: isMutating
                      ? null
                      : () {
                          setState(() {
                            _mutatingReservations.add(bookingId);
                          });
                          _checkInReservation(bookingId).then((_) {
                            if (mounted) {
                              setState(() {
                                _mutatingReservations.remove(bookingId);
                              });
                              _loadReservations(tripId);
                            }
                          });
                        },
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12.0 : 16.0,
                      vertical: isSmallScreen ? 8.0 : 10.0,
                    ),
                  ),
                  child: isMutating
                      ? SizedBox(
                          height: isSmallScreen ? 14.0 : 16.0,
                          width: isSmallScreen ? 14.0 : 16.0,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          t('checkin'),
                          style:
                              TextStyle(fontSize: isSmallScreen ? 12.0 : 14.0),
                        ),
                ),
              if (isCheckedIn)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 10.0 : 12.0,
                      vertical: isSmallScreen ? 6.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green,
                          size: isSmallScreen ? 14.0 : 16.0),
                      SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                      Text(
                        t('checked_in'),
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 11.0 : 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '--';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }
}
