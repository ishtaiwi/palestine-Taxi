import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';

class LinePerformanceChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final String metric;
  final bool isArabic;

  const LinePerformanceChart({
    super.key,
    required this.data,
    required this.metric,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final linePerformance = (data['linePerformance'] as List<dynamic>?) ?? [];
    final sortedLines = List<Map<String, dynamic>>.from(linePerformance)
      ..sort((a, b) {
        final aValue = (a[metric] as num?)?.toDouble() ?? 0;
        final bValue = (b[metric] as num?)?.toDouble() ?? 0;
        return bValue.compareTo(aValue);
      });

    final displayLines = sortedLines.take(10).toList();

    if (displayLines.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxValue(displayLines, metric) * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.grey[900]!,
              tooltipRoundedRadius: 8,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < displayLines.length) {
                    final linename = displayLines[value.toInt()]['linename'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        linename.length > 10 ? '${linename.substring(0, 10)}...' : linename,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 50,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: metric == 'revenue' ? 60 : 40,
                getTitlesWidget: (value, meta) {
                  if (metric == 'revenue') {
                    return Text(
                      ReportDataProcessor.formatCurrencyCompact(value),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    );
                  } else if (metric == 'utilization') {
                    return Text(
                      '${(value * 100).toInt()}%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    );
                  }
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.getCardBorder(0.2),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppTheme.getCardBorder(0.2),
            ),
          ),
          barGroups: displayLines.asMap().entries.map((entry) {
            final value = (entry.value[metric] as num?)?.toDouble() ?? 0;
            Color color;
            if (metric == 'revenue') {
              color = Colors.green;
            } else if (metric == 'bookings') {
              color = Colors.blue;
            } else {
              color = Colors.orange;
            }
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: value,
                  color: color,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  double _getMaxValue(List<Map<String, dynamic>> lines, String metric) {
    if (lines.isEmpty) return 100;
    double max = 0;
    for (final line in lines) {
      final value = (line[metric] as num?)?.toDouble() ?? 0;
      if (value > max) max = value;
    }
    return max > 0 ? max : 100;
  }
}

