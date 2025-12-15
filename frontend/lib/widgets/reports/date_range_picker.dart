import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_data_processor.dart';

class DateRangePicker extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, DateTime) onDateRangeChanged;
  final bool isArabic;

  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    this.isArabic = false,
  });

  @override
  State<DateRangePicker> createState() => _DateRangePickerState();
}

class _DateRangePickerState extends State<DateRangePicker> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
  }

  @override
  void didUpdateWidget(DateRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate ||
        oldWidget.endDate != widget.endDate) {
      _startDate = widget.startDate;
      _endDate = widget.endDate;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: AppTheme.backgroundColor,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      widget.onDateRangeChanged(_startDate, _endDate);
    }
  }

  void _selectPreset(String period) {
    final range = ReportDataProcessor.getDateRange(period);
    setState(() {
      _startDate = range['start']!;
      _endDate = range['end']!;
    });
    widget.onDateRangeChanged(_startDate, _endDate);
  }

  @override
  Widget build(BuildContext context) {
    final texts = widget.isArabic
        ? {
            'dateRange': 'نطاق التاريخ',
            'custom': 'مخصص',
            'today': 'اليوم',
            'last7days': 'آخر 7 أيام',
            'last30days': 'آخر 30 يوم',
            'last90days': 'آخر 90 يوم',
            'thisMonth': 'هذا الشهر',
            'lastMonth': 'الشهر الماضي',
          }
        : {
            'dateRange': 'Date Range',
            'custom': 'Custom',
            'today': 'Today',
            'last7days': 'Last 7 Days',
            'last30days': 'Last 30 Days',
            'last90days': 'Last 90 Days',
            'thisMonth': 'This Month',
            'lastMonth': 'Last Month',
          };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getCardBorder(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            texts['dateRange']!,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton(texts['today']!, () => _selectPreset('today')),
              _buildPresetButton(
                  texts['last7days']!, () => _selectPreset('last7days')),
              _buildPresetButton(
                  texts['last30days']!, () => _selectPreset('last30days')),
              _buildPresetButton(
                  texts['last90days']!, () => _selectPreset('last90days')),
              _buildPresetButton(
                  texts['thisMonth']!, () => _selectPreset('thisMonth')),
              _buildPresetButton(
                  texts['lastMonth']!, () => _selectPreset('lastMonth')),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDateRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.getCardBorder(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${ReportDataProcessor.formatDate(_startDate)} - ${ReportDataProcessor.formatDate(_endDate)}',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.getCardBorder(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

