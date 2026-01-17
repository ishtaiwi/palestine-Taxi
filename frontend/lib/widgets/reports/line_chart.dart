import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';
import 'shared/shared.dart';

class LinePerformanceChart extends StatefulWidget {
  final Map<String, dynamic> data;
  final String metric;
  final bool isArabic;
  final bool showInsights;

  const LinePerformanceChart({
    super.key,
    required this.data,
    required this.metric,
    this.isArabic = false,
    this.showInsights = true,
  });

  @override
  State<LinePerformanceChart> createState() => _LinePerformanceChartState();
}

class _LinePerformanceChartState extends State<LinePerformanceChart> {
  int? _touchedIndex;

  static const Map<String, Color> _metricColors = {
    'revenue': Colors.green,
    'bookings': Colors.blue,
    'trips': Colors.purple,
    'utilization': Colors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final linePerformance =
        (widget.data['linePerformance'] as List<dynamic>?) ?? [];
    final totals = widget.data['totals'] as Map<String, dynamic>?;
    final topLines = widget.data['topLines'] as Map<String, dynamic>?;
    final percentageChange =
        widget.data['percentageChange'] as Map<String, dynamic>?;

    final sortedLines = List<Map<String, dynamic>>.from(linePerformance)
      ..sort((a, b) {
        final aValue = (a[widget.metric] as num?)?.toDouble() ?? 0;
        final bValue = (b[widget.metric] as num?)?.toDouble() ?? 0;
        return bValue.compareTo(aValue);
      });

    final displayLines = sortedLines
        .where((l) {
          final value = (l[widget.metric] as num?)?.toDouble() ?? 0;
          return value > 0;
        })
        .take(10)
        .toList();

    if (displayLines.isEmpty) {
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

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 400;
      final barColor = _metricColors[widget.metric] ?? Colors.blue;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Summary stats
          if (totals != null) ...[
            _buildSummaryStats(totals, percentageChange, isSmall),
            SizedBox(height: isSmall ? 12 : 16),
          ],

          // Chart
          ResponsiveChartContainer(
            preferredSize: ChartSize.large,
            chart: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxY(_getMaxValue(displayLines, widget.metric)),
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
                      final line = displayLines[group.x];
                      final linename = line['linename'] ?? '';
                      final revenue = line['revenue'] ?? 0;
                      final bookings = line['bookings'] ?? 0;
                      final trips = line['trips'] ?? 0;
                      final utilization =
                          ((line['utilization'] as num?)?.toDouble() ?? 0) *
                              100;
                      final rank =
                          line['${widget.metric}Rank'] ?? (group.x + 1);

                      return BarTooltipItem(
                        '$linename\n'
                        '#$rank ${_getMetricLabel(widget.metric)}\n'
                        '${widget.isArabic ? 'الإيرادات' : 'Revenue'}: ${ReportDataProcessor.formatCurrencyCompact(revenue)}\n'
                        '${widget.isArabic ? 'الحجوزات' : 'Bookings'}: $bookings\n'
                        '${widget.isArabic ? 'الرحلات' : 'Trips'}: $trips\n'
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
                            value.toInt() < displayLines.length) {
                          final linename =
                              displayLines[value.toInt()]['linename'] as String? ??
                                  '';
                          final isHighlighted = _touchedIndex == value.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RotatedBox(
                              quarterTurns: isSmall ? 1 : 0,
                              child: Text(
                                linename.length > 10
                                    ? '${linename.substring(0, 10)}...'
                                    : linename,
                                style: TextStyle(
                                  color: isHighlighted
                                      ? barColor
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
                      reservedSize: isSmall ? 60 : 50,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: isSmall ? 50 : 60,
                      interval:
                          _getInterval(_getMaxValue(displayLines, widget.metric)),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            _formatAxisValue(value),
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
                      _getInterval(_getMaxValue(displayLines, widget.metric)),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.getCardBorder(0.15),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: displayLines.asMap().entries.map((entry) {
                  final value =
                      (entry.value[widget.metric] as num?)?.toDouble() ?? 0;
                  final isHighlighted = _touchedIndex == entry.key;

                  // Gradient color based on ranking
                  final colorOpacity = 1.0 - (entry.key * 0.07);

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: isHighlighted
                            ? barColor
                            : barColor
                                .withOpacity(colorOpacity.clamp(0.5, 1.0)),
                        width: isHighlighted ? 24 : 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: _getMaxY(_getMaxValue(displayLines, widget.metric)),
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
          if (widget.showInsights && topLines != null) ...[
            SizedBox(height: isSmall ? 12 : 16),
            _buildTopLinesInsight(topLines, isSmall),
          ],
        ],
      );
    });
  }

  Widget _buildSummaryStats(
    Map<String, dynamic> totals,
    Map<String, dynamic>? percentageChange,
    bool isSmall,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'إجمالي الإيرادات' : 'Total Revenue',
            value: ReportDataProcessor.formatCurrencyCompact(
                totals['revenue'] ?? 0),
            icon: Icons.attach_money,
            color: Colors.green,
            percentageChange: percentageChange?['revenue']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'الحجوزات' : 'Bookings',
            value: (totals['bookings'] ?? 0).toString(),
            icon: Icons.book_online,
            color: Colors.blue,
            percentageChange: percentageChange?['bookings']?.toDouble(),
          ),
        ),
        SizedBox(
          width: isSmall ? double.infinity : 150,
          child: ResponsiveStatCard(
            label: widget.isArabic ? 'الرحلات' : 'Trips',
            value: (totals['trips'] ?? 0).toString(),
            icon: Icons.directions_bus,
            color: Colors.purple,
            percentageChange: percentageChange?['trips']?.toDouble(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopLinesInsight(Map<String, dynamic> topLines, bool isSmall) {
    final topByMetric =
        topLines['by${_capitalizeFirst(widget.metric)}'] as List<dynamic>? ??
            [];

    if (topByMetric.isEmpty) return const SizedBox.shrink();

    final topLine = topByMetric.first as Map<String, dynamic>;
    final topLineName = topLine['linename'] as String? ?? '';
    final topLineValue = topLine[widget.metric];

    return ChartDescription(
      isCompact: isSmall,
      summary: widget.isArabic
          ? 'الخط الأفضل أداءً: $topLineName'
          : 'Top performing line: $topLineName',
      insights: [
        ChartInsight(
          label: widget.isArabic ? 'الأول' : 'Top Line',
          value: topLineName.length > 15
              ? '${topLineName.substring(0, 15)}...'
              : topLineName,
          color: _metricColors[widget.metric] ?? Colors.blue,
          icon: Icons.emoji_events,
        ),
        ChartInsight(
          label: _getMetricLabel(widget.metric),
          value: _formatMetricValue(topLineValue),
          color: _metricColors[widget.metric] ?? Colors.blue,
          icon: _getMetricIcon(widget.metric),
        ),
      ],
    );
  }

  String _getMetricLabel(String metric) {
    final labels = {
      'revenue': widget.isArabic ? 'الإيرادات' : 'Revenue',
      'bookings': widget.isArabic ? 'الحجوزات' : 'Bookings',
      'trips': widget.isArabic ? 'الرحلات' : 'Trips',
      'utilization': widget.isArabic ? 'الاستخدام' : 'Utilization',
    };
    return labels[metric] ?? metric;
  }

  IconData _getMetricIcon(String metric) {
    final icons = {
      'revenue': Icons.attach_money,
      'bookings': Icons.book_online,
      'trips': Icons.directions_bus,
      'utilization': Icons.speed,
    };
    return icons[metric] ?? Icons.show_chart;
  }

  String _formatAxisValue(double value) {
    if (widget.metric == 'revenue') {
      return ReportDataProcessor.formatCurrencyCompact(value);
    } else if (widget.metric == 'utilization') {
      return '${(value * 100).toInt()}%';
    }
    return value.toInt().toString();
  }

  String _formatMetricValue(dynamic value) {
    if (value == null) return '0';
    if (widget.metric == 'revenue') {
      return ReportDataProcessor.formatCurrencyCompact(value);
    } else if (widget.metric == 'utilization') {
      return '${((value as num).toDouble() * 100).toStringAsFixed(1)}%';
    }
    return value.toString();
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  double _getMaxValue(List<Map<String, dynamic>> lines, String metric) {
    if (lines.isEmpty) return 0;
    double max = 0;
    for (final line in lines) {
      final value = (line[metric] as num?)?.toDouble() ?? 0;
      if (value > max) max = value;
    }
    return max;
  }

  double _getInterval(double max) {
    if (max <= 0) {
      if (widget.metric == 'utilization') return 0.25;
      return 10;
    }
    if (widget.metric == 'utilization') return 0.25;
    if (max < 10) return 2;
    if (max < 100) return 25;
    if (max < 1000) return 250;
    return (max / 4).ceilToDouble();
  }

  double _getMaxY(double max) {
    if (max <= 0) {
      if (widget.metric == 'utilization') return 1.0;
      return 20;
    }
    if (widget.metric == 'utilization') return 1.0;
    return (max * 1.2).ceilToDouble();
  }
}

/// Line ranking table widget
class LineRankingTable extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const LineRankingTable({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final linePerformance = (data['linePerformance'] as List<dynamic>?) ?? [];

    final sortedLines = List<Map<String, dynamic>>.from(linePerformance)
      ..sort((a, b) {
        final aRev = (a['revenue'] as num?)?.toDouble() ?? 0;
        final bRev = (b['revenue'] as num?)?.toDouble() ?? 0;
        return bRev.compareTo(aRev);
      });

    final displayLines = sortedLines.take(5).toList();

    if (displayLines.isEmpty) {
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
        Text(
          isArabic ? 'ترتيب الخطوط' : 'Line Rankings',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...displayLines.asMap().entries.map((entry) {
          final line = entry.value;
          final rank = entry.key + 1;
          final linename = line['linename'] ?? '';
          final revenue = line['revenue'] ?? 0;
          final bookings = line['bookings'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber.withOpacity(0.1)
                  : AppTheme.getCardBackground(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: rank == 1
                    ? Colors.amber.withOpacity(0.3)
                    : AppTheme.getCardBorder(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _getRankColor(rank).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: _getRankColor(rank),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linename,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$bookings ${isArabic ? 'حجز' : 'bookings'}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ReportDataProcessor.formatCurrencyCompact(revenue),
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}
