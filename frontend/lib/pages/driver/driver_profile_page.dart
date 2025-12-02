import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isArabic = true;
  String? _error;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الملف الشخصي',
      'profileInfo': 'معلومات الملف الشخصي',
      'driverInfo': 'معلومات السائق',
      'personalInfo': 'المعلومات الشخصية',
      'vehicleInfo': 'معلومات المركبة',
      'lineInfo': 'معلومات الخط',
      'statistics': 'الإحصائيات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'refresh': 'تحديث',
      'retry': 'إعادة المحاولة',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'phone': 'الهاتف',
      'licenseId': 'رقم الرخصة',
      'status': 'الحالة',
      'rating': 'التقييم',
      'line': 'الخط',
      'vehicle': 'المركبة',
      'plateNumber': 'رقم اللوحة',
      'seatLayout': 'نوع المقاعد',
      'seatNumber': 'عدد المقاعد',
      'hasVehicle': 'يوجد مركبة',
      'noVehicle': 'لا توجد مركبة',
      'hasLine': 'يوجد خط',
      'noLine': 'لا يوجد خط',
      'unknown': 'غير معروف',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'pending': 'قيد الانتظار',
      'approved': 'معتمد',
      'rejected': 'مرفوض',
    },
    'en': {
      'title': 'Profile',
      'profileInfo': 'Profile Information',
      'driverInfo': 'Driver Information',
      'personalInfo': 'Personal Information',
      'vehicleInfo': 'Vehicle Information',
      'lineInfo': 'Line Information',
      'statistics': 'Statistics',
      'loading': 'Loading...',
      'error': 'Error',
      'refresh': 'Refresh',
      'retry': 'Retry',
      'name': 'Name',
      'email': 'Email',
      'phone': 'Phone',
      'licenseId': 'License ID',
      'status': 'Status',
      'rating': 'Rating',
      'line': 'Line',
      'vehicle': 'Vehicle',
      'plateNumber': 'Plate Number',
      'seatLayout': 'Seat Layout',
      'seatNumber': 'Seat Number',
      'hasVehicle': 'Has Vehicle',
      'noVehicle': 'No Vehicle',
      'hasLine': 'Has Line',
      'noLine': 'No Line',
      'unknown': 'Unknown',
      'active': 'Active',
      'inactive': 'Inactive',
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'price': 'Price',
      'base': 'Base',
      'distance': 'Distance',
      'duration': 'Duration',
    },
  };

  String t(String key) {
    final textMap = _texts[_isArabic ? 'ar' : 'en'];
    if (textMap == null) return key;
    return textMap[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadProfile();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getDriverProfile();
      if (mounted) {
        setState(() {
          _profileData = data;
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

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'approved':
        return Colors.green;
      case 'inactive':
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return t('active');
      case 'inactive':
        return t('inactive');
      case 'pending':
        return t('pending');
      case 'approved':
        return t('approved');
      case 'rejected':
        return t('rejected');
      default:
        return status ?? t('unknown');
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? t('unknown'),
                  style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
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
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadProfile,
              tooltip: t('refresh'),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          t('error'),
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _error ?? t('error'),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(t('retry')),
                        ),
                      ],
                    ),
                  )
                : _profileData == null
                    ? Center(
                        child: Text(
                          t('error'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          if (_profileData == null) {
                            return Center(
                              child: Text(
                                t('error'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          
                          final driver = _profileData?['driver'] as Map<String, dynamic>?;
                          final user = driver?['user'] as Map<String, dynamic>?;
                          final line = _profileData?['line'] as Map<String, dynamic>?;
                          final vehicles = _profileData?['vehicles'] as List<dynamic>?;
                          final hasVehicle = _profileData?['hasVehicle'] == true;
                          final hasLine = _profileData?['hasLine'] == true;
                          
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Driver Information
                                _buildSection(
                                  t('driverInfo'),
                                  Column(
                                    children: [
                                      _buildInfoRow(
                                    Icons.person,
                                    t('name'),
                                    user?['fullname']?.toString(),
                                  ),
                                  _buildInfoRow(
                                    Icons.email,
                                    t('email'),
                                    user?['email']?.toString(),
                                  ),
                                  if (user?['phone'] != null)
                                    _buildInfoRow(
                                      Icons.phone,
                                      t('phone'),
                                      user?['phone']?.toString(),
                                    ),
                                  if (driver?['licenseid'] != null)
                                    _buildInfoRow(
                                      Icons.card_membership,
                                      t('licenseId'),
                                      driver?['licenseid']?.toString(),
                                    ),
                                  _buildInfoRow(
                                    Icons.assessment,
                                    t('status'),
                                    _getStatusText(driver?['status']?.toString()),
                                    valueColor: _getStatusColor(driver?['status']?.toString()),
                                  ),
                                  if (driver?['rating'] != null)
                                    _buildInfoRow(
                                      Icons.star,
                                      t('rating'),
                                      '${driver?['rating']}/5.0',
                                      valueColor: Colors.orange,
                                    ),
                                ],
                              ),
                            ),

                                // Line Information
                                _buildSection(
                                  t('lineInfo'),
                                  Column(
                                    children: [
                                      if (hasLine && line != null) ...[
                                    _buildInfoRow(
                                      Icons.alt_route,
                                      t('line'),
                                      _isArabic
                                          ? (line['name_ar']?.toString() ?? 
                                             line['linename']?.toString() ?? 
                                             line['name_en']?.toString() ?? 
                                             t('unknown'))
                                          : (line['name_en']?.toString() ?? 
                                             line['linename']?.toString() ?? 
                                             line['name_ar']?.toString() ?? 
                                             t('unknown')),
                                    ),
                                    _buildInfoRow(
                                      Icons.attach_money,
                                      '${t('price')} (${t('base')})',
                                      '${line['baseprice'] ?? 0} ₪',
                                    ),
                                    if (line['distance'] != null)
                                      _buildInfoRow(
                                        Icons.straighten,
                                        '${t('distance')} (km)',
                                        '${line['distance']}',
                                      ),
                                    if (line['estduration'] != null)
                                      _buildInfoRow(
                                        Icons.access_time,
                                        '${t('duration')} (min)',
                                        '${line['estduration']}',
                                      ),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          t('noLine'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                                // Vehicle Information
                                _buildSection(
                                  t('vehicleInfo'),
                                  Column(
                                    children: [
                                      if (hasVehicle && vehicles != null && vehicles.isNotEmpty) ...[
                                    ...vehicles.map((vehicle) {
                                      final v = vehicle as Map<String, dynamic>;
                                      return Column(
                                        children: [
                                          _buildInfoRow(
                                            Icons.directions_car,
                                            t('plateNumber'),
                                            v['plateno']?.toString() ?? t('unknown'),
                                          ),
                                          _buildInfoRow(
                                            Icons.event_seat,
                                            t('seatLayout'),
                                            v['seatlayout']?.toString() ?? t('unknown'),
                                          ),
                                          _buildInfoRow(
                                            Icons.confirmation_number,
                                            t('seatNumber'),
                                            v['seatnum']?.toString() ?? t('unknown'),
                                          ),
                                          if (vehicles.length > 1 && vehicles.indexOf(vehicle) < vehicles.length - 1)
                                            const Divider(color: Colors.white24, height: 32),
                                        ],
                                      );
                                    }),
                                  ] else ...[
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text(
                                          t('noVehicle'),
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

