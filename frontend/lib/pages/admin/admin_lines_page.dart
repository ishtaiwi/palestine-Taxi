import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminLinesPage extends StatefulWidget {
  const AdminLinesPage({super.key});

  @override
  State<AdminLinesPage> createState() => _AdminLinesPageState();
}

class _AdminLinesPageState extends State<AdminLinesPage> {
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _filteredLines = [];
  bool _isLoading = true;
  bool _isArabic = true;

  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  
  final _formKey = GlobalKey<FormState>();
  final _nameArController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _additionalPriceController = TextEditingController();
  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  bool _active = true;
  String? _editingLineId;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة الخطوط',
      'lines': 'الخطوط',
      'createLine': 'إنشاء خط جديد',
      'lineName': 'اسم الخط',
      'lineNameAr': 'الاسم بالعربية',
      'lineNameEn': 'الاسم بالإنجليزية',
      'basePrice': 'السعر الأساسي',
      'additionalPrice': 'السعر الإضافي',
      'duration': 'المدة (دقيقة)',
      'distance': 'المسافة (كم)',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'edit': 'تعديل',
      'delete': 'حذف',
      'noLines': 'لا توجد خطوط',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'confirmDelete': 'هل أنت متأكد من حذف هذا الخط؟',
      'yes': 'نعم',
      'no': 'لا',
      'required': 'مطلوب',
      'search': 'بحث عن خط...',
      'lineDetails': 'تفاصيل الخط',
      'currency': 'شيكل',
      'min': 'دقيقة',
      'km': 'كم',
    },
    'en': {
      'title': 'Lines Management',
      'lines': 'Lines',
      'createLine': 'Create New Line',
      'lineName': 'Line Name',
      'lineNameAr': 'Arabic Name',
      'lineNameEn': 'English Name',
      'basePrice': 'Base Price',
      'additionalPrice': 'Additional Price',
      'duration': 'Duration (minutes)',
      'distance': 'Distance (km)',
      'active': 'Active',
      'inactive': 'Inactive',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'delete': 'Delete',
      'noLines': 'No lines found',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirmDelete': 'Are you sure you want to delete this line?',
      'yes': 'Yes',
      'no': 'No',
      'required': 'Required',
      'search': 'Search lines...',
      'lineDetails': 'Line Details',
      'currency': 'NIS',
      'min': 'min',
      'km': 'km',
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
    _nameArController.dispose();
    _nameEnController.dispose();
    _basePriceController.dispose();
    _additionalPriceController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
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
      final lines = await ApiService.getAllLines();
      setState(() {
        _lines = lines;
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
    _filteredLines = _lines.where((line) {
      final nameAr = (line['name_ar'] ?? '').toString().toLowerCase();
      final nameEn = (line['name_en'] ?? '').toString().toLowerCase();
      final lineName = (line['linename'] ?? '').toString().toLowerCase();
      
      return _searchQuery.isEmpty || 
             nameAr.contains(_searchQuery) || 
             nameEn.contains(_searchQuery) ||
             lineName.contains(_searchQuery);
    }).toList();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();

    
    if (nameAr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isArabic ? 'الاسم بالعربية مطلوب' : 'Arabic name is required'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = _editingLineId != null
          ? await ApiService.updateLine(
              _editingLineId!,
              nameAr: nameAr.isNotEmpty ? nameAr : null,
              nameEn: nameEn.isNotEmpty ? nameEn : null,
              baseprice: double.tryParse(_basePriceController.text) ?? 0,
              additionalprice:
                  double.tryParse(_additionalPriceController.text) ?? 0,
              estduration: int.tryParse(_durationController.text),
              distance: double.tryParse(_distanceController.text),
              active: _active,
            )
          : await ApiService.createLine(
              nameAr: nameAr.isNotEmpty ? nameAr : null,
              nameEn: nameEn.isNotEmpty ? nameEn : null,
              baseprice: double.tryParse(_basePriceController.text) ?? 0,
              additionalprice:
                  double.tryParse(_additionalPriceController.text) ?? 0,
              estduration: int.tryParse(_durationController.text),
              distance: double.tryParse(_distanceController.text),
              active: _active,
            );

      
      if (mounted) Navigator.pop(context); 
      if (mounted) Navigator.pop(context); 

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? t('success')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? t('error')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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

  void _openFormDialog(BuildContext context, {Map<String, dynamic>? line}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    if (line != null) {
      _editingLineId = line['lineid'];
      _nameArController.text = line['name_ar'] ?? line['linename'] ?? '';
      _nameEnController.text = line['name_en'] ?? '';
      _basePriceController.text = (line['baseprice'] ?? 0).toString();
      _additionalPriceController.text =
          (line['additionalprice'] ?? 0).toString();
      _durationController.text = (line['estduration'] ?? '').toString();
      _distanceController.text = (line['distance'] ?? '').toString();
      _active = line['active'] ?? true;
    } else {
      _editingLineId = null;
      _nameArController.clear();
      _nameEnController.clear();
      _basePriceController.clear();
      _additionalPriceController.clear();
      _durationController.clear();
      _distanceController.clear();
      _active = true;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 20.0 : 24.0)
        ),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
        contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Center(
          child: Text(
            line == null ? t('createLine') : t('edit'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0),
            ),
          ),
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTextField(
                    controller: _nameArController,
                    label: t('lineNameAr'),
                    icon: Icons.text_fields_rounded,
                    validator: (value) =>
                        value?.isEmpty ?? true ? t('required') : null,
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  _buildTextField(
                    controller: _nameEnController,
                    label: t('lineNameEn'),
                    icon: Icons.language_rounded,
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _basePriceController,
                          label: t('basePrice'),
                          icon: Icons.attach_money_rounded,
                          isNumber: true,
                          validator: (value) =>
                              value?.isEmpty ?? true ? t('required') : null,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                      Expanded(
                        child: _buildTextField(
                          controller: _additionalPriceController,
                          label: t('additionalPrice'),
                          icon: Icons.add_circle_outline_rounded,
                          isNumber: true,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _durationController,
                          label: t('duration'),
                          icon: Icons.timer_rounded,
                          isNumber: true,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                      Expanded(
                        child: _buildTextField(
                          controller: _distanceController,
                          label: t('distance'),
                          icon: Icons.straighten_rounded,
                          isNumber: true,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                  StatefulBuilder(
                    builder: (context, setState) => SwitchListTile(
                      title: Text(
                        _active ? t('active') : t('inactive'),
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                      ),
                      value: _active,
                      activeColor: Colors.green,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                  ),
                ],
              ),
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
                fontWeight: FontWeight.w600,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20.0 : 24.0, 
                vertical: isSmallScreen ? 10.0 : 12.0
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)
              ),
              elevation: 4,
            ),
            child: Text(
              t('save'),
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: isSmallScreen ? 14.0 : 16.0
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(String lineid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        title: Text(
          t('confirmDelete'),
          style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
        ),
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

    final result = await ApiService.deleteLine(lineid);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('success')),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openFormDialog(context),
          backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          icon: Icon(
            Icons.add_rounded, 
            color: Colors.white,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
          label: Text(
            t('createLine'), 
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 13.0 : 14.0,
            ),
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  Expanded(
                    child: _filteredLines.isEmpty
                        ? _buildEmptyState(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              basePadding, 
                              basePadding, 
                              basePadding, 
                              isSmallScreen ? 70.0 : 80.0
                            ), 
                            itemCount: _filteredLines.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                            itemBuilder: (context, index) {
                              return _buildLineCard(
                                _filteredLines[index],
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
        4.0
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    String? Function(String?)? validator,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: isSmallScreen ? 13.0 : 14.0,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide(
            color: AppTheme.isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide(
            color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16.0 : 20.0, 
          vertical: isSmallScreen ? 12.0 : 16.0
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildLineCard(Map<String, dynamic> line, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    
    final lineName = _isArabic
        ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? '')
        : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? '');

    final isActive = line['active'] == true;

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
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: InkWell(
          onTap: () => _openFormDialog(context, line: line),
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                      decoration: BoxDecoration(
                        color: AppTheme.isDarkMode ? Colors.blueAccent.withOpacity(0.1) : AppTheme.appBarColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.timeline_rounded,
                        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                        size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineName,
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 6.0 : 8.0, 
                              vertical: isSmallScreen ? 1.0 : 2.0
                            ),
                            decoration: BoxDecoration(
                              color: (isActive ? Colors.green : Colors.red).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                            ),
                            child: Text(
                              isActive ? t('active') : t('inactive'),
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.edit_rounded,
                          color: Colors.blueAccent,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                          onTap: () => _openFormDialog(context, line: line),
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                          onTap: () => _handleDelete(line['lineid']),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Divider(color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor),
                SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      Icons.attach_money_rounded,
                      t('basePrice'),
                      '${line['baseprice'] ?? 0} ${t('currency')}',
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                    _buildInfoItem(
                      Icons.timer_rounded,
                      t('duration'),
                      '${line['estduration'] ?? 0} ${t('min')}',
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                    _buildInfoItem(
                      Icons.straighten_rounded,
                      t('distance'),
                      '${line['distance'] ?? 0} ${t('km')}',
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Column(
      children: [
        Icon(
          icon, 
          size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0), 
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary
        ),
        SizedBox(height: isSmallScreen ? 2.0 : 4.0),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            fontSize: isSmallScreen ? 10.0 : 11.0,
          ),
        ),
      ],
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
              Icons.directions_bus_filled_rounded,
              size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
              color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            t('noLines'),
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
