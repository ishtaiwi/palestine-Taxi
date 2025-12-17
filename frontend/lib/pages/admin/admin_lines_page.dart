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

  void _openFormDialog({Map<String, dynamic>? line}) {
    
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        title: Center(
          child: Text(
            line == null ? t('createLine') : t('edit'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 22,
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
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _nameEnController,
                    label: t('lineNameEn'),
                    icon: Icons.language_rounded,
                  ),
                  const SizedBox(height: 16),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _additionalPriceController,
                          label: t('additionalPrice'),
                          icon: Icons.add_circle_outline_rounded,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _durationController,
                          label: t('duration'),
                          icon: Icons.timer_rounded,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _distanceController,
                          label: t('distance'),
                          icon: Icons.straighten_rounded,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: Text(
              t('save'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openFormDialog(),
          backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(t('createLine'), style: const TextStyle(color: Colors.white)),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(),
                  Expanded(
                    child: _filteredLines.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), 
                            itemCount: _filteredLines.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              return _buildLineCard(_filteredLines[index]);
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
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541) // Dark card color for better integration
          : AppTheme.appBarColor,
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
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 4),
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
        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
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
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _buildLineCard(Map<String, dynamic> line) {
    
    final lineName = _isArabic
        ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? '')
        : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? '');

    final isActive = line['active'] == true;

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
        border: Border.all(
          color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openFormDialog(line: line),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.isDarkMode ? Colors.blueAccent.withOpacity(0.1) : AppTheme.appBarColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.timeline_rounded,
                        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineName,
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isActive ? Colors.green : Colors.red).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isActive ? t('active') : t('inactive'),
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontSize: 12,
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
                          onTap: () => _openFormDialog(line: line),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          onTap: () => _handleDelete(line['lineid']),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      Icons.attach_money_rounded,
                      t('basePrice'),
                      '${line['baseprice'] ?? 0} ${t('currency')}',
                    ),
                    _buildInfoItem(
                      Icons.timer_rounded,
                      t('duration'),
                      '${line['estduration'] ?? 0} ${t('min')}',
                    ),
                    _buildInfoItem(
                      Icons.straighten_rounded,
                      t('distance'),
                      '${line['distance'] ?? 0} ${t('km')}',
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

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon, 
          size: 20, 
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
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
              Icons.directions_bus_filled_rounded,
              size: 80,
              color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('noLines'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
