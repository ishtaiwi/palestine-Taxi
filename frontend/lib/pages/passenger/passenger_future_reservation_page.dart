import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'passenger_book_trip_page.dart';
import 'package:taxi_palestine_app/utils/server_time_sync.dart';

class PassengerFutureReservationPage extends StatefulWidget {
  const PassengerFutureReservationPage({super.key});

  @override
  State<PassengerFutureReservationPage> createState() =>
      _PassengerFutureReservationPageState();
}

class _PassengerFutureReservationPageState
    extends State<PassengerFutureReservationPage> {
  bool _isArabic = true;
  bool _isDarkMode = false;
  List<Map<String, dynamic>> _lines = [];
  String? _selectedLineId;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _availableTrips = [];
  bool _isLoadingTrips = false;
  String? _selectedTripTime;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadThemePreference();
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
    await _loadLines();
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
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadTrips() async {
    if (_selectedLineId == null || _selectedDate == null) return;

    setState(() {
      _isLoadingTrips = true;
      _selectedTripTime = null;
    });

    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final result = await ApiService.getAvailableTripTimes(
        lineId: _selectedLineId!,
        date: dateStr,
      );

      if (mounted) {
        setState(() {
          _availableTrips = (result['trips'] as List?)
                  ?.map((t) => t as Map<String, dynamic>)
                  .toList() ??
              [];
          _isLoadingTrips = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingTrips = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isArabic
                  ? 'فشل تحميل الرحلات المتاحة'
                  : 'Failed to load available trips',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final now = TimeSyncService.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      locale: _isArabic ? const Locale('ar') : const Locale('en'),
      selectableDayPredicate: (DateTime date) {
        // Block Fridays (day 5 in Dart, where Monday = 1, Friday = 5)
        return date.weekday != 5;
      },
      helpText: _isArabic ? 'اختر التاريخ' : 'Select Date',
      cancelText: _isArabic ? 'إلغاء' : 'Cancel',
      confirmText: _isArabic ? 'تأكيد' : 'Confirm',
    );

    if (picked != null) {
      // Double check that it's not a Friday (shouldn't happen due to selectableDayPredicate, but just in case)
      if (picked.weekday == 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isArabic
                    ? 'الحجز غير متاح يوم الجمعة'
                    : 'Booking is not available on Fridays',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      setState(() {
        _selectedDate = picked;
        _availableTrips = [];
        _selectedTripTime = null;
      });
      await _loadTrips();
    }
  }


  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

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
        : const Color(0xFF546E7A);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            _isArabic ? 'حجز مستقبلي' : 'Future Reservation',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF2C5F8D),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line Selection
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 14.0 : 16.0),
                  decoration: BoxDecoration(
                    color: cardColor,
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
                  child: DropdownButtonFormField<String>(
                    value: _selectedLineId,
                    decoration: InputDecoration(
                      labelText: _isArabic ? 'اختر الخط' : 'Select Line',
                      labelStyle: TextStyle(color: textSecondary),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.directions_bus_rounded,
                        color: _isDarkMode
                            ? const Color(0xFF64B5F6)
                            : const Color(0xFF1E3A5F),
                      ),
                    ),
                    items: _lines.map((line) {
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
                      return DropdownMenuItem<String>(
                        value: lineId,
                        child: Text(lineName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLineId = value;
                        _selectedDate = null;
                        _availableTrips = [];
                        _selectedTripTime = null;
                      });
                    },
                    style: TextStyle(color: textPrimary),
                    dropdownColor: cardColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Date Selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: EdgeInsets.all(isSmallScreen ? 14.0 : 16.0),
                        decoration: BoxDecoration(
                          color: cardColor,
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
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: textPrimary,
                              size: isSmallScreen ? 20.0 : 24.0,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDate == null
                                    ? (_isArabic ? 'اختر التاريخ' : 'Select Date')
                                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isSmallScreen ? 14.0 : 16.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isArabic
                                  ? 'ملاحظة: الحجز غير متاح يوم الجمعة'
                                  : 'Note: Booking is not available on Fridays',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Trips List
                if (_selectedLineId != null && _selectedDate != null) ...[
                  Text(
                    _isArabic ? 'الرحلات المتاحة' : 'Available Trips',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 18.0 : 20.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingTrips)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_availableTrips.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isDarkMode
                              ? const Color(0xFF2C5F8D)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_bus,
                            color: textSecondary,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isArabic
                                ? 'لا توجد رحلات متاحة في هذا التاريخ'
                                : 'No trips available on this date',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._availableTrips.map((trip) {
                      final time = trip['time'] as String? ?? trip['deptime'] as String?;
                      final hour = trip['hour'] as int?;
                      final minute = trip['minute'] as int?;
                      final interval = trip['interval_minutes'] as int? ?? 60;
                      final availableseats = trip['availableseats'] as int? ?? 0;
                      final totalbookings = trip['totalbookings'] as int? ?? 0;

                      String timeStr = '';
                      if (hour != null && minute != null) {
                        timeStr =
                            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
                      } else if (time != null) {
                        try {
                          final dt = DateTime.parse(time);
                          timeStr =
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        } catch (e) {
                          timeStr = time;
                        }
                      }

                      final isSelected = _selectedTripTime == time;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF57C00).withOpacity(0.1)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF57C00)
                                : (_isDarkMode
                                    ? const Color(0xFF2C5F8D)
                                    : Colors.grey.shade300),
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTripTime = time;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 14.0 : 16.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color: isSelected
                                      ? const Color(0xFFF57C00)
                                      : textSecondary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isSmallScreen ? 18.0 : 20.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isDarkMode
                                                  ? const Color(0xFF2C5F8D)
                                                      .withOpacity(0.3)
                                                  : Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${interval} ${_isArabic ? 'دقيقة' : 'min'}',
                                              style: TextStyle(
                                                color: _isDarkMode
                                                    ? const Color(0xFF64B5F6)
                                                    : Colors.blue.shade700,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (availableseats > 0 ||
                                              totalbookings > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: availableseats > 0
                                                    ? (_isDarkMode
                                                        ? Colors.green
                                                            .withOpacity(0.3)
                                                        : Colors.green.shade50)
                                                    : (_isDarkMode
                                                        ? Colors.red
                                                            .withOpacity(0.3)
                                                        : Colors.red.shade50),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _isArabic
                                                    ? '$availableseats ${availableseats > 0 ? 'مقاعد متاحة' : 'مقعد متاح'}'
                                                    : '$availableseats ${availableseats == 1 ? 'seat' : 'seats'} available',
                                                style: TextStyle(
                                                  color: availableseats > 0
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
                const SizedBox(height: 24),
                // Book Button
                if (_selectedLineId != null &&
                    _selectedDate != null &&
                    _selectedTripTime != null)
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PassengerBookTripPage(
                            lineId: _selectedLineId,
                            bookingType: 'future',
                            scheduledTripTime: _selectedTripTime,
                          ),
                        ),
                      ).then((result) {
                        if (result == true) {
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF57C00),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 14.0 : 16.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isArabic ? 'احجز الآن' : 'Book Now',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16.0 : 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
