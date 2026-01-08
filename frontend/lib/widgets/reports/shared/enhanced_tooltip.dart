import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A rich tooltip widget for charts showing detailed information
class EnhancedTooltip extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? percentageChange;
  final List<TooltipDataItem>? dataItems;
  final Color? accentColor;

  const EnhancedTooltip({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.percentageChange,
    this.dataItems,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode ? const Color(0xFF1A1F35) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor?.withOpacity(0.3) ?? AppTheme.getCardBorder(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and trend
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accentColor != null) ...[
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (percentageChange != null) ...[
                const SizedBox(width: 8),
                _buildTrendBadge(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Main value
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Subtitle
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
          // Additional data items
          if (dataItems != null && dataItems!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.getCardBorder(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children:
                    dataItems!.map((item) => _buildDataItem(item)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final isPositive = percentageChange! >= 0;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${percentageChange!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(TooltipDataItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Data item for tooltip breakdown
class TooltipDataItem {
  final String label;
  final String value;
  final Color color;

  const TooltipDataItem({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Helper class to build tooltips for fl_chart
class ChartTooltipHelper {
  /// Format a number with compact notation (e.g., 1.2K, 3.5M)
  static String formatCompact(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }

  /// Format currency with compact notation
  static String formatCurrency(num value, {String symbol = '\$'}) {
    return '$symbol${formatCompact(value)}';
  }

  /// Calculate percentage change between two values
  static double? calculatePercentageChange(num? current, num? previous) {
    if (previous == null || previous == 0 || current == null) return null;
    return ((current - previous) / previous) * 100;
  }

  /// Get a human-readable date format
  static String formatDate(String isoDate, {bool shortMonth = true}) {
    try {
      final date = DateTime.parse(isoDate);
      final months = shortMonth
          ? [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ]
          : [
              'January',
              'February',
              'March',
              'April',
              'May',
              'June',
              'July',
              'August',
              'September',
              'October',
              'November',
              'December'
            ];
      return '${months[date.month - 1]} ${date.day}';
    } catch (e) {
      return isoDate;
    }
  }
}
