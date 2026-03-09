import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Heat map for showing bookings by day and hour
class BookingHeatMap extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isArabic;

  const BookingHeatMap({
    super.key,
    required this.data,
    this.isArabic = false,
  });

  @override
  State<BookingHeatMap> createState() => _BookingHeatMapState();
}

class _BookingHeatMapState extends State<BookingHeatMap> {
  int? _hoveredDay;
  int? _hoveredHour;

  static const List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  static const List<String> _weekDaysAr = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];

  @override
  Widget build(BuildContext context) {
    // Generate sample heat map data from booking data
    final heatMapData = _generateHeatMapData();
    final maxValue = _getMaxValue(heatMapData);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 500;
        final cellSize = isSmall ? 28.0 : 36.0;
        final hourLabelWidth = isSmall ? 35.0 : 45.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.isArabic
                  ? 'توزيع الحجوزات حسب الوقت'
                  : 'Booking Distribution by Time',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: isSmall ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmall ? 12 : 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.isArabic ? 'أقل' : 'Low',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 8),
                ..._buildLegendGradient(),
                const SizedBox(width: 8),
                Text(
                  widget.isArabic ? 'أكثر' : 'High',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 12 : 16),

            // Day labels
            Padding(
              padding: EdgeInsets.only(left: hourLabelWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:
                    (widget.isArabic ? _weekDaysAr : _weekDays).map((day) {
                  return SizedBox(
                    width: cellSize,
                    child: Text(
                      isSmall ? day.substring(0, 1) : day,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isSmall ? 10 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Heat map grid
            SizedBox(
              height: 24 * (cellSize + 2),
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(24, (hour) {
                    return Row(
                      children: [
                        // Hour label
                        SizedBox(
                          width: hourLabelWidth,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: isSmall ? 9 : 10,
                            ),
                          ),
                        ),
                        // Day cells
                        ...List.generate(7, (day) {
                          final value = heatMapData[day][hour];
                          final intensity =
                              maxValue > 0 ? value / maxValue : 0.0;
                          final isHovered =
                              _hoveredDay == day && _hoveredHour == hour;

                          return GestureDetector(
                            onTapDown: (_) => setState(() {
                              _hoveredDay = day;
                              _hoveredHour = hour;
                            }),
                            onTapUp: (_) => setState(() {
                              _hoveredDay = null;
                              _hoveredHour = null;
                            }),
                            child: MouseRegion(
                              onEnter: (_) => setState(() {
                                _hoveredDay = day;
                                _hoveredHour = hour;
                              }),
                              onExit: (_) => setState(() {
                                _hoveredDay = null;
                                _hoveredHour = null;
                              }),
                              child: Tooltip(
                                message:
                                    '${_weekDays[day]} ${hour.toString().padLeft(2, '0')}:00\n${value.toInt()} bookings',
                                child: Container(
                                  width: cellSize,
                                  height: cellSize,
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: _getHeatColor(intensity),
                                    borderRadius: BorderRadius.circular(4),
                                    border: isHovered
                                        ? Border.all(
                                            color: AppTheme.textPrimary,
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<List<double>> _generateHeatMapData() {
    // Initialize 7 days x 24 hours matrix
    final heatMap = List.generate(7, (_) => List.filled(24, 0.0));

    final chartData = (widget.data['data'] as List<dynamic>?) ?? [];

    for (final item in chartData) {
      final dateStr = item['date'] as String? ?? '';
      final total = (item['total'] as num?)?.toDouble() ?? 0;

      try {
        final date = DateTime.parse(dateStr);
        final dayOfWeek = (date.weekday - 1) % 7; // Mon=0, Sun=6

        // Distribute bookings across peak hours (8-20)
        for (int hour = 8; hour < 20; hour++) {
          // Assume more bookings during morning and evening rush
          double hourWeight = 1.0;
          if (hour >= 7 && hour <= 9) hourWeight = 2.0;
          if (hour >= 17 && hour <= 19) hourWeight = 1.8;
          if (hour >= 12 && hour <= 14) hourWeight = 1.5;

          heatMap[dayOfWeek][hour] += (total / 12) * hourWeight;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return heatMap;
  }

  double _getMaxValue(List<List<double>> data) {
    double max = 0;
    for (final day in data) {
      for (final value in day) {
        if (value > max) max = value;
      }
    }
    return max;
  }

  Color _getHeatColor(double intensity) {
    if (intensity <= 0) {
      return AppTheme.isDarkMode
          ? Colors.grey.withOpacity(0.1)
          : Colors.grey.withOpacity(0.15);
    }

    // Green gradient for intensity
    final color = Color.lerp(
      Colors.green.withOpacity(0.2),
      Colors.green,
      intensity.clamp(0.0, 1.0),
    );
    return color ?? Colors.green;
  }

  List<Widget> _buildLegendGradient() {
    return List.generate(5, (i) {
      final intensity = i / 4;
      return Container(
        width: 16,
        height: 12,
        decoration: BoxDecoration(
          color: _getHeatColor(intensity),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    });
  }
}

/// Comparison bar chart for current vs previous period
class ComparisonBarChart extends StatefulWidget {
  final Map<String, dynamic> currentData;
  final Map<String, dynamic>? previousData;
  final String title;
  final String valueKey;
  final String labelKey;
  final bool isArabic;
  final Color currentColor;
  final Color previousColor;
  final String Function(num)? formatValue;

  const ComparisonBarChart({
    super.key,
    required this.currentData,
    this.previousData,
    required this.title,
    required this.valueKey,
    required this.labelKey,
    this.isArabic = false,
    this.currentColor = Colors.blue,
    this.previousColor = Colors.grey,
    this.formatValue,
  });

  @override
  State<ComparisonBarChart> createState() => _ComparisonBarChartState();
}

class _ComparisonBarChartState extends State<ComparisonBarChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final currentItems = (widget.currentData['data'] as List<dynamic>?) ?? [];
    final previousItems =
        (widget.previousData?['data'] as List<dynamic>?) ?? [];

    if (currentItems.isEmpty) {
      return Center(
        child: Text(
          widget.isArabic ? 'لا توجد بيانات' : 'No data available',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    // Match current and previous data by date
    final comparisonData = <Map<String, dynamic>>[];
    for (int i = 0; i < currentItems.length; i++) {
      final current = currentItems[i];
      final previous = i < previousItems.length ? previousItems[i] : null;

      comparisonData.add({
        'label': current[widget.labelKey] ?? '',
        'current': current[widget.valueKey] ?? 0,
        'previous': previous?[widget.valueKey] ?? 0,
      });
    }

    final maxValue = comparisonData.fold<double>(0, (max, item) {
      final current = (item['current'] as num).toDouble();
      final previous = (item['previous'] as num).toDouble();
      return [max, current, previous].reduce((a, b) => a > b ? a : b);
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 400;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: isSmall ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildLegendItem(
                      widget.isArabic ? 'الفترة الحالية' : 'Current',
                      widget.currentColor,
                    ),
                    const SizedBox(width: 16),
                    _buildLegendItem(
                      widget.isArabic ? 'الفترة السابقة' : 'Previous',
                      widget.previousColor,
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: isSmall ? 12 : 16),

            // Bars
            ...comparisonData.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final label = item['label'] as String;
              final currentValue = (item['current'] as num).toDouble();
              final previousValue = (item['previous'] as num).toDouble();
              final currentWidth = maxValue > 0 ? currentValue / maxValue : 0;
              final previousWidth = maxValue > 0 ? previousValue / maxValue : 0;
              final isHovered = _hoveredIndex == idx;

              final change = previousValue > 0
                  ? ((currentValue - previousValue) / previousValue * 100)
                  : (currentValue > 0 ? 100 : 0);

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = idx),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? AppTheme.getCardBackground(0.08)
                        : AppTheme.getCardBackground(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label.length > 10
                                  ? label.substring(5, 10)
                                  : label,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: isSmall ? 11 : 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.previousData != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: change >= 0
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    change >= 0
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10,
                                    color:
                                        change >= 0 ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: change >= 0
                                          ? Colors.green
                                          : Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Current bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.getCardBorder(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: FractionallySizedBox(
                                widthFactor:
                                    currentWidth.clamp(0.0, 1.0).toDouble(),
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.currentColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 60,
                            child: Text(
                              widget.formatValue?.call(currentValue) ??
                                  currentValue.toStringAsFixed(0),
                              style: TextStyle(
                                color: widget.currentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      if (widget.previousData != null) ...[
                        const SizedBox(height: 4),
                        // Previous bar
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppTheme.getCardBorder(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  widthFactor:
                                      previousWidth.clamp(0.0, 1.0).toDouble(),
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: widget.previousColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: Text(
                                widget.formatValue?.call(previousValue) ??
                                    previousValue.toStringAsFixed(0),
                                style: TextStyle(
                                  color: widget.previousColor,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Mini sparkline chart for stat cards
class SparklineChart extends StatelessWidget {
  final List<num> data;
  final Color color;
  final double height;
  final double strokeWidth;
  final bool showDots;
  final bool fillArea;

  const SparklineChart({
    super.key,
    required this.data,
    this.color = Colors.blue,
    this.height = 40,
    this.strokeWidth = 2,
    this.showDots = false,
    this.fillArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          data: data.map((v) => v.toDouble()).toList(),
          color: color,
          strokeWidth: strokeWidth,
          showDots: showDots,
          fillArea: fillArea,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double strokeWidth;
  final bool showDots;
  final bool fillArea;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.strokeWidth,
    required this.showDots,
    required this.fillArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedY = range > 0 ? (data[i] - minValue) / range : 0.5;
      final y =
          size.height - (normalizedY * size.height * 0.8) - (size.height * 0.1);
      points.add(Offset(x, y));
    }

    // Draw fill area
    if (fillArea && points.length > 1) {
      final fillPath = Path();
      fillPath.moveTo(0, size.height);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath.lineTo(size.width, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    if (points.length > 1) {
      final linePath = Path();
      linePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, linePaint);
    }

    // Draw dots
    if (showDots) {
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final point in points) {
        canvas.drawCircle(point, strokeWidth * 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
