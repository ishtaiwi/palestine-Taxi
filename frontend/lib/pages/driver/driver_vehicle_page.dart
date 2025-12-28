import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import 'driver_home.dart';

class DriverVehiclePage extends StatefulWidget {
  const DriverVehiclePage({super.key});

  @override
  State<DriverVehiclePage> createState() => _DriverVehiclePageState();
}

class _DriverVehiclePageState extends State<DriverVehiclePage> {
  bool _isArabic = true;
  bool _isDarkMode = false;
  bool _isLoadingVehicles = true;
  bool _isLoadingSeatMap = false;
  String? _error;
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  List<List<Map<String, dynamic>>> _seatRows = [];
  Set<String> _brokenSeats = {};
  Map<String, dynamic>? _upcomingTrip;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'مركبتي',
      'subtitle': 'إدارة حالة المقاعد ومتابعة المركبة',
      'vehicles': 'المركبات',
      'plate': 'رقم اللوحة',
      'seats': 'عدد المقاعد',
      'line': 'الخط',
      'departure': 'موعد الانطلاق',
      'lastUpdated': 'آخر تحديث',
      'legendAvailable': 'متاح',
      'legendBroken': 'عاطل',
      'noVehicles': 'لا توجد مركبات مرتبطة بحسابك',
      'addVehicle': 'إضافة مركبة',
      'addVehicleTitle': 'إضافة مركبة جديدة',
      'plateNumber': 'رقم اللوحة',
      'plateHint': 'مثال: 3-1234-A',
      'plateInvalid': 'يجب أن يكون رقم اللوحة بالصيغة: رقم-أربع أرقام-حرف',
      'seatLayout': 'نوع المقاعد',
      'seatLayout4': '4+1 (خمسة مقاعد)',
      'seatLayout7': '7+1 (ثمانية مقاعد)',
      'upcomingTrip': 'الرحلة القادمة',
      'unknown': 'غير معروف',
      'vehicleInfo': 'معلومات المركبة',
      'toggleBroken': 'تغيير حالة المقعد',
      'tapSeat': 'اضغط لتغيير حالة المقعد',
      'refresh': 'تحديث',
      'create': 'إنشاء',
      'cancel': 'إلغاء',
    },
    'en': {
      'title': 'My Vehicle',
      'subtitle': 'Manage seat status and vehicle information',
      'vehicles': 'Vehicles',
      'plate': 'Plate number',
      'seats': 'Seats',
      'line': 'Line',
      'departure': 'Departure',
      'lastUpdated': 'Last update',
      'legendAvailable': 'Available',
      'legendBroken': 'Out of service',
      'noVehicles': 'No vehicles linked to your account',
      'addVehicle': 'Add Vehicle',
      'addVehicleTitle': 'Add New Vehicle',
      'plateNumber': 'Plate Number',
      'plateHint': 'Example: 3-1234-A',
      'plateInvalid': 'Plate number must be in format: number-4digits-letter',
      'seatLayout': 'Seat Layout',
      'seatLayout4': '4+1 (Five seats)',
      'seatLayout7': '7+1 (Eight seats)',
      'upcomingTrip': 'Upcoming trip',
      'unknown': 'Unknown',
      'vehicleInfo': 'Vehicle Information',
      'toggleBroken': 'Toggle seat status',
      'tapSeat': 'Tap a seat to toggle its status',
      'refresh': 'Refresh',
      'create': 'Create',
      'cancel': 'Cancel',
    },
  };

  String t(String key) {
    final textMap = _texts[_isArabic ? 'ar' : 'en'];
    if (textMap == null) return key;
    return textMap[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    await AppTheme.init();
    setState(() {
      _isArabic = isArabic;
      _isDarkMode = AppTheme.isDarkMode;
    });
    await _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _isLoadingVehicles = true;
      _error = null;
    });

    try {
      final vehicles = await ApiService.fetchDriverVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _selectedVehicle = vehicles.isNotEmpty ? vehicles.first : null;
      });
      if (vehicles.isNotEmpty) {
        await _loadSeatMap(vehicles.first['vehicleid'].toString());
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVehicles = false;
        });
      }
    }
  }

  Future<void> _loadSeatMap(String vehicleId) async {
    setState(() {
      _isLoadingSeatMap = true;
      _error = null;
    });

    final result = await ApiService.fetchVehicleSeatMap(vehicleId);
    if (!mounted) return;

    if (result['success'] == true) {
      final seatMapRaw = result['seatMap'] as List<dynamic>? ?? [];
      final seatRows = seatMapRaw
          .map(
            (row) => (row as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .toList(),
          )
          .toList();
      
      print('[DriverVehiclePage] Seat map loaded:');
      for (var row in seatRows) {
        for (var seat in row) {
          print('  Seat ${seat['number']}: status=${seat['status']}, id=${seat['id']}');
        }
      }
      
      setState(() {
        _seatRows = seatRows;
        _brokenSeats = ((result['brokenSeats'] as List?) ?? [])
            .map((seat) => seat.toString())
            .toSet();
        _upcomingTrip = result['upcomingTrip'] as Map<String, dynamic>?;
      });
      
      print('[DriverVehiclePage] Broken seats: $_brokenSeats');
      print('[DriverVehiclePage] Upcoming trip: ${_upcomingTrip != null}');
    } else {
      setState(() {
        _error = result['message']?.toString();
      });
    }

    setState(() {
      _isLoadingSeatMap = false;
    });
  }

  Future<void> _toggleSeatStatus(String seatId, String currentStatus) async {
    final vehicleId = _selectedVehicle?['vehicleid']?.toString();
    if (vehicleId == null) return;

    final updatedSeats = Set<String>.from(_brokenSeats);
    if (currentStatus == 'broken') {
      updatedSeats.remove(seatId);
    } else {
      updatedSeats.add(seatId);
    }

    setState(() {
      _brokenSeats = updatedSeats;
    });

    final result = await ApiService.updateVehicleBrokenSeats(
      vehicleId,
      updatedSeats.toList(),
    );

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Error')),
      );
      setState(() {
        if (currentStatus == 'broken') {
          updatedSeats.add(seatId);
        } else {
          updatedSeats.remove(seatId);
        }
        _brokenSeats = updatedSeats;
      });
    } else {
      await _loadSeatMap(vehicleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
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
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    final double cardPadding = isWeb
        ? (isDesktop ? 28.0 : (isTablet ? 24.0 : 20.0))
        : (isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;
    
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
                margin: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: isSmallScreen ? 18.0 : 20.0),
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
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
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
                    icon: Icon(Icons.refresh_rounded, size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
                    onPressed: _loadVehicles,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: _isLoadingVehicles
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: _buildBody(),
                ),
              ),
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 3, // My Vehicle is index 3
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
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    
    if (_error != null) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 360;
      final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
      
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              FilledButton.tonal(
                onPressed: _loadVehicles,
                child: Text(t('refresh')),
              ),
            ],
          ),
        ),
      );
    }

    if (_vehicles.isEmpty) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 360;
      final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
      
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: isSmallScreen ? 48.0 : (isMediumScreen ? 56.0 : 64.0),
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : textSecondaryColor,
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Text(
                t('noVehicles'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                ),
              ),
              SizedBox(height: isSmallScreen ? 18.0 : 24.0),
              FilledButton.icon(
                onPressed: _showAddVehicleDialog,
                icon: Icon(Icons.add, size: isSmallScreen ? 18.0 : 20.0),
                label: Text(t('addVehicle')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0), 
                    vertical: isSmallScreen ? 10.0 : 12.0
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    final double cardPadding = isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0);
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(basePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                        const Color(0xFF1C2541).withOpacity(0.6),
                        const Color(0xFF2C3E50).withOpacity(0.4),
                      ]
                    : [
                        const Color(0xFF2C5F8D).withOpacity(0.1),
                        const Color(0xFF1E3A5F).withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                  ),
                  child: Icon(
                    Icons.directions_car_rounded,
                    color: Colors.orange,
                    size: isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('title'),
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                      Text(
                        t('subtitle'),
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          _buildVehicleSelector(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          if (_selectedVehicle != null) _buildVehicleInfoCard(_selectedVehicle!, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          _buildSeatMap(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
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
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                ),
                child: Icon(
                  Icons.list_alt_rounded,
                  color: Colors.orange,
                  size: isSmallScreen ? 18.0 : 20.0,
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('vehicles'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0, 
              vertical: isSmallScreen ? 12.0 : 16.0
            ),
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car_rounded,
                  color: Colors.orange,
                  size: isSmallScreen ? 18.0 : 20.0,
                ),
                SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                Expanded(
                  child: Text(
                    '${t('plate')}: ${_selectedVehicle?['plateno'] ?? t('unknown')}',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleInfoCard(Map<String, dynamic> vehicle, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 15,
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
                padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.3),
                      Colors.orange.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange,
                  size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('vehicleInfo'),
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
          _buildInfoRow(Icons.directions_car_rounded, t('plate'), vehicle['plateno'] ?? t('unknown'), isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          _buildInfoRow(Icons.event_seat_rounded, t('seats'), vehicle['seatnum']?.toString() ?? '--', isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          _buildInfoRow(Icons.alt_route_rounded, t('line'), _isArabic
              ? (vehicle['line']?['name_ar']?.toString() ?? vehicle['line']?['linename']?.toString() ?? vehicle['line']?['name_en']?.toString() ?? t('unknown'))
              : (vehicle['line']?['name_en']?.toString() ?? vehicle['line']?['linename']?.toString() ?? vehicle['line']?['name_ar']?.toString() ?? t('unknown')), isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          if (_upcomingTrip != null) ...[
            SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.15),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        color: Colors.orange,
                        size: isSmallScreen ? 18.0 : 20.0,
                      ),
                      SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                      Text(
                        t('upcomingTrip'),
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                  _buildInfoRow(
                    Icons.access_time_rounded,
                    t('departure'),
                    _formatDateTime(_upcomingTrip?['deptime']),
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeatMap({bool isSmallScreen = false, bool isMediumScreen = false}) {
    if (_isLoadingSeatMap) {
      return const Center(child: CircularProgressIndicator());
    }

    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? const Color(0xFFB0BEC5)
        : const Color(0xFF546E7A);
    
    if (_seatRows.isEmpty) {
      return Text(
        t('tapSeat'),
        style: TextStyle(color: textPrimaryColor),
      );
    }

    final seatLayout = _selectedVehicle?['seatlayout']?.toString() ?? '4+1';
    final is4Plus1 = seatLayout == '4+1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          decoration: BoxDecoration(
            color: _isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
            border: Border.all(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.orange,
                size: isSmallScreen ? 18.0 : 20.0,
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Expanded(
                child: Text(
                  t('tapSeat'),
                  style: TextStyle(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.9)
                        : textSecondaryColor,
                    fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isDarkMode
                  ? [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ]
                  : [
                      Colors.grey.shade50,
                      Colors.white,
                    ],
            ),
            borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 24.0),
            border: Border.all(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.2)
                  : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildFrontRow(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
              SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
              if (is4Plus1)
                _buildBackRow4Plus1(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
              else
                _buildBackRows7Plus1(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            ],
          ),
        ),
        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
        _buildLegend(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
      ],
    );
  }

  Widget _buildFrontRow({bool isSmallScreen = false, bool isMediumScreen = false}) {
    Map<String, dynamic>? seat1;
    Map<String, dynamic>? seat2;
    
    for (var row in _seatRows) {
      for (var seat in row) {
        final seatNum = seat['number']?.toString();
        if (seatNum == '1') seat1 = seat;
        if (seatNum == '2') seat2 = seat;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (seat1 != null)
          _buildSeatWidget(seat1, isDriver: true, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
        else
          _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        SizedBox(width: isSmallScreen ? 30.0 : (isMediumScreen ? 35.0 : 40.0)),
        if (seat2 != null)
          _buildSeatWidget(seat2, isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
        else
          _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
      ],
    );
  }

  Widget _buildBackRow4Plus1({bool isSmallScreen = false, bool isMediumScreen = false}) {
    List<Map<String, dynamic>> backSeats = [];
    
    for (var row in _seatRows) {
      for (var seat in row) {
        final seatNum = int.tryParse(seat['number']?.toString() ?? '');
        if (seatNum != null && seatNum >= 3 && seatNum <= 5) {
          backSeats.add(seat);
        }
      }
    }
    
    backSeats.sort((a, b) {
      final numA = int.tryParse(a['number']?.toString() ?? '0') ?? 0;
      final numB = int.tryParse(b['number']?.toString() ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (backSeats.length >= 1) _buildSeatWidget(backSeats[0], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        SizedBox(width: isSmallScreen ? 8.0 : 12.0),
        if (backSeats.length >= 2) _buildSeatWidget(backSeats[1], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        SizedBox(width: isSmallScreen ? 8.0 : 12.0),
        if (backSeats.length >= 3) _buildSeatWidget(backSeats[2], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
      ],
    );
  }

  Widget _buildBackRows7Plus1({bool isSmallScreen = false, bool isMediumScreen = false}) {
    List<Map<String, dynamic>> firstRow = [];
    List<Map<String, dynamic>> secondRow = [];
    
    for (var row in _seatRows) {
      for (var seat in row) {
        final seatNum = int.tryParse(seat['number']?.toString() ?? '');
        if (seatNum != null && seatNum >= 3 && seatNum <= 5) {
          firstRow.add(seat);
        } else if (seatNum != null && seatNum >= 6 && seatNum <= 8) {
          secondRow.add(seat);
        }
      }
    }
    
    firstRow.sort((a, b) {
      final numA = int.tryParse(a['number']?.toString() ?? '0') ?? 0;
      final numB = int.tryParse(b['number']?.toString() ?? '0') ?? 0;
      return numA.compareTo(numB);
    });
    
    secondRow.sort((a, b) {
      final numA = int.tryParse(a['number']?.toString() ?? '0') ?? 0;
      final numB = int.tryParse(b['number']?.toString() ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (firstRow.length >= 1) _buildSeatWidget(firstRow[0], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            if (firstRow.length >= 2) _buildSeatWidget(firstRow[1], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            if (firstRow.length >= 3) _buildSeatWidget(firstRow[2], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (secondRow.length >= 1) _buildSeatWidget(secondRow[0], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            if (secondRow.length >= 2) _buildSeatWidget(secondRow[1], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            if (secondRow.length >= 3) _buildSeatWidget(secondRow[2], isDriver: false, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen) else _buildEmptySeat(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          ],
        ),
      ],
    );
  }

  Widget _buildSeatWidget(Map<String, dynamic> seat, {required bool isDriver, bool isSmallScreen = false, bool isMediumScreen = false}) {
    final status = (seat['status']?.toString() ?? 'available').toLowerCase();
    final seatNumber = seat['number']?.toString() ?? '--';
    final seatId = seat['id']?.toString() ?? '';
    
    final seatIdLower = seatId.toLowerCase();
    final isBroken = _brokenSeats.contains(seatIdLower) || 
                     _brokenSeats.contains(seatId);
    
    Color seatColor;
    Color textColor;
    IconData? seatIcon;
    
    if (isBroken || status == 'broken') {
      seatColor = const Color(0xFF2C2C2C); // Dark gray instead of pure black
      textColor = Colors.white;
      seatIcon = Icons.block;
    } else {
      seatColor = const Color(0xFF4CAF50); // Bright green - more visible
      textColor = Colors.white;
      seatIcon = Icons.event_seat;
    }

    final seatSize = isDriver 
        ? (isSmallScreen ? 60.0 : (isMediumScreen ? 68.0 : 75.0))
        : (isSmallScreen ? 52.0 : (isMediumScreen ? 59.0 : 65.0));
    final iconSize = isDriver
        ? (isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0))
        : (isSmallScreen ? 18.0 : (isMediumScreen ? 21.0 : 24.0));
    final fontSize = isDriver
        ? (isSmallScreen ? 8.0 : (isMediumScreen ? 9.0 : 10.0))
        : (isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0));
    
    return GestureDetector(
      onTap: () => _toggleSeatStatus(seatId, status),
      child: Container(
        width: seatSize,
        height: seatSize,
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: isSmallScreen ? 2.0 : 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: seatColor.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 3,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              seatIcon,
              color: textColor,
              size: iconSize,
            ),
            SizedBox(height: isSmallScreen ? 2.0 : 4.0),
            Text(
              isDriver ? (_isArabic ? 'سائق' : 'Driver') : seatNumber,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySeat({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final size = isSmallScreen ? 48.0 : (isMediumScreen ? 54.0 : 60.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Widget _buildLegend({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final legendBgColor = _isDarkMode
        ? Colors.white.withOpacity(0.08)
        : Colors.grey.shade100;
    final legendBorderColor = _isDarkMode
        ? Colors.white.withOpacity(0.2)
        : Colors.grey.shade300;
    
    Widget legendItem(Color color, String label) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10.0 : 12.0, 
          vertical: isSmallScreen ? 6.0 : 8.0
        ),
        decoration: BoxDecoration(
          color: legendBgColor,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
          border: Border.all(
            color: legendBorderColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSmallScreen ? 16.0 : 20.0,
              height: isSmallScreen ? 16.0 : 20.0,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isSmallScreen ? 5.0 : 6.0),
                border: Border.all(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.4)
                      : Colors.grey.shade400,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 8.0 : 10.0),
            Text(
              label,
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        legendItem(const Color(0xFF4CAF50), t('legendAvailable')),
        legendItem(const Color(0xFF2C2C2C), t('legendBroken')),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final textPrimaryColor = _isDarkMode
        ? Colors.white
        : const Color(0xFF1E3A5F);
    final textSecondaryColor = _isDarkMode
        ? Colors.white70
        : const Color(0xFF546E7A);
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 10.0 : (isMediumScreen ? 12.0 : 14.0)),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
            ),
            child: Icon(
              icon,
              color: Colors.orange,
              size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12.0 : 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: isSmallScreen ? 11.0 : 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                Text(
                  value,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return t('unknown');
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

  Future<void> _showAddVehicleDialog() async {
    final plateController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String selectedLayout = '4+1';

          return AlertDialog(
            backgroundColor: const Color(0xFF0B132B),
            title: Text(
              t('addVehicleTitle'),
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
              ),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: plateController,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                      ),
                      decoration: InputDecoration(
                        labelText: t('plateNumber'),
                        hintText: t('plateHint'),
                        labelStyle: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13.0 : 14.0,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 13.0 : 14.0,
                        ),
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white38),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFF57C00)),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return t('plateNumber');
                        }
                        final plateRegex = RegExp(r'^\d-\d{4}-[A-Za-z]$');
                        if (!plateRegex.hasMatch(value.trim())) {
                          return t('plateInvalid');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
                    Text(
                      t('seatLayout'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                    RadioListTile<String>(
                      title: Text(
                        t('seatLayout4'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13.0 : 14.0,
                        ),
                      ),
                      value: '4+1',
                      groupValue: selectedLayout,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLayout = value!;
                        });
                      },
                      activeColor: const Color(0xFFF57C00),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 16.0,
                        vertical: isSmallScreen ? 4.0 : 8.0,
                      ),
                    ),
                    RadioListTile<String>(
                      title: Text(
                        t('seatLayout7'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 13.0 : 14.0,
                        ),
                      ),
                      value: '7+1',
                      groupValue: selectedLayout,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLayout = value!;
                        });
                      },
                      activeColor: const Color(0xFFF57C00),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8.0 : 16.0,
                        vertical: isSmallScreen ? 4.0 : 8.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  t('cancel'),
                  style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                ),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  Navigator.pop(context);
                  await _createVehicle(
                    plateController.text.trim(),
                    selectedLayout,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16.0 : 20.0,
                    vertical: isSmallScreen ? 10.0 : 12.0,
                  ),
                ),
                child: Text(
                  t('create'),
                  style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createVehicle(String plateno, String seatlayout) async {
    final result = await ApiService.createMyVehicle(
      plateno: plateno,
      seatlayout: seatlayout,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Vehicle created successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadVehicles();
    } else {
      final errorMsg = result['message'] ?? 'Failed to create vehicle';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: _isArabic ? 'إعادة المحاولة' : 'Retry',
            textColor: Colors.white,
            onPressed: () => _showAddVehicleDialog(),
          ),
        ),
      );
    }
  }
}

