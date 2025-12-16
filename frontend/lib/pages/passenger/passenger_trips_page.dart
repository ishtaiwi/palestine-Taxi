import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'passenger_book_trip_page.dart';
import 'package:taxi_palestine_app/utils/server_time_sync.dart';

class PassengerTripsPage extends StatefulWidget {
  const PassengerTripsPage({super.key});

  @override
  State<PassengerTripsPage> createState() => _PassengerTripsPageState();
}

class _PassengerTripsPageState extends State<PassengerTripsPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  String? _error;
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _lines = [];
  String? _selectedLineId;
  DateTime? _selectedDate;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الرحلات المتاحة',
      'subtitle': 'اختر رحلة واحجز مقعدك',
      'noTrips': 'لا توجد رحلات متاحة حالياً',
      'filterByLine': 'فلترة حسب الخط',
      'filterByDate': 'فلترة حسب التاريخ',
      'allLines': 'جميع الخطوط',
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
    },
    'en': {
      'title': 'Available Trips',
      'subtitle': 'Select a trip and book your seat',
      'noTrips': 'No trips available at the moment',
      'filterByLine': 'Filter by Line',
      'filterByDate': 'Filter by Date',
      'allLines': 'All Lines',
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
    await _loadLines();
    await _loadTrips();
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
      // Ignore error, lines are optional
    }
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trips = await ApiService.fetchUpcomingTrips(
        lineid: _selectedLineId,
        date: _selectedDate?.toIso8601String().split('T')[0],
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

  Future<void> _selectDate() async {
    final now = TimeSyncService.now();
    ;
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: _isArabic ? const Locale('ar') : const Locale('en'),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadTrips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          foregroundColor: Colors.white,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadTrips,
              tooltip: t('refresh'),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Filters
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Line Filter
                    DropdownButtonFormField<String>(
                      value: _selectedLineId,
                      decoration: InputDecoration(
                        labelText: t('filterByLine'),
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E3A5F), width: 2),
                        ),
                      ),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                          color: Color(0xFF1E3A5F),
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                      iconEnabledColor: const Color(0xFF1E3A5F),
                      iconSize: 24,
                      menuMaxHeight: 300,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            t('allLines'),
                            style: const TextStyle(
                              color: Color(0xFF1E3A5F),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        ..._lines.map((line) {
                          // Get line name based on current language
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
                            value: line['lineid']?.toString(),
                            child: Text(
                              lineName.isEmpty
                                  ? (_isArabic ? 'غير معروف' : 'Unknown')
                                  : lineName,
                              style: const TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedLineId = value;
                        });
                        _loadTrips();
                      },
                    ),
                    const SizedBox(height: 12),
                    // Date Filter
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: const Color(0xFF1E3A5F)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDate == null
                                    ? t('filterByDate')
                                    : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (_selectedDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                color: const Color(0xFF1E3A5F),
                                onPressed: () {
                                  setState(() {
                                    _selectedDate = null;
                                  });
                                  _loadTrips();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Trips List
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
                                  style:
                                      const TextStyle(color: Color(0xFF1E3A5F)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadTrips,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
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
                                        color: Colors.grey.shade400, size: 64),
                                    const SizedBox(height: 16),
                                    Text(
                                      t('noTrips'),
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _trips.length,
                                itemBuilder: (context, index) {
                                  return _buildTripCard(_trips[index]);
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final line = trip['line'] as Map<String, dynamic>? ?? {};
    // Get line name based on current language
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
    final tripOpeningTimeStr = trip['trip_opening_time']?.toString();

    // Parse departure time
    DateTime? departureTime;
    try {
      // Parse as server local time (strip timezone and treat as local)
      // Backend sends UTC but it should be interpreted as server local time
      final tzRegex = RegExp(r'([+-]\d{2}):(\d{2})$');
      final datePart = deptime.replaceFirst(tzRegex, "");
      departureTime = DateTime.parse(datePart);
    } catch (e) {
      // Ignore
    }

    // Parse trip opening time
    DateTime? tripOpeningTime;
    if (tripOpeningTimeStr != null && tripOpeningTimeStr.isNotEmpty) {
      try {
        // Parse as server local time (strip timezone and treat as local)
        // Backend sends UTC but it should be interpreted as server local time
        final tzRegex = RegExp(r'([+-]\d{2}):(\d{2})$');
        final datePart = tripOpeningTimeStr.replaceFirst(tzRegex, "");
        tripOpeningTime = DateTime.parse(datePart);
      } catch (e) {
        // Ignore
      }
    }

    // Get server time (already in server's local timezone)
    DateTime now = TimeSyncService.now();

    bool isTripOpened;

    if (tripOpeningTime != null) {
      final opening = tripOpeningTime;
      isTripOpened = opening.isBefore(now) || opening.isAtSameMomentAs(now);
    } else if (departureTime != null) {
      final departure = departureTime;
      final defaultOpening = departure.subtract(const Duration(minutes: 45));
      isTripOpened =
          defaultOpening.isBefore(now) || defaultOpening.isAtSameMomentAs(now);
    } else {
      isTripOpened = false;
    }
    print("************************************************************");
    print("now (server local): ${now}");
    print("opening (original): ${tripOpeningTimeStr}");
    print("opening (parsed, local): ${tripOpeningTime}");
    print("opening.isBefore(now): ${tripOpeningTime?.isBefore(now) ?? 'N/A'}");
    print(
        "opening.isAtSameMomentAs(now): ${tripOpeningTime?.isAtSameMomentAs(now) ?? 'N/A'}");
    print("isTripOpened: $isTripOpened");

    final isScheduled = status == 'scheduled' || status == 'open';

    // Instant booking: trip must be opened (trip_opening_time passed) AND have available seats
    final canBookInstant = isScheduled && isTripOpened && availableseats > 0;

    // Future booking: always available if trip is scheduled (regardless of opening time)
    final canBookFuture = isScheduled;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF57C00).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                color: Color(0xFFF57C00),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lineName,
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 20,
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFF57C00),
                          Color(0xFFE65100),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF57C00).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${baseprice.toStringAsFixed(2)} ₪',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          t('price'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: canBookFuture
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canBookFuture
                        ? Colors.green.withOpacity(0.4)
                        : Colors.red.withOpacity(0.4),
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
              const SizedBox(height: 18),
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
                            message =
                                '${t('tripOpensAt')} $hour:$minute $isTripOpened';
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
                        size: 18,
                      ),
                      label: Text(t('bookNow')),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(t('bookFuture')),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF57C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
