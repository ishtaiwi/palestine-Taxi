import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';
import 'shared/shared.dart';

class RevenueChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showSummary;
  final bool showInsights;
  final bool showComparison;
  final ChartSize preferredSize;

  const RevenueChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showSummary = true,
    this.showInsights = true,
    this.showComparison = true,
    this.preferredSize = ChartSize.large,
  });

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final chartData = (widget.data['data'] as List<dynamic>?) ?? [];
    final totalRevenue = widget.data['totalRevenue'] ?? 0;
    final totalTransactions = widget.data['totalTransactions'] ?? 0;
    final stats = widget.data['stats'] as Map<String, dynamic>?;
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;
    final previousPeriod =
        widget.data['previousPeriod'] as Map<String, dynamic>?;

    if (chartData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
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
      final isConstrained = constraints.maxHeight.isFinite && constraints.maxHeight > 0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isConstrained ? MainAxisSize.max : MainAxisSize.min,
        children: [
          // Summary statistics with comparison
          if (widget.showSummary) ...[
            _buildSummaryStats(
              totalRevenue: totalRevenue,
              totalTransactions: totalTransactions,
              percentageChange: percentageChange,
              isSmall: isSmall,
            ),
            SizedBox(height: isSmall ? 12 : 16),
          ],

          // Period comparison widget
          if (widget.showComparison && previousPeriod != null) ...[
            PeriodComparison(
              currentLabel: widget.isArabic ? 'الفترة الحالية' : 'Current Period',
              currentValue:
                  ReportDataProcessor.formatCurrencyCompact(totalRevenue),
              previousLabel: widget.isArabic ? 'الفترة السابقة' : 'Previous Period',
              previousValue: ReportDataProcessor.formatCurrencyCompact(
                previousPeriod['totalRevenue'] ?? 0,
              ),
              percentageChange: percentageChange?['revenue']?.toDouble(),
              isArabic: widget.isArabic,
            ),
            SizedBox(height: isSmall ? 12 : 16),
          ],

          // Chart with responsive height
          if (isConstrained)
            Expanded(
              child: ResponsiveChartContainer(
                preferredSize: isSmall ? ChartSize.medium : widget.preferredSize,
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
                          final revenue =
                              (dataPoint['revenue'] as num?)?.toDouble() ?? 0;
                          final transactions = dataPoint['transactions'] ?? 0;

                          // Calculate change from previous day
                          String changeText = '';
                          if (idx > 0) {
                            final prevRevenue =
                                (chartData[idx - 1]['revenue'] as num?)
                                        ?.toDouble() ??
                                    0;
                            if (prevRevenue > 0) {
                              final change =
                                  ((revenue - prevRevenue) / prevRevenue * 100);
                              changeText =
                                  '\n${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% from prev';
                            }
                          }

                          return LineTooltipItem(
                            '${ChartTooltipHelper.formatDate(date)}\n${ReportDataProcessor.formatCurrencyCompact(revenue)}\n$transactions txns$changeText',
                            TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
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
                  horizontalInterval: _getInterval(_getMaxRevenue(chartData)),
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
                      reservedSize: isSmall ? 45 : 55,
                      interval: _getInterval(_getMaxRevenue(chartData)),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            ReportDataProcessor.formatCurrencyCompact(value),
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
                maxY: _getMaxY(_getMaxRevenue(chartData)),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        (entry.value['revenue'] as num).toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: Colors.green,
                    barWidth: isSmall ? 2.5 : 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isHighlighted = index == _touchedIndex;
                        return FlDotCirclePainter(
                          radius: isHighlighted
                              ? 6
                              : (chartData.length < 15 ? 3 : 0),
                          color: Colors.green,
                          strokeWidth: isHighlighted ? 3 : 2,
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
                          Colors.green.withOpacity(0.25),
                          Colors.green.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ],
                ),
              ),
              ),
            )
          else
            ResponsiveChartContainer(
              preferredSize: isSmall ? ChartSize.medium : widget.preferredSize,
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
                            final revenue =
                                (dataPoint['revenue'] as num?)?.toDouble() ?? 0;
                            final transactions = dataPoint['transactions'] ?? 0;

                            // Calculate change from previous day
                            String changeText = '';
                            if (idx > 0) {
                              final prevRevenue =
                                  (chartData[idx - 1]['revenue'] as num?)
                                          ?.toDouble() ??
                                      0;
                              if (prevRevenue > 0) {
                                final change =
                                    ((revenue - prevRevenue) / prevRevenue * 100);
                                changeText =
                                    '\n${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}% from prev';
                              }
                            }

                            return LineTooltipItem(
                              '${ChartTooltipHelper.formatDate(date)}\n${ReportDataProcessor.formatCurrencyCompact(revenue)}\n$transactions txns$changeText',
                              TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 12,
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
                    horizontalInterval: _getInterval(_getMaxRevenue(chartData)),
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
                        reservedSize: isSmall ? 45 : 55,
                        interval: _getInterval(_getMaxRevenue(chartData)),
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              ReportDataProcessor.formatCurrencyCompact(value),
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
                  maxY: _getMaxY(_getMaxRevenue(chartData)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          (entry.value['revenue'] as num).toDouble(),
                        );
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.25,
                      color: Colors.green,
                      barWidth: isSmall ? 2.5 : 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isHighlighted = index == _touchedIndex;
                          return FlDotCirclePainter(
                            radius: isHighlighted
                                ? 6
                                : (chartData.length < 15 ? 3 : 0),
                            color: Colors.green,
                            strokeWidth: isHighlighted ? 3 : 2,
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
                            Colors.green.withOpacity(0.25),
                            Colors.green.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Insights section
          if (widget.showInsights && stats != null) ...[
            SizedBox(height: isSmall ? 12 : 16),
            ChartDescription(
              isCompact: isSmall,
              summary: _generateSummary(chartData, totalRevenue),
              insights: _generateInsights(chartData, stats),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildSummaryStats({
    required dynamic totalRevenue,
    required dynamic totalTransactions,
    Map<String, dynamic>? percentageChange,
    required bool isSmall,
  }) {
    if (isSmall) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'إجمالي الإيرادات' : 'Total Revenue',
              value: ReportDataProcessor.formatCurrencyCompact(totalRevenue),
              icon: Icons.attach_money,
              color: Colors.green,
              percentageChange: percentageChange?['revenue']?.toDouble(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ResponsiveStatCard(
              label: widget.isArabic ? 'المعاملات' : 'Transactions',
              value: totalTransactions.toString(),
              icon: Icons.receipt_long,
              color: Colors.blue,
              percentageChange: percentageChange?['transactions']?.toDouble(),
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي الإيرادات' : 'Total Revenue',
            value: ReportDataProcessor.formatCurrencyCompact(totalRevenue),
            icon: Icons.attach_money,
            color: Colors.green,
            percentageChange: percentageChange?['revenue']?.toDouble(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'المعاملات' : 'Transactions',
            value: totalTransactions.toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
            percentageChange: percentageChange?['transactions']?.toDouble(),
          ),
        ),
      ],
    );
  }

  String _generateSummary(List<dynamic> chartData, dynamic totalRevenue) {
    if (chartData.isEmpty) return '';

    final values =
        chartData.map((d) => (d['revenue'] as num?)?.toDouble() ?? 0).toList();
    final firstHalf = values.sublist(0, values.length ~/ 2);
    final secondHalf = values.sublist(values.length ~/ 2);

    if (firstHalf.isEmpty || secondHalf.isEmpty) {
      return widget.isArabic
          ? 'إجمالي الإيرادات: ${ReportDataProcessor.formatCurrencyCompact(totalRevenue)}'
          : 'Total revenue: ${ReportDataProcessor.formatCurrencyCompact(totalRevenue)}';
    }

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    if (firstAvg == 0) {
      return widget.isArabic
          ? 'إجمالي الإيرادات: ${ReportDataProcessor.formatCurrencyCompact(totalRevenue)}'
          : 'Total revenue: ${ReportDataProcessor.formatCurrencyCompact(totalRevenue)}';
    }

    final trendPercent = ((secondAvg - firstAvg) / firstAvg * 100);

    if (trendPercent.abs() > 5) {
      final direction = trendPercent >= 0
          ? (widget.isArabic ? 'ارتفعت' : 'increased')
          : (widget.isArabic ? 'انخفضت' : 'decreased');
      return widget.isArabic
          ? 'الإيرادات $direction بنسبة ${trendPercent.abs().toStringAsFixed(1)}% خلال هذه الفترة'
          : 'Revenue $direction by ${trendPercent.abs().toStringAsFixed(1)}% over this period';
    }

    return widget.isArabic
        ? 'الإيرادات مستقرة خلال هذه الفترة'
        : 'Revenue remained stable during this period';
  }

  List<ChartInsight> _generateInsights(
      List<dynamic> chartData, Map<String, dynamic> stats) {
    final insights = <ChartInsight>[];

    // Average daily revenue
    if (stats['average'] != null) {
      insights.add(ChartInsight(
        label: widget.isArabic ? 'المتوسط اليومي' : 'Daily Average',
        value: ReportDataProcessor.formatCurrencyCompact(stats['average']),
        color: Colors.blue,
        icon: Icons.analytics,
      ));
    }

    // Best day
    if (stats['bestDay'] != null) {
      final bestDay = stats['bestDay'] as Map<String, dynamic>;
      insights.add(ChartInsight(
        label: widget.isArabic ? 'أفضل يوم' : 'Best Day',
        value:
            '${ReportDataProcessor.formatCurrencyCompact(bestDay['revenue'])} (${_formatShortDate(bestDay['date'])})',
        color: Colors.green,
        icon: Icons.trending_up,
      ));
    }

    // Worst day
    if (stats['worstDay'] != null) {
      final worstDay = stats['worstDay'] as Map<String, dynamic>;
      insights.add(ChartInsight(
        label: widget.isArabic ? 'أدنى يوم' : 'Lowest Day',
        value:
            '${ReportDataProcessor.formatCurrencyCompact(worstDay['revenue'])} (${_formatShortDate(worstDay['date'])})',
        color: Colors.orange,
        icon: Icons.trending_down,
      ));
    }

    return insights;
  }

  String _formatShortDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.month}/${d.day}';
    } catch (e) {
      return date.toString().length > 5
          ? date.toString().substring(5, 10)
          : date.toString();
    }
  }

  double _getMaxRevenue(List<dynamic> data) {
    if (data.isEmpty) return 0;
    double max = 0;
    for (final item in data) {
      final revenue = (item['revenue'] as num?)?.toDouble() ?? 0;
      if (revenue > max) max = revenue;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 250;
    if (max < 10) return 2.5;
    if (max < 100) return 25;
    if (max < 1000) return 250;
    if (max < 10000) return 2500;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 1000;
    return (max * 1.2).ceilToDouble();
  }
}

class RevenueByLineChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;
  final bool showLegend;

  const RevenueByLineChart({
    super.key,
    required this.data,
    this.isArabic = false,
    this.showLegend = true,
  });

  @override
  State<RevenueByLineChart> createState() => _RevenueByLineChartState();
}

class _RevenueByLineChartState extends State<RevenueByLineChart> {
  int? _touchedIndex;

  // Color palette for bars
  static const List<Color> _barColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF8BC34A),
    Color(0xFF3F51B5),
  ];

  @override
  Widget build(BuildContext context) {
    final revenueByLine =
        widget.data['revenueByLine'] as Map<String, dynamic>? ?? {};
    final entries = revenueByLine.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
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

    final totalRevenue =
        entries.fold<double>(0, (sum, e) => sum + (e.value as num).toDouble());

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 400;
      final barWidth = isSmall ? 16.0 : 24.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Legend
          if (widget.showLegend && entries.length <= 8) ...[
            CompactLegend(
              items: entries.take(8).toList().asMap().entries.map((entry) {
                final percentage =
                    (entry.value.value as num) / totalRevenue * 100;
                return LegendItem(
                  label: entry.value.key.length > 12
                      ? '${entry.value.key.substring(0, 12)}...'
                      : entry.value.key,
                  color: _barColors[entry.key % _barColors.length],
                  value: '${percentage.toStringAsFixed(1)}%',
                );
              }).toList(),
            ),
            SizedBox(height: isSmall ? 12 : 16),
          ],

          // Chart
          ResponsiveChartContainer(
            preferredSize: ChartSize.large,
            chart: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(_getMaxRevenueByLine(entries)),
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
                      final entry = entries[group.x];
                      final percentage =
                          (entry.value as num) / totalRevenue * 100;
                      return BarTooltipItem(
                        '${entry.key}\n${ReportDataProcessor.formatCurrencyCompact(entry.value)}\n${percentage.toStringAsFixed(1)}% of total',
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
                        if (value.toInt() >= 0 &&
                            value.toInt() < entries.length) {
                          final lineid = entries[value.toInt()].key;
                          final isHighlighted = _touchedIndex == value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RotatedBox(
                              quarterTurns: isSmall ? 1 : 0,
                              child: Text(
                                lineid.length > 8
                                    ? '${lineid.substring(0, 8)}...'
                                    : lineid,
                                style: TextStyle(
                                  color: isHighlighted
                                      ? _barColors[
                                          value.toInt() % _barColors.length]
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
                      reservedSize: isSmall ? 50 : 60,
                      interval: _getInterval(_getMaxRevenueByLine(entries)),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            ReportDataProcessor.formatCurrencyCompact(value),
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
                      _getInterval(_getMaxRevenueByLine(entries)),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.getCardBorder(0.15),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: entries.asMap().entries.map((entry) {
                  final isHighlighted = _touchedIndex == entry.key;
                  final color = _barColors[entry.key % _barColors.length];
                  final maxVal = _getMaxRevenueByLine(entries);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: (entry.value.value as num).toDouble(),
                        color: isHighlighted ? color : color.withOpacity(0.8),
                        width: isHighlighted ? barWidth * 1.1 : barWidth,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _getMaxY(maxVal),
                          color: AppTheme.getCardBorder(0.05),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          // Summary insight
          SizedBox(height: isSmall ? 12 : 16),
          ChartDescription(
            isCompact: isSmall,
            insights: [
              ChartInsight(
                label: widget.isArabic ? 'الإجمالي' : 'Total',
                value: ReportDataProcessor.formatCurrencyCompact(totalRevenue),
                color: Colors.green,
                icon: Icons.attach_money,
              ),
              if (entries.isNotEmpty)
                ChartInsight(
                  label: widget.isArabic ? 'الأعلى' : 'Top Line',
                  value: entries.first.key.length > 15
                      ? '${entries.first.key.substring(0, 15)}...'
                      : entries.first.key,
                  color: _barColors[0],
                  icon: Icons.star,
                ),
            ],
          ),
        ],
      );
    });
  }

  double _getMaxRevenueByLine(List<MapEntry<String, dynamic>> entries) {
    if (entries.isEmpty) return 0;
    double max = 0;
    for (final entry in entries) {
      final revenue = (entry.value as num).toDouble();
      if (revenue > max) max = revenue;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) return 250;
    if (max < 10) return 2.5;
    if (max < 100) return 25;
    if (max < 1000) return 250;
    if (max < 10000) return 2500;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) return 1000;
    return (max * 1.2).ceilToDouble();
  }
}
