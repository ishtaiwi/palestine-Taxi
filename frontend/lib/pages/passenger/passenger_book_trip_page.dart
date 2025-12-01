import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:taxi_palestine_app/utils/server_time_sync.dart';

class PassengerBookTripPage extends StatefulWidget {
  final String? tripId;
  final String? lineId; // Line ID for future bookings when tripId is null
  final String? bookingType; // 'future' or 'instant'
  final String? scheduledTripTime;

  const PassengerBookTripPage({
    super.key,
    this.tripId,
    this.lineId,
    this.bookingType,
    this.scheduledTripTime,
  });

  @override
  State<PassengerBookTripPage> createState() => _PassengerBookTripPageState();
}

class _PassengerBookTripPageState extends State<PassengerBookTripPage> {
  bool _isLoading = false;
  bool _isArabic = true;
  Map<String, dynamic>? _trip;
  Map<String, dynamic>? _line;
  String? _selectedSeat;
  String? _dropoffPoint;
  String? _paymentMethod = 'wallet';
  String? _bookingType;
  DateTime? _selectedScheduledTime;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'حجز رحلة',
      'bookingType': 'نوع الحجز',
      'instant': 'فوري',
      'future': 'مسبق',
      'tripDetails': 'تفاصيل الرحلة',
      'selectSeat': 'اختر المقعد',
      'dropoffPoint': 'نقطة النزول',
      'paymentMethod': 'طريقة الدفع',
      'wallet': 'المحفظة',
      'cash': 'نقد',
      'card': 'بطاقة',
      'book': 'احجز',
      'cancel': 'إلغاء',
      'loading': 'جاري الحجز...',
      'success': 'تم الحجز بنجاح',
      'error': 'حدث خطأ',
      'scheduledTime': 'وقت الرحلة المحدد',
      'selectTime': 'اختر الوقت',
    },
    'en': {
      'title': 'Book Trip',
      'bookingType': 'Booking Type',
      'instant': 'Instant',
      'future': 'Future',
      'tripDetails': 'Trip Details',
      'selectSeat': 'Select Seat',
      'dropoffPoint': 'Drop-off Point',
      'paymentMethod': 'Payment Method',
      'wallet': 'Wallet',
      'cash': 'Cash',
      'card': 'Card',
      'book': 'Book',
      'cancel': 'Cancel',
      'loading': 'Booking...',
      'success': 'Booking successful',
      'error': 'An error occurred',
      'scheduledTime': 'Scheduled Trip Time',
      'selectTime': 'Select Time',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _bookingType = widget.bookingType ?? 'instant';
    _initialize();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });

    if (widget.tripId != null) {
      await _loadTrip();
    }

    if (widget.scheduledTripTime != null) {
      try {
        _selectedScheduledTime = DateTime.parse(widget.scheduledTripTime!);
      } catch (e) {
        // Ignore
      }
    }
  }

  Future<void> _loadTrip() async {
    if (widget.tripId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final trip = await ApiService.fetchTripById(widget.tripId!);
      if (mounted) {
        setState(() {
          _trip = trip;
          _line = trip['line'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t('error')}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectScheduledTime() async {
    final now = TimeSyncService.now();
    final firstDate = now;
    final lastDate = now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedScheduledTime ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: _isArabic ? const Locale('ar') : const Locale('en'),
    );

    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedScheduledTime ?? now),
      );

      if (time != null) {
        setState(() {
          _selectedScheduledTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _bookTrip() async {
    if (_bookingType == 'future' && _selectedScheduledTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('selectTime'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For future bookings, ensure we have lineid
      String? finalLineId;
      if (_bookingType == 'future') {
        // Priority: widget.lineId > _line > trip.lineid
        finalLineId = widget.lineId;
        if (finalLineId == null && _line != null) {
          finalLineId = _line!['lineid']?.toString();
        }
        if (finalLineId == null && _trip != null && _trip!['line'] != null) {
          final tripLine = _trip!['line'] as Map<String, dynamic>?;
          if (tripLine != null) {
            finalLineId = tripLine['lineid']?.toString();
          }
        }

        if (finalLineId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${t('error')}: ${_isArabic ? 'يرجى تحديد الخط' : 'Please select a line'}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else {
        // For instant bookings, use line from trip
        finalLineId = _line?['lineid']?.toString();
      }

      final result = await ApiService.createReservation(
        tripid: _bookingType == 'instant' ? widget.tripId : null,
        lineid: finalLineId,
        seatlocation: _selectedSeat,
        dropoffpoint: _dropoffPoint,
        paymentmethod: _paymentMethod,
        booking_type: _bookingType,
        scheduled_trip_time: _selectedScheduledTime?.toIso8601String(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('error')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        ),
        body: _isLoading && _trip == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking Type
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('bookingType'),
                              style: const TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      t('instant'),
                                      style: const TextStyle(
                                          color: Color(0xFF1E3A5F),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    value: 'instant',
                                    groupValue: _bookingType,
                                    onChanged: (value) {
                                      setState(() {
                                        _bookingType = value;
                                      });
                                    },
                                    activeColor: Colors.blue,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<String>(
                                    title: Text(
                                      t('future'),
                                      style: const TextStyle(
                                          color: Color(0xFF1E3A5F),
                                          fontWeight: FontWeight.w500),
                                    ),
                                    value: 'future',
                                    groupValue: _bookingType,
                                    onChanged: (value) {
                                      setState(() {
                                        _bookingType = value;
                                      });
                                    },
                                    activeColor: Colors.orange,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                            if (_bookingType == 'future') ...[
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _selectScheduledTime,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          color: const Color(0xFF1E3A5F)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _selectedScheduledTime == null
                                              ? t('selectTime')
                                              : '${_selectedScheduledTime!.day}/${_selectedScheduledTime!.month}/${_selectedScheduledTime!.year} ${_selectedScheduledTime!.hour.toString().padLeft(2, '0')}:${_selectedScheduledTime!.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(
                                              color: Color(0xFF1E3A5F),
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Trip Details (if instant booking)
                      if (_bookingType == 'instant' && _trip != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('tripDetails'),
                                style: const TextStyle(
                                  color: Color(0xFF1E3A5F),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_line != null)
                                Text(
                                  _isArabic
                                      ? (_line!['name_ar']?.toString() ??
                                          _line!['linename']?.toString() ??
                                          _line!['name_en']?.toString() ??
                                          '')
                                      : (_line!['name_en']?.toString() ??
                                          _line!['linename']?.toString() ??
                                          _line!['name_ar']?.toString() ??
                                          ''),
                                  style: const TextStyle(
                                      color: Color(0xFF1E3A5F),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Drop-off Point
                      TextField(
                        decoration: InputDecoration(
                          labelText: t('dropoffPoint'),
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
                        style: const TextStyle(
                            color: Color(0xFF1E3A5F),
                            fontWeight: FontWeight.w500),
                        onChanged: (value) {
                          setState(() {
                            _dropoffPoint = value.isEmpty ? null : value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Payment Method
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: Colors.grey.shade200, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('paymentMethod'),
                              style: const TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            RadioListTile<String>(
                              title: Text(
                                t('wallet'),
                                style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontWeight: FontWeight.w500),
                              ),
                              value: 'wallet',
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value;
                                });
                              },
                              activeColor: Colors.green,
                            ),
                            RadioListTile<String>(
                              title: Text(
                                t('cash'),
                                style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontWeight: FontWeight.w500),
                              ),
                              value: 'cash',
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value;
                                });
                              },
                              activeColor: Colors.orange,
                            ),
                            RadioListTile<String>(
                              title: Text(
                                t('card'),
                                style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontWeight: FontWeight.w500),
                              ),
                              value: 'card',
                              groupValue: _paymentMethod,
                              onChanged: (value) {
                                setState(() {
                                  _paymentMethod = value;
                                });
                              },
                              activeColor: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Book Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _bookTrip,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  t('book'),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
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
