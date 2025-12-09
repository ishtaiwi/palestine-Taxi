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
  bool _isLoading = true;
  bool _isArabic = true;
  bool _showCreateForm = false;

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

  @override
  void dispose() {
    _nameArController.dispose();
    _nameEnController.dispose();
    _basePriceController.dispose();
    _additionalPriceController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    super.dispose();
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final nameAr = _nameArController.text.trim();
    final nameEn = _nameEnController.text.trim();

    // At least Arabic name is required
    if (nameAr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isArabic ? 'الاسم بالعربية مطلوب' : 'Arabic name is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? t('success')),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
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

  void _resetForm() {
    setState(() {
      _showCreateForm = false;
      _editingLineId = null;
      _nameArController.clear();
      _nameEnController.clear();
      _basePriceController.clear();
      _additionalPriceController.clear();
      _durationController.clear();
      _distanceController.clear();
      _active = true;
    });
  }

  void _openEditForm(Map<String, dynamic> line) {
    setState(() {
      _showCreateForm = true;
      _editingLineId = line['lineid'];
      _nameArController.text = line['name_ar'] ?? line['linename'] ?? '';
      _nameEnController.text = line['name_en'] ?? '';
      _basePriceController.text = (line['baseprice'] ?? 0).toString();
      _additionalPriceController.text =
          (line['additionalprice'] ?? 0).toString();
      _durationController.text = (line['estduration'] ?? '').toString();
      _distanceController.text = (line['distance'] ?? '').toString();
      _active = line['active'] ?? true;
    });
  }

  Future<void> _handleDelete(String lineid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          t('confirmDelete'),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('no'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('yes'), style: const TextStyle(color: Colors.red)),
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
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          actionsIconTheme: IconThemeData(color: AppTheme.textPrimary),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
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
            IconButton(
              icon: Icon(
                _showCreateForm ? Icons.close : Icons.add,
                color: AppTheme.textPrimary,
              ),
              onPressed: () {
                if (_showCreateForm) {
                  _resetForm();
                } else {
                  setState(() {
                    _showCreateForm = true;
                  });
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_showCreateForm) _buildForm(),
                  Expanded(
                    child: _lines.isEmpty
                        ? Center(
                            child: Text(
                              t('noLines'),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _lines.length,
                            itemBuilder: (context, index) {
                              return _buildLineCard(_lines[index]);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: const Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Arabic Name Field
            TextFormField(
              controller: _nameArController,
              decoration: InputDecoration(
                labelText: t('lineNameAr'),
                labelStyle: const TextStyle(color: Colors.white70),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              validator: (value) =>
                  value?.isEmpty ?? true ? t('required') : null,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),
            // English Name Field (Optional)
            TextFormField(
              controller: _nameEnController,
              decoration: InputDecoration(
                labelText: t('lineNameEn'),
                labelStyle: const TextStyle(color: Colors.white70),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _basePriceController,
                    decoration: InputDecoration(
                      labelText: t('basePrice'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                    validator: (value) =>
                        value?.isEmpty ?? true ? t('required') : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _additionalPriceController,
                    decoration: InputDecoration(
                      labelText: t('additionalPrice'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: InputDecoration(
                      labelText: t('duration'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    decoration: InputDecoration(
                      labelText: t('distance'),
                      labelStyle: const TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                _active ? t('active') : t('inactive'),
                style: const TextStyle(color: Colors.white),
              ),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: Text(t('cancel'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('save'),
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineCard(Map<String, dynamic> line) {
    // Get line name based on current language
    final lineName = _isArabic
        ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? '')
        : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? '');

    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          lineName,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('basePrice')}: ${line['baseprice'] ?? 0}',
              style: const TextStyle(color: Colors.white70),
            ),
            if (line['active'] != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (line['active'] == true ? Colors.green : Colors.red)
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  line['active'] == true ? t('active') : t('inactive'),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _openEditForm(line),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _handleDelete(line['lineid']),
            ),
          ],
        ),
      ),
    );
  }
}
