import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/api_service.dart';

class QRScannerPage extends StatefulWidget {
  final String? tripId;

  const QRScannerPage({super.key, this.tripId});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _isArabic = true;
  bool _isProcessing = false;
  MobileScannerController controller = MobileScannerController();

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'مسح QR Code',
      'instructions': 'وجه الكاميرا نحو QR Code للراكب',
      'processing': 'جاري المعالجة...',
      'success': 'تم تأكيد صعود الراكب بنجاح',
      'error': 'حدث خطأ',
      'invalidQR': 'QR Code غير صالح',
      'unauthorized': 'غير مصرح - هذا الحجز لا ينتمي لرحلتك',
      'close': 'إغلاق',
      'tryAgain': 'حاول مرة أخرى',
    },
    'en': {
      'title': 'Scan QR Code',
      'instructions': 'Point camera at passenger QR Code',
      'processing': 'Processing...',
      'success': 'Passenger checked in successfully',
      'error': 'Error occurred',
      'invalidQR': 'Invalid QR Code',
      'unauthorized': 'Unauthorized - This booking does not belong to your trip',
      'close': 'Close',
      'tryAgain': 'Try Again',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  void _onQRCodeDetect(BarcodeCapture barcodeCapture) {
    if (_isProcessing) return;

    final barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
    });

    // Stop scanning
    controller.stop();

    _processQRCode(barcode.rawValue!);
  }

  Future<void> _processQRCode(String qrData) async {
    try {
      // Show processing dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                t('processing'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      final result = await ApiService.checkInReservation(null, qrData: qrData);

      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog

      if (result['success'] == true) {
        // Show success message
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E3A5F),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  t('success'),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              result['reservation']?['passenger']?['user']?['fullname']?.toString() ??
                  'Passenger',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(context); // Go back to trips page
                },
                child: Text(t('close'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        // Show error message
        if (!mounted) return;
        final errorMessage = result['message']?.toString() ?? t('error');
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E3A5F),
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  t('error'),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close error dialog
                  setState(() {
                    _isProcessing = false;
                  });
                  controller.start(); // Resume scanning
                },
                child: Text(t('tryAgain'), style: const TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close error dialog
                  Navigator.pop(context); // Go back
                },
                child: Text(t('close'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                t('error'),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            e.toString(),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                setState(() {
                  _isProcessing = false;
                });
                controller.start(); // Resume scanning
              },
              child: Text(t('tryAgain'), style: const TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                Navigator.pop(context); // Go back
              },
              child: Text(t('close'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: controller,
              onDetect: _onQRCodeDetect,
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t('instructions'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

