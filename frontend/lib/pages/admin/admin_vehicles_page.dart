import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminVehiclesPage extends StatefulWidget {
  const AdminVehiclesPage({super.key});

  @override
  State<AdminVehiclesPage> createState() => _AdminVehiclesPageState();
}

class _AdminVehiclesPageState extends State<AdminVehiclesPage> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _isLoading = true;
  bool _isArabic = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة المركبات',
      'vehicles': 'المركبات',
      'noVehicles': 'لا توجد مركبات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'plateNumber': 'رقم اللوحة',
      'seatLayout': 'تخطيط المقاعد',
      'seats': 'المقاعد',
      'status': 'الحالة',
      'active': 'نشط',
      'inactive': 'غير نشط',
    },
    'en': {
      'title': 'Vehicles Management',
      'vehicles': 'Vehicles',
      'noVehicles': 'No vehicles found',
      'loading': 'Loading...',
      'error': 'Error',
      'plateNumber': 'Plate Number',
      'seatLayout': 'Seat Layout',
      'seats': 'Seats',
      'status': 'Status',
      'active': 'Active',
      'inactive': 'Inactive',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
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
      final vehicles = await ApiService.getAllVehicles();
      setState(() {
        _vehicles = vehicles;
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

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: Colors.white,
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
            : _vehicles.isEmpty
                ? Center(
                    child: Text(
                      t('noVehicles'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.directions_car, color: Colors.orange, size: 40),
                          title: Text(
                            vehicle['plateno'] ?? 'No Plate',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t('seatLayout')}: ${vehicle['seatlayout'] ?? ''}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '${t('seats')}: ${vehicle['seatnum'] ?? 0}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (vehicle['status'] != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (vehicle['status'] == 'active' ? Colors.green : Colors.red).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    vehicle['status'] == 'active' ? t('active') : t('inactive'),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
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

