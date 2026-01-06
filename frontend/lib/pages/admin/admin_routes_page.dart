import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'line_route_editor_page.dart';

class AdminRoutesPage extends StatefulWidget {
  const AdminRoutesPage({super.key});

  @override
  State<AdminRoutesPage> createState() => _AdminRoutesPageState();
}

class _AdminRoutesPageState extends State<AdminRoutesPage> {
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _filteredLines = [];
  Map<String, Map<String, dynamic>?> _linePaths = {};
  bool _isLoading = true;
  bool _isArabic = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, configured, unconfigured

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'إدارة المسارات',
      'routes': 'المسارات',
      'search': 'بحث عن خط...',
      'all': 'الكل',
      'configured': 'مُهيأ',
      'unconfigured': 'غير مُهيأ',
      'editRoute': 'تعديل المسار',
      'deleteRoute': 'حذف المسار',
      'noRoutes': 'لا توجد خطوط',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'confirmDelete': 'هل أنت متأكد من حذف مسار هذا الخط؟',
      'yes': 'نعم',
      'no': 'لا',
      'distance': 'المسافة',
      'waypoints': 'نقاط المسار',
      'noPath': 'لم يتم تحديد المسار',
      'hasPath': 'المسار مُهيأ',
      'km': 'كم',
      'meters': 'متر',
      'lastUpdated': 'آخر تحديث',
      'filterBy': 'تصفية حسب',
      'linesCount': 'عدد الخطوط',
      'configuredCount': 'مسارات مهيأة',
    },
    'en': {
      'title': 'Routes Management',
      'routes': 'Routes',
      'search': 'Search lines...',
      'all': 'All',
      'configured': 'Configured',
      'unconfigured': 'Unconfigured',
      'editRoute': 'Edit Route',
      'deleteRoute': 'Delete Route',
      'noRoutes': 'No lines found',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'confirmDelete': 'Are you sure you want to delete this line\'s route?',
      'yes': 'Yes',
      'no': 'No',
      'distance': 'Distance',
      'waypoints': 'Waypoints',
      'noPath': 'Route not configured',
      'hasPath': 'Route configured',
      'km': 'km',
      'meters': 'meters',
      'lastUpdated': 'Last updated',
      'filterBy': 'Filter by',
      'linesCount': 'Total Lines',
      'configuredCount': 'Configured Routes',
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
      // Load all lines
      final lines = await ApiService.getAllLines();
      setState(() {
        _lines = lines;
      });

      // Load paths for each line
      for (final line in lines) {
        final lineid = line['lineid']?.toString();
        if (lineid != null) {
          try {
            final pathResult = await ApiService.getLinePath(lineid);
            if (pathResult['success'] == true && pathResult['path'] != null) {
              _linePaths[lineid] = pathResult['path'];
            } else {
              _linePaths[lineid] = null;
            }
          } catch (e) {
            _linePaths[lineid] = null;
          }
        }
      }

      setState(() {
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
      final lineid = line['lineid']?.toString();

      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          nameAr.contains(_searchQuery) ||
          nameEn.contains(_searchQuery) ||
          lineName.contains(_searchQuery);

      // Status filter
      final hasPath = lineid != null && _linePaths[lineid] != null;
      final matchesStatus = _filterStatus == 'all' ||
          (_filterStatus == 'configured' && hasPath) ||
          (_filterStatus == 'unconfigured' && !hasPath);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  String _getLineName(Map<String, dynamic> line) {
    return _isArabic
        ? (line['name_ar'] ?? line['linename'] ?? line['name_en'] ?? '')
        : (line['name_en'] ?? line['linename'] ?? line['name_ar'] ?? '');
  }

  String _formatDistance(double? meters) {
    if (meters == null || meters == 0) return '-';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} ${t('km')}';
    }
    return '${meters.toStringAsFixed(0)} ${t('meters')}';
  }

  Future<void> _handleDeletePath(String lineid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        title: Text(
          t('confirmDelete'),
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t('no'),
              style: TextStyle(
                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
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

    final result = await ApiService.deleteLinePath(lineid);
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

  void _openRouteEditor(Map<String, dynamic> line) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LineRouteEditorPage(
          lineid: line['lineid'].toString(),
          lineName: _getLineName(line),
        ),
      ),
    ).then((_) => _loadData());
  }

  int get _configuredCount {
    return _lines.where((line) {
      final lineid = line['lineid']?.toString();
      return lineid != null && _linePaths[lineid] != null;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppTheme.appBarColor,
                ),
              )
            : Column(
                children: [
                  // Stats bar
                  _buildStatsBar(isDesktop: isDesktop),
                  // Search and filter bar
                  _buildSearchAndFilter(isDesktop: isDesktop, isTablet: isTablet),
                  // Lines list
                  Expanded(
                    child: _filteredLines.isEmpty
                        ? _buildEmptyState()
                        : isDesktop
                            ? _buildDesktopGrid()
                            : _buildMobileList(),
                  ),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541)
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
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadData,
        ),
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

  Widget _buildStatsBar({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.route_rounded,
            label: t('linesCount'),
            value: _lines.length.toString(),
            color: Colors.blue,
          ),
          Container(
            height: 40,
            width: 1,
            color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
          ),
          _buildStatItem(
            icon: Icons.check_circle_rounded,
            label: t('configuredCount'),
            value: '$_configuredCount / ${_lines.length}',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter({required bool isDesktop, required bool isTablet}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      child: isDesktop
          ? Row(
              children: [
                Expanded(flex: 2, child: _buildSearchField()),
                const SizedBox(width: 16),
                Expanded(child: _buildFilterChips()),
              ],
            )
          : Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildFilterChips(),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
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
        style: TextStyle(
          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: t('search'),
          hintStyle: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
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

  Widget _buildFilterChips() {
    return Row(
      children: [
        Text(
          '${t('filterBy')}: ',
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        _buildFilterChip('all', t('all')),
        const SizedBox(width: 8),
        _buildFilterChip('configured', t('configured')),
        const SizedBox(width: 8),
        _buildFilterChip('unconfigured', t('unconfigured')),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _applyFilter();
        });
      },
      backgroundColor: AppTheme.cardBackground,
      selectedColor: (AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor).withOpacity(0.2),
      checkmarkColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
      labelStyle: TextStyle(
        color: isSelected
            ? (AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor)
            : (AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? (AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor)
            : (AppTheme.isDarkMode ? Colors.white24 : AppTheme.borderColor),
      ),
    );
  }

  Widget _buildDesktopGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredLines.length,
      itemBuilder: (context, index) => _buildLineCard(_filteredLines[index]),
    );
  }

  Widget _buildMobileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLines.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildLineCard(_filteredLines[index]),
    );
  }

  Widget _buildLineCard(Map<String, dynamic> line) {
    final lineid = line['lineid']?.toString();
    final path = lineid != null ? _linePaths[lineid] : null;
    final hasPath = path != null;
    final lineName = _getLineName(line);
    final isActive = line['active'] == true;

    final waypoints = path?['waypoints'] as List?;
    final waypointCount = waypoints?.length ?? 0;
    final distance = path?['distance_meters'] as num?;

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
          color: hasPath
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openRouteEditor(line),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (hasPath ? Colors.green : Colors.orange).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasPath ? Icons.route_rounded : Icons.add_location_alt_rounded,
                        color: hasPath ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lineName,
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (hasPath ? Colors.green : Colors.orange).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  hasPath ? t('hasPath') : t('noPath'),
                                  style: TextStyle(
                                    color: hasPath ? Colors.green : Colors.orange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!isActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isArabic ? 'غير نشط' : 'Inactive',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Divider(
                  color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
                ),
                const SizedBox(height: 12),

                // Stats
                if (hasPath) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCardStat(
                        Icons.place_rounded,
                        t('waypoints'),
                        waypointCount.toString(),
                      ),
                      _buildCardStat(
                        Icons.straighten_rounded,
                        t('distance'),
                        _formatDistance(distance?.toDouble()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openRouteEditor(line),
                        icon: Icon(
                          hasPath ? Icons.edit_rounded : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(t('editRoute')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (hasPath) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => _handleDeletePath(lineid!),
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: Colors.redAccent,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.textSecondary,
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
              Icons.route_rounded,
              size: 80,
              color: AppTheme.isDarkMode
                  ? Colors.white24
                  : AppTheme.textSecondary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('noRoutes'),
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

