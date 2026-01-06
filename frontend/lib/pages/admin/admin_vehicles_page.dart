import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminVehiclesPage extends StatefulWidget {
  const AdminVehiclesPage({super.key});

  @override
  State<AdminVehiclesPage> createState() => _AdminVehiclesPageState();
}

class _AdminVehiclesPageState extends State<AdminVehiclesPage> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  bool _isLoading = true;
  bool _isArabic = true;

  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; 

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
      'search': 'بحث برقم اللوحة...',
      'filterAll': 'الكل',
      'edit': 'تعديل',
      'delete': 'حذف',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'editVehicle': 'تعديل المركبة',
      'deleteConfirm': 'هل أنت متأكد من حذف هذه المركبة؟',
      'yes': 'نعم',
      'no': 'لا',
      'success': 'تم بنجاح',
      'vehicleDeleted': 'تم حذف المركبة بنجاح',
      'vehicleUpdated': 'تم تحديث المركبة بنجاح',
      'plateRequired': 'رقم اللوحة مطلوب',
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
      'search': 'Search by plate number...',
      'filterAll': 'All',
      'edit': 'Edit',
      'delete': 'Delete',
      'save': 'Save',
      'cancel': 'Cancel',
      'editVehicle': 'Edit Vehicle',
      'deleteConfirm': 'Are you sure you want to delete this vehicle?',
      'yes': 'Yes',
      'no': 'No',
      'success': 'Success',
      'vehicleDeleted': 'Vehicle deleted successfully',
      'vehicleUpdated': 'Vehicle updated successfully',
      'plateRequired': 'Plate number is required',
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
      final vehicles = await ApiService.getAllVehicles();
      setState(() {
        _vehicles = vehicles;
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
    _filteredVehicles = _vehicles.where((vehicle) {
      final plateNo = (vehicle['plateno'] ?? '').toString().toLowerCase();
      final status = (vehicle['status'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty || plateNo.contains(_searchQuery);
      final matchesStatus = _statusFilter == null || status == _statusFilter?.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  

  Future<void> _deleteVehicle(String vehicleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        title: Text(t('delete'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
        content: Text(t('deleteConfirm'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary)),
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

    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final token = await ApiService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.delete(
        Uri.parse('${AppConfig.apiBaseUrl}/vehicles/$vehicleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (mounted) Navigator.pop(context); 

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('vehicleDeleted')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData(); 
        }
      } else {
        throw Exception('Failed to delete vehicle: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateVehicle(String vehicleId, Map<String, dynamic> updates) async {
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await ApiService.getToken();
      if (token == null) throw Exception('Not authenticated');

      final response = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/vehicles/$vehicleId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
        body: jsonEncode(updates),
      );

      if (mounted) Navigator.pop(context); 

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('vehicleUpdated')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData(); 
        }
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['message'] ?? 'Failed to update vehicle');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openEditDialog(Map<String, dynamic> vehicle) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final plateController = TextEditingController(text: vehicle['plateno']);
    String status = vehicle['status'] ?? 'active';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0)
        ),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          t('editVehicle'),
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary, 
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: plateController,
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                  ),
                  decoration: InputDecoration(
                    labelText: t('plateNumber'),
                    labelStyle: TextStyle(
                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                    ),
                    prefixIcon: Icon(
                      Icons.confirmation_number_rounded, 
                      color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary,
                      size: isSmallScreen ? 20.0 : 24.0,
                    ),
                    filled: true,
                    fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                      vertical: isSmallScreen ? 12.0 : 16.0,
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? t('plateRequired') : null,
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                DropdownButtonFormField<String>(
                  value: status,
                  dropdownColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                    fontSize: isSmallScreen ? 14.0 : 16.0,
                  ),
                  decoration: InputDecoration(
                    labelText: t('status'),
                    labelStyle: TextStyle(
                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                    ),
                    prefixIcon: Icon(
                      Icons.info_outline_rounded, 
                      color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary,
                      size: isSmallScreen ? 20.0 : 24.0,
                    ),
                    filled: true,
                    fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                      vertical: isSmallScreen ? 12.0 : 16.0,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(
                        t('active'), 
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text(
                        t('inactive'), 
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                          fontSize: isSmallScreen ? 14.0 : 16.0,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) status = value;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t('cancel'), 
              style: TextStyle(
                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _updateVehicle(vehicle['vehicleid'], {
                  'plateno': plateController.text.trim(),
                  'status': status,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0)
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20.0 : 24.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
            ),
            child: Text(
              t('save'), 
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

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
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
                  _buildFilterSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  Expanded(
                    child: _filteredVehicles.isEmpty
                        ? _buildEmptyState(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                        : ListView.separated(
                            padding: EdgeInsets.all(basePadding),
                            itemCount: _filteredVehicles.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                            itemBuilder: (context, index) {
                              return _buildVehicleCard(
                                _filteredVehicles[index],
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
          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
          fontSize: isSmallScreen ? 14.0 : 16.0,
        ),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
          prefixIcon: Icon(
            Icons.search_rounded, 
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0, 
            vertical: isSmallScreen ? 12.0 : 15.0
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded, 
                    color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                    size: isSmallScreen ? 20.0 : 24.0,
                  ),
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

  Widget _buildFilterSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0), 
        horizontal: isSmallScreen ? 12.0 : 16.0
      ),
      child: Row(
        children: [
          _buildFilterChip(null, t('filterAll'), isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(width: isSmallScreen ? 8.0 : 12.0),
          _buildFilterChip('active', t('active'), color: Colors.green, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(width: isSmallScreen ? 8.0 : 12.0),
          _buildFilterChip('inactive', t('inactive'), color: Colors.red, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        ],
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
                : (isDark ? Colors.white.withOpacity(0.1) : AppTheme.textSecondary.withOpacity(0.3)),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark && status == null ? Colors.blueAccent : activeColor).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textSecondary),
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final isActive = vehicle['status'] == 'active';
    final statusColor = isActive ? Colors.green : Colors.red;

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
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                decoration: BoxDecoration(
                  color: AppTheme.isDarkMode ? Colors.blueAccent.withOpacity(0.1) : AppTheme.appBarColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.directions_car_rounded,
                  color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                  size: isSmallScreen ? 24.0 : (isMediumScreen ? 26.0 : 28.0),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12.0 : 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle['plateno'] ?? 'No Plate',
                      style: TextStyle(
                        color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                        fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4.0 : 6.0),
                    Row(
                      children: [
                        Icon(
                          Icons.event_seat_rounded, 
                          size: isSmallScreen ? 12.0 : 14.0, 
                          color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary
                        ),
                        SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                        Text(
                          '${t('seats')}: ${vehicle['seatnum'] ?? 0}',
                          style: TextStyle(
                            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary, 
                            fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0)
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6.0 : 8.0, 
                            vertical: isSmallScreen ? 1.0 : 2.0
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                          ),
                          child: Text(
                            isActive ? t('active') : t('inactive'),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: isSmallScreen ? 10.0 : 11.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: Colors.blueAccent,
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                    onTap: () => _openEditDialog(vehicle),
                  ),
                  SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                    onTap: () => _deleteVehicle(vehicle['vehicleid']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Material(
      color: AppTheme.isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
          child: Icon(
            icon,
            size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
            color: color,
          ),
        ),
      ),
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
              Icons.directions_car_outlined,
              size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
              color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            t('noVehicles'),
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
