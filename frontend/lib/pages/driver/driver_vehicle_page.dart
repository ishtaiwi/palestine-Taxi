import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class DriverVehiclePage extends StatefulWidget {
  const DriverVehiclePage({super.key});

  @override
  State<DriverVehiclePage> createState() => _DriverVehiclePageState();
}

class _DriverVehiclePageState extends State<DriverVehiclePage> {
  bool _isArabic = true;
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
      'legendReserved': 'محجوز',
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
      'toggleBroken': 'تغيير حالة المقعد',
      'tapSeat': 'اضغط لتغيير حالة المقعد (باستثناء المقعد المحجوز)',
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
      'legendReserved': 'Reserved',
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
      'toggleBroken': 'Toggle seat status',
      'tapSeat': 'Tap a seat to toggle its status (reserved seats locked)',
      'refresh': 'Refresh',
      'create': 'Create',
      'cancel': 'Cancel',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
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
      
      // Debug: Log seat statuses
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
    if (currentStatus == 'reserved') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('legendReserved'))),
      );
      return;
    }

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
      // revert on failure
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

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B132B),
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: Colors.white,
              ),
              onPressed: () async {
                final next = !_isArabic;
                await ApiService.saveLanguagePreference(next);
                if (mounted) {
                  setState(() => _isArabic = next);
                }
              },
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadVehicles,
              tooltip: t('refresh'),
            ),
          ],
        ),
        body: _isLoadingVehicles
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
              ),
              const SizedBox(height: 16),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                t('noVehicles'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, // نص أبيض على خلفية غامقة
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showAddVehicleDialog,
                icon: const Icon(Icons.add),
                label: Text(t('addVehicle')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          t('subtitle'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
          const SizedBox(height: 16),
          _buildVehicleSelector(),
          const SizedBox(height: 16),
          if (_selectedVehicle != null) _buildVehicleInfoCard(_selectedVehicle!),
          const SizedBox(height: 16),
          _buildSeatMap(),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: const Color(0xFF0B132B),
          value: _selectedVehicle?['vehicleid']?.toString(),
          iconEnabledColor: Colors.white,
          style: const TextStyle(color: Colors.white),
          items: _vehicles
              .map(
                (vehicle) => DropdownMenuItem<String>(
                  value: vehicle['vehicleid']?.toString(),
                  child: Text(
                    '${t('plate')}: ${vehicle['plateno'] ?? t('unknown')}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            final vehicle = _vehicles.firstWhere(
              (item) => item['vehicleid']?.toString() == value,
            );
            setState(() {
              _selectedVehicle = vehicle;
            });
            _loadSeatMap(vehicle['vehicleid']?.toString() ?? '');
          },
        ),
      ),
    );
  }

  Widget _buildVehicleInfoCard(Map<String, dynamic> vehicle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF57C00).withOpacity(0.15),
            const Color(0xFFF57C00).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF57C00).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF57C00).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(Icons.directions_car, t('plate'), vehicle['plateno'] ?? t('unknown')),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.event_seat, t('seats'), vehicle['seatnum']?.toString() ?? '--'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.alt_route, t('line'), _isArabic
              ? (vehicle['line']?['name_ar']?.toString() ?? vehicle['line']?['linename']?.toString() ?? vehicle['line']?['name_en']?.toString() ?? t('unknown'))
              : (vehicle['line']?['name_en']?.toString() ?? vehicle['line']?['linename']?.toString() ?? vehicle['line']?['name_ar']?.toString() ?? t('unknown'))),
          if (_upcomingTrip != null) ...[
            const SizedBox(height: 12),
            Text(
              t('upcomingTrip'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            _buildInfoRow(
              Icons.schedule,
              t('departure'),
              _formatDateTime(_upcomingTrip?['deptime']),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeatMap() {
    if (_isLoadingSeatMap) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_seatRows.isEmpty) {
      return Text(
        t('tapSeat'),
        style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
      );
    }

    // Get vehicle layout type
    final seatLayout = _selectedVehicle?['seatlayout']?.toString() ?? '4+1';
    final is4Plus1 = seatLayout == '4+1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('tapSeat'),
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Front row (driver + passenger)
              _buildFrontRow(),
              const SizedBox(height: 20),
              // Back rows
              if (is4Plus1)
                _buildBackRow4Plus1()
              else
                _buildBackRows7Plus1(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildFrontRow() {
    // Front row: Driver (left) + Passenger (right)
    // Find seats 1 and 2
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
        // Driver seat (left)
        if (seat1 != null)
          _buildSeatWidget(seat1, isDriver: true)
        else
          _buildEmptySeat(),
        const SizedBox(width: 40),
        // Passenger seat (right)
        if (seat2 != null)
          _buildSeatWidget(seat2, isDriver: false)
        else
          _buildEmptySeat(),
      ],
    );
  }

  Widget _buildBackRow4Plus1() {
    // Back row: 3 seats (seats 3, 4, 5)
    List<Map<String, dynamic>> backSeats = [];
    
    for (var row in _seatRows) {
      for (var seat in row) {
        final seatNum = int.tryParse(seat['number']?.toString() ?? '');
        if (seatNum != null && seatNum >= 3 && seatNum <= 5) {
          backSeats.add(seat);
        }
      }
    }
    
    // Sort by seat number
    backSeats.sort((a, b) {
      final numA = int.tryParse(a['number']?.toString() ?? '0') ?? 0;
      final numB = int.tryParse(b['number']?.toString() ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (backSeats.length >= 1) _buildSeatWidget(backSeats[0], isDriver: false) else _buildEmptySeat(),
        const SizedBox(width: 12),
        if (backSeats.length >= 2) _buildSeatWidget(backSeats[1], isDriver: false) else _buildEmptySeat(),
        const SizedBox(width: 12),
        if (backSeats.length >= 3) _buildSeatWidget(backSeats[2], isDriver: false) else _buildEmptySeat(),
      ],
    );
  }

  Widget _buildBackRows7Plus1() {
    // First back row: 3 seats (seats 3, 4, 5)
    // Second back row: 3 seats (seats 6, 7, 8)
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
    
    // Sort by seat number
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
        // First back row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (firstRow.length >= 1) _buildSeatWidget(firstRow[0], isDriver: false) else _buildEmptySeat(),
            const SizedBox(width: 12),
            if (firstRow.length >= 2) _buildSeatWidget(firstRow[1], isDriver: false) else _buildEmptySeat(),
            const SizedBox(width: 12),
            if (firstRow.length >= 3) _buildSeatWidget(firstRow[2], isDriver: false) else _buildEmptySeat(),
          ],
        ),
        const SizedBox(height: 16),
        // Second back row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (secondRow.length >= 1) _buildSeatWidget(secondRow[0], isDriver: false) else _buildEmptySeat(),
            const SizedBox(width: 12),
            if (secondRow.length >= 2) _buildSeatWidget(secondRow[1], isDriver: false) else _buildEmptySeat(),
            const SizedBox(width: 12),
            if (secondRow.length >= 3) _buildSeatWidget(secondRow[2], isDriver: false) else _buildEmptySeat(),
          ],
        ),
      ],
    );
  }

  Widget _buildSeatWidget(Map<String, dynamic> seat, {required bool isDriver}) {
    final status = (seat['status']?.toString() ?? 'available').toLowerCase();
    final seatNumber = seat['number']?.toString() ?? '--';
    final seatId = seat['id']?.toString() ?? '';
    
    // Also check if seat is in broken seats set
    final seatIdLower = seatId.toLowerCase();
    final isBroken = _brokenSeats.contains(seatIdLower) || 
                     _brokenSeats.contains(seatId);
    
    Color seatColor;
    Color textColor;
    IconData? seatIcon;
    
    // Priority: broken > reserved > available
    // Improved colors for better visibility
    if (isBroken || status == 'broken') {
      seatColor = const Color(0xFF2C2C2C); // Dark gray instead of pure black
      textColor = Colors.white;
      seatIcon = Icons.block;
    } else if (status == 'reserved') {
      seatColor = const Color(0xFFE53935); // Bright red - more visible
      textColor = Colors.white;
      seatIcon = Icons.event_seat;
    } else {
      seatColor = const Color(0xFF4CAF50); // Bright green - more visible
      textColor = Colors.white;
      seatIcon = Icons.event_seat;
    }

    return GestureDetector(
      onTap: () => _toggleSeatStatus(seatId, status),
      child: Container(
        width: isDriver ? 75 : 65,
        height: isDriver ? 75 : 65,
        decoration: BoxDecoration(
          color: seatColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 2.5,
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
              size: isDriver ? 28 : 24,
            ),
            const SizedBox(height: 4),
            Text(
              isDriver ? (_isArabic ? 'سائق' : 'Driver') : seatNumber,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: isDriver ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySeat() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    Widget legendItem(Color color, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
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
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
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
        legendItem(const Color(0xFFE53935), t('legendReserved')),
        legendItem(const Color(0xFF2C2C2C), t('legendBroken')),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF57C00).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFF57C00),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          String selectedLayout = '4+1';

          return AlertDialog(
            backgroundColor: const Color(0xFF0B132B),
            title: Text(
              t('addVehicleTitle'),
              style: const TextStyle(color: Colors.white),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: plateController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: t('plateNumber'),
                        hintText: t('plateHint'),
                        labelStyle: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
                        hintStyle: const TextStyle(color: Colors.white70),
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
                    const SizedBox(height: 24),
                    Text(
                      t('seatLayout'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RadioListTile<String>(
                      title: Text(
                        t('seatLayout4'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: '4+1',
                      groupValue: selectedLayout,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLayout = value!;
                        });
                      },
                      activeColor: const Color(0xFFF57C00),
                    ),
                    RadioListTile<String>(
                      title: Text(
                        t('seatLayout7'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      value: '7+1',
                      groupValue: selectedLayout,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLayout = value!;
                        });
                      },
                      activeColor: const Color(0xFFF57C00),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('cancel')),
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
                ),
                child: Text(t('create')),
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

