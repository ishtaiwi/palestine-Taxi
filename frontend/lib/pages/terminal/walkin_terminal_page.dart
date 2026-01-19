import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../services/api_service.dart';

/// Walk-in Terminal Touch Screen Page
/// Multi-step wizard for walk-in passengers to book trips
class WalkinTerminalPage extends StatefulWidget {
  const WalkinTerminalPage({super.key});

  @override
  State<WalkinTerminalPage> createState() => _WalkinTerminalPageState();
}

class _WalkinTerminalPageState extends State<WalkinTerminalPage> {
  // Current step in the wizard (0-3)
  int _currentStep = 0;

  // State variables
  bool _isLoading = false;
  String? _error;
  bool _isArabic = true;

  // Step 1: Line selection
  List<Map<String, dynamic>> _lines = [];
  Map<String, dynamic>? _selectedLine;

  // Step 2: Phone number
  final TextEditingController _phoneController = TextEditingController();
  String _phoneNumber = '';

  // Step 3: Trip selection
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _selectedTrip;

  // Step 4: QR Code result
  String? _qrCode;
  Map<String, dynamic>? _bookingResult;

  // Localization
  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'حجز تذكرة',
      'selectLine': 'اختر الخط',
      'selectLineDesc': 'اختر خط الرحلة الخاص بك',
      'enterPhone': 'أدخل رقم هاتفك',
      'enterPhoneDesc': 'أدخل رقم هاتفك لتأكيد الحجز',
      'phoneHint': '05XXXXXXXX',
      'selectTrip': 'اختر الرحلة',
      'selectTripDesc': 'اختر وقت المغادرة',
      'booking': 'الحجز',
      'bookingComplete': 'تم الحجز بنجاح!',
      'bookingCompleteDesc': 'امسح رمز QR عند ركوب السيارة',
      'next': 'التالي',
      'back': 'رجوع',
      'confirm': 'تأكيد الحجز',
      'newBooking': 'حجز جديد',
      'departure': 'المغادرة',
      'availableSeats': 'المقاعد المتاحة',
      'price': 'السعر',
      'loading': 'جاري التحميل...',
      'noLines': 'لا توجد خطوط متاحة',
      'noTrips': 'لا توجد رحلات متاحة',
      'invalidPhone': 'رقم الهاتف غير صحيح',
      'phoneRequired': 'رقم الهاتف مطلوب',
      'error': 'حدث خطأ',
      'retry': 'إعادة المحاولة',
      'direction': 'الاتجاه',
      'going': 'ذهاب',
      'return': 'عودة',
      'seats': 'مقاعد',
      'bookingId': 'رقم الحجز',
      'showQrToDriver': 'أظهر رمز QR للسائق عند الصعود',
      'cashPayment': 'الدفع نقداً للسائق',
      'welcome': 'مرحباً بك',
      'welcomeDesc': 'احجز رحلتك بسهولة من هنا',
      'switchLanguage': 'English',
      'driverInfo': 'معلومات السائق',
      'driverName': 'اسم السائق',
      'driverPhone': 'هاتف السائق',
      'vehicleInfo': 'معلومات المركبة',
      'plateNumber': 'رقم اللوحة',
      'noDriverAssigned': 'سيتم تعيين سائق قريباً',
    },
    'en': {
      'title': 'Book a Ticket',
      'selectLine': 'Select Line',
      'selectLineDesc': 'Choose your travel line',
      'enterPhone': 'Enter Your Phone',
      'enterPhoneDesc': 'Enter your phone number to confirm booking',
      'phoneHint': '05XXXXXXXX',
      'selectTrip': 'Select Trip',
      'selectTripDesc': 'Choose your departure time',
      'booking': 'Booking',
      'bookingComplete': 'Booking Complete!',
      'bookingCompleteDesc': 'Scan the QR code when boarding',
      'next': 'Next',
      'back': 'Back',
      'confirm': 'Confirm Booking',
      'newBooking': 'New Booking',
      'departure': 'Departure',
      'availableSeats': 'Available Seats',
      'price': 'Price',
      'loading': 'Loading...',
      'noLines': 'No lines available',
      'noTrips': 'No trips available',
      'invalidPhone': 'Invalid phone number',
      'phoneRequired': 'Phone number is required',
      'error': 'An error occurred',
      'retry': 'Retry',
      'direction': 'Direction',
      'going': 'Going',
      'return': 'Return',
      'seats': 'seats',
      'bookingId': 'Booking ID',
      'showQrToDriver': 'Show QR code to driver when boarding',
      'cashPayment': 'Pay cash to driver',
      'welcome': 'Welcome',
      'welcomeDesc': 'Book your trip easily from here',
      'switchLanguage': 'العربية',
      'driverInfo': 'Driver Information',
      'driverName': 'Driver Name',
      'driverPhone': 'Driver Phone',
      'vehicleInfo': 'Vehicle Information',
      'plateNumber': 'Plate Number',
      'noDriverAssigned': 'Driver will be assigned soon',
    },
  };

  String t(String key) {
    final lang = _isArabic ? 'ar' : 'en';
    return _texts[lang]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadLines();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadLines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getWalkInLines();
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _lines = (result['lines'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result['message'] ?? t('error');
            _isLoading = false;
          });
        }
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

  Future<void> _loadTrips() async {
    if (_selectedLine == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Default to 'going' direction for walk-in terminal (passengers at station)
      final result = await ApiService.getWalkInTrips(
        lineid: _selectedLine!['lineid'].toString(),
        direction: 'going',
      );
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _trips = (result['trips'] as List?)
                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                    .toList() ??
                [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = result['message'] ?? t('error');
            _isLoading = false;
          });
        }
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

  Future<void> _createBooking() async {
    if (_selectedLine == null || _selectedTrip == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.registerWalkInBooking(
        lineid: _selectedLine!['lineid'].toString(),
        phone: _phoneNumber,
        tripid: _selectedTrip!['tripid'].toString(),
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _qrCode = result['qrCode'] as String?;
            _bookingResult = result;
            _isLoading = false;
            _currentStep = 3; // Move to QR display step
          });
        } else {
          setState(() {
            _error = result['message'] ?? t('error');
            _isLoading = false;
          });
        }
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

  void _onLineSelected(Map<String, dynamic> line) {
    setState(() {
      _selectedLine = line;
    });
  }

  void _onTripSelected(Map<String, dynamic> trip) {
    setState(() {
      _selectedTrip = trip;
    });
  }

  bool _validatePhone() {
    final phone = _phoneController.text.trim().replaceAll(' ', '');
    // Palestinian phone format validation
    final phoneRegex = RegExp(r'^(\+?970|0)?[5][0-9]{8}$');
    if (phone.isEmpty) {
      setState(() {
        _error = t('phoneRequired');
      });
      return false;
    }
    if (!phoneRegex.hasMatch(phone)) {
      setState(() {
        _error = t('invalidPhone');
      });
      return false;
    }
    _phoneNumber = phone;
    return true;
  }

  void _goToNextStep() {
    setState(() {
      _error = null;
    });

    if (_currentStep == 0) {
      // From line selection to phone entry
      if (_selectedLine == null) return;
      setState(() {
        _currentStep = 1;
      });
    } else if (_currentStep == 1) {
      // From phone entry to trip selection
      if (!_validatePhone()) return;
      _loadTrips();
      setState(() {
        _currentStep = 2;
      });
    } else if (_currentStep == 2) {
      // From trip selection to booking confirmation
      if (_selectedTrip == null) return;
      _createBooking();
    }
  }

  void _goToPreviousStep() {
    setState(() {
      _error = null;
    });

    if (_currentStep > 0 && _currentStep < 3) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _resetWizard() {
    setState(() {
      _currentStep = 0;
      _selectedLine = null;
      _selectedTrip = null;
      _phoneController.clear();
      _phoneNumber = '';
      _qrCode = null;
      _bookingResult = null;
      _trips = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1929),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingView()
                    : _error != null
                        ? _buildErrorView()
                        : _buildStepContent(),
              ),
              if (_currentStep < 3) _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF0A1929)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Logo or icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStepIndicator(),
              ],
            ),
          ),
          // Language toggle
          TextButton(
            onPressed: () {
              setState(() {
                _isArabic = !_isArabic;
              });
            },
            child: Text(
              t('switchLanguage'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      t('selectLine'),
      t('enterPhone'),
      t('selectTrip'),
      t('booking'),
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index == _currentStep;
        final isCompleted = index < _currentStep;
        return Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? Colors.green
                    : isActive
                        ? Colors.blue
                        : Colors.white24,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            if (index < steps.length - 1)
              Container(
                width: 30,
                height: 2,
                color: isCompleted ? Colors.green : Colors.white24,
              ),
          ],
        );
      }),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.blue,
            strokeWidth: 4,
          ),
          const SizedBox(height: 20),
          Text(
            t('loading'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            _error ?? t('error'),
            style: const TextStyle(
              color: Colors.red,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _error = null;
              });
              if (_currentStep == 0) {
                _loadLines();
              } else if (_currentStep == 2) {
                _loadTrips();
              }
            },
            icon: const Icon(Icons.refresh),
            label: Text(t('retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildLineSelectionStep();
      case 1:
        return _buildPhoneEntryStep();
      case 2:
        return _buildTripSelectionStep();
      case 3:
        return _buildQRDisplayStep();
      default:
        return _buildLineSelectionStep();
    }
  }

  Widget _buildLineSelectionStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                t('selectLine'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('selectLineDesc'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Text(
                    t('noLines'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _lines.length,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    final isSelected =
                        _selectedLine?['lineid'] == line['lineid'];
                    final lineName = _isArabic
                        ? (line['name_ar'] ?? line['linename'] ?? '')
                        : (line['name_en'] ?? line['linename'] ?? '');
                    final price = line['baseprice'] ?? 0;

                    return GestureDetector(
                      onTap: () => _onLineSelected(line),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : Colors.white.withOpacity(0.2),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.route,
                                color: isSelected ? Colors.white : Colors.blue,
                                size: 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                lineName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.9),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '₪$price',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.green,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPhoneEntryStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                t('enterPhone'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('enterPhoneDesc'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phone input field
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: t('phoneHint'),
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 32,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Numeric keypad
                    _buildNumericKeypad(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => _onKeypadPress(key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: key == 'C'
                          ? Colors.red.withOpacity(0.3)
                          : key == '⌫'
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  void _onKeypadPress(String key) {
    setState(() {
      if (key == 'C') {
        _phoneController.clear();
      } else if (key == '⌫') {
        if (_phoneController.text.isNotEmpty) {
          _phoneController.text = _phoneController.text
              .substring(0, _phoneController.text.length - 1);
        }
      } else {
        if (_phoneController.text.length < 10) {
          _phoneController.text = _phoneController.text + key;
        }
      }
    });
  }

  Widget _buildTripSelectionStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                t('selectTrip'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('selectTripDesc'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (_selectedLine != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isArabic
                        ? (_selectedLine!['name_ar'] ??
                            _selectedLine!['linename'] ??
                            '')
                        : (_selectedLine!['name_en'] ??
                            _selectedLine!['linename'] ??
                            ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _trips.isEmpty
              ? Center(
                  child: Text(
                    t('noTrips'),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _trips.length,
                  itemBuilder: (context, index) {
                    final trip = _trips[index];
                    final isSelected =
                        _selectedTrip?['tripid'] == trip['tripid'];

                    // Parse departure time and convert UTC to local
                    String timeStr = '';
                    if (trip['deptime'] != null) {
                      try {
                        final depTimeUtc =
                            DateTime.parse(trip['deptime'].toString());
                        // Convert UTC to local time
                        final depTimeLocal = depTimeUtc.toLocal();
                        final hour = depTimeLocal.hour.toString().padLeft(2, '0');
                        final minute =
                            depTimeLocal.minute.toString().padLeft(2, '0');
                        timeStr = '$hour:$minute';
                      } catch (e) {
                        timeStr = trip['deptime'].toString();
                      }
                    }

                    final direction = trip['direction'] ?? 'going';
                    final directionText = direction == 'return'
                        ? t('return')
                        : t('going');
                    final availableSeats = trip['availableseats'] ?? 0;
                    final price =
                        trip['line']?['baseprice'] ?? _selectedLine?['baseprice'] ?? 0;

                    return GestureDetector(
                      onTap: () => _onTripSelected(trip),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2E7D32),
                                    Color(0xFF1B5E20)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : Colors.white.withOpacity(0.2),
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Time
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          direction == 'return'
                                              ? Icons.arrow_back
                                              : Icons.arrow_forward,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          directionText,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.event_seat,
                                          color: Colors.green,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$availableSeats ${t('seats')}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Price
                              Column(
                                children: [
                                  Text(
                                    '₪$price',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.green,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildQRDisplayStep() {
    final reservation = _bookingResult?['reservation'];
    final driver = _bookingResult?['driver'];
    final bookingId = reservation?['bookingid']?.toString() ?? '';
    final shortBookingId =
        bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
          // Success icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('bookingComplete'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${t('bookingId')}: $shortBookingId',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          // Driver Info Card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.teal.withOpacity(0.4),
                width: 2,
              ),
            ),
            child: driver != null
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person,
                            color: Colors.teal,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            t('driverInfo'),
                            style: const TextStyle(
                              color: Colors.teal,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Driver name
                      if (driver['fullname'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.badge,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                driver['fullname'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Driver phone
                      if (driver['phone'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                driver['phone'].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Vehicle info
                      if (driver['vehicle'] != null) ...[
                        const Divider(color: Colors.white24, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.directions_car,
                              color: Colors.amber,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              t('vehicleInfo'),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Plate number
                        if (driver['vehicle']['platenumber'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              driver['vehicle']['platenumber'].toString(),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Make, model, color
                        Text(
                          [
                            driver['vehicle']['make'],
                            driver['vehicle']['model'],
                            driver['vehicle']['color'],
                          ].where((e) => e != null).join(' • '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  )
                : Column(
                    children: [
                      const Icon(
                        Icons.hourglass_empty,
                        color: Colors.amber,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('noDriverAssigned'),
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          // QR Code
          if (_qrCode != null && _qrCode!.startsWith('data:image'))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Image.memory(
                base64Decode(_qrCode!.split(',').last),
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 24),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.blue,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('showQrToDriver'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.payments,
                      color: Colors.green,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        t('cashPayment'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // New booking button
          ElevatedButton.icon(
            onPressed: _resetWizard,
            icon: const Icon(Icons.add),
            label: Text(
              t('newBooking'),
              style: const TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
      child: Row(
        children: [
          // Back button
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _goToPreviousStep,
                icon: Icon(
                  _isArabic ? Icons.arrow_forward : Icons.arrow_back,
                  color: Colors.white70,
                ),
                label: Text(
                  t('back'),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          // Next/Confirm button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _canProceed() ? _goToNextStep : null,
              icon: Icon(
                _currentStep == 2
                    ? Icons.check
                    : _isArabic
                        ? Icons.arrow_back
                        : Icons.arrow_forward,
              ),
              label: Text(
                _currentStep == 2 ? t('confirm') : t('next'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceed() ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedLine != null;
      case 1:
        return _phoneController.text.length >= 9;
      case 2:
        return _selectedTrip != null;
      default:
        return false;
    }
  }
}

