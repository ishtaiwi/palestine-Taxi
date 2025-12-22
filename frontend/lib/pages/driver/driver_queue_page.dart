import 'package:flutter/material.dart';

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

    final result = await ApiService.fetchDriverQueue();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _queueData = result;
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

    final result = await ApiService.joinDriverQueue();
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
    
    final body = _buildBody();

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
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 22),
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

  Widget _buildBody() {
    final textPrimaryColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: textPrimaryColor, fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadQueue,
                child: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }

    final content = _buildQueueContent();

    if (widget.embedded) {
      return content;
    }

    return RefreshIndicator(
      color: Colors.orange,
      onRefresh: _loadQueue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: content,
      ),
    );
  }

  Widget _buildQueueContent() {
    final queue = (_queueData?['queue'] as List?) ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          _buildLineCard(),
          const SizedBox(height: 20),
        ],
        _buildStatsRow(),
        const SizedBox(height: 24),
        _buildActionButton(),
        const SizedBox(height: 24),
        if (!_isInQueue)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
        
        _buildQueueList(queue),
      ],
    );
  }

  Widget _buildLineCard() {
    final line = _queueData?['line'] as Map<String, dynamic>? ?? {};
    final lineName = _isArabic
        ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '---')
        : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? '---');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDarkMode 
              ? [const Color(0xFF1565C0), const Color(0xFF0D47A1)]
              : [const Color(0xFF1E88E5), const Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                t('line'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lineName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
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
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatBox(
            label: t('behind'),
            value: '$behind',
            icon: Icons.keyboard_arrow_down_rounded,
            color: Colors.green,
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
  }) {
    final cardColor = _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor = _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200;
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1E3A5F);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _isMutating
            ? null
            : _isInQueue
                ? _leaveQueue
                : _joinQueue,
        icon: _isMutating 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(_isInQueue ? Icons.exit_to_app_rounded : Icons.add_circle_outline_rounded),
        label: Text(
          _isMutating 
              ? '' 
              : (_isInQueue ? t('leaveQueue') : t('joinQueue')),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _isInQueue ? Colors.redAccent : const Color(0xFFF57C00),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: (_isInQueue ? Colors.redAccent : const Color(0xFFF57C00)).withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildQueueList(List<dynamic> queue) {
    if (queue.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: _isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              t('noDrivers'),
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : const Color(0xFF546E7A),
                fontSize: 16,
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrent 
                ? (_isDarkMode ? const Color(0xFF1B5E20).withOpacity(0.3) : Colors.green.shade50)
                : cardBgColor,
            borderRadius: BorderRadius.circular(16),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: isCurrent ? Colors.green : Colors.orange.withOpacity(0.2),
              child: Text(
                '${entry['position']}',
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              isCurrent ? '${user['fullname']} (${t('you')})' : (user['fullname']?.toString() ?? '---'),
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              user['phone']?.toString() ?? '',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : const Color(0xFF546E7A),
                fontSize: 13,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isCurrent ? Colors.green : const Color(0xFF546E7A)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                t('statusWaiting'),
                style: TextStyle(
                  color: isCurrent ? Colors.green : const Color(0xFF546E7A),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
