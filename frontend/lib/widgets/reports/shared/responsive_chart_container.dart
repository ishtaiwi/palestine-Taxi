import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'chart_legend.dart';

/// Responsive container for charts with adaptive sizing and layout
class ResponsiveChartContainer extends StatelessWidget {
  final Widget chart;
  final ChartLegend? legend;
  final Widget? description;
  final Widget? header;
  final double minHeight;
  final double maxHeight;
  final EdgeInsets padding;
  final ChartSize preferredSize;

  const ResponsiveChartContainer({
    super.key,
    required this.chart,
    this.legend,
    this.description,
    this.header,
    this.minHeight = 150,
    this.maxHeight = 400,
    this.padding = const EdgeInsets.all(16),
    this.preferredSize = ChartSize.small,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = _getScreenSize(constraints.maxWidth);
        final chartHeight = _getChartHeight(screenSize);
        final legendPosition = _getLegendPosition(screenSize);

        final showFullLegend = screenSize != ScreenSize.small;

        return Padding(
          padding: _getResponsivePadding(screenSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (if any)
              if (header != null) ...[
                header!,
                SizedBox(height: _getSpacing(screenSize)),
              ],

              // Top legend position
              if (legend != null && legendPosition == LegendPosition.top) ...[
                _buildLegend(showFullLegend),
                SizedBox(height: _getSpacing(screenSize)),
              ],

              // Chart with optional side legend
              if (legend != null && legendPosition == LegendPosition.left)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: _buildVerticalLegend(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: chartHeight,
                        child: chart,
                      ),
                    ),
                  ],
                )
              else if (legend != null && legendPosition == LegendPosition.right)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: chartHeight,
                        child: chart,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: _buildVerticalLegend(),
                    ),
                  ],
                )
              else
                SizedBox(
                  height: chartHeight,
                  child: chart,
                ),

              // Bottom legend position
              if (legend != null &&
                  legendPosition == LegendPosition.bottom) ...[
                SizedBox(height: _getSpacing(screenSize)),
                _buildLegend(showFullLegend),
              ],

              // Description (if any)
              if (description != null) ...[
                SizedBox(height: _getSpacing(screenSize) * 1.5),
                description!,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend(bool showFull) {
    if (!showFull && legend != null) {
      return CompactLegend(items: legend!.items);
    }
    return legend ?? const SizedBox.shrink();
  }

  Widget _buildVerticalLegend() {
    if (legend == null) return const SizedBox.shrink();
    return ChartLegend(
      items: legend!.items,
      layout: LegendLayout.vertical,
      showValues: legend!.showValues,
      onToggle: legend!.onToggle,
    );
  }

  ScreenSize _getScreenSize(double width) {
    if (width < 400) return ScreenSize.small;
    if (width < 700) return ScreenSize.medium;
    return ScreenSize.large;
  }

  double _getChartHeight(ScreenSize screenSize) {
    // Calculate base height based on preferred size (using fixed percentages)
    double baseHeight;
    switch (preferredSize) {
      case ChartSize.small:
        baseHeight = 160;
        break;
      case ChartSize.medium:
        baseHeight = 260;
        break;
      case ChartSize.large:
        baseHeight = 360;
        break;
      case ChartSize.extraLarge:
        baseHeight = 460;
        break;
    }

    // Adjust for screen size
    switch (screenSize) {
      case ScreenSize.small:
        baseHeight *= 0.8;
        break;
      case ScreenSize.medium:
        // Keep base height
        break;
      case ScreenSize.large:
        baseHeight *= 1.1;
        break;
    }

    return baseHeight.clamp(minHeight, maxHeight);
  }

  LegendPosition _getLegendPosition(ScreenSize screenSize) {
    if (legend == null) return LegendPosition.bottom;

    switch (screenSize) {
      case ScreenSize.small:
        return LegendPosition.bottom;
      case ScreenSize.medium:
        return legend!.position;
      case ScreenSize.large:
        return legend!.position;
    }
  }

  EdgeInsets _getResponsivePadding(ScreenSize screenSize) {
    // Reduce padding for small charts
    final effectivePadding = preferredSize == ChartSize.small 
        ? padding.copyWith(top: padding.top * 0.5, bottom: padding.bottom * 0.5)
        : padding;

    switch (screenSize) {
      case ScreenSize.small:
        return EdgeInsets.symmetric(
          horizontal: effectivePadding.horizontal * 0.5,
          vertical: effectivePadding.vertical * 0.5,
        );
      case ScreenSize.medium:
        return effectivePadding;
      case ScreenSize.large:
        return EdgeInsets.symmetric(
          horizontal: effectivePadding.horizontal * 1.25,
          vertical: effectivePadding.vertical,
        );
    }
  }

  double _getSpacing(ScreenSize screenSize) {
    switch (screenSize) {
      case ScreenSize.small:
        return 8;
      case ScreenSize.medium:
        return 12;
      case ScreenSize.large:
        return 16;
    }
  }
}

/// A responsive grid layout for multiple charts
class ResponsiveChartGrid extends StatelessWidget {
  final List<Widget> charts;
  final int smallScreenColumns;
  final int mediumScreenColumns;
  final int largeScreenColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveChartGrid({
    super.key,
    required this.charts,
    this.smallScreenColumns = 1,
    this.mediumScreenColumns = 2,
    this.largeScreenColumns = 2,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _getColumns(constraints.maxWidth);

        if (columns == 1) {
          return Column(
            children: charts
                .expand((chart) => [chart, SizedBox(height: runSpacing)])
                .take(charts.length * 2 - 1)
                .toList(),
          );
        }

        // Build rows
        final rows = <Widget>[];
        for (int i = 0; i < charts.length; i += columns) {
          final rowCharts = charts.skip(i).take(columns).toList();
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowCharts.asMap().entries.map((entry) {
                final isLast = entry.key == rowCharts.length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : spacing),
                    child: entry.value,
                  ),
                );
              }).toList(),
            ),
          );
          if (i + columns < charts.length) {
            rows.add(SizedBox(height: runSpacing));
          }
        }

        return Column(children: rows);
      },
    );
  }

  int _getColumns(double width) {
    if (width < 600) return smallScreenColumns;
    if (width < 900) return mediumScreenColumns;
    return largeScreenColumns;
  }
}

/// Responsive stat card for summary statistics
class ResponsiveStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? percentageChange;
  final String? subtitle;
  final Widget? sparkline;
  final VoidCallback? onTap;

  const ResponsiveStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.blue,
    this.percentageChange,
    this.subtitle,
    this.sparkline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 200;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.isDarkMode
                  ? color.withOpacity(0.08)
                  : color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 6 : 8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: isCompact ? 16 : 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isCompact ? 11 : 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (percentageChange != null) _buildTrendBadge(isCompact),
                  ],
                ),
                SizedBox(height: isCompact ? 8 : 12),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: isCompact ? 14 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: isCompact ? 10 : 11,
                    ),
                  ),
                ],
                if (sparkline != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: sparkline!,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrendBadge(bool isCompact) {
    final isPositive = percentageChange! >= 0;
    final trendColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: isCompact ? 10 : 12,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${percentageChange!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: trendColor,
              fontSize: isCompact ? 9 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum ScreenSize { small, medium, large }

enum ChartSize { small, medium, large, extraLarge }
