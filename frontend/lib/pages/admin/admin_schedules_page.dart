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
  bool _autoDepartureEnabled = false;
  bool _scheduledDepartureEnforced = false;
  String? _editingTemplateId;
  String _selectedDirection = 'going'; // 'going' or 'return'

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
      'autoDepartureEnabled': 'تفعيل المغادرة التلقائية',
      'scheduledDepartureEnforced': 'فرض وقت المغادرة المجدول',
      'autoDepartureDescription':
          'تفعيل المغادرة التلقائية للرحلات المبنية من هذا الجدول',
      'scheduledDepartureDescription':
          'فرض وقت المغادرة المجدول للرحلات المبنية من هذا الجدول',
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
      'invalidIntervalValue': 'يجب أن تكون الفترة إما 30 أو 60 دقيقة',
      'endBeforeStart': 'ساعة النهاية يجب أن تكون بعد ساعة البداية',
      'trips': 'الرحلات',
      'search': 'بحث عن جدول...',
      'duplicateSchedule': 'جدول موجود بالفعل لهذا الخط',
      'allLinesHaveSchedules': 'جميع الخطوط لديها جداول بالفعل',
      'hasTrips': 'لا يمكن حذف الجدول. يوجد رحلات مرتبطة بهذا الجدول',
      'direction': 'الاتجاه',
      'going': 'ذهاب',
      'return': 'عودة',
      'selectDirection': 'اختر الاتجاه',
      'goingSchedule': 'جدول الذهاب',
      'returningSchedule': 'جدول العودة',
      'lineHasGoingSchedule': 'هذا الخط لديه جدول ذهاب بالفعل',
      'lineHasReturningSchedule': 'هذا الخط لديه جدول عودة بالفعل',
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
      'autoDepartureEnabled': 'Auto Departure Enabled',
      'scheduledDepartureEnforced': 'Scheduled Departure Enforced',
      'autoDepartureDescription':
          'Enable automatic departure for trips created from this schedule',
      'scheduledDepartureDescription':
          'Enforce scheduled departure time for trips created from this schedule',
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
      'invalidIntervalValue': 'Interval must be either 30 or 60 minutes',
      'endBeforeStart': 'End time must be after start time',
      'trips': 'Trips',
      'search': 'Search schedules...',
      'duplicateSchedule': 'A schedule already exists for this line',
      'allLinesHaveSchedules': 'All lines already have schedules',
      'hasTrips':
          'Cannot delete schedule. There are trips associated with this schedule',
      'direction': 'Direction',
      'going': 'Going',
      'return': 'Return',
      'selectDirection': 'Select Direction',
      'goingSchedule': 'Going Schedule',
      'returningSchedule': 'Returning Schedule',
      'lineHasGoingSchedule': 'This line already has a going schedule',
      'lineHasReturningSchedule': 'This line already has a returning schedule',
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

  List<Map<String, dynamic>> _getAvailableLines() {
    // Always return all lines - we'll disable the ones with schedules in the UI
    return _lines;
  }

  // Get direction label with station names from line name
  // Line name format: "station1-station2" (e.g., "nablus-beit iba")
  String _getDirectionLabel(String direction, Map<String, dynamic>? line) {
    if (line == null) {
      // Fallback to default labels if line not available
      return direction == 'going' ? t('going') : t('return');
    }

    // Get line name (prefer name_ar for Arabic, name_en for English, fallback to linename)
    String? lineName;
    if (_isArabic) {
      lineName = line['name_ar']?.toString() ??
          line['linename']?.toString() ??
          line['name_en']?.toString();
    } else {
      lineName = line['name_en']?.toString() ??
          line['linename']?.toString() ??
          line['name_ar']?.toString();
    }

    if (lineName == null || lineName.isEmpty) {
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

  bool _lineHasSchedule(String? lineId, {String? direction}) {
    if (lineId == null) return false;

    // Use the explicitly passed direction, or fall back to selected direction
    final checkDirection =
        (direction ?? _selectedDirection).toLowerCase().trim();

    for (final s in _schedules) {
      final scheduleLineId = s['lineid']?.toString() ??
          ((s['line'] is Map<String, dynamic>)
              ? (s['line'] as Map<String, dynamic>)['lineid']?.toString()
              : null);
      final scheduleDirection =
          (s['direction']?.toString() ?? 'going').toLowerCase().trim();
      final isActive = s['active'] ?? true;

      // Skip if editing this schedule
      if (_editingTemplateId != null &&
          s['templateid']?.toString() == _editingTemplateId) {
        continue;
      }

      // Skip inactive schedules
      if (!isActive) {
        continue;
      }

      // Check if this schedule matches the line and direction
      if (scheduleLineId == lineId && scheduleDirection == checkDirection) {
        return true;
      }
    }

    return false;
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

    // Check if line already has a schedule for the selected direction (only when creating new schedule)
    if (_editingTemplateId == null &&
        _lineHasSchedule(_selectedLineId, direction: _selectedDirection)) {
      final errorMsg = _selectedDirection == 'going'
          ? t('lineHasGoingSchedule')
          : t('lineHasReturningSchedule');
      _showSnackBar(errorMsg, isError: true);
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
          autoDepartureEnabled: _autoDepartureEnabled,
          scheduledDepartureEnforced: _scheduledDepartureEnforced,
        );
      } else {
        result = await ApiService.createSchedule(
          lineid: _selectedLineId!,
          startHour: _startHour,
          endHour: _endHour,
          intervalMinutes: _intervalMinutes,
          active: _active,
          autoDepartureEnabled: _autoDepartureEnabled,
          scheduledDepartureEnforced: _scheduledDepartureEnforced,
          direction: _selectedDirection,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.isDarkMode
            ? const Color(0xFF1C2541)
            : AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 14.0 : 16.0)),
        titlePadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(
            isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          t('confirmDelete'),
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: Text(
          t('deleteWarning'),
          style: TextStyle(
            color:
                AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            fontSize: isSmallScreen ? 13.0 : 14.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t('no'),
              style: TextStyle(
                color: AppTheme.isDarkMode
                    ? Colors.white70
                    : AppTheme.textSecondary,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(isSmallScreen ? 6.0 : 8.0)),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20.0 : 24.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
            ),
            child: Text(
              t('yes'),
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
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

  void _openScheduleForm(BuildContext context,
      {Map<String, dynamic>? schedule}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    if (schedule != null) {
      final interval = schedule['interval_minutes'] ?? 60;
      // Ensure interval is either 30 or 60, default to 60 if invalid
      final validInterval = (interval == 30 || interval == 60) ? interval : 60;

      setState(() {
        _editingTemplateId = schedule['templateid'] as String;
        _selectedLineId = schedule['lineid'];
        _startHour = schedule['start_hour'] ?? 7;
        _endHour = schedule['end_hour'] ?? 19;
        _intervalMinutes = validInterval;
        _active = schedule['active'] ?? true;
        _autoDepartureEnabled = schedule['auto_departure_enabled'] ?? false;
        _scheduledDepartureEnforced =
            schedule['scheduled_departure_enforced'] ?? false;
        _selectedDirection = schedule['direction']?.toString() ?? 'going';
      });
    } else {
      setState(() {
        _editingTemplateId = null;
        _selectedLineId = null;
        _startHour = 7;
        _endHour = 19;
        _intervalMinutes = 60;
        _active = true;
        _autoDepartureEnabled = false;
        _scheduledDepartureEnforced = false;
        _selectedDirection = 'going';
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(isSmallScreen ? 20.0 : 24.0)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
            right: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
            top: isSmallScreen ? 20.0 : 24.0,
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
                      _editingTemplateId != null
                          ? t('updateSchedule')
                          : t('createSchedule'),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: isSmallScreen
                            ? 18.0
                            : (isMediumScreen ? 19.0 : 20.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: isSmallScreen ? 20.0 : 24.0,
                      ),
                    ),
                  ],
                ),
                Divider(height: isSmallScreen ? 0.5 : 1.0),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_editingTemplateId == null)
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          margin: EdgeInsets.only(
                              bottom: isSmallScreen ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                                isSmallScreen ? 10.0 : 12.0),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: isSmallScreen ? 18.0 : 20.0,
                              ),
                              SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                              Expanded(
                                child: Text(
                                  _isArabic
                                      ? 'الخطوط التي لديها جدول للاتجاه المحدد معطلة ولا يمكن اختيارها'
                                      : 'Lines with existing schedules for the selected direction are disabled',
                                  style: TextStyle(
                                    color: AppTheme.isDarkMode
                                        ? Colors.blueAccent
                                        : Colors.blue.shade800,
                                    fontSize: isSmallScreen ? 12.0 : 13.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Direction selector (only for creating new schedules, disabled when editing)
                      if (_editingTemplateId == null)
                        _buildDropdown(
                          label: t('direction'),
                          value: _selectedDirection,
                          items: [
                            DropdownMenuItem<String>(
                              value: 'going',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: isSmallScreen ? 16.0 : 18.0,
                                    color: AppTheme.isDarkMode
                                        ? Colors.blueAccent
                                        : AppTheme.appBarColor,
                                  ),
                                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                  Text(
                                    t('going'),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: isSmallScreen ? 14.0 : 15.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DropdownMenuItem<String>(
                              value: 'return',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back_ios,
                                    size: isSmallScreen ? 16.0 : 18.0,
                                    color: AppTheme.isDarkMode
                                        ? Colors.orangeAccent
                                        : Colors.orange.shade700,
                                  ),
                                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                  Text(
                                    t('return'),
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: isSmallScreen ? 14.0 : 15.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null && val != _selectedDirection) {
                              setModalState(() {
                                _selectedDirection = val;
                                // Reset line selection when direction changes to re-check availability
                                _selectedLineId = null;
                              });
                            }
                          },
                          icon: Icons.compare_arrows_rounded,
                          isSmallScreen: isSmallScreen,
                          isMediumScreen: isMediumScreen,
                        ),
                      if (_editingTemplateId == null)
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      // Show direction as read-only when editing
                      if (_editingTemplateId != null)
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                          decoration: BoxDecoration(
                            color: AppTheme.isDarkMode
                                ? Colors.white.withOpacity(0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(
                                isSmallScreen ? 10.0 : 12.0),
                            border: Border.all(
                              color: AppTheme.isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedDirection == 'going'
                                    ? Icons.arrow_forward_ios
                                    : Icons.arrow_back_ios,
                                size: isSmallScreen ? 16.0 : 18.0,
                                color: AppTheme.isDarkMode
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                              ),
                              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                              Text(
                                '${t('direction')}: ${_selectedDirection == 'going' ? t('going') : t('return')}',
                                style: TextStyle(
                                  color: AppTheme.isDarkMode
                                      ? Colors.white70
                                      : AppTheme.textSecondary,
                                  fontSize: isSmallScreen ? 13.0 : 14.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_editingTemplateId != null)
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      // Line dropdown rebuilds when direction changes via setModalState
                      Builder(
                        builder: (context) {
                          // Recalculate items based on current direction
                          final availableLines = _getAvailableLines();
                          final currentDirection = _selectedDirection;
                          final lineItems = availableLines.map((line) {
                            final lineId = line['lineid']?.toString();
                            final name = _isArabic
                                ? (line['name_ar'] ??
                                    line['linename'] ??
                                    line['name_en'] ??
                                    'Unknown')
                                : (line['name_en'] ??
                                    line['linename'] ??
                                    line['name_ar'] ??
                                    'Unknown');
                            final isDisabled = _editingTemplateId == null &&
                                _lineHasSchedule(lineId,
                                    direction: currentDirection);
                            return DropdownMenuItem<String>(
                              value: lineId,
                              enabled: !isDisabled,
                              child: Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 3.0 : 4.0),
                                padding:
                                    EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                                decoration: BoxDecoration(
                                  color: isDisabled
                                      ? (AppTheme.isDarkMode
                                          ? Colors.white.withOpacity(0.02)
                                          : Colors.grey.shade100)
                                      : (AppTheme.isDarkMode
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.shade50),
                                  borderRadius: BorderRadius.circular(
                                      isSmallScreen ? 10.0 : 12.0),
                                  border: Border.all(
                                    color: isDisabled
                                        ? (AppTheme.isDarkMode
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.grey.shade300)
                                        : (AppTheme.isDarkMode
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.grey.shade200),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          isSmallScreen ? 6.0 : 8.0),
                                      decoration: BoxDecoration(
                                        color: isDisabled
                                            ? (AppTheme.isDarkMode
                                                ? Colors.grey.withOpacity(0.1)
                                                : Colors.grey.shade200)
                                            : (AppTheme.isDarkMode
                                                ? Colors.blueAccent
                                                    .withOpacity(0.2)
                                                : AppTheme.appBarColor
                                                    .withOpacity(0.1)),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.directions_bus_rounded,
                                        size: isSmallScreen ? 16.0 : 18.0,
                                        color: isDisabled
                                            ? (AppTheme.isDarkMode
                                                ? Colors.grey
                                                : Colors.grey.shade600)
                                            : (AppTheme.isDarkMode
                                                ? Colors.blueAccent
                                                : AppTheme.appBarColor),
                                      ),
                                    ),
                                    SizedBox(
                                        width: isSmallScreen ? 10.0 : 12.0),
                                    Expanded(
                                      child: Text(
                                        name.toString(),
                                        style: TextStyle(
                                          color: isDisabled
                                              ? (AppTheme.isDarkMode
                                                  ? Colors.white38
                                                  : Colors.grey.shade500)
                                              : AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: isSmallScreen ? 13.0 : 14.0,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isDisabled)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            left: isSmallScreen ? 6.0 : 8.0),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: isSmallScreen ? 14.0 : 16.0,
                                          color: AppTheme.isDarkMode
                                              ? Colors.orangeAccent
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList();

                          return _buildDropdown(
                            label: t('line'),
                            value: _selectedLineId,
                            items: lineItems,
                            selectedItemBuilder: (context) {
                              return availableLines.map((line) {
                                final lineId = line['lineid']?.toString();
                                final name = _isArabic
                                    ? (line['name_ar'] ??
                                        line['linename'] ??
                                        line['name_en'] ??
                                        'Unknown')
                                    : (line['name_en'] ??
                                        line['linename'] ??
                                        line['name_ar'] ??
                                        'Unknown');
                                final isDisabled = _editingTemplateId == null &&
                                    _lineHasSchedule(lineId,
                                        direction: currentDirection);
                                return Text(
                                  name.toString(),
                                  style: TextStyle(
                                    color: isDisabled
                                        ? (AppTheme.isDarkMode
                                            ? Colors.white38
                                            : Colors.grey.shade500)
                                        : AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: isSmallScreen ? 14.0 : 15.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              }).toList();
                            },
                            onChanged: (val) {
                              if (val != null &&
                                  _editingTemplateId == null &&
                                  _lineHasSchedule(val,
                                      direction: currentDirection)) {
                                final errorMsg = currentDirection == 'going'
                                    ? t('lineHasGoingSchedule')
                                    : t('lineHasReturningSchedule');
                                _showSnackBar(errorMsg, isError: true);
                                return;
                              }
                              setModalState(() => _selectedLineId = val);
                            },
                            isSmallScreen: isSmallScreen,
                            isMediumScreen: isMediumScreen,
                          );
                        },
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNumberInput(
                              label: t('startHour'),
                              value: _startHour,
                              onChanged: (val) => _startHour = val,
                              max: 23,
                              isSmallScreen: isSmallScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                          Expanded(
                            child: _buildNumberInput(
                              label: t('endHour'),
                              value: _endHour,
                              onChanged: (val) => _endHour = val,
                              validator: (val) {
                                if (val != null && val < _startHour)
                                  return t('endBeforeStart');
                                return null;
                              },
                              max: 23,
                              isSmallScreen: isSmallScreen,
                              isMediumScreen: isMediumScreen,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      _buildIntervalDropdown(
                        label: t('interval'),
                        value: _intervalMinutes,
                        onChanged: (val) =>
                            setModalState(() => _intervalMinutes = val!),
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen,
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t('active'),
                          style: TextStyle(
                            color: AppTheme.isDarkMode
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: isSmallScreen ? 14.0 : 15.0,
                          ),
                        ),
                        value: _active,
                        activeColor: Colors.blue.shade600,
                        onChanged: (val) => setModalState(() => _active = val),
                      ),
                      SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t('autoDepartureEnabled'),
                          style: TextStyle(
                            color: AppTheme.isDarkMode
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: isSmallScreen ? 14.0 : 15.0,
                          ),
                        ),
                        subtitle: Text(
                          t('autoDepartureDescription'),
                          style: TextStyle(
                              color: AppTheme.isDarkMode
                                  ? Colors.white70
                                  : AppTheme.textSecondary,
                              fontSize: isSmallScreen ? 11.0 : 12.0),
                        ),
                        value: _autoDepartureEnabled,
                        activeColor: Colors.blue.shade600,
                        onChanged: (val) =>
                            setModalState(() => _autoDepartureEnabled = val),
                      ),
                      SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          t('scheduledDepartureEnforced'),
                          style: TextStyle(
                            color: AppTheme.isDarkMode
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: isSmallScreen ? 14.0 : 15.0,
                          ),
                        ),
                        subtitle: Text(
                          t('scheduledDepartureDescription'),
                          style: TextStyle(
                              color: AppTheme.isDarkMode
                                  ? Colors.white70
                                  : AppTheme.textSecondary,
                              fontSize: isSmallScreen ? 11.0 : 12.0),
                        ),
                        value: _scheduledDepartureEnforced,
                        activeColor: Colors.blue.shade600,
                        onChanged: (val) => setModalState(
                            () => _scheduledDepartureEnforced = val),
                      ),
                      SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                      SizedBox(
                        width: double.infinity,
                        height: isSmallScreen
                            ? 44.0
                            : (isMediumScreen ? 47.0 : 50.0),
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.appBarColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 10.0 : 12.0)),
                            elevation: 2,
                          ),
                          child: Text(
                            t('save'),
                            style: TextStyle(
                                fontSize: isSmallScreen ? 14.0 : 16.0,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20.0 : 24.0),
                    ],
                  ),
                ),
              ],
            ),
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
        fontSize: isSmallScreen ? 14.0 : 16.0,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          fontSize: isSmallScreen ? 13.0 : 14.0,
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
          borderSide: BorderSide(
              color:
                  AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor),
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : AppTheme.backgroundColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16.0 : 20.0,
          vertical: isSmallScreen ? 12.0 : 16.0,
        ),
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items,
      selectedItemBuilder: selectedItemBuilder,
      onChanged: onChanged,
      isExpanded: true,
      itemHeight: null, // Allow variable height for card items
      dropdownColor:
          AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: isSmallScreen ? 14.0 : 15.0,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
        size: isSmallScreen ? 20.0 : 24.0,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: isSmallScreen ? 13.0 : 14.0,
        ),
        prefixIcon: Icon(
          icon,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide(
            color:
                AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0,
            vertical: isSmallScreen ? 12.0 : 16.0),
      ),
      validator: (val) => val == null ? t('required') : null,
    );
  }

  Widget _buildIntervalDropdown({
    required String label,
    required int value,
    required Function(int?) onChanged,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    // Ensure value is either 30 or 60, default to 60 if invalid
    final validValue = (value == 30 || value == 60) ? value : 60;

    return DropdownButtonFormField<int>(
      value: validValue,
      items: [
        DropdownMenuItem<int>(
          value: 30,
          child: Row(
            children: [
              Icon(
                Icons.timer_rounded,
                size: isSmallScreen ? 18.0 : 20.0,
                color: AppTheme.isDarkMode
                    ? Colors.blueAccent
                    : AppTheme.appBarColor,
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                '30 ${t('minutes')}',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isSmallScreen ? 14.0 : 15.0,
                ),
              ),
            ],
          ),
        ),
        DropdownMenuItem<int>(
          value: 60,
          child: Row(
            children: [
              Icon(
                Icons.timer_rounded,
                size: isSmallScreen ? 18.0 : 20.0,
                color: AppTheme.isDarkMode
                    ? Colors.blueAccent
                    : AppTheme.appBarColor,
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                '60 ${t('minutes')}',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isSmallScreen ? 14.0 : 15.0,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor:
          AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
      borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: isSmallScreen ? 14.0 : 15.0,
      ),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
        size: isSmallScreen ? 20.0 : 24.0,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: isSmallScreen ? 13.0 : 14.0,
        ),
        prefixIcon: Icon(
          Icons.timer_rounded,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          borderSide: BorderSide(
            color:
                AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16.0 : 20.0,
            vertical: isSmallScreen ? 12.0 : 16.0),
      ),
      validator: (val) => val == null ? t('required') : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;

    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding =
        isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(context),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openScheduleForm(context),
          backgroundColor:
              AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
          foregroundColor: Colors.white,
          icon: Icon(
            Icons.add,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
          label: Text(
            t('createSchedule'),
            style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
          ),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppTheme.appBarColor))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.appBarColor,
                child: Column(
                  children: [
                    _buildSearchBar(
                        isSmallScreen: isSmallScreen,
                        isMediumScreen: isMediumScreen),
                    Expanded(
                      child: _filteredSchedules.isEmpty
                          ? _buildEmptyState(
                              isSmallScreen: isSmallScreen,
                              isMediumScreen: isMediumScreen)
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                  basePadding,
                                  basePadding,
                                  basePadding,
                                  isSmallScreen ? 70.0 : 80.0),
                              itemCount: _filteredSchedules.length,
                              itemBuilder: (context, index) =>
                                  _buildScheduleCard(
                                _filteredSchedules[index],
                                isSmallScreen: isSmallScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            ),
                    ),
                  ],
                ),
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
        PopupMenuButton(
          icon: Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
            size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 24.0),
          ),
          color: AppTheme.cardBackground,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'createAll',
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      color: AppTheme.textPrimary,
                      size: isSmallScreen ? 18.0 : 20.0),
                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                  Text(
                    t('createAllTrips'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: isSmallScreen ? 13.0 : 14.0,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'createAll') _handleCreateAllTrips();
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

  Widget _buildSearchBar(
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
          isSmallScreen ? 16.0 : 20.0,
          isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
          0),
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
            color:
                AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color:
                AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            size: isSmallScreen ? 20.0 : 24.0,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16.0 : 20.0,
              vertical: isSmallScreen ? 12.0 : 15.0),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.isDarkMode
                        ? Colors.white70
                        : AppTheme.textSecondary,
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

  Widget _buildEmptyState(
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule_outlined,
                size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
                color: AppTheme.isDarkMode
                    ? Colors.white24
                    : AppTheme.textSecondary.withOpacity(0.5)),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            Text(
              t('noSchedules'),
              style: TextStyle(
                fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                fontWeight: FontWeight.bold,
                color:
                    AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6.0 : 8.0),
            Text(
              t('noSchedulesSub'),
              style: TextStyle(
                color: AppTheme.isDarkMode
                    ? Colors.white70
                    : AppTheme.textSecondary,
                fontSize: isSmallScreen ? 13.0 : 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule,
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final line = schedule['line'] as Map<String, dynamic>?;
    final startHour = schedule['start_hour'] ?? 0;
    final endHour = schedule['end_hour'] ?? 23;
    final interval = schedule['interval_minutes'] ?? 60;
    final active = schedule['active'] ?? true;
    final templateid = schedule['templateid'] as String;
    final direction = schedule['direction']?.toString() ?? 'going';
    final isDark = AppTheme.isDarkMode;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12.0 : 16.0),
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
          color: active
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.all(
                isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                      decoration: BoxDecoration(
                        color: active
                            ? (isDark
                                ? Colors.greenAccent.withOpacity(0.1)
                                : Colors.green.shade50)
                            : (isDark
                                ? Colors.redAccent.withOpacity(0.1)
                                : Colors.red.shade50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: active
                            ? (isDark
                                ? Colors.greenAccent
                                : Colors.green.shade700)
                            : (isDark ? Colors.redAccent : Colors.red.shade700),
                        size: isSmallScreen
                            ? 20.0
                            : (isMediumScreen ? 22.0 : 24.0),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getDirectionLabel(direction, line),
                            style: TextStyle(
                              color:
                                  isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: isSmallScreen
                                  ? 16.0
                                  : (isMediumScreen ? 17.0 : 18.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6.0 : 8.0,
                                vertical: isSmallScreen ? 1.0 : 2.0),
                            decoration: BoxDecoration(
                              color: active
                                  ? (isDark
                                      ? Colors.greenAccent.withOpacity(0.1)
                                      : Colors.green.shade100)
                                  : (isDark
                                      ? Colors.redAccent.withOpacity(0.1)
                                      : Colors.red.shade100),
                              borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 6.0 : 8.0),
                            ),
                            child: Text(
                              active ? t('active') : t('inactive'),
                              style: TextStyle(
                                color: active
                                    ? (isDark
                                        ? Colors.greenAccent
                                        : Colors.green.shade800)
                                    : (isDark
                                        ? Colors.redAccent
                                        : Colors.red.shade800),
                                fontSize: isSmallScreen ? 10.0 : 11.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Divider(
                    color: isDark
                        ? Colors.white12
                        : AppTheme.borderColor.withOpacity(0.5)),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Row(
                  children: [
                    _buildInfoItem(
                      Icons.start_rounded,
                      t('startHour'),
                      '$startHour:00',
                      isDark,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                    _buildInfoItem(
                      Icons.last_page_rounded,
                      t('endHour'),
                      '$endHour:00',
                      isDark,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                    _buildInfoItem(
                      Icons.timer_rounded,
                      t('interval'),
                      '$interval ${t('minutes')}',
                      isDark,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Divider(
                    color: isDark
                        ? Colors.white12
                        : AppTheme.borderColor.withOpacity(0.5)),
                SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _handleCreateTrips(templateid),
                        icon: Icon(
                          Icons.add_task_rounded,
                          color:
                              isDark ? Colors.blueAccent : AppTheme.appBarColor,
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        label: Text(
                          t('createTrips'),
                          style: TextStyle(
                            color: isDark
                                ? Colors.blueAccent
                                : AppTheme.appBarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 12.0 : 13.0,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 10.0 : 12.0),
                          backgroundColor: isDark
                              ? Colors.blueAccent.withOpacity(0.1)
                              : AppTheme.appBarColor.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  isSmallScreen ? 6.0 : 8.0)),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: Colors.blueAccent,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      onTap: () =>
                          _openScheduleForm(context, schedule: schedule),
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
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

  Widget _buildInfoItem(IconData icon, String label, String value, bool isDark,
      {bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
              color: isDark ? Colors.blueAccent : AppTheme.textSecondary),
          SizedBox(height: isSmallScreen ? 4.0 : 6.0),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
            ),
          ),
          SizedBox(height: isSmallScreen ? 1.0 : 2.0),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              fontSize: isSmallScreen ? 10.0 : 11.0,
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
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    return Material(
      color:
          AppTheme.isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
          child: Icon(
            icon,
            size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
            color: color,
          ),
        ),
      ),
    );
  }
}
