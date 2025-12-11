import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';

class VehicleUtilizationChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const VehicleUtilizationChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final vehicleUtilization = (data['vehicleUtilization'] as List<dynamic>?) ?? [];
    final topVehicles = vehicleUtilization
        .where((v) => ((v['tripCount'] as num?)?.toInt() ?? 0) > 0)
        .toList()
      ..sort((a, b) => ((b['tripCount'] as num?) ?? 0).compareTo((a['tripCount'] as num?) ?? 0));

    final displayVehicles = topVehicles.take(10).toList();

    if (displayVehicles.isEmpty) {
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
          maxY: _getMaxTrips(displayVehicles) * 1.2,
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
                  if (value.toInt() >= 0 && value.toInt() < displayVehicles.length) {
                    final plateno = displayVehicles[value.toInt()]['plateno'] as String? ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        plateno,
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
          barGroups: displayVehicles.asMap().entries.map((entry) {
            final tripCount = (entry.value['tripCount'] as num?)?.toInt() ?? 0;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: tripCount.toDouble(),
                  color: Colors.blue,
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

  double _getMaxTrips(List<dynamic> vehicles) {
    if (vehicles.isEmpty) return 100;
    double max = 0;
    for (final vehicle in vehicles) {
      final trips = (vehicle['tripCount'] as num?)?.toDouble() ?? 0;
      if (trips > max) max = trips;
    }
    return max > 0 ? max : 100;
  }
}

class VehicleStatusChart extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const VehicleStatusChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusCount = data['vehicleStatusCount'] as Map<String, dynamic>? ?? {};
    final entries = statusCount.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    if (entries.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final statusColors = {
      'active': Colors.green,
      'inactive': Colors.grey,
      'maintenance': Colors.orange,
    };

    return SizedBox(
      height: 300,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: entries.map((entry) {
            final status = entry.key;
            final count = (entry.value as num).toDouble();
            final total = entries.fold<double>(0, (sum, e) => sum + (e.value as num).toDouble());
            final percentage = total > 0 ? (count / total * 100) : 0;
            final color = statusColors[status.toLowerCase()] ?? Colors.blue;
            return PieChartSectionData(
              value: count,
              color: color,
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

