import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../pages/driver/driver_home.dart';
import 'select_role_page.dart';

class DriverAdditionalInfoScreen extends StatefulWidget {
  final RegisterFormData formData;
  final bool startArabic;
  const DriverAdditionalInfoScreen({
    super.key,
    required this.formData,
    this.startArabic = true,
  });

  @override
  State<DriverAdditionalInfoScreen> createState() =>
      _DriverAdditionalInfoScreenState();
}

class _DriverAdditionalInfoScreenState
    extends State<DriverAdditionalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _licenseIdController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();

  bool _isArabic = true;
  bool _isLoading = false;
  bool _isLinesLoading = false;
  String? _linesError;
  String? _selectedLineId;
  String _selectedSeatLayout = '4+1';
  List<Map<String, dynamic>> _lines = [];

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'معلومات السائق',
      'subtitle': 'أدخل معلومات الرخصة للتسجيل كسائق',
      'licenseId': 'رقم الرخصة',
      'enterLicenseId': 'أدخل رقم الرخصة',
      'createAccount': 'إنشاء الحساب',
      'back': 'الرجوع',
      'lineSection': 'اختر خط العمل',
      'lineLabel': 'الخط',
      'lineHint': 'اختر الخط الذي تعمل عليه',
      'lineRequired': 'يرجى اختيار الخط',
      'lineLoading': 'جارٍ تحميل الخطوط...',
      'lineRetry': 'إعادة تحميل الخطوط',
      'lineError': 'فشل تحميل الخطوط',
      'lineEmpty': 'لا توجد خطوط متاحة حالياً',
      'vehicleInfo': 'معلومات المركبة (اختياري)',
      'vehicleInfoNote': 'سيتم إنشاء المركبة تلقائياً. يمكنك إضافة رقم اللوحة وتخطيط المقاعد لاحقاً.',
      'plateNumber': 'رقم اللوحة',
      'plateNumberHint': 'مثال: 3-1234-A (اختياري)',
      'seatLayout': 'تخطيط المقاعد',
    },
    'en': {
      'title': 'Driver Information',
      'subtitle': 'Enter license information to register as a driver',
      'licenseId': 'License ID',
      'enterLicenseId': 'Enter license ID',
      'createAccount': 'Create Account',
      'back': 'Back',
      'lineSection': 'Select your operating line',
      'lineLabel': 'Line',
      'lineHint': 'Choose the line you operate on',
      'lineRequired': 'Please select a line',
      'lineLoading': 'Loading lines...',
      'lineRetry': 'Reload lines',
      'lineError': 'Failed to load lines',
      'lineEmpty': 'No lines available right now',
      'vehicleInfo': 'Vehicle Information (Optional)',
      'vehicleInfoNote': 'Vehicle will be created automatically. You can add plate number and seat layout later.',
      'plateNumber': 'Plate Number',
      'plateNumberHint': 'Example: 3-1234-A (optional)',
      'seatLayout': 'Seat Layout',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.startArabic;
    _loadLanguagePreference();
    _fetchLines();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
  }

  Future<void> _switchLanguage(bool arabic) async {
    await ApiService.saveLanguagePreference(arabic);
    setState(() {
      _isArabic = arabic;
    });
  }

  @override
  void dispose() {
    _licenseIdController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchLines() async {
    setState(() {
      _isLinesLoading = true;
      _linesError = null;
    });
    try {
      final lines = await ApiService.fetchActiveLines();
      if (!mounted) return;
      setState(() {
        _lines = lines;
        _isLinesLoading = false;
        if (_lines.isEmpty) {
          _selectedLineId = null;
        } else if (!_lines.any((line) => line['lineid'] == _selectedLineId)) {
          _selectedLineId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLinesLoading = false;
        _linesError = e.toString();
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'يرجى تصحيح الأخطاء في النموذج'
                : 'Please fix the errors in the form',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedLineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('lineRequired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final resolvedLineId = _resolveSelectedLineId();
    if (resolvedLineId == null || resolvedLineId.isEmpty) {
      debugPrint(
        '[DriverSignup] Failed to resolve line ID. Selected value: $_selectedLineId',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('lineRequired')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint(
        '[DriverSignup] Submitting driver registration with lineId: $resolvedLineId',
      );
      // Vehicle will be created automatically even if plate number is empty
      // Default: seatlayout = '4+1', plateno = null (can be added later)
      final result = await ApiService.register(
        fullname: widget.formData.fullName,
        email: widget.formData.email,
        phone: widget.formData.phone,
        password: widget.formData.password,
        role: 'DRIVER',
        licenseId: _licenseIdController.text.trim(),
        lineId: resolvedLineId,
        vehiclePlate: _plateNumberController.text.trim().isEmpty 
            ? null 
            : _plateNumberController.text.trim(), // Send null if empty
        vehicleSeatLayout: _selectedSeatLayout, // Always send (default: '4+1')
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final success = result['success'] == true || result['success'] == 'true';

      if (success) {
        final message = result['message'] ?? (_isArabic ? 'تم إنشاء الحساب بنجاح' : 'Registration successful');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const DriverHomePage()),
                (route) => false,
              );
            }
          });
        }
      } else {
        final errorMessage = result['message'] ?? (_isArabic ? 'فشل إنشاء الحساب' : 'Registration failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'حدث خطأ: ${e.toString()}'
                : 'Error occurred: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: () => _switchLanguage(!_isArabic),
              icon: Icon(_isArabic ? Icons.language : Icons.translate),
              color: Colors.white,
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A1528), Color(0xFF1A2F4A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('subtitle'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _licenseIdController,
                        label: t('licenseId'),
                        hint: t('enterLicenseId'),
                        keyboardType: TextInputType.text,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return t('enterLicenseId');
                          }
                          if (value.trim().length < 3) {
                            return _isArabic
                                ? 'رقم الرخصة قصير جداً'
                                : 'License ID is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        t('lineSection'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildLineSelector(),
                      const SizedBox(height: 24),
                      // Vehicle Information Section (Optional)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t('vehicleInfoNote'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _plateNumberController,
                        label: t('plateNumber'),
                        hint: t('plateNumberHint'),
                        keyboardType: TextInputType.text,
                        validator: _validatePlateNumber,
                      ),
                      const SizedBox(height: 24),
                      _buildSeatLayoutSelector(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF57C00), Color(0xFFE65100)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF57C00).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(t('createAccount')),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.person_add, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          t('back'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validatePlateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _isArabic ? 'رقم المركبة مطلوب' : 'Vehicle plate is required';
    }
    final pattern = RegExp(r'^\d-\d{4}-[A-Za-z]$');
    if (!pattern.hasMatch(value.trim())) {
      return _isArabic
          ? 'استخدم الصيغة 3-1234-A'
          : 'Use format 3-1234-A';
    }
    return null;
  }

  Widget _buildSeatLayoutSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isArabic ? 'نوع المقاعد' : 'Seat configuration',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ToggleButtons(
          isSelected: [
            _selectedSeatLayout == '4+1',
            _selectedSeatLayout == '7+1',
          ],
          borderRadius: BorderRadius.circular(12),
          fillColor: const Color(0xFFF57C00),
          selectedColor: Colors.white,
          color: Colors.white70,
          onPressed: (index) {
            setState(() {
              _selectedSeatLayout = index == 0 ? '4+1' : '7+1';
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_isArabic ? '4+1 (خمس ركاب)' : '4+1 (5 seats)'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_isArabic ? '7+1 (ثمانية ركاب)' : '7+1 (8 seats)'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(label, hint),
      validator: validator,
      enableInteractiveSelection: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint,
  ) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white38),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      enabledBorder: baseBorder,
      focusedBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Color(0xFFF57C00), width: 2),
      ),
    );
  }

  String? _resolveSelectedLineId() {
    if (_selectedLineId == null || _selectedLineId!.isEmpty) return null;

    for (final line in _lines) {
      final id = line['lineid']?.toString();
      final nameAr = line['name_ar']?.toString();
      final nameEn = line['name_en']?.toString();
      final nameOld = line['linename']?.toString();
      if (_selectedLineId == id || _selectedLineId == nameAr || _selectedLineId == nameEn || _selectedLineId == nameOld) {
        return id;
      }
    }
    return null;
  }

  Widget _buildLineSelector() {
    if (_isLinesLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white38),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF57C00)),
            ),
            const SizedBox(height: 12),
            Text(
              t('lineLoading'),
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_linesError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('lineError'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _linesError ?? '',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                onPressed: _fetchLines,
                icon: const Icon(Icons.refresh),
                label: Text(t('lineRetry')),
              ),
            ),
          ],
        ),
      );
    }

    if (_lines.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('lineEmpty'),
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              onPressed: _fetchLines,
              icon: const Icon(Icons.refresh),
              label: Text(t('lineRetry')),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedLineId,
      decoration: _inputDecoration(t('lineLabel'), t('lineHint')),
      dropdownColor: const Color(0xFF142238),
      iconEnabledColor: Colors.white,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      items: _lines
          .map(
            (line) => DropdownMenuItem<String>(
              value: line['lineid']?.toString(),
              child: Text(
                _isArabic
                    ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '')
                    : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? ''),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedLineId = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return t('lineRequired');
        }
        return null;
      },
    );
  }
}

