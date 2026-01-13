import 'package:flutter/material.dart';
import '../models/notification_model.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isArabic;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMarkAsRead;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isArabic,
    required this.onTap,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (isArabic) {
      if (difference.inDays > 365) {
        return 'منذ ${difference.inDays ~/ 365} سنة';
      } else if (difference.inDays > 30) {
        return 'منذ ${difference.inDays ~/ 30} شهر';
      } else if (difference.inDays > 0) {
        return 'منذ ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'منذ ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'منذ ${difference.inMinutes} دقيقة';
      } else {
        return 'الآن';
      }
    } else {
      if (difference.inDays > 365) {
        return '${difference.inDays ~/ 365}y ago';
      } else if (difference.inDays > 30) {
        return '${difference.inDays ~/ 30}mo ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    }
  }

  Color _getIconBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // You can customize colors based on notification type here
    if (notification.type.contains('payment')) {
      return isDark 
          ? Colors.green.withOpacity(0.2)
          : Colors.green.shade100;
    } else if (notification.type.contains('trip')) {
      return isDark
          ? Colors.blue.withOpacity(0.2)
          : Colors.blue.shade100;
    } else if (notification.type.contains('alert')) {
      return isDark
          ? Colors.red.withOpacity(0.2)
          : Colors.red.shade100;
    }
    return Theme.of(context).primaryColor.withOpacity(isDark ? 0.2 : 0.1);
  }

  Color _getIconColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (notification.type.contains('payment')) {
      return isDark
          ? Colors.green.shade300
          : Colors.green.shade700;
    } else if (notification.type.contains('trip')) {
      return isDark
          ? Colors.blue.shade300
          : Colors.blue.shade700;
    } else if (notification.type.contains('alert')) {
      return isDark
          ? Colors.red.shade300
          : Colors.red.shade700;
    }
    return Theme.of(context).primaryColor;
  }

  IconData _getIcon() {
    if (notification.type.contains('payment')) {
      return Icons.payment;
    } else if (notification.type.contains('trip')) {
      return Icons.directions_car;
    } else if (notification.type.contains('cancel')) {
      return Icons.cancel_outlined;
    } else if (notification.type.contains('message')) {
      return Icons.message_outlined;
    }
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    
    // Use proper surface colors that adapt to theme
    // For dark mode: use scaffold background (dark) with slight variations
    // For light mode: use surface color (light)
    final tileBackgroundColor = notification.read
        ? (isDark 
            ? scaffoldColor // Use scaffold background directly for dark mode
            : colorScheme.surface)
        : (isDark
            ? colorScheme.primary.withOpacity(0.2) // Slightly lighter for unread in dark mode
            : colorScheme.primary.withOpacity(0.1));

    return Dismissible(
      key: Key(notification.notificationid),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: isDark ? Colors.red.shade700 : Colors.red.shade400,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Material(
        color: tileBackgroundColor,
        child: InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withOpacity(0.1),
          highlightColor: colorScheme.primary.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(context),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(),
                    color: _getIconColor(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.getTitle(isArabic),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: notification.read
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: notification.read
                                        ? colorScheme.onSurface.withOpacity(0.7)
                                        : colorScheme.onSurface,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(notification.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.getBody(isArabic),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: notification.read
                                  ? colorScheme.onSurface.withOpacity(0.6)
                                  : colorScheme.onSurface.withOpacity(0.8),
                              height: 1.4,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Unread dot (if unread)
                if (!notification.read) ...[
                  const SizedBox(width: 12),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
