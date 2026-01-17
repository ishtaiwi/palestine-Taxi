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
  String? _lineFilter;
  List<Map<String, dynamic>> _lines = [];

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
      'going': 'ذهاب',
      'return': 'إياب',
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
      'going': 'Going',
      'return': 'Return',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  /// Get direction label with station names from line name and trip direction
  String _getTripDirectionLabel(Map<String, dynamic>? line, String? direction) {
    if (direction == null) {
      return '';
    }

    final lineName = _isArabic
        ? (line?['name_ar']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_en']?.toString() ??
            '')
        : (line?['name_en']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_ar']?.toString() ??
            '');

    if (lineName.isEmpty) {
      // Fallback to default labels if line name not available
      return direction == 'going' ? t('going') : t('return');
    }

    // Split line name by "-" to get station names
    final parts = lineName
        .split('-')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      // If line name doesn't have "-" separator, fallback to default labels
      return direction == 'going' ? t('going') : t('return');
    }

    // First part is the first station, second part is the second station
    final firstStation = parts[0];
    final secondStation = parts[1];

    String fromStation, toStation;
    if (direction == 'going') {
      // Going: From first station to second station
      fromStation = firstStation;
      toStation = secondStation;
    } else {
      // Returning: From second station to first station
      fromStation = secondStation;
      toStation = firstStation;
    }

    // Format: "From [station1] to [station2]"
    return _isArabic
        ? 'من $fromStation إلى $toStation'
        : 'From $fromStation to $toStation';
  }

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _loadLines();
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

  Future<void> _loadLines() async {
    try {
      final lines = await ApiService.getAllLines();
      if (mounted) {
        setState(() {
          _lines = lines;
        });
      }
    } catch (e) {
      // Silently fail - lines filter is optional
    }
  }

  void _applyFilter() {
    _filteredTrips = _trips.where((trip) {
      final lineName =
          (trip['line']?['linename'] ?? '').toString().toLowerCase();
      final lineNameAr =
          (trip['line']?['name_ar'] ?? '').toString().toLowerCase();
      final lineNameEn =
          (trip['line']?['name_en'] ?? '').toString().toLowerCase();
      final plateNo =
          (trip['vehicle']?['plateno'] ?? '').toString().toLowerCase();
      final driverName =
          (trip['vehicle']?['driver']?['user']?['fullname'] ?? '')
              .toString()
              .toLowerCase();
      final status = (trip['status'] ?? '').toString().toLowerCase();
      final lineId = trip['line']?['lineid']?.toString();

      final matchesSearch = _searchQuery.isEmpty ||
          lineName.contains(_searchQuery) ||
          lineNameAr.contains(_searchQuery) ||
          lineNameEn.contains(_searchQuery) ||
          plateNo.contains(_searchQuery) ||
          driverName.contains(_searchQuery);

      final matchesStatus =
          _statusFilter == null || status == _statusFilter?.toLowerCase();

      final matchesLine = _lineFilter == null || lineId == _lineFilter;

      return matchesSearch && matchesStatus && matchesLine;
    }).toList();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    try {
      // Normalize Supabase timestamp format to ISO 8601 and convert to local time
      // Supabase returns: "2025-12-23 21:00:00+00" -> convert to: "2025-12-23T21:00:00Z"
      String normalized = dateString.toString();
      // Replace space with T
      normalized = normalized.replaceFirst(' ', 'T');
      // Replace +00 or +00:00 with Z (UTC indicator)
      normalized = normalized.replaceFirst(RegExp(r'\+00:?00?$'), 'Z');
      // If no timezone indicator, assume UTC
      if (!normalized.contains('Z') &&
          !normalized.contains('+') &&
          !normalized.contains('-')) {
        normalized += 'Z';
      }
      // Parse as UTC and convert to local timezone for display
      final date = DateTime.parse(normalized).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      debugPrint('Error parsing date in admin trips: $dateString, error: $e');
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
        return status ?? 'Unknown';
    }
  }

  Future<void> _handleDelete(String tripid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        title: Text(t('deleteConfirm'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('no'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('yes'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteTrip(tripid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? (result['success'] == true ? t('tripDeleted') : t('error'))),
          backgroundColor: result['success'] == true ? Colors.green : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result['success'] == true) _loadData();
    }
  }

  String _getLineName(Map<String, dynamic>? line) {
    if (line == null) return '';
    final lineName = _isArabic
        ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '')
        : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? '');
    return lineName.isEmpty ? 'Unknown' : lineName;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection =
        _isArabic ? material.TextDirection.rtl : material.TextDirection.ltr;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(context),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildLineFilter(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildFilterSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  Expanded(
                    child: _filteredTrips.isEmpty
                        ? _buildEmptyState(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                        : ListView.separated(
                            padding: EdgeInsets.all(basePadding),
                            itemCount: _filteredTrips.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                            itemBuilder: (context, index) {
                              return _buildTripCard(
                                _filteredTrips[index],
                                isSmallScreen: isSmallScreen,
                                isMediumScreen: isMediumScreen,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541) // Dark card color for better integration
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded, 
          color: Colors.white,
          size: isSmallScreen ? 18.0 : 20.0,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        t('title'),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isArabic ? Icons.language : Icons.translate,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          onPressed: () {
            setState(() {
              _isArabic = !_isArabic;
              ApiService.saveLanguagePreference(_isArabic);
            });
          },
        ),
        SizedBox(width: isSmallScreen ? 4.0 : 8.0),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isSmallScreen ? 16.0 : 20.0),
        ),
      ),
    );
  }

  Widget _buildSearchBar({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        isSmallScreen ? 16.0 : 20.0, 
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        0
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 15.0),
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
        style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(
              color: AppTheme.isDarkMode
                  ? Colors.white70
                  : AppTheme.textSecondary),
          prefixIcon: Icon(Icons.search_rounded,
              color: AppTheme.isDarkMode
                  ? Colors.white70
                  : AppTheme.textSecondary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0, 
            vertical: isSmallScreen ? 12.0 : 15.0
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppTheme.isDarkMode
                          ? Colors.white70
                          : AppTheme.textSecondary),
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

  Widget _buildLineFilter({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        8.0, 
        isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
        0
      ),
      child: DropdownButtonFormField<String?>(
        value: _lineFilter,
        decoration: InputDecoration(
          labelText: t('line'),
          prefixIcon: Icon(Icons.directions_bus_rounded, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
          filled: true,
          fillColor: AppTheme.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 15.0),
            borderSide: BorderSide(color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 15.0),
            borderSide: BorderSide(color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 15.0),
            borderSide: BorderSide(color: AppTheme.appBarColor, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0, 
            vertical: isSmallScreen ? 12.0 : 15.0
          ),
        ),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(t('filterAll')),
          ),
          ..._lines.map((line) {
            final lineId = line['lineid']?.toString();
            final lineName = _getLineName(line);
            return DropdownMenuItem<String?>(
              value: lineId,
              child: Text(lineName),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _lineFilter = value;
            _applyFilter();
          });
        },
        style: TextStyle(
          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildFilterSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0), 
        horizontal: isSmallScreen ? 12.0 : 16.0
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, t('filterAll'), isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('scheduled', t('scheduled'),
                color: Colors.blueAccent, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('in_progress', t('in_progress'),
                color: Colors.orangeAccent, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('completed', t('completed'), color: Colors.green, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 6.0 : 8.0),
            _buildFilterChip('cancelled', t('cancelled'),
                color: Colors.redAccent, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? status, String label, {Color? color, bool isSmallScreen = false, bool isMediumScreen = false}) {
    final isSelected = _statusFilter == status;
    final activeColor = color ?? AppTheme.appBarColor;
    final isDark = AppTheme.isDarkMode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = status;
          _applyFilter();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
          vertical: isSmallScreen ? 6.0 : 8.0
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark && status == null ? Colors.blueAccent : activeColor)
              : AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
          border: Border.all(
            color: isSelected
                ? (isDark && status == null ? Colors.blueAccent : activeColor)
                : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : AppTheme.textSecondary.withOpacity(0.3)),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark && status == null
                            ? Colors.blueAccent
                            : activeColor)
                        .withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : AppTheme.textSecondary),
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
          ),
        ),
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final line = trip['line'] as Map<String, dynamic>?;
    final vehicle = trip['vehicle'] as Map<String, dynamic>?;
    final driver = vehicle?['driver']?['user'] as Map<String, dynamic>?;
    final direction = trip['direction']?.toString();

    // Get direction label with station names (e.g., "From Nablus to Beit Iba")
    final tripDirectionLabel = _getTripDirectionLabel(line, direction);

    final status = trip['status']?.toString();
    final statusColor = _getStatusColor(status);
    final isDark = AppTheme.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      color: statusColor,
                      size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tripDirectionLabel.isNotEmpty ? tripDirectionLabel : 'Unknown Line',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: isSmallScreen ? 12.0 : 14.0,
                                color: isDark
                                    ? Colors.white70
                                    : AppTheme.textSecondary),
                            SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                            Text(
                              _formatDate(trip['deptime']),
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8.0 : 10.0, 
                      vertical: isSmallScreen ? 3.0 : 4.0
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Divider(
                  color: isDark
                      ? Colors.white12
                      : AppTheme.textSecondary.withOpacity(0.1)),
              SizedBox(height: isSmallScreen ? 10.0 : 12.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildInfoColumn(Icons.directions_car_rounded, t('vehicle'),
                      vehicle?['plateno'] ?? 'N/A', isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildInfoColumn(Icons.person_rounded, t('driver'),
                      driver?['fullname'] ?? 'N/A', isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildInfoColumn(Icons.event_seat_rounded, t('bookings'),
                      '${trip['totalbookings'] ?? 0}', isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                ],
              ),
              SizedBox(height: isSmallScreen ? 10.0 : 12.0),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
                  onPressed: () => _handleDelete(trip['tripid']),
                  tooltip: t('delete'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final isDark = AppTheme.isDarkMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon,
            size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
            color: isDark ? Colors.blueAccent : AppTheme.textSecondary),
        SizedBox(height: isSmallScreen ? 4.0 : 6.0),
        Text(
          value,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
            fontSize: isSmallScreen ? 10.0 : 11.0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 24.0 : (isMediumScreen ? 27.0 : 30.0)),
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
              size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
              color: AppTheme.isDarkMode
                  ? Colors.white24
                  : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            t('noTrips'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
