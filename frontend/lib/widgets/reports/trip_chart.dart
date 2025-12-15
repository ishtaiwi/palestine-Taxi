import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

class TripTimeSeriesChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const TripTimeSeriesChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final overTime = (data['overTime'] as List<dynamic>?) ?? [];

    if (overTime.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getMaxTrips(overTime) / 5,
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
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < overTime.length) {
                    final date = overTime[value.toInt()]['date'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        date.length > 10 ? date.substring(5, 10) : date.substring(5),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
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
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppTheme.getCardBorder(0.2),
            ),
          ),
          minX: 0,
          maxX: (overTime.length - 1).toDouble(),
          minY: 0,
          maxY: _getMaxTrips(overTime) * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: overTime.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  (entry.value['completed'] as num).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: overTime.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  (entry.value['cancelled'] as num).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.red,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxTrips(List<dynamic> data) {
    if (data.isEmpty) return 100;
    double max = 0;
    for (final item in data) {
      final completed = (item['completed'] as num?)?.toDouble() ?? 0;
      final cancelled = (item['cancelled'] as num?)?.toDouble() ?? 0;
      final total = completed + cancelled;
      if (total > max) max = total;
    }
    return max > 0 ? max : 100;
  }
}

class TripStatusChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const TripStatusChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalTrips = data['totalTrips'] ?? 0;
    final completed = data['completed'] ?? 0;
    final cancelled = data['cancelled'] ?? 0;
    final scheduled = data['scheduled'] ?? 0;
    final inProgress = data['inProgress'] ?? 0;

    final statusData = [
      {'label': isArabic ? 'مكتمل' : 'Completed', 'value': completed, 'color': Colors.green},
      {'label': isArabic ? 'ملغي' : 'Cancelled', 'value': cancelled, 'color': Colors.red},
      {'label': isArabic ? 'مجدول' : 'Scheduled', 'value': scheduled, 'color': Colors.blue},
      {'label': isArabic ? 'قيد التنفيذ' : 'In Progress', 'value': inProgress, 'color': Colors.orange},
    ].where((item) => (item['value'] as num) > 0).toList();

    if (statusData.isEmpty) {
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
          maxY: totalTrips * 1.2,
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
                  if (value.toInt() >= 0 && value.toInt() < statusData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        statusData[value.toInt()]['label'] as String,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
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
          barGroups: statusData.asMap().entries.map((entry) {
            final color = entry.value['color'] as Color;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['value'] as num).toDouble(),
                  color: color,
                  width: 30,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class UtilizationGaugeChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const UtilizationGaugeChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final utilization = (data['averageUtilization'] as num?)?.toDouble() ?? 0.0;
    final percentage = (utilization * 100).clamp(0.0, 100.0);

    return Column(
      children: [
        SizedBox(
          height: 200,
          width: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 0,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  value: percentage,
                  color: Colors.green,
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: 100 - percentage,
                  color: Colors.grey[300]!,
                  title: '',
                  radius: 50,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isArabic ? 'متوسط الاستخدام' : 'Average Utilization',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

