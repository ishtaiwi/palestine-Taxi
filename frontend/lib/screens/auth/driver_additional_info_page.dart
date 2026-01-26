import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/api_service.dart';
import '../../pages/driver/driver_home.dart';
import 'select_role_page.dart';
import 'driver_pending_approval_page.dart';

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
      'vehicleInfo': 'معلومات المركبة',
      'plateNumber': 'رقم اللوحة',
      'plateNumberHint': 'مثال: 3-1234-A',
      'plateNumberRequired': 'رقم اللوحة مطلوب',
      'seatLayout': 'تخطيط المقاعد',
      'seatLayoutRequired': 'تخطيط المقاعد مطلوب',
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
      'vehicleInfo': 'Vehicle Information',
      'plateNumber': 'Plate Number',
      'plateNumberHint': 'Example: 3-1234-A',
      'plateNumberRequired': 'Plate number is required',
      'seatLayout': 'Seat Layout',
      'seatLayoutRequired': 'Seat layout is required',
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
      final result = await ApiService.register(
        fullname: widget.formData.fullName,
        email: widget.formData.email,
        phone: widget.formData.phone,
        password: widget.formData.password,
        role: 'DRIVER',
        licenseId: _licenseIdController.text.trim(),
        lineId: resolvedLineId,
        vehiclePlate: _plateNumberController.text.trim(),
        vehicleSeatLayout: _selectedSeatLayout,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final success = result['success'] == true || result['success'] == 'true';
      final approvalStatus = result['approvalStatus'] as String?;

      if (success) {
        final message = result['message'] ?? (_isArabic ? 'تم إنشاء الحساب بنجاح' : 'Registration successful');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              // If driver is pending approval, show pending screen
              if (approvalStatus == 'pending') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverPendingApprovalPage()),
                  (route) => false,
                );
              } else {
                // If approved, go to home
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverHomePage()),
                  (route) => false,
                );
              }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && screenWidth > 800;
    
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
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 24 : 24,
                  vertical: isDesktop ? 16 : 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 600 : double.infinity,
                  ),
                  child: Container(
                    width: isDesktop ? 600 : double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 32 : 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white38,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Text(
                        t('subtitle'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 20 : 24),
                      _buildTextField(
                        controller: _licenseIdController,
                        label: t('licenseId'),
                        hint: t('enterLicenseId'),
                        keyboardType: TextInputType.text,
                        isDesktop: isDesktop,
                        required: true,
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
                      SizedBox(height: isDesktop ? 20 : 24),
                      Text(
                        t('lineSection'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 14 : 16),
                      _buildLineSelector(),
                      SizedBox(height: isDesktop ? 24 : 28),
                      Text(
                        t('vehicleInfo'),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                      SizedBox(height: isDesktop ? 14 : 16),
                      _buildTextField(
                        controller: _plateNumberController,
                        label: t('plateNumber'),
                        hint: t('plateNumberHint'),
                        keyboardType: TextInputType.text,
                        isDesktop: isDesktop,
                        validator: _validatePlateNumber,
                        required: true,
                      ),
                      SizedBox(height: isDesktop ? 20 : 24),
                      _buildSeatLayoutSelector(),
                      SizedBox(height: isDesktop ? 28 : 32),
                      SizedBox(
                        width: double.infinity,
                        height: isDesktop ? 52 : 56,
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
        ),
      ),
    );
  }

  String? _validatePlateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return t('plateNumberRequired');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && screenWidth > 800;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              t('seatLayout'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: Color(0xFFF57C00),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildSeatOption(
                layout: '4+1',
                label: _isArabic ? '4+1 (خمس ركاب)' : '4+1 (5 seats)',
                isSelected: _selectedSeatLayout == '4+1',
                isDesktop: isDesktop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSeatOption(
                layout: '7+1',
                label: _isArabic ? '7+1 (ثمانية ركاب)' : '7+1 (8 seats)',
                isSelected: _selectedSeatLayout == '7+1',
                isDesktop: isDesktop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeatOption({
    required String layout,
    required String label,
    required bool isSelected,
    required bool isDesktop,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedSeatLayout = layout;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 14 : 16,
          horizontal: isDesktop ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF57C00).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF57C00)
                : Colors.white38,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFF57C00).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: isDesktop ? 15 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isDesktop = false,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: Colors.white,
        fontSize: isDesktop ? 16 : 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(label, hint, required: required),
      validator: validator,
      enableInteractiveSelection: true,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    bool required = false,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.white38),
    );

    return InputDecoration(
      labelText: required ? '$label *' : label,
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
      errorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: baseBorder.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = kIsWeb && screenWidth > 800;
    
    return DropdownButtonFormField<String>(
      value: _selectedLineId != null &&
              _lines.any((line) =>
                  line['lineid']?.toString() == _selectedLineId)
          ? _selectedLineId
          : null,
      decoration: _inputDecoration(t('lineLabel'), t('lineHint'), required: true),
      dropdownColor: const Color(0xFF142238),
      iconEnabledColor: Colors.white,
      iconSize: isDesktop ? 28 : 24,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: isDesktop ? 16 : 15,
      ),
      menuMaxHeight: 400,
      borderRadius: BorderRadius.circular(18),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      selectedItemBuilder: (BuildContext context) {
        return _lines.map<Widget>((line) {
          final lineName = _isArabic
              ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '')
              : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? '');
          return Align(
            alignment: _isArabic ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              lineName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 16 : 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: _lines
          .map(
            (line) => DropdownMenuItem<String>(
              value: line['lineid']?.toString(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF57C00).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.route,
                        color: Color(0xFFF57C00),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isArabic
                            ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '')
                            : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedLineId == line['lineid']?.toString())
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFFF57C00),
                          size: 20,
                        ),
                      ),
                  ],
                ),
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

