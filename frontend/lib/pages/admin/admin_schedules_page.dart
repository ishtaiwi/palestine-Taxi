import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminSchedulesPage extends StatefulWidget {
  const AdminSchedulesPage({super.key});

  @override
  State<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends State<AdminSchedulesPage> {
  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _filteredSchedules = [];
  List<Map<String, dynamic>> _lines = [];
  bool _isLoading = true;
  bool _isArabic = true;
  
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  
  final _formKey = GlobalKey<FormState>();
  String? _selectedLineId;
  int _startHour = 7;
  int _endHour = 19;
  int _intervalMinutes = 60;
  bool _active = true;
  String? _editingTemplateId;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة الجداول اليومية',
      'schedules': 'الجداول اليومية',
      'createSchedule': 'إنشاء جدول جديد',
      'updateSchedule': 'تحديث الجدول',
      'line': 'الخط',
      'selectLine': 'اختر الخط',
      'startHour': 'ساعة البداية (0-23)',
      'endHour': 'ساعة النهاية (0-23)',
      'interval': 'الفترة (بالدقائق)',
      'active': 'نشط',
      'inactive': 'غير نشط',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'edit': 'تعديل',
      'delete': 'حذف',
      'createTrips': 'إنشاء رحلات',
      'createTripsForDate': 'إنشاء رحلات لتاريخ محدد',
      'createAllTrips': 'إنشاء رحلات لجميع الجداول',
      'noSchedules': 'لا توجد جداول متاحة',
      'noSchedulesSub': 'قم بإضافة جدول جديد للبدء',
      'loading': 'جاري التحميل...',
      'error': 'حدث خطأ',
      'success': 'تمت العملية بنجاح',
      'confirmDelete': 'هل أنت متأكد من حذف هذا الجدول؟',
      'deleteWarning': 'لا يمكن التراجع عن هذا الإجراء',
      'yes': 'نعم، حذف',
      'no': 'إلغاء',
      'from': 'من',
      'to': 'إلى',
      'every': 'كل',
      'minutes': 'دقيقة',
      'hour': 'ساعة',
      'tripsCreated': 'تم إنشاء الرحلات بنجاح',
      'scheduleCreated': 'تم إنشاء الجدول بنجاح',
      'scheduleUpdated': 'تم تحديث الجدول بنجاح',
      'scheduleDeleted': 'تم حذف الجدول بنجاح',
      'required': 'مطلوب',
      'invalidHour': 'يجب أن تكون الساعة بين 0 و 23',
      'invalidInterval': 'يجب أن تكون الفترة أكبر من 0',
      'endBeforeStart': 'ساعة النهاية يجب أن تكون بعد ساعة البداية',
      'trips': 'الرحلات',
      'search': 'بحث عن جدول...',
    },
    'en': {
      'title': 'Daily Schedules',
      'schedules': 'Daily Schedules',
      'createSchedule': 'Create New Schedule',
      'updateSchedule': 'Update Schedule',
      'line': 'Line',
      'selectLine': 'Select Line',
      'startHour': 'Start Hour (0-23)',
      'endHour': 'End Hour (0-23)',
      'interval': 'Interval (minutes)',
      'active': 'Active',
      'inactive': 'Inactive',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'delete': 'Delete',
      'createTrips': 'Create Trips',
      'createTripsForDate': 'Create Trips for Date',
      'createAllTrips': 'Generate All Trips',
      'noSchedules': 'No schedules found',
      'noSchedulesSub': 'Add a new schedule to get started',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirmDelete': 'Delete this schedule?',
      'deleteWarning': 'This action cannot be undone',
      'yes': 'Delete',
      'no': 'Cancel',
      'from': 'From',
      'to': 'To',
      'every': 'Every',
      'minutes': 'min',
      'hour': 'hr',
      'tripsCreated': 'Trips created successfully',
      'scheduleCreated': 'Schedule created successfully',
      'scheduleUpdated': 'Schedule updated successfully',
      'scheduleDeleted': 'Schedule deleted successfully',
      'required': 'Required',
      'invalidHour': 'Hour must be between 0 and 23',
      'invalidInterval': 'Interval must be > 0',
      'endBeforeStart': 'End time must be after start time',
      'trips': 'Trips',
      'search': 'Search schedules...',
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
    setState(() => _isLoading = true);
    try {
      final [schedules, lines] = await Future.wait([
        ApiService.fetchSchedules(),
        ApiService.fetchActiveLines(),
      ]);

      setState(() {
        _schedules = schedules;
        _lines = lines;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('${t('error')}: ${e.toString()}', isError: true);
      }
    }
  }

  void _applyFilter() {
    _filteredSchedules = _schedules.where((schedule) {
      final line = schedule['line'] as Map<String, dynamic>?;
      final lineNameAr = (line?['name_ar'] ?? '').toString().toLowerCase();
      final lineNameEn = (line?['name_en'] ?? '').toString().toLowerCase();
      final lineName = (line?['linename'] ?? '').toString().toLowerCase();

      return _searchQuery.isEmpty ||
          lineNameAr.contains(_searchQuery) ||
          lineNameEn.contains(_searchQuery) ||
          lineName.contains(_searchQuery);
    }).toList();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLineId == null) {
      _showSnackBar(t('selectLine'), isError: true);
      return;
    }

    Navigator.pop(context); 
    setState(() => _isLoading = true);

    try {
      final Map<String, dynamic> result;
      if (_editingTemplateId != null) {
        result = await ApiService.updateSchedule(
          _editingTemplateId!,
          startHour: _startHour,
          endHour: _endHour,
          intervalMinutes: _intervalMinutes,
          active: _active,
        );
      } else {
        result = await ApiService.createSchedule(
          lineid: _selectedLineId!,
          startHour: _startHour,
          endHour: _endHour,
          intervalMinutes: _intervalMinutes,
          active: _active,
        );
      }

      if (result['success'] == true) {
        _showSnackBar(_editingTemplateId != null 
            ? t('scheduleUpdated') 
            : t('scheduleCreated'));
        _loadData();
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteSchedule(String templateid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('confirmDelete'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
        content: Text(t('deleteWarning'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('no'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(t('yes')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.deleteSchedule(templateid);
      if (result['success'] == true) {
        _showSnackBar(t('scheduleDeleted'));
        _loadData();
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateTrips(String templateid) async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createTripsForSchedule(templateid);
      if (result['success'] == true) {
        final created = result['result']?['created'] ?? 0;
        _showSnackBar('${t('tripsCreated')}: $created');
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateAllTrips() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.triggerDailyTripCreation();
      if (result['success'] == true) {
        final totalCreated = result['result']?['totalTripsCreated'] ?? 0;
        _showSnackBar('${t('tripsCreated')}: $totalCreated');
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openScheduleForm({Map<String, dynamic>? schedule}) {
    if (schedule != null) {
      setState(() {
        _editingTemplateId = schedule['templateid'] as String;
        _selectedLineId = schedule['lineid'];
        _startHour = schedule['start_hour'] ?? 7;
        _endHour = schedule['end_hour'] ?? 19;
        _intervalMinutes = schedule['interval_minutes'] ?? 60;
        _active = schedule['active'] ?? true;
      });
    } else {
      setState(() {
        _editingTemplateId = null;
        _selectedLineId = null;
        _startHour = 7;
        _endHour = 19;
        _intervalMinutes = 60;
        _active = true;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingTemplateId != null ? t('updateSchedule') : t('createSchedule'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildDropdown(
                      label: t('line'),
                      value: _selectedLineId,
                      items: _lines.map((line) {
                        final name = _isArabic
                            ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? 'Unknown')
                            : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? 'Unknown');
                        return DropdownMenuItem<String>(
                          value: line['lineid'],
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.isDarkMode
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.isDarkMode
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.isDarkMode
                                        ? Colors.blueAccent.withOpacity(0.2)
                                        : AppTheme.appBarColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.directions_bus_rounded,
                                    size: 18,
                                    color: AppTheme.isDarkMode
                                        ? Colors.blueAccent
                                        : AppTheme.appBarColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name.toString(),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      selectedItemBuilder: (context) {
                        return _lines.map((line) {
                          final name = _isArabic
                              ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? 'Unknown')
                              : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? 'Unknown');
                          return Text(
                            name.toString(),
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        }).toList();
                      },
                      onChanged: (val) => setState(() => _selectedLineId = val),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberInput(
                            label: t('startHour'),
                            value: _startHour,
                            onChanged: (val) => _startHour = val,
                            max: 23,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNumberInput(
                            label: t('endHour'),
                            value: _endHour,
                            onChanged: (val) => _endHour = val,
                            validator: (val) {
                              if (val != null && val < _startHour) return t('endBeforeStart');
                              return null;
                            },
                            max: 23,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildNumberInput(
                      label: t('interval'),
                      value: _intervalMinutes,
                      onChanged: (val) => _intervalMinutes = val,
                      min: 1,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('active'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
                      value: _active,
                      activeColor: Colors.blue.shade600,
                      onChanged: (val) => setState(() => _active = val),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.appBarColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: Text(
                          t('save'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberInput({
    required String label,
    required int value,
    required Function(int) onChanged,
    int min = 0,
    int max = 9999,
    String? Function(int?)? validator,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor),
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : AppTheme.backgroundColor,
      ),
      onChanged: (val) => onChanged(int.tryParse(val) ?? value),
      validator: (val) {
        final num = int.tryParse(val ?? '');
        if (num == null) return t('required');
        if (num < min || num > max) return t('invalidHour');
        if (validator != null) return validator(num);
        return null;
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    IconData icon = Icons.alt_route_rounded,
    List<Widget> Function(BuildContext)? selectedItemBuilder,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      onChanged: onChanged,
      isExpanded: true,
      itemHeight: null, // Allow variable height for card items
      dropdownColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        prefixIcon: Icon(
          icon,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: (val) => val == null ? t('required') : null,
    );
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
          onPressed: () => _openScheduleForm(),
          backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: Text(t('createSchedule')),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.appBarColor))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.appBarColor,
                child: Column(
                  children: [
                    _buildSearchBar(),
                    Expanded(
                      child: _filteredSchedules.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                              itemCount: _filteredSchedules.length,
                              itemBuilder: (context, index) => _buildScheduleCard(_filteredSchedules[index]),
                            ),
                    ),
                  ],
                ),
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
        PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: AppTheme.cardBackground,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'createAll',
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: AppTheme.textPrimary, size: 20),
                  const SizedBox(width: 12),
                  Text(t('createAllTrips'), style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'createAll') _handleCreateAllTrips();
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

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined, 
              size: 80, 
              color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.textSecondary.withOpacity(0.5)
            ),
            const SizedBox(height: 16),
            Text(
              t('noSchedules'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('noSchedulesSub'),
              style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final line = schedule['line'] as Map<String, dynamic>?;
    final lineName = _isArabic
        ? (line?['name_ar'] ?? line?['linename'] ?? line?['name_en'] ?? 'Unknown')
        : (line?['name_en'] ?? line?['linename'] ?? line?['name_ar'] ?? 'Unknown');
    final startHour = schedule['start_hour'] ?? 0;
    final endHour = schedule['end_hour'] ?? 23;
    final interval = schedule['interval_minutes'] ?? 60;
    final active = schedule['active'] ?? true;
    final templateid = schedule['templateid'] as String;
    final isDark = AppTheme.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          color: active ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
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
                        color: active
                            ? (isDark ? Colors.greenAccent.withOpacity(0.1) : Colors.green.shade50)
                            : (isDark ? Colors.redAccent.withOpacity(0.1) : Colors.red.shade50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: active
                            ? (isDark ? Colors.greenAccent : Colors.green.shade700)
                            : (isDark ? Colors.redAccent : Colors.red.shade700),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineName.toString(),
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: active
                                  ? (isDark ? Colors.greenAccent.withOpacity(0.1) : Colors.green.shade100)
                                  : (isDark ? Colors.redAccent.withOpacity(0.1) : Colors.red.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              active ? t('active') : t('inactive'),
                              style: TextStyle(
                                color: active
                                    ? (isDark ? Colors.greenAccent : Colors.green.shade800)
                                    : (isDark ? Colors.redAccent : Colors.red.shade800),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.white12 : AppTheme.borderColor.withOpacity(0.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.start_rounded, 
                      t('startHour'), 
                      '$startHour:00',
                      isDark,
                    ),
                    _buildInfoItem(
                      Icons.last_page_rounded, 
                      t('endHour'), 
                      '$endHour:00',
                      isDark,
                    ),
                    _buildInfoItem(
                      Icons.timer_rounded, 
                      t('interval'), 
                      '$interval ${t('minutes')}',
                      isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: isDark ? Colors.white12 : AppTheme.borderColor.withOpacity(0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _handleCreateTrips(templateid),
                        icon: Icon(
                          Icons.add_task_rounded,
                          color: isDark ? Colors.blueAccent : AppTheme.appBarColor,
                          size: 20,
                        ),
                        label: Text(
                          t('createTrips'),
                          style: TextStyle(
                            color: isDark ? Colors.blueAccent : AppTheme.appBarColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: isDark 
                              ? Colors.blueAccent.withOpacity(0.1) 
                              : AppTheme.appBarColor.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: Colors.blueAccent,
                      onTap: () => _openScheduleForm(schedule: schedule),
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: () => _handleDeleteSchedule(templateid),
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

  Widget _buildInfoItem(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.blueAccent : AppTheme.textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary, 
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}
