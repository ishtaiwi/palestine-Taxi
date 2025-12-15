import 'package:flutter/material.dart' hide TextDirection;
import 'package:flutter/material.dart' as material show TextDirection;
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminTripsPage extends StatefulWidget {
  const AdminTripsPage({super.key});

  @override
  State<AdminTripsPage> createState() => _AdminTripsPageState();
}

class _AdminTripsPageState extends State<AdminTripsPage> {
  List<Map<String, dynamic>> _trips = [];
  List<Map<String, dynamic>> _filteredTrips = [];
  bool _isLoading = true;
  bool _isArabic = true;

  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; 

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة الرحلات',
      'trips': 'الرحلات',
      'noTrips': 'لا توجد رحلات',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'departure': 'الانطلاق',
      'status': 'الحالة',
      'seats': 'المقاعد',
      'bookings': 'الحجوزات',
      'scheduled': 'مجدولة',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتملة',
      'cancelled': 'ملغاة',
      'search': 'بحث عن رحلة...',
      'filterAll': 'الكل',
      'delete': 'حذف',
      'deleteConfirm': 'هل أنت متأكد من حذف هذه الرحلة؟',
      'yes': 'نعم',
      'no': 'لا',
      'success': 'تم بنجاح',
      'tripDeleted': 'تم حذف الرحلة بنجاح',
      'line': 'الخط',
      'vehicle': 'المركبة',
      'driver': 'السائق',
    },
    'en': {
      'title': 'Trips Management',
      'trips': 'Trips',
      'noTrips': 'No trips found',
      'loading': 'Loading...',
      'error': 'Error',
      'departure': 'Departure',
      'status': 'Status',
      'seats': 'Seats',
      'bookings': 'Bookings',
      'scheduled': 'Scheduled',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'search': 'Search trips...',
      'filterAll': 'All',
      'delete': 'Delete',
      'deleteConfirm': 'Are you sure you want to delete this trip?',
      'yes': 'Yes',
      'no': 'No',
      'success': 'Success',
      'tripDeleted': 'Trip deleted successfully',
      'line': 'Line',
      'vehicle': 'Vehicle',
      'driver': 'Driver',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _loadLanguagePreference();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
      _applyFilter();
    });
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
        _applyFilter();
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
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _applyFilter() {
    _filteredTrips = _trips.where((trip) {
      final lineName = (trip['line']?['linename'] ?? '').toString().toLowerCase();
      final lineNameAr = (trip['line']?['name_ar'] ?? '').toString().toLowerCase();
      final lineNameEn = (trip['line']?['name_en'] ?? '').toString().toLowerCase();
      final plateNo = (trip['vehicle']?['plateno'] ?? '').toString().toLowerCase();
      final driverName = (trip['vehicle']?['driver']?['user']?['fullname'] ?? '').toString().toLowerCase();
      final status = (trip['status'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          lineName.contains(_searchQuery) ||
          lineNameAr.contains(_searchQuery) ||
          lineNameEn.contains(_searchQuery) ||
          plateNo.contains(_searchQuery) ||
          driverName.contains(_searchQuery);

      final matchesStatus = _statusFilter == null || status == _statusFilter?.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'scheduled':
        return Colors.blueAccent;
      case 'in_progress':
        return Colors.orangeAccent;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'scheduled':
        return t('scheduled');
      case 'in_progress':
        return t('in_progress');
      case 'completed':
        return t('completed');
      case 'cancelled':
        return t('cancelled');
      default:
        return status ?? '';
    }
  }

  

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? material.TextDirection.rtl : material.TextDirection.ltr;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterSection(),
                  Expanded(
                    child: _filteredTrips.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredTrips.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildTripCard(_filteredTrips[index]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        t('title'),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
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
        const SizedBox(width: 8),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(color: AppTheme.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, t('filterAll')),
            const SizedBox(width: 8),
            _buildFilterChip('scheduled', t('scheduled'), color: Colors.blueAccent),
            const SizedBox(width: 8),
            _buildFilterChip('in_progress', t('in_progress'), color: Colors.orangeAccent),
            const SizedBox(width: 8),
            _buildFilterChip('completed', t('completed'), color: Colors.green),
            const SizedBox(width: 8),
            _buildFilterChip('cancelled', t('cancelled'), color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? status, String label, {Color? color}) {
    final isSelected = _statusFilter == status;
    final activeColor = color ?? AppTheme.appBarColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = status;
          _applyFilter();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppTheme.textSecondary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final line = trip['line'] as Map<String, dynamic>?;
    final vehicle = trip['vehicle'] as Map<String, dynamic>?;
    final driver = vehicle?['driver']?['user'] as Map<String, dynamic>?;
    
    final lineName = _isArabic
        ? (line?['name_ar']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_en']?.toString() ??
            '')
        : (line?['name_en']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_ar']?.toString() ??
            '');

    final status = trip['status']?.toString();
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          right: _isArabic ? BorderSide(color: statusColor, width: 4) : BorderSide.none,
          left: !_isArabic ? BorderSide(color: statusColor, width: 4) : BorderSide.none,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lineName.isNotEmpty ? lineName : 'Unknown Line',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(trip['deptime']),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: AppTheme.textSecondary.withOpacity(0.1)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn(Icons.directions_car_rounded, t('vehicle'), vehicle?['plateno'] ?? 'N/A'),
                  _buildInfoColumn(Icons.person_rounded, t('driver'), driver?['fullname'] ?? 'N/A'),
                  _buildInfoColumn(Icons.event_seat_rounded, t('bookings'), '${trip['totalbookings'] ?? 0}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.directions_bus_outlined,
              size: 80,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('noTrips'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
