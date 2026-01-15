import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/driver_bottom_nav_bar.dart';
import 'driver_home.dart';

class DriverQueuePage extends StatefulWidget {
  final bool embedded;
  final bool? isArabicOverride;
  final bool? isDarkModeOverride;

  const DriverQueuePage({
    super.key,
    this.embedded = false,
    this.isArabicOverride,
    this.isDarkModeOverride,
  });

  @override
  State<DriverQueuePage> createState() => DriverQueuePageState();
}

class DriverQueuePageState extends State<DriverQueuePage> {
  late bool _isArabic;
  late bool _isDarkMode;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  Map<String, dynamic>? _queueData;
  String _selectedDirection = 'going'; // 'going' or 'returning'

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'دور السائقين',
      'line': 'الخط الحالي',
      'yourTurn': 'دورك',
      'ahead': 'قبلك',
      'behind': 'بعدك',
      'joinQueue': 'حجز دور',
      'leaveQueue': 'مغادرة الدور',
      'noDrivers': 'القائمة فارغة حالياً',
      'notInQueue': 'أنت لست في قائمة الانتظار',
      'refresh': 'تحديث',
      'statusWaiting': 'في الانتظار',
      'retry': 'إعادة المحاولة',
      'position': 'الترتيب',
      'driverName': 'اسم السائق',
      'phoneNumber': 'رقم الهاتف',
      'you': 'أنت',
      'direction': 'الاتجاه',
      'going': 'ذهاب',
      'returning': 'عودة',
      'selectDirection': 'اختر الاتجاه',
    },
    'en': {
      'title': 'Driver Queue',
      'line': 'Current Line',
      'yourTurn': 'Your Turn',
      'ahead': 'Ahead',
      'behind': 'Behind',
      'joinQueue': 'Join Queue',
      'leaveQueue': 'Leave Queue',
      'noDrivers': 'Queue is currently empty',
      'notInQueue': 'You are not in the queue',
      'refresh': 'Refresh',
      'statusWaiting': 'Waiting',
      'retry': 'Retry',
      'position': 'Pos',
      'driverName': 'Driver Name',
      'phoneNumber': 'Phone Number',
      'you': 'You',
      'direction': 'Direction',
      'going': 'Going',
      'returning': 'Returning',
      'selectDirection': 'Select Direction',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.isArabicOverride ?? true;
    _isDarkMode = widget.isDarkModeOverride ?? AppTheme.isDarkMode;
    if (widget.isArabicOverride == null) {
      _loadPreferences();
    }
    if (widget.isDarkModeOverride == null) {
      _loadThemePreference();
    }
    _loadQueue();
  }

  Future<void> _loadThemePreference() async {
    await AppTheme.init();
    if (mounted) {
      setState(() {
        _isDarkMode = AppTheme.isDarkMode;
      });
    }
  }

  @override
  void didUpdateWidget(covariant DriverQueuePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isArabicOverride != null &&
        widget.isArabicOverride != oldWidget.isArabicOverride &&
        widget.isArabicOverride != _isArabic) {
      setState(() {
        _isArabic = widget.isArabicOverride!;
      });
    }
    if (widget.isDarkModeOverride != null &&
        widget.isDarkModeOverride != oldWidget.isDarkModeOverride &&
        widget.isDarkModeOverride != _isDarkMode) {
      setState(() {
        _isDarkMode = widget.isDarkModeOverride!;
      });
    }
  }

  Future<void> _loadPreferences() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
  }

  void refresh() {
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Get current direction from queue data if available, otherwise use selected direction
    final direction = _queueData?['direction']?.toString() ?? _selectedDirection;
    final result = await ApiService.fetchDriverQueue(direction: direction);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _queueData = result;
        // Update selected direction from response if available
        if (result['direction'] != null) {
          _selectedDirection = result['direction'].toString();
        }
      } else {
        _error = result['message']?.toString() ?? 'Failed to load queue';
      }
    });
  }

  Future<void> _joinQueue() async {
    final currentLine = _queueData?['line'];
    setState(() {
      _isMutating = true;
      _error = null;
    });

    final result = await ApiService.joinDriverQueue(direction: _selectedDirection);
    if (!mounted) return;

    setState(() {
      _isMutating = false;
      if (result['success'] == true) {
        if (result['line'] == null && currentLine != null) {
          result['line'] = currentLine;
        }
        _queueData = result;
        // Update selected direction from response if available
        if (result['direction'] != null) {
          _selectedDirection = result['direction'].toString();
        }
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  Future<void> _leaveQueue() async {
    final currentLine = _queueData?['line'];
    setState(() {
      _isMutating = true;
      _error = null;
    });

    final result = await ApiService.leaveDriverQueue();
    if (!mounted) return;

    setState(() {
      _isMutating = false;
      if (result['success'] == true) {
        if (result['line'] == null && currentLine != null) {
          result['line'] = currentLine;
        }
        _queueData = result;
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  bool get _isInQueue => _queueData?['currentEntry'] != null;

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Web-specific responsive breakpoints
    final isWeb = kIsWeb;
    final isDesktop = isWeb && screenWidth >= 1200;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
    
    final body = _buildBody(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen, isWeb: isWeb);

    if (widget.embedded) {
      return Directionality(
        textDirection: textDirection,
        child: body,
      );
    }

    final backgroundColor = _isDarkMode
        ? const Color(0xFF0A0E21)
        : const Color.fromARGB(255, 224, 228, 231);

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDarkMode
                    ? [
                        const Color(0xFF1C2541),
                        const Color(0xFF2C3E50),
                        const Color(0xFF1C2541),
                      ]
                    : [
                        const Color(0xFF2C5F8D),
                        const Color(0xFF1E3A5F),
                        const Color(0xFF2C5F8D),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              leading: Container(
                margin: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, size: isSmallScreen ? 18.0 : 20.0),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DriverHomePage(),
                        ),
                      );
                    }
                  },
                ),
              ),
              title: Text(
                t('title'),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              actions: [
                Container(
                  margin: EdgeInsets.only(right: isSmallScreen ? 4.0 : 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh_rounded, size: isSmallScreen ? 20.0 : (isMediumScreen ? 21.0 : 22.0)),
                    onPressed: _loadQueue,
                    tooltip: t('refresh'),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: body,
        bottomNavigationBar: DriverBottomNavBar(
          currentIndex: 1, // Check-in is index 1
          isDarkMode: _isDarkMode,
          isArabic: _isArabic,
          onTap: (index) {
            DriverBottomNavBar.navigateToPage(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildBody({bool isSmallScreen = false, bool isMediumScreen = false, bool isWeb = false}) {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final double basePadding = isWeb 
        ? (isSmallScreen ? 24.0 : 32.0)
        : (isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0));
    
    // Max width for web to prevent content from stretching too wide
    final double maxContentWidth = isWeb ? 1400.0 : double.infinity;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline, 
                size: isSmallScreen ? 40.0 : (isMediumScreen ? 44.0 : 48.0), 
                color: Colors.redAccent
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textPrimaryColor, 
                  fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0)
                ),
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              FilledButton.tonal(
                onPressed: _loadQueue,
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }

    final content = _buildQueueContent(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen);

    if (widget.embedded) {
      return content;
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadQueue,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(basePadding),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildQueueContent({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final queue = (_queueData?['queue'] as List?) ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          _buildLineCard(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
          SizedBox(height: isSmallScreen ? 14.0 : (isMediumScreen ? 16.0 : 20.0)),
        ],
        _buildStatsRow(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        SizedBox(height: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
        if (!_isInQueue) _buildDirectionSelector(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        if (!_isInQueue) SizedBox(height: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
        _buildActionButton(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
        SizedBox(height: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 24.0)),
        if (!_isInQueue)
          Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 8.0 : 12.0),
            child: Center(
              child: Text(
                t('notInQueue'),
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.7)
                      : const Color(0xFF546E7A),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        
        _buildQueueList(queue, isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
      ],
    );
  }

  Widget _buildLineCard({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final line = _queueData?['line'] as Map<String, dynamic>? ?? {};
    final lineName = _isArabic
        ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '---')
        : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? '---');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode 
              ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
              : [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                ),
                child: Icon(Icons.alt_route_rounded, color: Colors.white, size: isSmallScreen ? 18.0 : 20.0),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Text(
                t('line'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: isSmallScreen ? 12.0 : (isMediumScreen ? 13.0 : 14.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          Row(
            children: [
              Expanded(
                child: Text(
                  lineName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 21.0 : 24.0),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_queueData?['direction'] != null || _isInQueue)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8.0 : 10.0,
                    vertical: isSmallScreen ? 4.0 : 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 10.0),
                  ),
                  child: Text(
                    (_queueData?['direction']?.toString() ?? _selectedDirection) == 'going'
                        ? t('going')
                        : t('returning'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final ahead = (_queueData?['aheadCount'] as num?)?.toInt() ?? 0;
    final behind = (_queueData?['behindCount'] as num?)?.toInt() ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatBox(
            label: t('ahead'),
            value: '$ahead',
            icon: Icons.keyboard_arrow_up_rounded,
            color: Colors.orange,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
        ),
        SizedBox(width: isSmallScreen ? 12.0 : 16.0),
        Expanded(
          child: _buildStatBox(
            label: t('behind'),
            value: '$behind',
            icon: Icons.keyboard_arrow_down_rounded,
            color: Colors.green,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isSmallScreen = false,
    bool isMediumScreen = false,
  }) {
    final cardColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _isDarkMode ? Colors.white70 : const Color(0xFF546E7A),
                  fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0)),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: isSmallScreen ? 22.0 : (isMediumScreen ? 25.0 : 28.0),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({bool isSmallScreen = false, bool isMediumScreen = false}) {
    return SizedBox(
      width: double.infinity,
      height: isSmallScreen ? 48.0 : (isMediumScreen ? 52.0 : 56.0),
      child: FilledButton.icon(
        onPressed: _isMutating
            ? null
            : _isInQueue
                ? _leaveQueue
                : _joinQueue,
        icon: _isMutating 
            ? SizedBox(
                width: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0), 
                height: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0), 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              )
            : Icon(
                _isInQueue ? Icons.exit_to_app_rounded : Icons.add_circle_outline_rounded,
                size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
              ),
        label: Text(
          _isMutating 
              ? '' 
              : (_isInQueue ? t('leaveQueue') : t('joinQueue')),
          style: TextStyle(
            fontSize: isSmallScreen ? 15.0 : (isMediumScreen ? 16.0 : 18.0), 
            fontWeight: FontWeight.bold
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _isInQueue ? Colors.redAccent : const Color(0xFFF57C00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          ),
          elevation: 4,
          shadowColor: (_isInQueue ? Colors.redAccent : const Color(0xFFF57C00)).withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildQueueList(List<dynamic> queue, {bool isSmallScreen = false, bool isMediumScreen = false}) {
    if (queue.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmallScreen ? 20.0 : (isMediumScreen ? 26.0 : 32.0)),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: isSmallScreen ? 40.0 : (isMediumScreen ? 44.0 : 48.0),
              color: _isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
            SizedBox(height: isSmallScreen ? 12.0 : 16.0),
            Text(
              t('noDrivers'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : const Color(0xFF546E7A),
                fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
              ),
            ),
          ],
        ),
      );
    }

    final currentEntry = _queueData?['currentEntry'] as Map<String, dynamic>?;
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final cardBgColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final entry = queue[index] as Map<String, dynamic>;
        final driver = entry['driver'] as Map<String, dynamic>? ?? {};
        final user = driver['user'] as Map<String, dynamic>? ?? {};
        final isCurrent = currentEntry != null && currentEntry['queueid'] == entry['queueid'];
        
        return Container(
          margin: EdgeInsets.only(bottom: isSmallScreen ? 10.0 : 12.0),
          decoration: BoxDecoration(
            color: isCurrent 
                ? (_isDarkMode ? const Color(0xFF1B5E20).withOpacity(0.3) : Colors.green.shade50)
                : cardBgColor,
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
            border: Border.all(
              color: isCurrent
                  ? Colors.green
                  : (_isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
              width: isCurrent ? 2 : 1,
            ),
            boxShadow: [
              if (!isCurrent)
                BoxShadow(
                  color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0, 
              vertical: isSmallScreen ? 6.0 : 8.0
            ),
            leading: CircleAvatar(
              radius: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
              backgroundColor: isCurrent ? Colors.green : Colors.orange.withOpacity(0.2),
              child: Text(
                '${entry['position']}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 14.0 : 16.0,
                ),
              ),
            ),
            title: Text(
              isCurrent ? '${user['fullname']} (${t('you')})' : (user['fullname']?.toString() ?? '---'),
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
              ),
            ),
            subtitle: Text(
              user['phone']?.toString() ?? '',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : const Color(0xFF546E7A),
                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
              ),
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8.0 : 10.0, 
                vertical: isSmallScreen ? 4.0 : 6.0
              ),
              decoration: BoxDecoration(
                color: (isCurrent ? Colors.green : const Color(0xFF546E7A)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
              ),
              child: Text(
                t('statusWaiting'),
                style: TextStyle(
                  color: isCurrent ? Colors.green : const Color(0xFF546E7A),
                  fontSize: isSmallScreen ? 10.0 : (isMediumScreen ? 11.0 : 12.0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectionSelector({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final cardColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    final selectedColor = const Color(0xFFF57C00);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('selectDirection'),
            style: TextStyle(
              color: textColor,
              fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDirection = 'going';
                    });
                    _loadQueue();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 10.0 : 12.0,
                      horizontal: isSmallScreen ? 8.0 : 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedDirection == 'going'
                          ? selectedColor.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                      border: Border.all(
                        color: _selectedDirection == 'going'
                            ? selectedColor
                            : borderColor,
                        width: _selectedDirection == 'going' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          color: _selectedDirection == 'going'
                              ? selectedColor
                              : textColor.withOpacity(0.7),
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          t('going'),
                          style: TextStyle(
                            color: _selectedDirection == 'going'
                                ? selectedColor
                                : textColor,
                            fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
                            fontWeight: _selectedDirection == 'going'
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 10.0 : 12.0),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDirection = 'returning';
                    });
                    _loadQueue();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 10.0 : 12.0,
                      horizontal: isSmallScreen ? 8.0 : 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedDirection == 'returning'
                          ? selectedColor.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                      border: Border.all(
                        color: _selectedDirection == 'returning'
                            ? selectedColor
                            : borderColor,
                        width: _selectedDirection == 'returning' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: _selectedDirection == 'returning'
                              ? selectedColor
                              : textColor.withOpacity(0.7),
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          t('returning'),
                          style: TextStyle(
                            color: _selectedDirection == 'returning'
                                ? selectedColor
                                : textColor,
                            fontSize: isSmallScreen ? 13.0 : (isMediumScreen ? 14.0 : 15.0),
                            fontWeight: _selectedDirection == 'returning'
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
