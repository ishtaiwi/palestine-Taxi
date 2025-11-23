import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isArabic = true;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة المستخدمين',
      'users': 'المستخدمين',
      'noUsers': 'لا يوجد مستخدمين',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'confirmDelete': 'هل أنت متأكد من حذف هذا المستخدم؟',
      'yes': 'نعم',
      'no': 'لا',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'editUser': 'تعديل المستخدم',
      'name': 'الاسم',
      'email': 'البريد الإلكتروني',
      'role': 'الدور',
      'phone': 'الهاتف',
      'selectRole': 'اختر الدور',
      'nameRequired': 'الاسم مطلوب',
      'emailRequired': 'البريد الإلكتروني مطلوب',
      'emailInvalid': 'البريد الإلكتروني غير صحيح',
      'userUpdated': 'تم تحديث المستخدم بنجاح',
      'updateFailed': 'فشل تحديث المستخدم',
    },
    'en': {
      'title': 'Users Management',
      'users': 'Users',
      'noUsers': 'No users found',
      'loading': 'Loading...',
      'error': 'Error',
      'delete': 'Delete',
      'edit': 'Edit',
      'confirmDelete': 'Are you sure you want to delete this user?',
      'yes': 'Yes',
      'no': 'No',
      'cancel': 'Cancel',
      'save': 'Save',
      'editUser': 'Edit User',
      'name': 'Name',
      'email': 'Email',
      'role': 'Role',
      'phone': 'Phone',
      'selectRole': 'Select Role',
      'nameRequired': 'Name is required',
      'emailRequired': 'Email is required',
      'emailInvalid': 'Invalid email address',
      'userUpdated': 'User updated successfully',
      'updateFailed': 'Failed to update user',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
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
      final users = await ApiService.getAllUsers();
      setState(() {
        _users = users;
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

  Future<void> _handleEdit(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['fullname'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    String? selectedRole = user['role']?.toString().toLowerCase();

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3A5F),
        title: Text(
          t('editUser'),
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t('name'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t('nameRequired');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t('email'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return t('emailRequired');
                    }
                    if (!value.contains('@')) {
                      return t('emailInvalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: t('phone'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF1E3A5F),
                  decoration: InputDecoration(
                    labelText: t('role'),
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('Admin', style: const TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'driver',
                      child: Text('Driver', style: const TextStyle(color: Colors.white)),
                    ),
                    DropdownMenuItem(
                      value: 'passenger',
                      child: Text('Passenger', style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                  onChanged: (value) {
                    selectedRole = value;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('cancel'), style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(t('save'), style: const TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (result != true) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    final updateResult = await ApiService.updateUser(
      userid: user['userid'],
      fullname: nameController.text.trim(),
      email: emailController.text.trim(),
      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      role: selectedRole,
    );

    // Close loading
    if (mounted) Navigator.pop(context);

    if (mounted) {
      if (updateResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t('userUpdated')),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updateResult['message'] ?? t('updateFailed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(String userid) async {
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

    final result = await ApiService.deleteUser(userid);
    if (mounted) {
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'User deleted'),
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
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          title: Text(
            t('title'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF1E3A5F),
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
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
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? Center(
                    child: Text(
                      t('noUsers'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            user['fullname'] ?? '',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t('email')}: ${user['email'] ?? ''}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '${t('role')}: ${user['role'] ?? ''}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (user['phone'] != null)
                                Text(
                                  '${t('phone')}: ${user['phone']}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange),
                                onPressed: () => _handleEdit(user),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _handleDelete(user['userid']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

