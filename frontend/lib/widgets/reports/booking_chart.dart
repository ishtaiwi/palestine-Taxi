import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import 'shared/shared.dart';

class BookingTimeSeriesChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showLegend;
  final bool showInsights;

  const BookingTimeSeriesChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showLegend = true,
    this.showInsights = true,
  });

  @override
  State<BookingTimeSeriesChart> createState() => _BookingTimeSeriesChartState();
}

class _BookingTimeSeriesChartState extends State<BookingTimeSeriesChart> {
  int? _touchedIndex;
  final Map<String, bool> _seriesVisibility = {
    'total': true,
    'confirmed': true,
    'cancelled': true,
    'pending': true,
  };

  static const Map<String, Color> _seriesColors = {
    'total': Colors.blue,
    'confirmed': Colors.green,
    'cancelled': Colors.red,
    'pending': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final chartData = (widget.data['data'] as List<dynamic>?) ?? [];
    final totalBookings = widget.data['totalBookings'] ?? 0;
    final confirmationRate = widget.data['confirmationRate'] as num? ?? 0;
    final peakHours = widget.data['peakHours'] as List<dynamic>? ?? [];
    final byStatus = widget.data['byStatus'] as Map<String, dynamic>? ?? {};
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    if (chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_online,
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
            totalBookings: totalBookings,
            confirmationRate: confirmationRate,
            byStatus: byStatus,
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
                  label: widget.isArabic ? 'مؤكد' : 'Confirmed',
                  color: _seriesColors['confirmed']!,
                  shape: LegendShape.line,
                  isVisible: _seriesVisibility['confirmed']!,
                ),
                LegendItem(
                  label: widget.isArabic ? 'ملغي' : 'Cancelled',
                  color: _seriesColors['cancelled']!,
                  shape: LegendShape.line,
                  isVisible: _seriesVisibility['cancelled']!,
                ),
              ],
              onToggle: (index, isVisible) {
                setState(() {
                  final keys = ['total', 'confirmed', 'cancelled'];
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
                          final total = dataPoint['total'] ?? 0;
                          final confirmed = dataPoint['confirmed'] ?? 0;
                          final cancelled = dataPoint['cancelled'] ?? 0;
                          final pending = dataPoint['pending'] ?? 0;
                          final rate =
                              total > 0 ? (confirmed / total * 100) : 0;

                          return LineTooltipItem(
                            '${ChartTooltipHelper.formatDate(date)}\n'
                            '${widget.isArabic ? 'الإجمالي' : 'Total'}: $total\n'
                            '${widget.isArabic ? 'مؤكد' : 'Confirmed'}: $confirmed\n'
                            '${widget.isArabic ? 'ملغي' : 'Cancelled'}: $cancelled\n'
                            '${widget.isArabic ? 'قيد الانتظار' : 'Pending'}: $pending\n'
                            '${widget.isArabic ? 'معدل التأكيد' : 'Confirm Rate'}: ${rate.toStringAsFixed(1)}%',
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
                  horizontalInterval: _getInterval(_getMaxBookings(chartData)),
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
                          ? (chartData.length / (isSmall ? 4 : 6))
                              .ceilToDouble()
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
                      interval: _getInterval(_getMaxBookings(chartData)),
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
                maxY: _getMaxY(_getMaxBookings(chartData)),
                lineBarsData: _buildLineBarsData(chartData, isSmall),
              ),
            ),
          ),

          // Insights
          if (widget.showInsights) ...[
            SizedBox(height: isSmall ? 12 : 16),
            ChartDescription(
              isCompact: isSmall,
              summary: _generateSummary(confirmationRate.toDouble()),
              insights: [
                ChartInsight(
                  label: widget.isArabic ? 'معدل التأكيد' : 'Confirmation Rate',
                  value: '${confirmationRate.toStringAsFixed(1)}%',
                  color: confirmationRate >= 80
                      ? Colors.green
                      : (confirmationRate >= 60 ? Colors.orange : Colors.red),
                  icon: Icons.verified,
                ),
                if (peakHours.isNotEmpty)
                  ChartInsight(
                    label: widget.isArabic ? 'أوقات الذروة' : 'Peak Hours',
                    value: _formatPeakHours(peakHours),
                    color: Colors.purple,
                    icon: Icons.schedule,
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }

  Widget _buildSummaryStats({
    required dynamic totalBookings,
    required num confirmationRate,
    required Map<String, dynamic> byStatus,
    Map<String, dynamic>? percentageChange,
    required bool isSmall,
  }) {
    if (isSmall) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'إجمالي الحجوزات' : 'Total Bookings',
              value: totalBookings.toString(),
              icon: Icons.book_online,
              color: Colors.blue,
              percentageChange: percentageChange?['bookings']?.toDouble(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'مؤكد' : 'Confirmed',
              value: (byStatus['confirmed'] ?? 0).toString(),
              icon: Icons.check_circle,
              color: Colors.green,
              percentageChange: percentageChange?['confirmed']?.toDouble(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'معدل التأكيد' : 'Rate',
              value: '${confirmationRate.toStringAsFixed(1)}%',
              icon: Icons.percent,
              color: confirmationRate >= 80 ? Colors.green : Colors.orange,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي الحجوزات' : 'Total Bookings',
            value: totalBookings.toString(),
            icon: Icons.book_online,
            color: Colors.blue,
            percentageChange: percentageChange?['bookings']?.toDouble(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'مؤكد' : 'Confirmed',
            value: (byStatus['confirmed'] ?? 0).toString(),
            icon: Icons.check_circle,
            color: Colors.green,
            percentageChange: percentageChange?['confirmed']?.toDouble(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'معدل التأكيد' : 'Rate',
            value: '${confirmationRate.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: confirmationRate >= 80 ? Colors.green : Colors.orange,
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

    if (_seriesVisibility['confirmed']!) {
      lines.add(_buildLineData(
        chartData: chartData,
        valueKey: 'confirmed',
        color: _seriesColors['confirmed']!,
        isSmall: isSmall,
      ));
    }

    if (_seriesVisibility['cancelled']!) {
      lines.add(_buildLineData(
        chartData: chartData,
        valueKey: 'cancelled',
        color: _seriesColors['cancelled']!,
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

  String _generateSummary(double confirmationRate) {
    if (confirmationRate >= 90) {
      return widget.isArabic
          ? 'معدل تأكيد ممتاز! معظم الحجوزات تم تأكيدها بنجاح'
          : 'Excellent confirmation rate! Most bookings are successfully confirmed';
    } else if (confirmationRate >= 75) {
      return widget.isArabic
          ? 'معدل تأكيد جيد مع نسبة إلغاء منخفضة'
          : 'Good confirmation rate with low cancellation ratio';
    } else if (confirmationRate >= 60) {
      return widget.isArabic
          ? 'معدل تأكيد مقبول، يمكن تحسينه'
          : 'Acceptable confirmation rate, room for improvement';
    } else {
      return widget.isArabic
          ? 'معدل التأكيد يحتاج إلى تحسين'
          : 'Confirmation rate needs improvement';
    }
  }

  String _formatPeakHours(List<dynamic> peakHours) {
    if (peakHours.isEmpty) return '';
    return peakHours.take(2).map((h) {
      final hour = h['hour'] as int? ?? 0;
      return '${hour.toString().padLeft(2, '0')}:00';
    }).join(', ');
  }

  double _getMaxBookings(List<dynamic> data) {
    if (data.isEmpty) return 0;
    double max = 0;
    for (final item in data) {
      final total = (item['total'] as num?)?.toDouble() ?? 0;
      if (total > max) max = total;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 5;
    if (max < 10) return 2;
    if (max < 50) return 10;
    if (max < 100) return 20;
    if (max < 500) return 100;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 10;
    return (max * 1.2).ceilToDouble();
  }
}

class BookingByStatusChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showAsDonut;

  const BookingByStatusChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showAsDonut = true,
  });

  @override
  State<BookingByStatusChart> createState() => _BookingByStatusChartState();
}

class _BookingByStatusChartState extends State<BookingByStatusChart> {
  int? _touchedIndex;

  static const Map<String, Color> _statusColors = {
    'confirmed': Colors.green,
    'cancelled': Colors.red,
    'pending': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final byStatus = widget.data['byStatus'] as Map<String, dynamic>? ?? {};
    final totalBookings = widget.data['totalBookings'] ??
        byStatus.values.fold<num>(0, (sum, v) => sum + (v as num));

    final statusData = byStatus.entries
        .where((e) => (e.value as num) > 0)
        .map((e) => {
              'key': e.key,
              'label': _getStatusLabel(e.key),
              'value': e.value,
              'color': _statusColors[e.key] ?? Colors.grey,
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

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Legend
          CompactLegend(
            items: statusData
                .map((item) => LegendItem(
                      label: item['label'] as String,
                      color: item['color'] as Color,
                      value: totalBookings > 0
                          ? '${((item['value'] as num) / totalBookings * 100).toStringAsFixed(1)}%'
                          : '0%',
                    ))
                .toList(),
          ),
          SizedBox(height: isSmall ? 12 : 16),

          // Chart
          if (widget.showAsDonut)
            _buildDonutChart(statusData, totalBookings, isSmall)
          else
            _buildBarChart(statusData, isSmall),
        ],
      );
    });
  }

  String _getStatusLabel(String status) {
    final labels = {
      'confirmed': widget.isArabic ? 'مؤكد' : 'Confirmed',
      'cancelled': widget.isArabic ? 'ملغي' : 'Cancelled',
      'pending': widget.isArabic ? 'قيد الانتظار' : 'Pending',
    };
    return labels[status] ?? status;
  }

  Widget _buildDonutChart(List<Map<String, dynamic>> statusData,
      dynamic totalBookings, bool isSmall) {
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
              sectionsSpace: 3,
              centerSpaceRadius: isSmall ? 50 : 70,
              sections: statusData.asMap().entries.map((entry) {
                final isHighlighted = entry.key == _touchedIndex;
                final color = entry.value['color'] as Color;
                final value = entry.value['value'] as num;
                final percentage =
                    totalBookings > 0 ? (value / totalBookings * 100) : 0;

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
                totalBookings.toString(),
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

  Widget _buildBarChart(List<Map<String, dynamic>> statusData, bool isSmall) {
    final maxValue = statusData.fold<double>(0, (max, item) {
      final value = (item['value'] as num).toDouble();
      return value > max ? value : max;
    });

    return ResponsiveChartContainer(
      preferredSize: ChartSize.large,
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxY(maxValue),
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
                return BarTooltipItem(
                  '${item['label']}\n${item['value']} bookings',
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
                reservedSize: isSmall ? 40 : 50,
                interval: _getInterval(maxValue),
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
            horizontalInterval: _getInterval(maxValue),
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
                    toY: _getMaxY(maxValue),
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

  double _getInterval(double max) {
    if (max <= 0) return 5;
    if (max < 10) return 2;
    if (max < 50) return 10;
    if (max < 100) return 20;
    if (max < 500) return 100;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 10;
    return (max * 1.2).ceilToDouble();
  }
}

/// Peak booking hours chart
class PeakHoursChart extends StatelessWidget {
  final List<dynamic> peakHours;
  final bool isArabic;

  const PeakHoursChart({
    super.key,
    required this.peakHours,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    if (peakHours.isEmpty) {
      return Center(
        child: Text(
          isArabic ? 'لا توجد بيانات' : 'No peak hours data',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'أوقات الذروة' : 'Peak Booking Hours',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...peakHours.take(5).map((item) {
          final hour = item['hour'] as int? ?? 0;
          final count = item['count'] as int? ?? 0;
          final maxCount = (peakHours.first['count'] as int? ?? 1);
          final percentage = maxCount > 0 ? count / maxCount : 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppTheme.getCardBorder(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: percentage.toDouble(),
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.purple.withOpacity(0.8),
                              Colors.purple,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
