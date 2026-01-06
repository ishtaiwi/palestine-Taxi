import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';

class RevenueChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showSummary;

  const RevenueChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showSummary = true,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = (data['data'] as List<dynamic>?) ?? [];
    final totalRevenue = data['totalRevenue'] ?? 0;
    final totalTransactions = data['totalTransactions'] ?? 0;

    if (chartData.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSummary) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                isArabic ? 'إجمالي الإيرادات' : 'Total Revenue',
                ReportDataProcessor.formatCurrencyCompact(totalRevenue),
                Colors.green,
              ),
              _buildStatItem(
                isArabic ? 'إجمالي المعاملات' : 'Total Transactions',
                totalTransactions.toString(),
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 170,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _getMaxRevenue(chartData) / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppTheme.getCardBorder(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: chartData.length > 10
                        ? (chartData.length / 5).ceilToDouble()
                        : 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < chartData.length) {
                        final date = chartData[idx]['date'] as String;
                        return Text(
                          date.substring(5, 10),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 8,
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35,
                    interval: _getMaxRevenue(chartData) / 3,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        ReportDataProcessor.formatCurrencyCompact(value),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 8,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: AppTheme.getCardBorder(0.2),
                ),
              ),
              minX: 0,
              maxX: (chartData.length - 1).toDouble(),
              minY: 0,
              maxY: _getMaxRevenue(chartData) * 1.1,
              lineBarsData: [
                LineChartBarData(
                  spots: chartData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      (entry.value['revenue'] as num).toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Colors.green.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxRevenue(List<dynamic> data) {
    if (data.isEmpty) return 1000;
    double max = 0;
    for (final item in data) {
      final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
      if (revenue > max) max = revenue;
    }
    return max > 0 ? max : 1000;
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class RevenueByLineChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const RevenueByLineChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final revenueByLine = data['revenueByLine'] as Map<String, dynamic>? ?? {};
    final entries = revenueByLine.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    if (entries.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxRevenue(entries) * 1.2,
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
                  if (value.toInt() >= 0 && value.toInt() < entries.length) {
                    final lineid = entries[value.toInt()].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        lineid.length > 8 ? lineid.substring(0, 8) : lineid,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    ReportDataProcessor.formatCurrencyCompact(value),
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
          barGroups: entries.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value.value as num).toDouble(),
                  color: Colors.green,
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  double _getMaxRevenue(List<MapEntry<String, dynamic>> entries) {
    if (entries.isEmpty) return 1000;
    double max = 0;
    for (final entry in entries) {
      final revenue = (entry.value as num).toDouble();
      if (revenue > max) max = revenue;
    }
    return max > 0 ? max : 1000;
  }
}
