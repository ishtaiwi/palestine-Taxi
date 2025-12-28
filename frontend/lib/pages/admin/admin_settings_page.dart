import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _isLoading = true;
  bool _isArabic = true;
  bool _isSaving = false;
  int _timezoneOffset = 2;
  String _timezoneName = 'UTC+2';
  String _description = 'Palestine Standard Time';

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الإعدادات',
      'timezone': 'المنطقة الزمنية',
      'timezoneDescription': 'اختر المنطقة الزمنية للخادم',
      'currentTimezone': 'المنطقة الزمنية الحالية',
      'selectTimezone': 'اختر المنطقة الزمنية',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'saving': 'جاري الحفظ...',
      'success': 'تم تحديث المنطقة الزمنية بنجاح',
      'error': 'حدث خطأ',
      'loading': 'جاري التحميل...',
      'note': 'ملاحظة: سيتم استخدام هذه المنطقة الزمنية عند إنشاء الرحلات من الجداول.',
    },
    'en': {
      'title': 'Settings',
      'timezone': 'Timezone',
      'timezoneDescription': 'Select the server timezone',
      'currentTimezone': 'Current Timezone',
      'selectTimezone': 'Select Timezone',
      'save': 'Save',
      'cancel': 'Cancel',
      'saving': 'Saving...',
      'success': 'Timezone updated successfully',
      'error': 'Error',
      'loading': 'Loading...',
      'note': 'Note: This timezone will be used when creating trips from schedules.',
    },
  };

  // Common timezones
  final List<Map<String, dynamic>> _timezones = [
    {'offset': -12, 'name': 'UTC-12', 'description': 'Baker Island Time'},
    {'offset': -11, 'name': 'UTC-11', 'description': 'Hawaii-Aleutian Standard Time'},
    {'offset': -10, 'name': 'UTC-10', 'description': 'Hawaii Standard Time'},
    {'offset': -9, 'name': 'UTC-9', 'description': 'Alaska Standard Time'},
    {'offset': -8, 'name': 'UTC-8', 'description': 'Pacific Standard Time'},
    {'offset': -7, 'name': 'UTC-7', 'description': 'Mountain Standard Time'},
    {'offset': -6, 'name': 'UTC-6', 'description': 'Central Standard Time'},
    {'offset': -5, 'name': 'UTC-5', 'description': 'Eastern Standard Time'},
    {'offset': -4, 'name': 'UTC-4', 'description': 'Atlantic Standard Time'},
    {'offset': -3, 'name': 'UTC-3', 'description': 'Argentina Time'},
    {'offset': -2, 'name': 'UTC-2', 'description': 'South Georgia Time'},
    {'offset': -1, 'name': 'UTC-1', 'description': 'Cape Verde Time'},
    {'offset': 0, 'name': 'UTC', 'description': 'Coordinated Universal Time'},
    {'offset': 1, 'name': 'UTC+1', 'description': 'Central European Time'},
    {'offset': 2, 'name': 'UTC+2', 'description': 'Palestine Standard Time'},
    {'offset': 3, 'name': 'UTC+3', 'description': 'Arabia Standard Time'},
    {'offset': 4, 'name': 'UTC+4', 'description': 'Gulf Standard Time'},
    {'offset': 5, 'name': 'UTC+5', 'description': 'Pakistan Standard Time'},
    {'offset': 6, 'name': 'UTC+6', 'description': 'Bangladesh Standard Time'},
    {'offset': 7, 'name': 'UTC+7', 'description': 'Indochina Time'},
    {'offset': 8, 'name': 'UTC+8', 'description': 'China Standard Time'},
    {'offset': 9, 'name': 'UTC+9', 'description': 'Japan Standard Time'},
    {'offset': 10, 'name': 'UTC+10', 'description': 'Australian Eastern Time'},
    {'offset': 11, 'name': 'UTC+11', 'description': 'Solomon Islands Time'},
    {'offset': 12, 'name': 'UTC+12', 'description': 'New Zealand Standard Time'},
    {'offset': 13, 'name': 'UTC+13', 'description': 'Tonga Time'},
    {'offset': 14, 'name': 'UTC+14', 'description': 'Line Islands Time'},
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadTimezoneConfig();
  }

  Future<void> _loadLanguagePreference() async {
    final pref = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = pref;
    });
  }

  Future<void> _loadTimezoneConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getTimezoneConfig();
      if (result['success'] == true) {
        setState(() {
          _timezoneOffset = result['timezone_offset'] ?? 2;
          _timezoneName = result['timezone_name'] ?? 'UTC+2';
          _description = result['description'] ?? 'Palestine Standard Time';
        });
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTimezoneConfig() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ApiService.updateTimezoneConfig(_timezoneOffset);
      if (result['success'] == true) {
        setState(() {
          _timezoneName = result['timezone_name'] ?? _timezoneName;
        });
        _showSnackBar(t('success'));
      } else {
        _showSnackBar(result['message'] ?? t('error'), isError: true);
      }
    } catch (e) {
      _showSnackBar('${t('error')}: $e', isError: true);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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

  String t(String key) {
    return _texts[_isArabic ? 'ar' : 'en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final _isDarkMode = AppTheme.isDarkMode;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: _isDarkMode
            ? const Color(0xFF0A0E21)
            : const Color.fromARGB(255, 224, 228, 231),
        appBar: AppBar(
          backgroundColor: AppTheme.isDarkMode
              ? const Color(0xFF1C2541)
              : AppTheme.appBarColor,
          elevation: 0,
          title: Text(
            t('title'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back, 
              color: Colors.white,
              size: isSmallScreen ? 20.0 : 24.0,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(basePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Timezone Card
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF1C2541)
                              : const Color(0xFFFAFBFC),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                          border: Border.all(
                            color: _isDarkMode
                                ? const Color(0xFF2C3E50)
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF546E7A),
                                  size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                                ),
                                SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                Text(
                                  t('currentTimezone'),
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF1E3A5F),
                                    fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                            Text(
                              _timezoneName,
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E3A5F),
                                fontSize: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                            Text(
                              _description,
                              style: TextStyle(
                                color: _isDarkMode
                                    ? const Color(0xFFB0BEC5)
                                    : const Color(0xFF546E7A),
                                fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                      // Timezone Selection Card
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
                        decoration: BoxDecoration(
                          color: _isDarkMode
                              ? const Color(0xFF1C2541)
                              : const Color(0xFFFAFBFC),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                          border: Border.all(
                            color: _isDarkMode
                                ? const Color(0xFF2C3E50)
                                : Colors.grey.shade200,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('selectTimezone'),
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E3A5F),
                                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                            DropdownButtonFormField<int>(
                              value: _timezoneOffset,
                              decoration: InputDecoration(
                                labelText: t('timezone'),
                                labelStyle: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : const Color(0xFF546E7A),
                                  fontSize: isSmallScreen ? 13.0 : 14.0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                  borderSide: BorderSide(
                                    color: _isDarkMode
                                        ? Colors.white12
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                filled: true,
                                fillColor: _isDarkMode
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 16.0 : 20.0,
                                  vertical: isSmallScreen ? 12.0 : 16.0,
                                ),
                              ),
                              dropdownColor: _isDarkMode
                                  ? const Color(0xFF1C2541)
                                  : Colors.white,
                              style: TextStyle(
                                color: _isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF1E3A5F),
                                fontSize: isSmallScreen ? 14.0 : 16.0,
                              ),
                              items: _timezones.map((tz) {
                                return DropdownMenuItem<int>(
                                  value: tz['offset'] as int,
                                  child: Text(
                                    '${tz['name']} - ${tz['description']}',
                                    style: TextStyle(
                                      color: _isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF1E3A5F),
                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _timezoneOffset = value;
                                    final tz = _timezones.firstWhere(
                                      (tz) => tz['offset'] == value,
                                    );
                                    _timezoneName = tz['name'] as String;
                                    _description = tz['description'] as String;
                                  });
                                }
                              },
                            ),
                            SizedBox(height: isSmallScreen ? 16.0 : 24.0),
                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveTimezoneConfig,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.appBarColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                        height: isSmallScreen ? 18.0 : 20.0,
                                        width: isSmallScreen ? 18.0 : 20.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        t('save'),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                            // Note
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                              decoration: BoxDecoration(
                                color: _isDarkMode
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                border: Border.all(
                                  color: _isDarkMode
                                      ? Colors.blue.withOpacity(0.3)
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: _isDarkMode
                                        ? Colors.blueAccent
                                        : Colors.blue.shade700,
                                    size: isSmallScreen ? 18.0 : 20.0,
                                  ),
                                  SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                  Expanded(
                                    child: Text(
                                      t('note'),
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.blueAccent
                                            : Colors.blue.shade700,
                                        fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 12.5 : 13.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
}

