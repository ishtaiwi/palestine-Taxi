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
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 360;
      final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Text(
                t('processing'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 14.0 : 16.0,
                ),
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
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E3A5F),
            titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
            contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
            actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle, 
                  color: Colors.green,
                  size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                ),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                Text(
                  t('success'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                  ),
                ),
              ],
            ),
            content: Text(
              result['reservation']?['passenger']?['user']?['fullname']?.toString() ??
                  'Passenger',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14.0 : 16.0,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(context); // Go back to trips page
                },
                child: Text(
                  t('close'), 
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.0 : 14.0,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Show error message
        if (!mounted) return;
        final errorMessage = result['message']?.toString() ?? t('error');
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 360;
        final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E3A5F),
            titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
            contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
            actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            title: Row(
              children: [
                Icon(
                  Icons.error, 
                  color: Colors.red,
                  size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                ),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                Text(
                  t('error'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                  ),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14.0 : 16.0,
              ),
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
                child: Text(
                  t('tryAgain'), 
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.0 : 14.0,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close error dialog
                  Navigator.pop(context); // Go back
                },
                child: Text(
                  t('close'), 
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 13.0 : 14.0,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog
      
      final screenWidth = MediaQuery.of(context).size.width;
      final isSmallScreen = screenWidth < 360;
      final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E3A5F),
          titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
          contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
          actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          title: Row(
            children: [
              Icon(
                Icons.error, 
                color: Colors.red,
                size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
              ),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Text(
                t('error'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                ),
              ),
            ],
          ),
          content: Text(
            e.toString(),
            style: TextStyle(
              color: Colors.white70,
              fontSize: isSmallScreen ? 14.0 : 16.0,
            ),
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
              child: Text(
                t('tryAgain'), 
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 13.0 : 14.0,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close error dialog
                Navigator.pop(context); // Go back
              },
              child: Text(
                t('close'), 
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 13.0 : 14.0,
                ),
              ),
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
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 18.0 : 24.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(
            t('title'),
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
            ),
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
                padding: EdgeInsets.all(basePadding),
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
                      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline, 
                            color: Colors.white, 
                            size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0)
                          ),
                          SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                          Expanded(
                            child: Text(
                              t('instructions'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
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

