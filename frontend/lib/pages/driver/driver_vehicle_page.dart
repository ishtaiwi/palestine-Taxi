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
      setState(() {
        _seatRows = seatRows;
        _brokenSeats = ((result['brokenSeats'] as List?) ?? [])
            .map((seat) => seat.toString())
            .toSet();
        _upcomingTrip = result['upcomingTrip'] as Map<String, dynamic>?;
      });
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
                style: const TextStyle(color: Colors.white70),
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
                  color: Colors.white70,
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
            style: const TextStyle(color: Colors.white70),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(Icons.directions_car, t('plate'), vehicle['plateno'] ?? t('unknown')),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.event_seat, t('seats'), vehicle['seatnum']?.toString() ?? '--'),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.alt_route, t('line'), vehicle['line']?['linename'] ?? t('unknown')),
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
        style: const TextStyle(color: Colors.white70),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('tapSeat'),
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            children: _seatRows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row
                          .map(
                            (seat) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _buildSeatTile(seat),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(),
      ],
    );
  }

  Widget _buildSeatTile(Map<String, dynamic> seat) {
    final status = seat['status']?.toString() ?? 'available';
    final colors = {
      'available': Colors.greenAccent,
      'reserved': Colors.redAccent,
      'broken': Colors.black87,
    };
    final color = colors[status] ?? Colors.greenAccent;

    return GestureDetector(
      onTap: () => _toggleSeatStatus(seat['id']?.toString() ?? '', status),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(
          child: Text(
            seat['number']?.toString() ?? '--',
            style: TextStyle(
              color: status == 'broken' ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    Widget legendItem(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white30),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        legendItem(Colors.greenAccent, t('legendAvailable')),
        legendItem(Colors.redAccent, t('legendReserved')),
        legendItem(Colors.black87, t('legendBroken')),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white54),
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

