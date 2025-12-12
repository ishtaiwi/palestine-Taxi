import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/passenger_bottom_nav_bar.dart';
import 'passenger_home.dart';

class PassengerReservationsPage extends StatefulWidget {
  const PassengerReservationsPage({super.key});

  @override
  State<PassengerReservationsPage> createState() => _PassengerReservationsPageState();
}

class _PassengerReservationsPageState extends State<PassengerReservationsPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isDarkMode = false; // Light mode as default
  String? _error;
  List<Map<String, dynamic>> _reservations = [];
  String? _selectedStatus;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'حجوزاتي',
      'subtitle': 'عرض وإدارة حجوزاتك',
      'all': 'الكل',
      'pending': 'قيد الانتظار',
      'confirmed': 'مؤكد',
      'checked_in': 'تم الصعود',
      'cancelled': 'ملغى',
      'no_show': 'لم يحضر',
      'noReservations': 'لا توجد حجوزات',
      'trip': 'الرحلة',
      'status': 'الحالة',
      'price': 'السعر',
      'seat': 'المقعد',
      'departure': 'موعد الانطلاق',
      'cancel': 'إلغاء',
      'viewDetails': 'عرض التفاصيل',
      'refresh': 'تحديث',
      'bookingType': 'نوع الحجز',
      'instant': 'فوري',
      'future': 'مسبق',
      'rateTrip': 'قيم الرحلة',
      'rating': 'التقييم',
      'comment': 'تعليق (اختياري)',
      'submit': 'إرسال',
      'alreadyRated': 'تم التقييم',
      'rateAgain': 'عدّل التقييم',
      'tripCompleted': 'الرحلة مكتملة',
      'showQRCode': 'عرض QR Code',
      'qrCode': 'QR Code',
      'scanQRCode': 'امسح QR Code للسائق',
      'driverInfo': 'معلومات السائق',
      'driverName': 'اسم السائق',
      'driverPhone': 'رقم الهاتف',
      'vehiclePlate': 'رقم اللوحة',
      'vehicleType': 'نوع المركبة',
      'close': 'إغلاق',
    },
    'en': {
      'title': 'My Reservations',
      'subtitle': 'View and manage your reservations',
      'all': 'All',
      'pending': 'Pending',
      'confirmed': 'Confirmed',
      'checked_in': 'Checked In',
      'cancelled': 'Cancelled',
      'no_show': 'No Show',
      'noReservations': 'No reservations',
      'trip': 'Trip',
      'status': 'Status',
      'price': 'Price',
      'seat': 'Seat',
      'departure': 'Departure',
      'cancel': 'Cancel',
      'viewDetails': 'View Details',
      'refresh': 'Refresh',
      'bookingType': 'Booking Type',
      'instant': 'Instant',
      'future': 'Future',
      'rateTrip': 'Rate Trip',
      'rating': 'Rating',
      'comment': 'Comment (Optional)',
      'submit': 'Submit',
      'alreadyRated': 'Already Rated',
      'rateAgain': 'Update Rating',
      'tripCompleted': 'Trip Completed',
      'showQRCode': 'Show QR Code',
      'qrCode': 'QR Code',
      'scanQRCode': 'Scan QR Code for driver',
      'driverInfo': 'Driver Information',
      'driverName': 'Driver Name',
      'driverPhone': 'Phone Number',
      'vehiclePlate': 'Vehicle Plate',
      'vehicleType': 'Vehicle Type',
      'close': 'Close',
    },
  };

  Map<String, Map<String, dynamic>?> _ratings = {};

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _initialize();
    _loadThemePreference();
  }

  Future<void> _initialize() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
    await _loadReservations();
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    setState(() {
      _isDarkMode = AppTheme.isDarkMode;
    });
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reservations = await ApiService.fetchPassengerReservations(
        status: _selectedStatus,
      );
      
      // Load ratings for completed trips
      final ratings = <String, Map<String, dynamic>?>{};
      for (final reservation in reservations) {
        final bookingid = reservation['bookingid']?.toString();
        final trip = reservation['trip'] as Map<String, dynamic>?;
        final tripStatus = trip?['status']?.toString();
        
        // Only load rating if trip is completed
        if (bookingid != null && tripStatus == 'completed') {
          try {
            final rating = await ApiService.getRatingByBookingId(bookingid);
            if (rating != null) {
              ratings[bookingid] = rating;
            }
          } catch (e) {
            // Ignore rating load errors
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _reservations = reservations;
          _ratings = ratings;
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
  
  Future<void> _showRatingDialog(Map<String, dynamic> reservation, Map<String, dynamic>? existingRating) async {
    final bookingid = reservation['bookingid']?.toString() ?? '';
    int selectedRating = existingRating?['rating'] ?? 5;
    final commentController = TextEditingController(text: existingRating?['comment'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            existingRating != null ? t('rateAgain') : t('rateTrip'),
            style: const TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rating stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 40,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // Comment field
                TextField(
                  controller: commentController,
                  style: const TextStyle(color: Color(0xFF1E3A5F)),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: t('comment'),
                    labelStyle: TextStyle(color: Colors.grey.shade700),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                t('cancel'),
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t('submit'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    Map<String, dynamic> ratingResult;
    if (existingRating != null) {
      // Update existing rating
      ratingResult = await ApiService.updateRating(
        ratingid: existingRating['ratingid'],
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
      );
    } else {
      // Submit new rating
      ratingResult = await ApiService.submitRating(
        bookingid: bookingid,
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
      );
    }

    // Close loading
    if (mounted) Navigator.pop(context);

    if (mounted) {
      if (ratingResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ratingResult['message'] ?? t('rating')),
            backgroundColor: Colors.green,
          ),
        );
        _loadReservations(); // Reload to update rating display
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ratingResult['message'] ?? 'Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showQRCodeDialog(String bookingId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await ApiService.getReservationQRCode(bookingId);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Failed to load QR code'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final qrData = result['qrData'] as String?;
      final qrCode = result['qrCode'] as String?;

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code, color: const Color(0xFF1E3A5F), size: 28),
                    const SizedBox(width: 12),
                    Text(
                      t('qrCode'),
                      style: const TextStyle(
                        color: Color(0xFF1E3A5F),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (qrData != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                    ),
                  )
                else if (qrCode != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: Image.network(
                      qrCode,
                      width: 250,
                      height: 250,
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          t('scanQRCode'),
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t('close'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelReservation(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancellation',
                style: const TextStyle(color: Color(0xFF1E3A5F), fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ],
        ),
        content: Text(
          _isArabic
              ? 'هل أنت متأكد من إلغاء هذه الحجز؟'
              : 'Are you sure you want to cancel this reservation?',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _isArabic ? 'لا' : 'No',
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isArabic ? 'نعم، إلغاء' : 'Yes, Cancel',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.cancelReservation(bookingId);
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? t('cancel')),
              backgroundColor: Colors.green,
            ),
          );
          _loadReservations();
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
      case 'pending_payment':
        return Colors.orange;
      case 'checked_in':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'no_show':
        return Colors.grey;
      default:
        return Colors.white; // نص أبيض على خلفية غامقة
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.hourglass_empty;
      case 'checked_in':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      case 'no_show':
        return Icons.person_off;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return t('confirmed');
      case 'pending':
      case 'pending_payment':
        return t('pending');
      case 'checked_in':
        return t('checked_in');
      case 'cancelled':
        return t('cancelled');
      case 'no_show':
        return t('no_show');
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    // Theme-aware colors
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
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
                    onPressed: _loadReservations,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Status Filter
              Container(
                padding: const EdgeInsets.all(16),
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
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip(null, t('all'), textPrimary, cardColor),
                      const SizedBox(width: 8),
                      _buildStatusChip('confirmed', t('confirmed'), textPrimary, cardColor),
                      const SizedBox(width: 8),
                      _buildStatusChip('pending', t('pending'), textPrimary, cardColor),
                      const SizedBox(width: 8),
                      _buildStatusChip('checked_in', t('checked_in'), textPrimary, cardColor),
                      const SizedBox(width: 8),
                      _buildStatusChip('cancelled', t('cancelled'), textPrimary, cardColor),
                    ],
                  ),
                ),
              ),
              // Reservations List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: const TextStyle(color: Color(0xFF1E3A5F)),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadReservations,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(t('refresh'), style: const TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : _reservations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.book_online, color: Colors.grey.shade400, size: 64),
                                    const SizedBox(height: 16),
                                    Text(
                                      t('noReservations'),
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _reservations.length,
                                itemBuilder: (context, index) {
                                  return _buildReservationCard(_reservations[index]);
                                },
                              ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: PassengerBottomNavBar(
          currentIndex: 1, // My Reservations is index 1
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            PassengerBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildDriverInfoRow(IconData icon, String label, String value, Color textColor) {
    final iconColor = _isDarkMode
        ? const Color(0xFF64B5F6)
        : Colors.blue.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status, String label, Color textColor, Color bgColor) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : textColor, // White when selected, theme color otherwise
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _loadReservations();
      },
      selectedColor: const Color(0xFF2C5F8D), // Professional blue when selected
      backgroundColor: _isDarkMode
          ? const Color(0xFF1E3A5F).withAlpha(128)
          : const Color(0xFF2C5F8D).withAlpha(51), // Theme-aware background
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : textColor, // White when selected, theme color otherwise
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final bookingId = reservation['bookingid']?.toString() ?? '';
    final status = reservation['status']?.toString() ?? '';
    final bookingType = reservation['booking_type']?.toString() ?? 'instant';
    final price = reservation['bookingprice'] ?? 0.0;
    final seat = reservation['seatlocation']?.toString() ?? '-';
    final trip = reservation['trip'] as Map<String, dynamic>?;
    final line = trip?['line'] as Map<String, dynamic>? ?? reservation['line'] as Map<String, dynamic>?;
    final deptime = trip?['deptime']?.toString() ?? reservation['scheduled_trip_time']?.toString() ?? '';

    // Theme-aware colors
    final cardColor = _isDarkMode
        ? const Color(0xFF1C2541)
        : const Color(0xFFFAFBFC);

    final textPrimary = _isDarkMode
        ? const Color(0xFFE8EAF6)
        : const Color(0xFF1E3A5F);

    final borderColor = _isDarkMode
        ? const Color(0xFF2C3E50)
        : Colors.grey.shade200;

    // Get line name based on current language
    final lineName = _isArabic
        ? (line?['name_ar']?.toString() ??
           line?['linename']?.toString() ??
           line?['name_en']?.toString() ??
           '')
        : (line?['name_en']?.toString() ??
           line?['linename']?.toString() ??
           line?['name_ar']?.toString() ??
           '');

    DateTime? departureTime;
    try {
      departureTime = DateTime.parse(deptime);
    } catch (e) {
      // Ignore
    }

    final canCancel = status != 'cancelled' && status != 'no_show' && status != 'checked_in';
    final tripStatus = trip?['status']?.toString();
    final canRate = tripStatus == 'completed' && (status == 'checked_in' || status == 'confirmed');
    final existingRating = _ratings[bookingId];

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF57C00).withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.route,
                            color: Color(0xFFF57C00),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lineName,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: bookingType == 'future'
                                  ? [Colors.orange.withAlpha(77), Colors.orange.withAlpha(51)]
                                  : [Colors.blue.withAlpha(77), Colors.blue.withAlpha(51)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: bookingType == 'future' ? Colors.orange.withAlpha(128) : Colors.blue.withAlpha(128),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                bookingType == 'future' ? Icons.calendar_today : Icons.flash_on,
                                color: bookingType == 'future' ? Colors.orange : Colors.blue,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                bookingType == 'future' ? t('future') : t('instant'),
                                style: TextStyle(
                                  color: bookingType == 'future' ? Colors.orange : Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withAlpha(51),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getStatusColor(status).withAlpha(128),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getStatusIcon(status),
                                color: _getStatusColor(status),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFF57C00),
                      Color(0xFFE65100),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF57C00).withAlpha(102),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2)} ₪',
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
                        color: Colors.white.withAlpha(230),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (departureTime != null)
            Row(
              children: [
                Icon(Icons.access_time, color: textPrimary, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${departureTime.day}/${departureTime.month}/${departureTime.year} ${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.event_seat, color: textPrimary, size: 16),
              const SizedBox(width: 4),
              Text(
                '${t('seat')}: $seat',
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          // Rating button (if trip is completed)
          if (canRate) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRatingDialog(reservation, existingRating),
                icon: Icon(existingRating != null ? Icons.edit : Icons.star),
                label: Text(
                  existingRating != null ? t('rateAgain') : t('rateTrip'),
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            // Show existing rating
            if (existingRating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < (existingRating['rating'] as int? ?? 0)
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.orange,
                      size: 20,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    '${existingRating['rating']}/5',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (existingRating['comment'] != null && existingRating['comment'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  existingRating['comment'].toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
          // Driver Information (if trip is assigned)
          if (trip != null && trip['vehicle'] != null && trip['vehicle']['driver'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? const Color(0xFF1E3A5F).withAlpha(128)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDarkMode
                      ? const Color(0xFF2C5F8D)
                      : Colors.blue.shade200,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isDarkMode
                        ? Colors.blue.withAlpha(26)
                        : Colors.blue.withAlpha(26),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: _isDarkMode
                            ? const Color(0xFF64B5F6)
                            : Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t('driverInfo'),
                        style: TextStyle(
                          color: _isDarkMode
                              ? const Color(0xFF64B5F6)
                              : Colors.blue.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (trip['vehicle']['driver']['user'] != null) ...[
                    _buildDriverInfoRow(
                      Icons.person,
                      t('driverName'),
                      trip['vehicle']['driver']['user']['fullname']?.toString() ?? '-',
                      textPrimary,
                    ),
                    if (trip['vehicle']['driver']['user']['phone'] != null)
                      _buildDriverInfoRow(
                        Icons.phone,
                        t('driverPhone'),
                        trip['vehicle']['driver']['user']['phone']?.toString() ?? '-',
                        textPrimary,
                      ),
                  ],
                  if (trip['vehicle'] != null) ...[
                    // عرض رقم المركبة دائماً (حتى لو كان null)
                    _buildDriverInfoRow(
                      Icons.directions_car,
                      t('vehiclePlate'),
                      trip['vehicle']['platenum']?.toString() ??
                      trip['vehicle']['plateno']?.toString() ??
                      (_isArabic ? 'غير متوفر' : 'Not Available'),
                      textPrimary,
                    ),
                    _buildDriverInfoRow(
                      Icons.local_taxi,
                      t('vehicleType'),
                      trip['vehicle']['seatnum'] == 5 ? '4+1' : trip['vehicle']['seatnum'] == 8 ? '7+1' : '${trip['vehicle']['seatnum']} seats',
                      textPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ],
          // QR Code and Cancel buttons
          const SizedBox(height: 16),
          Row(
            children: [
              if (status != 'cancelled' && status != 'checked_in')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showQRCodeDialog(bookingId),
                    icon: const Icon(Icons.qr_code, size: 20),
                    label: Text(t('showQRCode')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (status != 'cancelled' && status != 'checked_in') const SizedBox(width: 12),
              if (canCancel)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelReservation(bookingId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade700, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t('cancel'),
                      style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
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

