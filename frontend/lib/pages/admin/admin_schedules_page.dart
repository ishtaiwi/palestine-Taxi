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
  List<Map<String, dynamic>> _lines = [];
  bool _isLoading = true;
  bool _isArabic = true;
  bool _showCreateForm = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? _selectedLineId;
  int _startHour = 7;
  int _endHour = 19;
  int _intervalMinutes = 60;
  bool _active = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة الجداول اليومية',
      'schedules': 'الجداول اليومية',
      'createSchedule': 'إنشاء جدول جديد',
      'line': 'الخط',
      'selectLine': 'اختر الخط',
      'startHour': 'ساعة البداية',
      'endHour': 'ساعة النهاية',
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
      'noSchedules': 'لا توجد جداول',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'confirmDelete': 'هل أنت متأكد من حذف هذا الجدول؟',
      'yes': 'نعم',
      'no': 'لا',
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
      'invalidHour': 'الساعة يجب أن تكون بين 0 و 23',
      'invalidInterval': 'الفترة يجب أن تكون أكبر من 0',
      'endBeforeStart': 'ساعة النهاية يجب أن تكون بعد ساعة البداية',
    },
    'en': {
      'title': 'Daily Schedules Management',
      'schedules': 'Daily Schedules',
      'createSchedule': 'Create New Schedule',
      'line': 'Line',
      'selectLine': 'Select Line',
      'startHour': 'Start Hour',
      'endHour': 'End Hour',
      'interval': 'Interval (minutes)',
      'active': 'Active',
      'inactive': 'Inactive',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'delete': 'Delete',
      'createTrips': 'Create Trips',
      'createTripsForDate': 'Create Trips for Date',
      'createAllTrips': 'Create Trips for All Schedules',
      'noSchedules': 'No schedules found',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirmDelete': 'Are you sure you want to delete this schedule?',
      'yes': 'Yes',
      'no': 'No',
      'from': 'From',
      'to': 'To',
      'every': 'Every',
      'minutes': 'minutes',
      'hour': 'hour',
      'tripsCreated': 'Trips created successfully',
      'scheduleCreated': 'Schedule created successfully',
      'scheduleUpdated': 'Schedule updated successfully',
      'scheduleDeleted': 'Schedule deleted successfully',
      'required': 'Required',
      'invalidHour': 'Hour must be between 0 and 23',
      'invalidInterval': 'Interval must be greater than 0',
      'endBeforeStart': 'End hour must be after start hour',
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
      final [schedules, lines] = await Future.wait([
        ApiService.fetchSchedules(),
        ApiService.fetchActiveLines(),
      ]);

      setState(() {
        _schedules = schedules;
        _lines = lines;
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

  Future<void> _handleCreateSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('selectLine')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await ApiService.createSchedule(
      lineid: _selectedLineId!,
      startHour: _startHour,
      endHour: _endHour,
      intervalMinutes: _intervalMinutes,
      active: _active,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('scheduleCreated')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showCreateForm = false;
          _editingTemplateId = null;
          _selectedLineId = null;
          _startHour = 7;
          _endHour = 19;
          _intervalMinutes = 60;
          _active = true;
        });
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleUpdateSchedule(String templateid) async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ApiService.updateSchedule(
      templateid,
      startHour: _startHour,
      endHour: _endHour,
      intervalMinutes: _intervalMinutes,
      active: _active,
    );

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('scheduleUpdated')),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _showCreateForm = false;
          _editingTemplateId = null;
        });
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteSchedule(String templateid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.appBarColor,
        title: Text(
          t('confirmDelete'),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                Text(t('no'), style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('yes'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ApiService.deleteSchedule(templateid);

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('scheduleDeleted')),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateTrips(String templateid) async {
    final result = await ApiService.createTripsForSchedule(templateid);

    if (mounted) {
      if (result['success'] == true) {
        final created = result['result']?['created'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('tripsCreated')}: $created'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleCreateAllTrips() async {
    final result = await ApiService.triggerDailyTripCreation();

    if (mounted) {
      if (result['success'] == true) {
        final totalCreated = result['result']?['totalTripsCreated'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('tripsCreated')}: $totalCreated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('error')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String? _editingTemplateId;

  void _openEditForm(Map<String, dynamic> schedule) {
    setState(() {
      _showCreateForm = true;
      _editingTemplateId = schedule['templateid'] as String;
      _selectedLineId = schedule['lineid'];
      _startHour = schedule['start_hour'] ?? 7;
      _endHour = schedule['end_hour'] ?? 19;
      _intervalMinutes = schedule['interval_minutes'] ?? 60;
      _active = schedule['active'] ?? true;
    });
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
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.appBarColor,
          elevation: 2,
          iconTheme: IconThemeData(
            color: AppTheme.textPrimary,
          ),
          actionsIconTheme: IconThemeData(
            color: AppTheme.textPrimary,
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppTheme.textPrimary,
            ),
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
            if (_schedules.isNotEmpty)
              PopupMenuButton(
                icon: Icon(
                  Icons.more_vert,
                  color: AppTheme.textPrimary,
                ),
                color: AppTheme.appBarColor,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Text(
                      t('createAllTrips'),
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    onTap: () => _handleCreateAllTrips(),
                  ),
                ],
              ),
            IconButton(
              icon: Icon(
                _showCreateForm ? Icons.close : Icons.add,
                color: AppTheme.textPrimary,
              ),
              onPressed: () {
                setState(() {
                  _showCreateForm = !_showCreateForm;
                  _editingTemplateId = null;
                  if (!_showCreateForm) {
                    _selectedLineId = null;
                    _startHour = 7;
                    _endHour = 19;
                    _intervalMinutes = 60;
                    _active = true;
                  }
                });
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_showCreateForm) _buildCreateForm(),
                  Expanded(
                    child: _schedules.isEmpty
                        ? Center(
                            child: Text(
                              t('noSchedules'),
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _schedules.length,
                            itemBuilder: (context, index) {
                              final schedule = _schedules[index];
                              return _buildScheduleCard(schedule);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(0.05),
        border: Border(
          bottom: BorderSide(color: AppTheme.getCardBorder(0.24)),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedLineId,
              decoration: InputDecoration(
                labelText: t('line'),
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.getCardBorder(0.54)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.textPrimary),
                ),
                filled: true,
                fillColor: AppTheme.getCardBackground(0.1),
              ),
              dropdownColor: AppTheme.getCardBackground(0.1),
              style: TextStyle(color: AppTheme.textPrimary),
              iconEnabledColor: AppTheme.textPrimary,
              items: _lines.map((line) {
                return DropdownMenuItem<String>(
                  value: line['lineid'],
                  child: Text(
                    _isArabic
                        ? (line['name_ar']?.toString() ??
                            line['linename']?.toString() ??
                            line['name_en']?.toString() ??
                            'Unknown')
                        : (line['name_en']?.toString() ??
                            line['linename']?.toString() ??
                            line['name_ar']?.toString() ??
                            'Unknown'),
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLineId = value;
                });
              },
              validator: (value) {
                if (value == null) return t('required');
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _startHour.toString(),
                    decoration: InputDecoration(
                      labelText: t('startHour'),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppTheme.getCardBorder(0.54)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.textPrimary),
                      ),
                      filled: true,
                      fillColor: AppTheme.getCardBackground(0.1),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _startHour = int.tryParse(value) ?? 7;
                    },
                    validator: (value) {
                      final hour = int.tryParse(value ?? '');
                      if (hour == null || hour < 0 || hour > 23) {
                        return t('invalidHour');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _endHour.toString(),
                    decoration: InputDecoration(
                      labelText: t('endHour'),
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: AppTheme.getCardBorder(0.54)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.textPrimary),
                      ),
                      filled: true,
                      fillColor: AppTheme.getCardBackground(0.1),
                    ),
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _endHour = int.tryParse(value) ?? 19;
                    },
                    validator: (value) {
                      final hour = int.tryParse(value ?? '');
                      if (hour == null || hour < 0 || hour > 23) {
                        return t('invalidHour');
                      }
                      if (hour < _startHour) {
                        return t('endBeforeStart');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _intervalMinutes.toString(),
              decoration: InputDecoration(
                labelText: t('interval'),
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white54),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                _intervalMinutes = int.tryParse(value) ?? 60;
              },
              validator: (value) {
                final interval = int.tryParse(value ?? '');
                if (interval == null || interval <= 0) {
                  return t('invalidInterval');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                _active ? t('active') : t('inactive'),
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              value: _active,
              onChanged: (value) {
                setState(() {
                  _active = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showCreateForm = false;
                        _editingTemplateId = null;
                        _selectedLineId = null;
                        _startHour = 7;
                        _endHour = 19;
                        _intervalMinutes = 60;
                        _active = true;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.getCardBorder(0.7)),
                    ),
                    child: Text(t('cancel'),
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _editingTemplateId != null
                        ? () => _handleUpdateSchedule(_editingTemplateId!)
                        : _handleCreateSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('save'),
                        style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final line = schedule['line'] as Map<String, dynamic>?;
    final lineName = _isArabic
        ? (line?['name_ar']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_en']?.toString() ??
            'Unknown')
        : (line?['name_en']?.toString() ??
            line?['linename']?.toString() ??
            line?['name_ar']?.toString() ??
            'Unknown');
    final startHour = schedule['start_hour'] ?? 0;
    final endHour = schedule['end_hour'] ?? 23;
    final interval = schedule['interval_minutes'] ?? 60;
    final active = schedule['active'] ?? true;
    final templateid = schedule['templateid'] as String;

    return Card(
      color: AppTheme.getCardBackground(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lineName,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    active ? t('active') : t('inactive'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${t('from')} $startHour:00 ${t('to')} $endHour:00',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${t('every')} $interval ${interval == 60 ? t('hour') : t('minutes')}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleCreateTrips(templateid),
                    icon: Icon(Icons.add_circle_outline,
                        color: AppTheme.textPrimary),
                    label: Text(t('createTrips'),
                        style: TextStyle(color: AppTheme.textPrimary)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: BorderSide(color: AppTheme.getCardBorder(0.7)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: Colors.blue,
                  onPressed: () => _openEditForm(schedule),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  onPressed: () => _handleDeleteSchedule(templateid),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
