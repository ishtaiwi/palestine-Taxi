import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class DriverQueuePage extends StatefulWidget {
  final bool embedded;
  final bool? isArabicOverride;

  const DriverQueuePage({
    super.key,
    this.embedded = false,
    this.isArabicOverride,
  });

  @override
  State<DriverQueuePage> createState() => _DriverQueuePageState();
}

class _DriverQueuePageState extends State<DriverQueuePage> {
  late bool _isArabic;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  Map<String, dynamic>? _queueData;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'دور السائقين',
      'line': 'الخط',
      'yourTurn': 'دورك الحالي',
      'ahead': 'قبلك',
      'behind': 'بعدك',
      'joinQueue': 'حجز دور',
      'leaveQueue': 'إلغاء الدور',
      'noDrivers': 'لا يوجد سائقون في الدور حالياً',
      'notInQueue': 'أنت خارج الدور حالياً',
      'refresh': 'تحديث',
      'statusWaiting': 'ينتظر',
      'retry': 'إعادة المحاولة',
    },
    'en': {
      'title': 'Driver Queue',
      'line': 'Line',
      'yourTurn': 'Your turn',
      'ahead': 'Ahead',
      'behind': 'Behind',
      'joinQueue': 'Join Queue',
      'leaveQueue': 'Leave Queue',
      'noDrivers': 'No drivers in the queue yet',
      'notInQueue': 'You are currently out of the queue',
      'refresh': 'Refresh',
      'statusWaiting': 'Waiting',
      'retry': 'Retry',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    _isArabic = widget.isArabicOverride ?? true;
    if (widget.isArabicOverride == null) {
      _loadPreferences();
    }
    _loadQueue();
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
  }

  Future<void> _loadPreferences() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
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
    setState(() {
      _isMutating = true;
      _error = null;
    });

    final result = await ApiService.joinDriverQueue();
    if (!mounted) return;

    setState(() {
      _isMutating = false;
      if (result['success'] == true) {
        _queueData = result;
      } else {
        _error = result['message']?.toString();
      }
    });
  }

  Future<void> _leaveQueue() async {
    setState(() {
      _isMutating = true;
      _error = null;
    });

    final result = await ApiService.leaveDriverQueue();
    if (!mounted) return;

    setState(() {
      _isMutating = false;
      if (result['success'] == true) {
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
      return body;
    }

    return Directionality(
      textDirection: textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF060A1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A5F), // خلفية فاتحة أكثر
          foregroundColor: Colors.white,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isArabic ? Icons.language : Icons.translate,
                color: Colors.white,
              ),
              onPressed: () async {
                final next = !_isArabic;
                await ApiService.saveLanguagePreference(next);
                if (mounted) {
                  setState(() => _isArabic = next);
                }
              },
              tooltip: _isArabic ? 'English' : 'العربية',
            ),
          ],
        ),
        body: body,
      ),
    );
  }

  Widget _buildBody() {
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
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16), // نص أبيض على خلفية غامقة
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
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }

  Widget _buildQueueContent() {
    final queue = (_queueData?['queue'] as List?) ?? [];
    final current = _queueData?['currentEntry'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) const SizedBox(height: 8),
        _buildLineCard(),
        const SizedBox(height: 16),
        _buildStatsRow(),
        const SizedBox(height: 16),
        _buildActionButton(),
        const SizedBox(height: 16),
        if (!_isInQueue)
          Text(
            t('notInQueue'),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                t('noDrivers'),
                style: const TextStyle(
                  color: Colors.white, // نص أبيض على خلفية غامقة
                  fontSize: 16,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final entry = queue[index] as Map<String, dynamic>;
              final driver = entry['driver'] as Map<String, dynamic>? ?? {};
              final user = driver['user'] as Map<String, dynamic>? ?? {};
              final isCurrent = current != null && current['queueid'] == entry['queueid'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF1B5E20).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent ? const Color(0xFF1B5E20) : Colors.white24,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: Text(
                        '${entry['position']}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['fullname']?.toString() ?? '---',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user['phone']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white, // نص أبيض على خلفية غامقة
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t('statusWaiting'),
                      style: const TextStyle(color: Colors.white), // نص أبيض على خلفية غامقة
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLineCard() {
    final line = _queueData?['line'] as Map<String, dynamic>? ?? {};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('line'),
            style: const TextStyle(
              color: Colors.white, // نص أبيض على خلفية غامقة
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isArabic
                ? (line['name_ar']?.toString() ?? line['linename']?.toString() ?? line['name_en']?.toString() ?? '---')
                : (line['name_en']?.toString() ?? line['linename']?.toString() ?? line['name_ar']?.toString() ?? '---'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatBox(
            label: t('behind'),
            value: '$behind',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isMutating
            ? null
            : _isInQueue
                ? _leaveQueue
                : _joinQueue,
        style: FilledButton.styleFrom(
          backgroundColor: _isInQueue ? Colors.redAccent : const Color(0xFFF57C00),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: _isMutating
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(_isInQueue ? t('leaveQueue') : t('joinQueue')),
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white, // نص أبيض على خلفية غامقة
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

