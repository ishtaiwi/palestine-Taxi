import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';
import '../../widgets/notification_tile.dart';

class PassengerNotificationsPage extends StatefulWidget {
  const PassengerNotificationsPage({super.key});

  @override
  State<PassengerNotificationsPage> createState() =>
      _PassengerNotificationsPageState();
}

class _PassengerNotificationsPageState
    extends State<PassengerNotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isArabic = true;
  int _unreadCount = 0;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'الإشعارات',
      'noNotifications': 'لا توجد إشعارات حالياً',
      'noNotificationsSub': 'سنخبرك عند وجود تحديثات جديدة',
      'markAllRead': 'تحديد الكل كمقروء',
      'delete': 'حذف',
      'markAsRead': 'تحديد كمقروء',
      'loading': 'جاري التحميل...',
    },
    'en': {
      'title': 'Notifications',
      'noNotifications': 'No notifications yet',
      'noNotificationsSub': 'We\'ll let you know when there are new updates',
      'markAllRead': 'Mark all as read',
      'delete': 'Delete',
      'markAsRead': 'Mark as read',
      'loading': 'Loading...',
    },
  };

  String t(String key) {
    return _texts[_isArabic ? 'ar' : 'en']![key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _loadNotifications();
    _loadUnreadCount();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    if (mounted) {
      setState(() {
        _isArabic = isArabic;
      });
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _currentPage = 1;
          _hasMore = true;
          _notifications = [];
        });
      }
    }

    if (!_hasMore && !refresh) return;

    if (mounted) {
      setState(() {
        if (_currentPage == 1) {
          _isLoading = true;
        } else {
          _isLoadingMore = true;
        }
      });
    }

    try {
      final result = await ApiService.getNotifications(
        page: _currentPage,
        limit: 20,
      );

      if (mounted) {
        if (result['success'] == true) {
          final List<dynamic> notificationsJson =
              result['notifications'] as List<dynamic>;
          final List<NotificationModel> newNotifications = notificationsJson
              .map((json) =>
                  NotificationModel.fromJson(json as Map<String, dynamic>))
              .toList();

          setState(() {
            if (refresh) {
              _notifications = newNotifications;
            } else {
              _notifications.addAll(newNotifications);
            }

            final pagination = result['pagination'] as Map<String, dynamic>?;
            _hasMore = pagination?['hasMore'] as bool? ?? false;
            _currentPage++;
            _isLoading = false;
            _isLoadingMore = false;
          });

          await _loadUnreadCount();
        } else {
          setState(() {
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await ApiService.getUnreadCount();
      if (mounted && result['success'] == true) {
        setState(() {
          _unreadCount = result['count'] as int? ?? 0;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await ApiService.markNotificationAsRead(notificationId);
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
              (n) => n.notificationid == notificationId);
          if (index != -1) {
            _notifications[index] = NotificationModel(
              notificationid: _notifications[index].notificationid,
              userid: _notifications[index].userid,
              type: _notifications[index].type,
              titleAr: _notifications[index].titleAr,
              titleEn: _notifications[index].titleEn,
              bodyAr: _notifications[index].bodyAr,
              bodyEn: _notifications[index].bodyEn,
              data: _notifications[index].data,
              read: true,
              readAt: DateTime.now(),
              createdAt: _notifications[index].createdAt,
              fcmSent: _notifications[index].fcmSent,
              fcmSentAt: _notifications[index].fcmSentAt,
            );
          }
        });
        await _loadUnreadCount();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      if (mounted) {
        setState(() {
          _notifications = _notifications.map((n) {
            return NotificationModel(
              notificationid: n.notificationid,
              userid: n.userid,
              type: n.type,
              titleAr: n.titleAr,
              titleEn: n.titleEn,
              bodyAr: n.bodyAr,
              bodyEn: n.bodyEn,
              data: n.data,
              read: true,
              readAt: DateTime.now(),
              createdAt: n.createdAt,
              fcmSent: n.fcmSent,
              fcmSentAt: n.fcmSentAt,
            );
          }).toList();
        });
        await _loadUnreadCount();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await ApiService.deleteNotification(notificationId);
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.notificationid == notificationId);
        });
        await _loadUnreadCount();
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (!notification.read) {
      _markAsRead(notification.notificationid);
    }

    // Navigate based on notification type/data
    final data = notification.data;
    if (data != null) {
      if (data['action'] == 'view_reservation' && data['bookingid'] != null) {
        // Navigate to reservation details
        // Navigator.push(...);
      } else if (data['action'] == 'view_trip' && data['tripid'] != null) {
        // Navigate to trip details
        // Navigator.push(...);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(t('title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(t('markAllRead')),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        color: Theme.of(context).primaryColor,
        child: _isLoading && _notifications.isEmpty
            ? Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 10, bottom: 30),
                    itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? Theme.of(context).dividerColor.withOpacity(0.1)
                            : Theme.of(context).dividerColor.withOpacity(0.05),
                        indent: 80,
                      );
                    },
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      return NotificationTile(
                        notification: _notifications[index],
                        isArabic: _isArabic,
                        onTap: () => _handleNotificationTap(_notifications[index]),
                        onDelete: () => _deleteNotification(
                            _notifications[index].notificationid),
                        onMarkAsRead: () =>
                            _markAsRead(_notifications[index].notificationid),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t('noNotifications'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            t('noNotificationsSub'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
