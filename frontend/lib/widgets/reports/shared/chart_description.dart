import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A widget for displaying auto-generated chart insights and descriptions
class ChartDescription extends StatelessWidget {
  final List<ChartInsight> insights;
  final String? summary;
  final bool isCompact;

  const ChartDescription({
    super.key,
    this.insights = const [],
    this.summary,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty && summary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode
            ? Colors.blue.withOpacity(0.08)
            : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary text
          if (summary != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: isCompact ? 16 : 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    summary!,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: isCompact ? 12 : 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (insights.isNotEmpty)
              const SizedBox(height: 8),
          ],
          // Individual insights
          if (insights.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: insights
                  .map((insight) => _buildInsightChip(insight))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightChip(ChartInsight insight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: insight.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: insight.color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            insight.icon,
            size: 14,
            color: insight.color,
          ),
          const SizedBox(width: 6),
          Text(
            insight.label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            insight.value,
            style: TextStyle(
              color: insight.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual insight data
class ChartInsight {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const ChartInsight({
    required this.label,
    required this.value,
    this.color = Colors.blue,
    this.icon = Icons.show_chart,
  });
}

/// Widget for displaying period comparison statistics
class PeriodComparison extends StatelessWidget {
  final String currentLabel;
  final String currentValue;
  final String previousLabel;
  final String previousValue;
  final double? percentageChange;
  final bool isArabic;

  const PeriodComparison({
    super.key,
    required this.currentLabel,
    required this.currentValue,
    required this.previousLabel,
    required this.previousValue,
    this.percentageChange,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = (percentageChange ?? 0) >= 0;
    final trendColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode
            ? Colors.white.withOpacity(0.03)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getCardBorder(0.1),
        ),
      ),
      child: Row(
        children: [
          // Current period
          Expanded(
            child: _buildPeriodColumn(
              label: currentLabel,
              value: currentValue,
              isCurrent: true,
            ),
          ),
          // Divider with trend
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (percentageChange != null) ...[
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: trendColor,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isPositive ? '+' : ''}${percentageChange!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: trendColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ] else
                  Icon(
                    Icons.compare_arrows,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
              ],
            ),
          ),
          // Previous period
          Expanded(
            child: _buildPeriodColumn(
              label: previousLabel,
              value: previousValue,
              isCurrent: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodColumn({
    required String label,
    required String value,
    required bool isCurrent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: isCurrent ? 14 : 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Helper class for generating chart insights
class InsightGenerator {
  /// Generate insights from time series data
  static List<ChartInsight> fromTimeSeries({
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required String dateKey,
    bool isArabic = false,
    String Function(num)? formatValue,
  }) {
    if (data.isEmpty) return [];

    final insights = <ChartInsight>[];
    final values =
        data.map((d) => (d[valueKey] as num?)?.toDouble() ?? 0).toList();

    if (values.isEmpty) return [];

    final total = values.reduce((a, b) => a + b);
    final average = total / values.length;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxIndex = values.indexOf(maxValue);
    final minIndex = values.indexOf(minValue);

    final format = formatValue ?? (v) => v.toStringAsFixed(0);

    // Average insight
    insights.add(ChartInsight(
      label: isArabic ? 'المتوسط' : 'Average',
      value: format(average),
      color: Colors.blue,
      icon: Icons.analytics,
    ));

    // Best day insight
    if (maxIndex >= 0 && maxIndex < data.length) {
      final bestDate = data[maxIndex][dateKey] as String? ?? '';
      insights.add(ChartInsight(
        label: isArabic ? 'أعلى قيمة' : 'Peak',
        value: '${format(maxValue)} (${_formatShortDate(bestDate)})',
        color: Colors.green,
        icon: Icons.arrow_upward,
      ));
    }

    // Worst day insight
    if (minIndex >= 0 && minIndex < data.length) {
      final worstDate = data[minIndex][dateKey] as String? ?? '';
      insights.add(ChartInsight(
        label: isArabic ? 'أدنى قيمة' : 'Low',
        value: '${format(minValue)} (${_formatShortDate(worstDate)})',
        color: Colors.orange,
        icon: Icons.arrow_downward,
      ));
    }

    // Trend insight
    if (values.length >= 2) {
      final firstHalf = values.sublist(0, values.length ~/ 2);
      final secondHalf = values.sublist(values.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      final trendPercent = ((secondAvg - firstAvg) / firstAvg * 100);

      if (trendPercent.abs() > 5) {
        insights.add(ChartInsight(
          label: isArabic ? 'الاتجاه' : 'Trend',
          value:
              '${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}%',
          color: trendPercent >= 0 ? Colors.green : Colors.red,
          icon: trendPercent >= 0 ? Icons.trending_up : Icons.trending_down,
        ));
      }
    }

    return insights;
  }

  static String _formatShortDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}';
    } catch (e) {
      return isoDate.length > 5 ? isoDate.substring(5, 10) : isoDate;
    }
  }

  /// Generate a summary text from data
  static String generateSummary({
    required List<Map<String, dynamic>> data,
    required String valueKey,
    required String metricName,
    bool isArabic = false,
    String Function(num)? formatValue,
  }) {
    if (data.isEmpty) {
      return isArabic ? 'لا توجد بيانات متاحة' : 'No data available';
    }

    final values =
        data.map((d) => (d[valueKey] as num?)?.toDouble() ?? 0).toList();
    final total = values.reduce((a, b) => a + b);
    final format = formatValue ?? (v) => v.toStringAsFixed(0);

    // Calculate trend
    if (values.length >= 2) {
      final firstHalf = values.sublist(0, values.length ~/ 2);
      final secondHalf = values.sublist(values.length ~/ 2);
      final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
      final trendPercent = ((secondAvg - firstAvg) / firstAvg * 100);

      if (trendPercent.abs() > 5) {
        final direction = trendPercent >= 0
            ? (isArabic ? 'ارتفع' : 'increased')
            : (isArabic ? 'انخفض' : 'decreased');
        return isArabic
            ? '$metricName $direction بنسبة ${trendPercent.abs().toStringAsFixed(1)}% خلال هذه الفترة. الإجمالي: ${format(total)}'
            : '$metricName $direction by ${trendPercent.abs().toStringAsFixed(1)}% over this period. Total: ${format(total)}';
      }
    }

    return isArabic
        ? 'إجمالي $metricName: ${format(total)} خلال ${data.length} ${data.length == 1 ? 'يوم' : 'أيام'}'
        : 'Total $metricName: ${format(total)} over ${data.length} ${data.length == 1 ? 'day' : 'days'}';
  }
}
