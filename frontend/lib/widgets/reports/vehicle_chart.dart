import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import 'shared/shared.dart';

class VehicleUtilizationChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showInsights;

  const VehicleUtilizationChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showInsights = true,
  });

  @override
  State<VehicleUtilizationChart> createState() =>
      _VehicleUtilizationChartState();
}

class _VehicleUtilizationChartState extends State<VehicleUtilizationChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final vehicleUtilization =
        (widget.data['vehicleUtilization'] as List<dynamic>?) ?? [];
    final fleetStats = widget.data['fleetStats'] as Map<String, dynamic>?;
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    final topVehicles = vehicleUtilization
        .where((v) => ((v['tripCount'] as num?)?.toInt() ?? 0) > 0)
        .toList()
      ..sort((a, b) => ((b['tripCount'] as num?) ?? 0)
          .compareTo((a['tripCount'] as num?) ?? 0));

    final displayVehicles = topVehicles.take(10).toList();

    if (displayVehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_car,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isArabic ? 'لا توجد بيانات' : 'No data available',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 400;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fleet summary stats
          if (fleetStats != null) ...[
            _buildFleetStats(fleetStats, percentageChange, isSmall),
            SizedBox(height: isSmall ? 12 : 16),
          ],

          // Chart
          ResponsiveChartContainer(
            preferredSize: ChartSize.large,
            chart: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(_getMaxTripsValue(displayVehicles)),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipRoundedRadius: 12,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipColor: (group) => AppTheme.isDarkMode
                        ? const Color(0xFF1A1F35)
                        : Colors.white,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final vehicle = displayVehicles[group.x];
                      final plateno = vehicle['plateno'] ?? '';
                      final tripCount = vehicle['tripCount'] ?? 0;
                      final totalBookings = vehicle['totalBookings'] ?? 0;
                      final utilization =
                          ((vehicle['utilization'] as num?)?.toDouble() ?? 0) *
                              100;

                      return BarTooltipItem(
                        '$plateno\n'
                        '${widget.isArabic ? 'الرحلات' : 'Trips'}: $tripCount\n'
                        '${widget.isArabic ? 'الحجوزات' : 'Bookings'}: $totalBookings\n'
                        '${widget.isArabic ? 'الاستخدام' : 'Utilization'}: ${utilization.toStringAsFixed(1)}%',
                        TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (event.isInterestedForInteractions &&
                          response?.spot != null) {
                        _touchedIndex = response!.spot!.touchedBarGroupIndex;
                      } else {
                        _touchedIndex = null;
                      }
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < displayVehicles.length) {
                          final plateno = displayVehicles[value.toInt()]
                                  ['plateno'] as String? ??
                              '';
                          final isHighlighted = _touchedIndex == value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RotatedBox(
                              quarterTurns: isSmall ? 1 : 0,
                              child: Text(
                                plateno.length > 8
                                    ? '${plateno.substring(0, 8)}...'
                                    : plateno,
                                style: TextStyle(
                                  color: isHighlighted
                                      ? Colors.blue
                                      : AppTheme.textSecondary,
                                  fontSize: isSmall ? 9 : 10,
                                  fontWeight: isHighlighted
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: isSmall ? 50 : 40,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isSmall ? 40 : 50,
                      interval: _getInterval(_getMaxTripsValue(displayVehicles)),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isSmall ? 9 : 10,
                            ),
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
                  horizontalInterval:
                      _getInterval(_getMaxTripsValue(displayVehicles)),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.getCardBorder(0.15),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: displayVehicles.asMap().entries.map((entry) {
                  final tripCount =
                      (entry.value['tripCount'] as num?)?.toInt() ?? 0;
                  final utilization =
                      ((entry.value['utilization'] as num?)?.toDouble() ?? 0);
                  final isHighlighted = _touchedIndex == entry.key;

                  // Color based on utilization
                  Color barColor;
                  if (utilization >= 0.8) {
                    barColor = Colors.green;
                  } else if (utilization >= 0.5) {
                    barColor = Colors.blue;
                  } else {
                    barColor = Colors.orange;
                  }

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: tripCount.toDouble(),
                        color: isHighlighted ? barColor : barColor.withOpacity(0.8),
                        width: isHighlighted ? 24 : 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _getMaxY(_getMaxTripsValue(displayVehicles)),
                          color: AppTheme.getCardBorder(0.05),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Insights
          if (widget.showInsights && fleetStats != null) ...[
            SizedBox(height: isSmall ? 12 : 16),
            ChartDescription(
              isCompact: isSmall,
              insights: [
                ChartInsight(
                  label: widget.isArabic ? 'متوسط الاستخدام' : 'Avg Utilization',
                  value:
                      '${((fleetStats['averageUtilization'] as num?)?.toDouble() ?? 0 * 100).toStringAsFixed(1)}%',
                  color: Colors.blue,
                  icon: Icons.speed,
                ),
                ChartInsight(
                  label: widget.isArabic ? 'مركبات نشطة' : 'Active Vehicles',
                  value:
                      '${fleetStats['activeVehicles'] ?? 0}/${fleetStats['totalVehicles'] ?? 0}',
                  color: Colors.green,
                  icon: Icons.directions_car,
                ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildFleetStats(
    Map<String, dynamic> fleetStats,
    Map<String, dynamic>? percentageChange,
    bool isSmall,
  ) {
    if (isSmall) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'إجمالي المركبات' : 'Total Vehicles',
              value: (fleetStats['totalVehicles'] ?? 0).toString(),
              icon: Icons.directions_car,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'نشطة' : 'Active',
              value: (fleetStats['activeVehicles'] ?? 0).toString(),
              icon: Icons.check_circle,
              color: Colors.green,
              percentageChange: percentageChange?['activeVehicles']?.toDouble(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'خاملة' : 'Idle',
              value: (fleetStats['idleVehicles'] ?? 0).toString(),
              icon: Icons.pause_circle,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي المركبات' : 'Total Vehicles',
            value: (fleetStats['totalVehicles'] ?? 0).toString(),
            icon: Icons.directions_car,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'نشطة' : 'Active',
            value: (fleetStats['activeVehicles'] ?? 0).toString(),
            icon: Icons.check_circle,
            color: Colors.green,
            percentageChange: percentageChange?['activeVehicles']?.toDouble(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'خاملة' : 'Idle',
            value: (fleetStats['idleVehicles'] ?? 0).toString(),
            icon: Icons.pause_circle,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  double _getMaxTripsValue(List<dynamic> vehicles) {
    if (vehicles.isEmpty) return 0;
    double max = 0;
    for (final vehicle in vehicles) {
      final trips = (vehicle['tripCount'] as num?)?.toDouble() ?? 0;
      if (trips > max) max = trips;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 5;
    if (max < 10) return 2;
    if (max < 50) return 10;
    if (max < 100) return 20;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 10;
    return (max * 1.2).ceilToDouble();
  }
}

class VehicleStatusChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const VehicleStatusChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  State<VehicleStatusChart> createState() => _VehicleStatusChartState();
}

class _VehicleStatusChartState extends State<VehicleStatusChart> {
  int? _touchedIndex;

  static const Map<String, Color> _statusColors = {
    'active': Colors.green,
    'inactive': Colors.grey,
    'maintenance': Colors.orange,
    'retired': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final statusCount =
        widget.data['vehicleStatusCount'] as Map<String, dynamic>? ?? {};
    final total = statusCount.values.fold<num>(0, (sum, v) => sum + (v as num));

    final statusData = statusCount.entries
        .where((e) => (e.value as num) > 0)
        .map((e) => {
              'key': e.key,
              'label': _getStatusLabel(e.key),
              'value': e.value,
              'color': _statusColors[e.key.toLowerCase()] ?? Colors.blue,
            })
        .toList()
      ..sort((a, b) => (b['value'] as num).compareTo(a['value'] as num));

    if (statusData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              widget.isArabic ? 'لا توجد بيانات' : 'No data available',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 400;
      final gaugeSize = isSmall ? 180.0 : 220.0;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Legend
          CompactLegend(
            items: statusData
                .map((item) => LegendItem(
                      label: item['label'] as String,
                      color: item['color'] as Color,
                      value: total > 0
                          ? '${((item['value'] as num) / total * 100).toStringAsFixed(1)}%'
                          : '0%',
                    ))
                .toList(),
          ),
          SizedBox(height: isSmall ? 12 : 16),

          // Donut chart
          SizedBox(
            height: gaugeSize,
            width: gaugeSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      enabled: true,
                      touchCallback: (event, response) {
                        setState(() {
                          if (event.isInterestedForInteractions &&
                              response?.touchedSection != null) {
                            _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex;
                          } else {
                            _touchedIndex = null;
                          }
                        });
                      },
                    ),
                    sectionsSpace: 3,
                    centerSpaceRadius: isSmall ? 45 : 60,
                    sections: statusData.asMap().entries.map((entry) {
                      final isHighlighted = entry.key == _touchedIndex;
                      final color = entry.value['color'] as Color;
                      final value = entry.value['value'] as num;
                      final percentage = total > 0 ? (value / total * 100) : 0;

                      return PieChartSectionData(
                        value: value.toDouble(),
                        color: color,
                        title: isHighlighted
                            ? '${percentage.toStringAsFixed(1)}%'
                            : '',
                        radius: isHighlighted
                            ? (isSmall ? 50 : 65)
                            : (isSmall ? 40 : 55),
                        titleStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      total.toString(),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: isSmall ? 24 : 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.isArabic ? 'مركبات' : 'Vehicles',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isSmall ? 11 : 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  String _getStatusLabel(String status) {
    final labels = {
      'active': widget.isArabic ? 'نشط' : 'Active',
      'inactive': widget.isArabic ? 'غير نشط' : 'Inactive',
      'maintenance': widget.isArabic ? 'صيانة' : 'Maintenance',
      'retired': widget.isArabic ? 'متقاعد' : 'Retired',
    };
    return labels[status.toLowerCase()] ?? status;
  }
}

/// Active vehicles over time chart
class ActiveVehiclesTimeChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const ActiveVehiclesTimeChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  State<ActiveVehiclesTimeChart> createState() =>
      _ActiveVehiclesTimeChartState();
}

class _ActiveVehiclesTimeChartState extends State<ActiveVehiclesTimeChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final activeVehiclesOverTime =
        (widget.data['activeVehiclesOverTime'] as List<dynamic>?) ?? [];

    if (activeVehiclesOverTime.isEmpty) {
      return Center(
        child: Text(
          widget.isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 400;

      return ResponsiveChartContainer(
        preferredSize: isSmall ? ChartSize.medium : ChartSize.large,
        chart: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipRoundedRadius: 12,
                getTooltipColor: (touchedSpot) => AppTheme.isDarkMode
                    ? const Color(0xFF1A1F35)
                    : Colors.white,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final idx = spot.x.toInt();
                    if (idx >= 0 && idx < activeVehiclesOverTime.length) {
                      final dataPoint = activeVehiclesOverTime[idx];
                      final date = dataPoint['date'] as String? ?? '';
                      final activeCount = dataPoint['activeVehicles'] ?? 0;
                      final tripCount = dataPoint['tripCount'] ?? 0;

                      return LineTooltipItem(
                        '${ChartTooltipHelper.formatDate(date)}\n'
                        '${widget.isArabic ? 'مركبات نشطة' : 'Active'}: $activeCount\n'
                        '${widget.isArabic ? 'رحلات' : 'Trips'}: $tripCount',
                        TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return null;
                  }).toList();
                },
              ),
              touchCallback: (event, response) {
                setState(() {
                  if (event.isInterestedForInteractions &&
                      response?.lineBarSpots != null &&
                      response!.lineBarSpots!.isNotEmpty) {
                    _touchedIndex = response.lineBarSpots!.first.x.toInt();
                  } else {
                    _touchedIndex = null;
                  }
                });
              },
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  _getInterval(_getMaxActiveVehicles(activeVehiclesOverTime)),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: AppTheme.getCardBorder(0.15),
                  strokeWidth: 1,
                  dashArray: [5, 5],
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
                  reservedSize: isSmall ? 22 : 26,
                  interval: activeVehiclesOverTime.length > 10
                      ? (activeVehiclesOverTime.length / (isSmall ? 4 : 6))
                          .ceilToDouble()
                      : 1,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx >= 0 && idx < activeVehiclesOverTime.length) {
                      final date =
                          activeVehiclesOverTime[idx]['date'] as String? ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          date.length >= 10 ? date.substring(5, 10) : date,
                          style: TextStyle(
                            color: _touchedIndex == idx
                                ? Colors.teal
                                : AppTheme.textSecondary,
                            fontSize: isSmall ? 9 : 10,
                            fontWeight: _touchedIndex == idx
                                ? FontWeight.bold
                                : FontWeight.normal,
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
                  reservedSize: isSmall ? 40 : 50,
                  interval:
                      _getInterval(_getMaxActiveVehicles(activeVehiclesOverTime)),
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isSmall ? 9 : 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: _getMaxY(_getMaxActiveVehicles(activeVehiclesOverTime)),
            lineBarsData: [
              LineChartBarData(
                spots: activeVehiclesOverTime.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    (entry.value['activeVehicles'] as num?)?.toDouble() ?? 0,
                  );
                }).toList(),
                isCurved: true,
                curveSmoothness: 0.25,
                color: Colors.teal,
                barWidth: isSmall ? 2.5 : 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isHighlighted = index == _touchedIndex;
                    return FlDotCirclePainter(
                      radius: isHighlighted
                          ? 5
                          : (activeVehiclesOverTime.length < 15 ? 2.5 : 0),
                      color: Colors.teal,
                      strokeWidth: isHighlighted ? 2 : 1.5,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.teal.withOpacity(0.2),
                      Colors.teal.withOpacity(0.02),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  double _getMaxActiveVehicles(List<dynamic> data) {
    if (data.isEmpty) return 0;
    double max = 0;
    for (final item in data) {
      final active = (item['activeVehicles'] as num?)?.toDouble() ?? 0;
      if (active > max) max = active;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 5;
    if (max < 10) return 2;
    if (max < 50) return 10;
    if (max < 100) return 20;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 10;
    return (max * 1.2).ceilToDouble();
  }
}
