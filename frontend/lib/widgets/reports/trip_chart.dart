import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import 'shared/shared.dart';

class TripTimeSeriesChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showLegend;
  final bool showInsights;

  const TripTimeSeriesChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showLegend = true,
    this.showInsights = true,
  });

  @override
  State<TripTimeSeriesChart> createState() => _TripTimeSeriesChartState();
}

class _TripTimeSeriesChartState extends State<TripTimeSeriesChart> {
  int? _touchedIndex;
  final Map<String, bool> _seriesVisibility = {
    'completed': true,
    'cancelled': true,
    'scheduled': true,
    'inProgress': true,
  };

  static const Map<String, Color> _seriesColors = {
    'completed': Colors.green,
    'cancelled': Colors.red,
    'scheduled': Colors.blue,
    'inProgress': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final overTime = (widget.data['overTime'] as List<dynamic>?) ?? [];
    final totalTrips = widget.data['totalTrips'] ?? 0;
    final completed = widget.data['completed'] ?? 0;
    final cancelled = widget.data['cancelled'] ?? 0;
    final completionRate = widget.data['completionRate'] as num? ?? 0;
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    if (overTime.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 400;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary stats
            _buildSummaryStats(
              totalTrips: totalTrips,
              completed: completed,
              cancelled: cancelled,
              completionRate: completionRate,
              percentageChange: percentageChange,
              isSmall: isSmall,
            ),
            SizedBox(height: isSmall ? 12 : 16),

            // Interactive legend
            if (widget.showLegend) ...[
              ChartLegend(
                items: [
                  LegendItem(
                    label: widget.isArabic ? 'مكتمل' : 'Completed',
                    color: _seriesColors['completed']!,
                    value: completed.toString(),
                    shape: LegendShape.line,
                    isVisible: _seriesVisibility['completed']!,
                  ),
                  LegendItem(
                    label: widget.isArabic ? 'ملغي' : 'Cancelled',
                    color: _seriesColors['cancelled']!,
                    value: cancelled.toString(),
                    shape: LegendShape.line,
                    isVisible: _seriesVisibility['cancelled']!,
                  ),
                ],
                showValues: true,
                onToggle: (index, isVisible) {
                  setState(() {
                    final key = index == 0 ? 'completed' : 'cancelled';
                    _seriesVisibility[key] = isVisible;
                  });
                },
              ),
              SizedBox(height: isSmall ? 12 : 16),
            ],

            // Chart
            ResponsiveChartContainer(
              preferredSize: isSmall ? ChartSize.medium : ChartSize.large,
              chart: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipRoundedRadius: 12,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      getTooltipColor: (touchedSpot) => AppTheme.isDarkMode
                          ? const Color(0xFF1A1F35)
                          : Colors.white,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.toInt();
                          if (idx >= 0 && idx < overTime.length) {
                            final dataPoint = overTime[idx];
                            final date = dataPoint['date'] as String? ?? '';
                            final completedVal = dataPoint['completed'] ?? 0;
                            final cancelledVal = dataPoint['cancelled'] ?? 0;
                            final total =
                                (completedVal as num) + (cancelledVal as num);
                            final rate =
                                total > 0 ? (completedVal / total * 100) : 0;

                            return LineTooltipItem(
                              '${ChartTooltipHelper.formatDate(date)}\n'
                              'Completed: $completedVal\n'
                              'Cancelled: $cancelledVal\n'
                              'Rate: ${rate.toStringAsFixed(1)}%',
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
                          _touchedIndex =
                              response.lineBarSpots!.first.x.toInt();
                        } else {
                          _touchedIndex = null;
                        }
                      });
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _getMaxTrips(overTime) / 5,
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
                        interval: overTime.length > 10
                            ? (overTime.length / (isSmall ? 4 : 6))
                                .ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < overTime.length) {
                            final date = overTime[idx]['date'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                date.substring(5, 10),
                                style: TextStyle(
                                  color: _touchedIndex == idx
                                      ? Colors.green
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
                        reservedSize: isSmall ? 35 : 40,
                        interval: _getMaxTrips(overTime) / 4,
                        getTitlesWidget: (value, meta) {
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
                  minX: 0,
                  maxX: (overTime.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxTrips(overTime) * 1.15,
                  lineBarsData: _buildLineBarsData(overTime, isSmall),
                ),
              ),
            ),

            // Insights
            if (widget.showInsights) ...[
              SizedBox(height: isSmall ? 12 : 16),
              ChartDescription(
                isCompact: isSmall,
                summary: _generateSummary(overTime, completionRate.toDouble()),
                insights: [
                  ChartInsight(
                    label: widget.isArabic ? 'معدل الإتمام' : 'Completion Rate',
                    value: '${completionRate.toStringAsFixed(1)}%',
                    color: completionRate >= 80
                        ? Colors.green
                        : (completionRate >= 60 ? Colors.orange : Colors.red),
                    icon: Icons.check_circle,
                  ),
                  ChartInsight(
                    label: widget.isArabic ? 'متوسط يومي' : 'Daily Average',
                    value: overTime.isNotEmpty
                        ? (completed / overTime.length).toStringAsFixed(1)
                        : '0',
                    color: Colors.blue,
                    icon: Icons.analytics,
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryStats({
    required dynamic totalTrips,
    required dynamic completed,
    required dynamic cancelled,
    required num completionRate,
    Map<String, dynamic>? percentageChange,
    required bool isSmall,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isSmall ? double.infinity : 140,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي الرحلات' : 'Total Trips',
            value: totalTrips.toString(),
            icon: Icons.directions_bus,
            color: Colors.indigo,
            percentageChange: percentageChange?['totalTrips']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 140,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'مكتملة' : 'Completed',
            value: completed.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
            percentageChange: percentageChange?['completed']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 140,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'معدل الإتمام' : 'Rate',
            value: '${completionRate.toStringAsFixed(1)}%',
            icon: Icons.speed,
            color: completionRate >= 80 ? Colors.green : Colors.orange,
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _buildLineBarsData(
      List<dynamic> overTime, bool isSmall) {
    final lines = <LineChartBarData>[];

    if (_seriesVisibility['completed']!) {
      lines.add(LineChartBarData(
        spots: overTime.asMap().entries.map((entry) {
          return FlSpot(
            entry.key.toDouble(),
            (entry.value['completed'] as num).toDouble(),
          );
        }).toList(),
        isCurved: true,
        curveSmoothness: 0.25,
        color: _seriesColors['completed'],
        barWidth: isSmall ? 2.5 : 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isHighlighted = index == _touchedIndex;
            return FlDotCirclePainter(
              radius: isHighlighted ? 5 : (overTime.length < 15 ? 2.5 : 0),
              color: _seriesColors['completed']!,
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
              _seriesColors['completed']!.withOpacity(0.2),
              _seriesColors['completed']!.withOpacity(0.02),
            ],
          ),
        ),
      ));
    }

    if (_seriesVisibility['cancelled']!) {
      lines.add(LineChartBarData(
        spots: overTime.asMap().entries.map((entry) {
          return FlSpot(
            entry.key.toDouble(),
            (entry.value['cancelled'] as num).toDouble(),
          );
        }).toList(),
        isCurved: true,
        curveSmoothness: 0.25,
        color: _seriesColors['cancelled'],
        barWidth: isSmall ? 2.5 : 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final isHighlighted = index == _touchedIndex;
            return FlDotCirclePainter(
              radius: isHighlighted ? 5 : (overTime.length < 15 ? 2.5 : 0),
              color: _seriesColors['cancelled']!,
              strokeWidth: isHighlighted ? 2 : 1.5,
              strokeColor: Colors.white,
            );
          },
        ),
      ));
    }

    return lines;
  }

  String _generateSummary(List<dynamic> overTime, double completionRate) {
    if (overTime.isEmpty) return '';

    if (completionRate >= 90) {
      return widget.isArabic
          ? 'أداء ممتاز! معدل إتمام مرتفع جداً خلال هذه الفترة'
          : 'Excellent performance! Very high completion rate during this period';
    } else if (completionRate >= 75) {
      return widget.isArabic
          ? 'أداء جيد مع معدل إتمام مرتفع'
          : 'Good performance with high completion rate';
    } else if (completionRate >= 60) {
      return widget.isArabic
          ? 'أداء مقبول، يمكن تحسين معدل الإتمام'
          : 'Acceptable performance, completion rate could be improved';
    } else {
      return widget.isArabic
          ? 'معدل الإتمام منخفض، يحتاج إلى اهتمام'
          : 'Low completion rate, needs attention';
    }
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

class TripStatusChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showAsDonut;

  const TripStatusChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showAsDonut = false,
  });

  @override
  State<TripStatusChart> createState() => _TripStatusChartState();
}

class _TripStatusChartState extends State<TripStatusChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final totalTrips = widget.data['totalTrips'] ?? 0;
    final completed = widget.data['completed'] ?? 0;
    final cancelled = widget.data['cancelled'] ?? 0;
    final scheduled = widget.data['scheduled'] ?? 0;
    final inProgress = widget.data['inProgress'] ?? 0;
    final open = widget.data['open'] ?? 0;

    final statusData = [
      {
        'label': widget.isArabic ? 'مكتمل' : 'Completed',
        'value': completed,
        'color': Colors.green
      },
      {
        'label': widget.isArabic ? 'ملغي' : 'Cancelled',
        'value': cancelled,
        'color': Colors.red
      },
      {
        'label': widget.isArabic ? 'مجدول' : 'Scheduled',
        'value': scheduled,
        'color': Colors.blue
      },
      {
        'label': widget.isArabic ? 'قيد التنفيذ' : 'In Progress',
        'value': inProgress,
        'color': Colors.orange
      },
      {
        'label': widget.isArabic ? 'مفتوح' : 'Open',
        'value': open,
        'color': Colors.purple
      },
    ].where((item) => (item['value'] as num) > 0).toList();

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 400;

        return Column(
          children: [
            // Legend
            CompactLegend(
              items: statusData
                  .map((item) => LegendItem(
                        label: item['label'] as String,
                        color: item['color'] as Color,
                        value: totalTrips > 0
                            ? '${((item['value'] as num) / totalTrips * 100).toStringAsFixed(1)}%'
                            : '0%',
                      ))
                  .toList(),
            ),
            SizedBox(height: isSmall ? 12 : 16),

            // Chart
            if (widget.showAsDonut)
              _buildDonutChart(statusData, totalTrips, isSmall)
            else
              _buildBarChart(statusData, totalTrips, isSmall),
          ],
        );
      },
    );
  }

  Widget _buildDonutChart(
      List<Map<String, dynamic>> statusData, dynamic totalTrips, bool isSmall) {
    return ResponsiveChartContainer(
      preferredSize: ChartSize.large,
      chart: Stack(
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
              sectionsSpace: 2,
              centerSpaceRadius: isSmall ? 50 : 70,
              sections: statusData.asMap().entries.map((entry) {
                final isHighlighted = entry.key == _touchedIndex;
                final color = entry.value['color'] as Color;
                final value = entry.value['value'] as num;
                final percentage =
                    totalTrips > 0 ? (value / totalTrips * 100) : 0;

                return PieChartSectionData(
                  value: value.toDouble(),
                  color: color,
                  title:
                      isHighlighted ? '${percentage.toStringAsFixed(1)}%' : '',
                  radius:
                      isHighlighted ? (isSmall ? 55 : 70) : (isSmall ? 45 : 60),
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
                totalTrips.toString(),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isSmall ? 24 : 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.isArabic ? 'إجمالي' : 'Total',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: isSmall ? 11 : 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(
      List<Map<String, dynamic>> statusData, dynamic totalTrips, bool isSmall) {
    final maxValue = statusData.fold<double>(0, (max, item) {
      final value = (item['value'] as num).toDouble();
      return value > max ? value : max;
    });

    return ResponsiveChartContainer(
      preferredSize: ChartSize.large,
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipRoundedRadius: 12,
              getTooltipColor: (group) =>
                  AppTheme.isDarkMode ? const Color(0xFF1A1F35) : Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = statusData[group.x];
                final value = item['value'] as num;
                final percentage =
                    totalTrips > 0 ? (value / totalTrips * 100) : 0;
                return BarTooltipItem(
                  '${item['label']}\n$value trips\n${percentage.toStringAsFixed(1)}%',
                  TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
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
                  if (value.toInt() >= 0 && value.toInt() < statusData.length) {
                    final isHighlighted = _touchedIndex == value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        statusData[value.toInt()]['label'] as String,
                        style: TextStyle(
                          color: isHighlighted
                              ? statusData[value.toInt()]['color'] as Color
                              : AppTheme.textSecondary,
                          fontSize: isSmall ? 9 : 10,
                          fontWeight: isHighlighted
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
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
                reservedSize: isSmall ? 35 : 40,
                getTitlesWidget: (value, meta) {
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
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.getCardBorder(0.15),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: statusData.asMap().entries.map((entry) {
            final color = entry.value['color'] as Color;
            final isHighlighted = _touchedIndex == entry.key;
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: (entry.value['value'] as num).toDouble(),
                  color: isHighlighted ? color : color.withOpacity(0.8),
                  width: isHighlighted ? 35 : 30,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxValue * 1.2,
                    color: AppTheme.getCardBorder(0.05),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class UtilizationGaugeChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showTrend;

  const UtilizationGaugeChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showTrend = true,
  });

  @override
  State<UtilizationGaugeChart> createState() => _UtilizationGaugeChartState();
}

class _UtilizationGaugeChartState extends State<UtilizationGaugeChart> {
  @override
  Widget build(BuildContext context) {
    final utilization =
        (widget.data['averageUtilization'] as num?)?.toDouble() ?? 0.0;
    final percentage = (utilization * 100).clamp(0.0, 100.0);
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    // Determine color based on utilization
    Color getUtilizationColor(double pct) {
      if (pct >= 80) return Colors.green;
      if (pct >= 60) return Colors.blue;
      if (pct >= 40) return Colors.orange;
      return Colors.red;
    }

    final utilizationColor = getUtilizationColor(percentage);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 300;
        final gaugeSize = isSmall ? 160.0 : 200.0;

        return Column(
          children: [
            // Gauge
            SizedBox(
              height: gaugeSize,
              width: gaugeSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: 180,
                      sectionsSpace: 0,
                      centerSpaceRadius: isSmall ? 45 : 60,
                      sections: [
                        // Filled portion
                        PieChartSectionData(
                          value: percentage,
                          color: utilizationColor,
                          title: '',
                          radius: isSmall ? 35 : 45,
                          showTitle: false,
                        ),
                        // Empty portion
                        PieChartSectionData(
                          value: 100 - percentage,
                          color: AppTheme.isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.15),
                          title: '',
                          radius: isSmall ? 35 : 45,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                  // Center content
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: utilizationColor,
                          fontSize: isSmall ? 24 : 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.showTrend &&
                          percentageChange != null &&
                          percentageChange['utilization'] != null) ...[
                        const SizedBox(height: 4),
                        _buildTrendBadge(
                            percentageChange['utilization'] as num),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Label
            Text(
              widget.isArabic ? 'متوسط الاستخدام' : 'Average Utilization',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isSmall ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Status text
            Text(
              _getUtilizationStatus(percentage),
              style: TextStyle(
                color: utilizationColor,
                fontSize: isSmall ? 11 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Insights
            const SizedBox(height: 16),
            ChartDescription(
              isCompact: true,
              insights: [
                ChartInsight(
                  label: widget.isArabic ? 'الحالة' : 'Status',
                  value: _getUtilizationStatusShort(percentage),
                  color: utilizationColor,
                  icon: _getUtilizationIcon(percentage),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrendBadge(num change) {
    final isPositive = change >= 0;
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}%',
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

  String _getUtilizationStatus(double percentage) {
    if (percentage >= 80) {
      return widget.isArabic ? 'استخدام ممتاز' : 'Excellent utilization';
    } else if (percentage >= 60) {
      return widget.isArabic ? 'استخدام جيد' : 'Good utilization';
    } else if (percentage >= 40) {
      return widget.isArabic ? 'استخدام متوسط' : 'Moderate utilization';
    } else {
      return widget.isArabic ? 'استخدام منخفض' : 'Low utilization';
    }
  }

  String _getUtilizationStatusShort(double percentage) {
    if (percentage >= 80) return widget.isArabic ? 'ممتاز' : 'Excellent';
    if (percentage >= 60) return widget.isArabic ? 'جيد' : 'Good';
    if (percentage >= 40) return widget.isArabic ? 'متوسط' : 'Moderate';
    return widget.isArabic ? 'منخفض' : 'Low';
  }

  IconData _getUtilizationIcon(double percentage) {
    if (percentage >= 80) return Icons.check_circle;
    if (percentage >= 60) return Icons.thumb_up;
    if (percentage >= 40) return Icons.info;
    return Icons.warning;
  }
}
