import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminTripsPage extends StatefulWidget {
  const AdminTripsPage({super.key});

  @override
  State<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends State<AdminTripsPage> {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  bool _isArabic = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة الرحلات',
      'trips': 'الرحلات',
      'noTrips': 'لا توجد رحلات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'departure': 'الانطلاق',
      'status': 'الحالة',
      'seats': 'المقاعد المتاحة',
      'bookings': 'الحجوزات',
      'scheduled': 'مجدولة',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتملة',
      'cancelled': 'ملغاة',
    },
    'en': {
      'title': 'Trips Management',
      'trips': 'Trips',
      'noTrips': 'No trips found',
      'loading': 'Loading...',
      'error': 'Error',
      'departure': 'Departure',
      'status': 'Status',
      'seats': 'Available Seats',
      'bookings': 'Bookings',
      'scheduled': 'Scheduled',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final trips = await ApiService.getAllTrips();
      setState(() {
        _trips = trips;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            t('title'),
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.appBarColor,
          elevation: 2,
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: AppTheme.textPrimary,
              ),
              onPressed: () {
                setState(() {
                  _isArabic = !_isArabic;
                  ApiService.saveLanguagePreference(_isArabic);
                });
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _trips.isEmpty
                ? Center(
                    child: Text(
                      t('noTrips'),
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      final line = trip['line'] as Map<String, dynamic>?;
                      return Card(
                        color: AppTheme.getCardBackground(0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.directions_bus,
                              color: Colors.purple, size: 40),
                          title: Text(
                            (_isArabic
                                ? (line?['name_ar']?.toString() ??
                                    line?['linename']?.toString() ??
                                    line?['name_en']?.toString() ??
                                    'Unknown Line')
                                : (line?['name_en']?.toString() ??
                                    line?['linename']?.toString() ??
                                    line?['name_ar']?.toString() ??
                                    'Unknown Line')),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t('departure')}: ${_formatDate(trip['deptime'])}',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              Text(
                                '${t('seats')}: ${trip['availableseats'] ?? 0} | ${t('bookings')}: ${trip['totalbookings'] ?? 0}',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                              if (trip['status'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    trip['status'] == 'scheduled'
                                        ? t('scheduled')
                                        : trip['status'] == 'in_progress'
                                            ? t('in_progress')
                                            : trip['status'] == 'completed'
                                                ? t('completed')
                                                : t('cancelled'),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
