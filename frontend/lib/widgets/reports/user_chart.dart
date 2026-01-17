import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import 'shared/shared.dart';

class UserGrowthChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showLegend;
  final bool showInsights;

  const UserGrowthChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showLegend = true,
    this.showInsights = true,
  });

  @override
  State<UserGrowthChart> createState() => _UserGrowthChartState();
}

class _UserGrowthChartState extends State<UserGrowthChart> {
  int? _touchedIndex;
  final Map<String, bool> _seriesVisibility = {
    'total': true,
    'drivers': true,
    'passengers': true,
  };

  static const Map<String, Color> _seriesColors = {
    'total': Colors.blue,
    'drivers': Colors.orange,
    'passengers': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    final chartData = (widget.data['data'] as List<dynamic>?) ?? [];
    final total = widget.data['total'] ?? 0;
    final byRole = widget.data['byRole'] as Map<String, dynamic>? ?? {};
    final growthRate = widget.data['growthRate'] as num? ?? 0;
    final active = widget.data['active'] ?? 0;
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    if (chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
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
          // Summary stats
          _buildSummaryStats(
            total: total,
            byRole: byRole,
            active: active,
            growthRate: growthRate,
            percentageChange: percentageChange,
            isSmall: isSmall,
          ),
          SizedBox(height: isSmall ? 12 : 16),

          // Interactive legend
          if (widget.showLegend) ...[
            ChartLegend(
              items: [
                LegendItem(
                  label: widget.isArabic ? 'الإجمالي' : 'Total',
                  color: _seriesColors['total']!,
                  shape: LegendShape.line,
                  isVisible: _seriesVisibility['total']!,
                ),
                LegendItem(
                  label: widget.isArabic ? 'السائقين' : 'Drivers',
                  color: _seriesColors['drivers']!,
                  shape: LegendShape.line,
                  isVisible: _seriesVisibility['drivers']!,
                ),
                LegendItem(
                  label: widget.isArabic ? 'الركاب' : 'Passengers',
                  color: _seriesColors['passengers']!,
                  shape: LegendShape.line,
                  isVisible: _seriesVisibility['passengers']!,
                ),
              ],
              onToggle: (index, isVisible) {
                setState(() {
                  final keys = ['total', 'drivers', 'passengers'];
                  if (index < keys.length) {
                    _seriesVisibility[keys[index]] = isVisible;
                  }
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
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipColor: (touchedSpot) => AppTheme.isDarkMode
                        ? const Color(0xFF1A1F35)
                        : Colors.white,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        if (idx >= 0 && idx < chartData.length) {
                          final dataPoint = chartData[idx];
                          final date = dataPoint['date'] as String? ?? '';
                          final totalVal = dataPoint['total'] ?? 0;
                          final driversVal = dataPoint['drivers'] ?? 0;
                          final passengersVal = dataPoint['passengers'] ?? 0;

                          return LineTooltipItem(
                            '${ChartTooltipHelper.formatDate(date)}\n'
                            '${widget.isArabic ? 'الإجمالي' : 'Total'}: $totalVal\n'
                            '${widget.isArabic ? 'سائقين' : 'Drivers'}: $driversVal\n'
                            '${widget.isArabic ? 'ركاب' : 'Passengers'}: $passengersVal',
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
                  horizontalInterval: _getInterval(_getMaxUsers(chartData)),
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
                      interval: chartData.length > 10
                          ? (chartData.length / (isSmall ? 4 : 6)).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < chartData.length) {
                          final date = chartData[idx]['date'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              date.length >= 10 ? date.substring(5, 10) : date,
                              style: TextStyle(
                                color: _touchedIndex == idx
                                    ? Colors.blue
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
                      interval: _getInterval(_getMaxUsers(chartData)),
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
                minX: 0,
                maxX: (chartData.length - 1).toDouble(),
                minY: 0,
                maxY: _getMaxY(_getMaxUsers(chartData)),
                lineBarsData: _buildLineBarsData(chartData, isSmall),
              ),
            ),
          ),

          // Insights
          if (widget.showInsights) ...[
            SizedBox(height: isSmall ? 12 : 16),
            ChartDescription(
              isCompact: isSmall,
              summary: _generateSummary(growthRate.toDouble(), total),
              insights: [
                ChartInsight(
                  label: widget.isArabic ? 'معدل النمو' : 'Growth Rate',
                  value:
                      '${growthRate >= 0 ? '+' : ''}${growthRate.toStringAsFixed(1)}%',
                  color: growthRate >= 0 ? Colors.green : Colors.red,
                  icon: growthRate >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
                ChartInsight(
                  label: widget.isArabic ? 'نشط' : 'Active',
                  value:
                      '$active (${total > 0 ? (active / total * 100).toStringAsFixed(1) : 0}%)',
                  color: Colors.green,
                  icon: Icons.person,
                ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildSummaryStats({
    required dynamic total,
    required Map<String, dynamic> byRole,
    required dynamic active,
    required num growthRate,
    Map<String, dynamic>? percentageChange,
    required bool isSmall,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي المستخدمين' : 'Total Users',
            value: total.toString(),
            icon: Icons.people,
            color: Colors.blue,
            percentageChange: percentageChange?['total']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'السائقين' : 'Drivers',
            value: (byRole['drivers'] ?? 0).toString(),
            icon: Icons.drive_eta,
            color: Colors.orange,
            percentageChange: percentageChange?['drivers']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'الركاب' : 'Passengers',
            value: (byRole['passengers'] ?? 0).toString(),
            icon: Icons.person,
            color: Colors.green,
            percentageChange: percentageChange?['passengers']?.toDouble(),
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _buildLineBarsData(
      List<dynamic> chartData, bool isSmall) {
    final lines = <LineChartBarData>[];

    if (_seriesVisibility['total']!) {
      lines.add(_buildLineData(
        chartData: chartData,
        valueKey: 'total',
        color: _seriesColors['total']!,
        isSmall: isSmall,
        showArea: true,
      ));
    }

    if (_seriesVisibility['drivers']!) {
      lines.add(_buildLineData(
        chartData: chartData,
        valueKey: 'drivers',
        color: _seriesColors['drivers']!,
        isSmall: isSmall,
      ));
    }

    if (_seriesVisibility['passengers']!) {
      lines.add(_buildLineData(
        chartData: chartData,
        valueKey: 'passengers',
        color: _seriesColors['passengers']!,
        isSmall: isSmall,
      ));
    }

    return lines;
  }

  LineChartBarData _buildLineData({
    required List<dynamic> chartData,
    required String valueKey,
    required Color color,
    required bool isSmall,
    bool showArea = false,
  }) {
    return LineChartBarData(
      spots: chartData.asMap().entries.map((entry) {
        return FlSpot(
          entry.key.toDouble(),
          (entry.value[valueKey] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
      isCurved: true,
      curveSmoothness: 0.25,
      color: color,
      barWidth: isSmall ? 2.5 : 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          final isHighlighted = index == _touchedIndex;
          return FlDotCirclePainter(
            radius: isHighlighted ? 5 : (chartData.length < 15 ? 2.5 : 0),
            color: color,
            strokeWidth: isHighlighted ? 2 : 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: showArea
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.02),
                ],
              ),
            )
          : null,
    );
  }

  String _generateSummary(double growthRate, dynamic total) {
    if (growthRate >= 20) {
      return widget.isArabic
          ? 'نمو ممتاز في قاعدة المستخدمين! زيادة كبيرة في التسجيلات'
          : 'Excellent user base growth! Significant increase in registrations';
    } else if (growthRate >= 10) {
      return widget.isArabic
          ? 'نمو جيد في عدد المستخدمين خلال هذه الفترة'
          : 'Good user growth during this period';
    } else if (growthRate >= 0) {
      return widget.isArabic
          ? 'نمو مستقر في قاعدة المستخدمين'
          : 'Stable user base growth';
    } else {
      return widget.isArabic
          ? 'انخفاض في التسجيلات الجديدة مقارنة بالفترة السابقة'
          : 'Decrease in new registrations compared to previous period';
    }
  }

  double _getMaxUsers(List<dynamic> data) {
    if (data.isEmpty) return 0;
    double max = 0;
    for (final item in data) {
      final total = (item['total'] as num?)?.toDouble() ?? 0;
      if (total > max) max = total;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 10;
    if (max < 20) return 5;
    if (max < 100) return 25;
    if (max < 500) return 100;
    if (max < 1000) return 250;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 20;
    return (max * 1.2).ceilToDouble();
  }
}

class UserByRoleChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const UserByRoleChart({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  State<UserByRoleChart> createState() => _UserByRoleChartState();
}

class _UserByRoleChartState extends State<UserByRoleChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final byRole = widget.data['byRole'] as Map<String, dynamic>? ?? {};
    final total = widget.data['total'] ?? 0;
    final active = widget.data['active'] ?? 0;
    final inactive = widget.data['inactive'] ?? 0;

    final roleData = [
      {
        'key': 'drivers',
        'label': widget.isArabic ? 'سائقون' : 'Drivers',
        'value': byRole['drivers'] ?? 0,
        'color': Colors.orange,
        'icon': Icons.drive_eta,
      },
      {
        'key': 'passengers',
        'label': widget.isArabic ? 'ركاب' : 'Passengers',
        'value': byRole['passengers'] ?? 0,
        'color': Colors.green,
        'icon': Icons.person,
      },
      {
        'key': 'admins',
        'label': widget.isArabic ? 'مدراء' : 'Admins',
        'value': byRole['admins'] ?? 0,
        'color': Colors.purple,
        'icon': Icons.admin_panel_settings,
      },
    ].where((item) => (item['value'] as num) > 0).toList();

    if (roleData.isEmpty) {
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
            items: roleData
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
                    sections: roleData.asMap().entries.map((entry) {
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
                      widget.isArabic ? 'مستخدم' : 'Users',
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

          SizedBox(height: isSmall ? 12 : 16),

          // Activity status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActivityBadge(
                label: widget.isArabic ? 'نشط' : 'Active',
                value: active,
                color: Colors.green,
                isSmall: isSmall,
              ),
              const SizedBox(width: 16),
              _buildActivityBadge(
                label: widget.isArabic ? 'غير نشط' : 'Inactive',
                value: inactive,
                color: Colors.grey,
                isSmall: isSmall,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildActivityBadge({
    required String label,
    required dynamic value,
    required Color color,
    required bool isSmall,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 12 : 16,
        vertical: isSmall ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: isSmall ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
