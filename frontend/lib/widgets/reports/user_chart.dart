import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

class UserGrowthChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const UserGrowthChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = (data['data'] as List<dynamic>?) ?? [];

    if (chartData.isEmpty) {
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
            horizontalInterval: _getMaxUsers(chartData) / 5,
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
                  if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                    final date = chartData[value.toInt()]['date'] as String;
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
          maxX: (chartData.length - 1).toDouble(),
          minY: 0,
          maxY: _getMaxUsers(chartData) * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: chartData.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  (entry.value['total'] as num).toDouble(),
                );
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxUsers(List<dynamic> data) {
    if (data.isEmpty) return 100;
    double max = 0;
    for (final item in data) {
      final total = (item['total'] as num?)?.toDouble() ?? 0;
      if (total > max) max = total;
    }
    return max > 0 ? max : 100;
  }
}

class UserByRoleChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const UserByRoleChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final byRole = data['byRole'] as Map<String, dynamic>? ?? {};
    final drivers = byRole['drivers'] ?? 0;
    final passengers = byRole['passengers'] ?? 0;
    final admins = byRole['admins'] ?? 0;

    final roleData = [
      {'label': isArabic ? 'سائقون' : 'Drivers', 'value': drivers, 'color': Colors.blue},
      {'label': isArabic ? 'ركاب' : 'Passengers', 'value': passengers, 'color': Colors.green},
      {'label': isArabic ? 'مدراء' : 'Admins', 'value': admins, 'color': Colors.orange},
    ].where((item) => (item['value'] as num) > 0).toList();

    if (roleData.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: roleData.map((item) {
            final total = drivers + passengers + admins;
            final percentage = total > 0 ? ((item['value'] as num).toDouble() / total * 100) : 0;
            return PieChartSectionData(
              value: (item['value'] as num).toDouble(),
              color: item['color'] as Color,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

