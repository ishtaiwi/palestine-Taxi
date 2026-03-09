import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A configurable legend widget for charts
class ChartLegend extends StatelessWidget {
  final List<LegendItem> items;
  final LegendLayout layout;
  final LegendPosition position;
  final bool showValues;
  final Function(int index, bool isVisible)? onToggle;
  final double spacing;

  const ChartLegend({
    super.key,
    required this.items,
    this.layout = LegendLayout.horizontal,
    this.position = LegendPosition.bottom,
    this.showValues = false,
    this.onToggle,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final legendItems = items.asMap().entries.map((entry) {
      return _buildLegendItem(entry.key, entry.value);
    }).toList();

    if (layout == LegendLayout.horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: legendItems
              .expand((item) => [item, SizedBox(width: spacing)])
              .take(legendItems.length * 2 - 1)
              .toList(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: legendItems
          .expand((item) => [item, SizedBox(height: spacing / 2)])
          .take(legendItems.length * 2 - 1)
          .toList(),
    );
  }

  Widget _buildLegendItem(int index, LegendItem item) {
    final isInteractive = onToggle != null;
    final isVisible = item.isVisible;

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color indicator
        Container(
          width: item.shape == LegendShape.line ? 20 : 12,
          height: item.shape == LegendShape.line ? 3 : 12,
          decoration: BoxDecoration(
            color: isVisible ? item.color : item.color.withOpacity(0.3),
            borderRadius: item.shape == LegendShape.circle
                ? BorderRadius.circular(6)
                : item.shape == LegendShape.line
                    ? BorderRadius.circular(1.5)
                    : BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        // Label
        Text(
          item.label,
          style: TextStyle(
            color: isVisible
                ? AppTheme.textPrimary
                : AppTheme.textSecondary.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            decoration: isVisible ? null : TextDecoration.lineThrough,
          ),
        ),
        // Optional value
        if (showValues && item.value != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.value!,
              style: TextStyle(
                color: item.color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );

    if (isInteractive) {
      return GestureDetector(
        onTap: () => onToggle!(index, !isVisible),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A compact inline legend for smaller spaces
class CompactLegend extends StatelessWidget {
  final List<LegendItem> items;
  final bool wrap;

  const CompactLegend({
    super.key,
    required this.items,
    this.wrap = true,
  });

  @override
  Widget build(BuildContext context) {
    final children = items.map((item) => _buildCompactItem(item)).toList();

    if (wrap) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: children,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: children
            .expand((item) => [item, const SizedBox(width: 12)])
            .take(children.length * 2 - 1)
            .toList(),
      ),
    );
  }

  Widget _buildCompactItem(LegendItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          item.label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Individual legend item data
class LegendItem {
  final String label;
  final Color color;
  final String? value;
  final LegendShape shape;
  final bool isVisible;

  const LegendItem({
    required this.label,
    required this.color,
    this.value,
    this.shape = LegendShape.circle,
    this.isVisible = true,
  });

  LegendItem copyWith({
    String? label,
    Color? color,
    String? value,
    LegendShape? shape,
    bool? isVisible,
  }) {
    return LegendItem(
      label: label ?? this.label,
      color: color ?? this.color,
      value: value ?? this.value,
      shape: shape ?? this.shape,
      isVisible: isVisible ?? this.isVisible,
    );
  }
}

enum LegendLayout { horizontal, vertical }

enum LegendPosition { top, bottom, left, right }

enum LegendShape { circle, square, line }
