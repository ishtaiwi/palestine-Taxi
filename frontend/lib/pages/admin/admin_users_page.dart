import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  bool _isArabic = true;
  String? _selectedRoleFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      'filterAll': 'الكل',
      'filterAdmin': 'مدراء',
      'filterDriver': 'سائقون',
      'filterPassenger': 'ركاب',
      'filterByRole': 'تصفية حسب الدور',
      'search': 'بحث...',
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
      'filterAll': 'All',
      'filterAdmin': 'Admins',
      'filterDriver': 'Drivers',
      'filterPassenger': 'Passengers',
      'filterByRole': 'Filter by Role',
      'search': 'Search...',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _loadData();
    _loadLanguagePreference();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      final users = await ApiService.getAllUsers();
      setState(() {
        _users = users;
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
    _filteredUsers = _users.where((user) {
      final userRole = user['role']?.toString().toLowerCase();
      final name = user['fullname']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';

      final matchesRole = _selectedRoleFilter == null || userRole == _selectedRoleFilter?.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery) || email.contains(_searchQuery);

      return matchesRole && matchesSearch;
    }).toList();
  }

  Color _getRoleColor(String? role) {
    if (AppTheme.isDarkMode) {
      switch (role?.toLowerCase()) {
        case 'admin':
          return const Color(0xFF7986CB); // Lighter Indigo
        case 'driver':
          return const Color(0xFF81C784); // Lighter Green
        case 'passenger':
          return const Color(0xFFFFB74D); // Lighter Orange
        default:
          return Colors.grey.shade400;
      }
    }
    switch (role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFF5C6BC0);
      case 'driver':
        return const Color(0xFF66BB6A);
      case 'passenger':
        return const Color(0xFFFFA726);
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'driver':
        return Icons.directions_car_rounded;
      case 'passenger':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
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
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  _buildFilterSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                  Expanded(
                    child: _filteredUsers.isEmpty
                        ? _buildEmptyState(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              basePadding, 
                              0, 
                              basePadding, 
                              basePadding
                            ),
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: isSmallScreen ? 10.0 : 12.0),
                            itemBuilder: (context, index) {
                              return _buildUserCard(
                                _filteredUsers[index],
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
        0
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
          color: AppTheme.textPrimary,
          fontSize: isSmallScreen ? 14.0 : 16.0,
        ),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: isSmallScreen ? 14.0 : 16.0,
          ),
          prefixIcon: Icon(
            Icons.search_rounded, 
            color: AppTheme.textSecondary,
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
                    color: AppTheme.textSecondary,
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

  Widget _buildFilterSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0), 
        horizontal: isSmallScreen ? 12.0 : 16.0
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, t('filterAll'), Icons.people_alt_rounded, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            _buildFilterChip('admin', t('filterAdmin'), Icons.admin_panel_settings_rounded, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            _buildFilterChip('driver', t('filterDriver'), Icons.directions_car_rounded, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
            SizedBox(width: isSmallScreen ? 8.0 : 12.0),
            _buildFilterChip('passenger', t('filterPassenger'), Icons.person_rounded, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String? role, String label, IconData icon, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final isSelected = _selectedRoleFilter == role;
    // Use BlueAccent for 'All' in dark mode for better visibility
    final color = role == null
        ? (AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor)
        : _getRoleColor(role);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRoleFilter = role;
            _applyFilter();
          });
        },
        borderRadius: BorderRadius.circular(isSmallScreen ? 24.0 : 30.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
            vertical: isSmallScreen ? 8.0 : 10.0
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (AppTheme.isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : AppTheme.cardBackground),
            borderRadius: BorderRadius.circular(isSmallScreen ? 24.0 : 30.0),
            border: Border.all(
              color: isSelected
                  ? color
                  : (AppTheme.isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : AppTheme.textSecondary.withOpacity(0.3)),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                color: isSelected
                    ? Colors.white
                    : (AppTheme.isDarkMode
                        ? Colors.white
                        : AppTheme.textSecondary),
              ),
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (AppTheme.isDarkMode
                          ? Colors.white
                          : AppTheme.textSecondary),
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    final role = user['role']?.toString();
    final roleColor = _getRoleColor(role);
    final roleIcon = _getRoleIcon(role);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        boxShadow: [
          BoxShadow(
            color: AppTheme.isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: AppTheme.isDarkMode
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        child: InkWell(
          onTap: () {}, 
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 42.0 : (isMediumScreen ? 46.0 : 50.0),
                  height: isSmallScreen ? 42.0 : (isMediumScreen ? 46.0 : 50.0),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    roleIcon,
                    color: roleColor,
                    size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['fullname'] ?? t('name'),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          color: AppTheme.isDarkMode
                              ? Colors.white.withOpacity(0.9)
                              : AppTheme.textSecondary,
                          fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user['phone'] != null && user['phone'].toString().isNotEmpty) ...[
                        SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_iphone_rounded,
                              size: isSmallScreen ? 10.0 : 12.0,
                              color: AppTheme.isDarkMode
                                  ? Colors.blueAccent.shade100
                                  : AppTheme.textSecondary,
                            ),
                            SizedBox(width: isSmallScreen ? 3.0 : 4.0),
                            Text(
                              user['phone'].toString(),
                              style: TextStyle(
                                color: AppTheme.isDarkMode
                                    ? Colors.blueAccent.shade100
                                    : AppTheme.textSecondary,
                                fontSize: isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: Colors.blueAccent,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      onTap: () => _handleEdit(user),
                    ),
                    SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      isSmallScreen: isSmallScreen,
                      isMediumScreen: isMediumScreen,
                      onTap: () => _handleDelete(user['userid']),
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
              Icons.people_outline_rounded,
              size: isSmallScreen ? 60.0 : (isMediumScreen ? 70.0 : 80.0),
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            t('noUsers'),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        title: Text(
          t('editUser'),
          style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: nameController,
                  label: t('name'),
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) return t('nameRequired');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: emailController,
                  label: t('email'),
                  icon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) return t('emailRequired');
                    if (!value.contains('@')) return t('emailInvalid');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: phoneController,
                  label: t('phone'),
                  icon: Icons.phone_iphone_rounded,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  dropdownColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
                  style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                  isExpanded: true,
                  itemHeight: null,
                  decoration: InputDecoration(
                    labelText: t('role'),
                    labelStyle: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  selectedItemBuilder: (context) {
                    return ['admin', 'driver', 'passenger'].map((role) {
                      return Text(
                        role[0].toUpperCase() + role.substring(1),
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList();
                  },
                  items: ['admin', 'driver', 'passenger'].map((role) {
                    final roleColor = _getRoleColor(role);
                    final isSelected = selectedRole == role;
                    return DropdownMenuItem(
                      value: role,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? roleColor : roleColor.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: roleColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getRoleIcon(role),
                                color: roleColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              role[0].toUpperCase() + role.substring(1),
                              style: TextStyle(
                                color: isSelected 
                                    ? roleColor 
                                    : (AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                     // Need to trigger rebuild to update the selected item styling in dropdown
                     (context as Element).markNeedsBuild();
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
            child: Text(t('cancel'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(t('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

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

    if (mounted) Navigator.pop(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updateResult['success'] == true ? t('userUpdated') : (updateResult['message'] ?? t('updateFailed')),
          ),
          backgroundColor: updateResult['success'] == true ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (updateResult['success'] == true) _loadData();
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
        prefixIcon: Icon(icon, color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _handleDelete(String userid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : AppTheme.cardBackground,
        title: Text(t('confirmDelete'), style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
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

    final result = await ApiService.deleteUser(userid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? (result['success'] == true ? 'User deleted' : t('error'))),
          backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (result['success'] == true) _loadData();
    }
  }
}
