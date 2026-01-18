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
  String? _bookingType;
  DateTime? _selectedScheduledTime;
  double _walletBalance = 0.0;
  bool _walletLoading = false;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'حجز رحلة',
      'bookingType': 'نوع الحجز',
      'instant': 'فوري',
      'future': 'مسبق',
      'tripDetails': 'تفاصيل الرحلة',
      'selectSeat': 'اختر المقعد',
      'dropoffPoint': 'نقطة النزول',
      'wallet': 'المحفظة',
      'walletBalance': 'رصيد المحفظة',
      'insufficientBalance': 'رصيدك غير كافٍ',
      'topUpWallet': 'شحن المحفظة',
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
      'wallet': 'Wallet',
      'walletBalance': 'Wallet Balance',
      'insufficientBalance': 'Insufficient balance',
      'topUpWallet': 'Top Up Wallet',
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

    await _loadWalletBalance();

    if (widget.tripId != null) {
      await _loadTrip();
    }

    if (widget.scheduledTripTime != null) {
      try {
        _selectedScheduledTime = DateTime.parse(widget.scheduledTripTime!);
      } catch (e) {
      }
    }
  }

  Future<void> _loadWalletBalance() async {
    setState(() {
      _walletLoading = true;
    });
    try {
      final result = await ApiService.fetchWallet();
      if (mounted && result['success'] == true) {
        setState(() {
          _walletBalance = (result['balance'] ?? 0.0).toDouble();
          _walletLoading = false;
        });
      } else {
        setState(() {
          _walletLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _walletLoading = false;
        });
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

    if (_bookingType == 'instant' && widget.tripId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isArabic ? 'خطأ: يجب تحديد رحلة' : 'Error: Trip must be selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? finalLineId;
      if (_bookingType == 'future') {
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
        finalLineId = _line?['lineid']?.toString();
        
        if (finalLineId == null && _trip != null) {
          if (_trip!['line'] != null) {
            final tripLine = _trip!['line'] as Map<String, dynamic>?;
            if (tripLine != null) {
              finalLineId = tripLine['lineid']?.toString();
            }
          } else if (_trip!['lineid'] != null) {
            finalLineId = _trip!['lineid']?.toString();
          }
        }
      }

      final result = await ApiService.createReservation(
        tripid: _bookingType == 'instant' ? widget.tripId : null,
        lineid: finalLineId,
        seatlocation: _selectedSeat,
        paymentmethod: 'wallet', // Always use wallet
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    // Responsive sizing
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0);
    final double titleFontSize = isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text(
            t('title'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
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
                  padding: EdgeInsets.all(basePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isSmallScreen ? 14.0 : 18.0),
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
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 14.0 : (isMediumScreen ? 17.0 : 20.0)),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(isSmallScreen ? 14.0 : 18.0),
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
                            Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet,
                                  color: Color(0xFF1E3A5F),
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t('walletBalance'),
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A5F),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_walletLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _walletBalance < (_trip != null && _line != null
                                          ? ((_line!['baseprice'] ?? 0.0).toDouble())
                                          : 0.0)
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _walletBalance < (_trip != null && _line != null
                                            ? ((_line!['baseprice'] ?? 0.0).toDouble())
                                            : 0.0)
                                        ? Colors.orange
                                        : Colors.green,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_walletBalance.toStringAsFixed(2)} ₪',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E3A5F),
                                          ),
                                        ),
                                        if (_walletBalance < (_trip != null && _line != null
                                                ? ((_line!['baseprice'] ?? 0.0).toDouble())
                                                : 0.0))
                                          Text(
                                            t('insufficientBalance'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_walletBalance < (_trip != null && _line != null
                                            ? ((_line!['baseprice'] ?? 0.0).toDouble())
                                            : 0.0))
                                      TextButton.icon(
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/passenger/wallet');
                                        },
                                        icon: const Icon(Icons.add_card, size: 18),
                                        label: Text(t('topUpWallet')),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.orange.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
