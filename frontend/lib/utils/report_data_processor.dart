import 'package:intl/intl.dart';

class ReportDataProcessor {
  /// Groups time-series data by time period (day, week, month)
  static List<Map<String, dynamic>> groupDataByTimePeriod(
    List<dynamic> data,
    String groupBy,
    String dateField,
  ) {
    if (data.isEmpty) return [];

    final Map<String, List<dynamic>> groups = {};
    final periodFormats = {
      'day': (DateTime date) => DateFormat('yyyy-MM-dd').format(date),
      'week': (DateTime date) {
        final d = DateTime(date.year, date.month, date.day);
        final weekStart = d.subtract(Duration(days: d.weekday - 1));
        return DateFormat('yyyy-MM-dd').format(weekStart);
      },
      'month': (DateTime date) => DateFormat('yyyy-MM').format(date),
    };

    final format = periodFormats[groupBy] ?? periodFormats['day']!;

    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final dateValue = item[dateField];
        if (dateValue != null) {
          DateTime? date;
          if (dateValue is String) {
            date = DateTime.tryParse(dateValue);
          } else if (dateValue is DateTime) {
            date = dateValue;
          }

          if (date != null) {
            final key = format(date);
            groups.putIfAbsent(key, () => []).add(item);
          }
        }
      }
    }

    return groups.entries
        .map((entry) => {
              'date': entry.key,
              'items': entry.value,
            })
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
  }

  /// Formats currency values
  static String formatCurrency(dynamic amount, {String symbol = '₪'}) {
    if (amount == null) return '$symbol 0.00';
    final num value =
        amount is num ? amount : (double.tryParse(amount.toString()) ?? 0);
    return '$symbol ${value.toStringAsFixed(2)}';
  }

  /// Formats currency values in compact form (K, M)
  static String formatCurrencyCompact(dynamic amount, {String symbol = '₪'}) {
    if (amount == null) return '$symbol 0';
    final num value =
        amount is num ? amount : (double.tryParse(amount.toString()) ?? 0);

    if (value >= 1000000) {
      return '$symbol ${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '$symbol ${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol ${value.toStringAsFixed(0)}';
  }

  /// Formats dates for display
  static String formatDate(dynamic date, {String format = 'yyyy-MM-dd'}) {
    if (date == null) return '';
    DateTime? dateTime;
    if (date is String) {
      dateTime = DateTime.tryParse(date);
    } else if (date is DateTime) {
      dateTime = date;
    }
    if (dateTime == null) return date.toString();
    return DateFormat(format).format(dateTime);
  }

  /// Formats dates with time
  static String formatDateTime(dynamic date) {
    return formatDate(date, format: 'yyyy-MM-dd HH:mm');
  }

  /// Calculates percentage
  static double calculatePercentage(dynamic value, dynamic total) {
    if (total == null || total == 0) return 0.0;
    final num val =
        value is num ? value : (double.tryParse(value.toString()) ?? 0);
    final num tot =
        total is num ? total : (double.tryParse(total.toString()) ?? 0);
    return (val / tot * 100);
  }

  /// Formats percentage string
  static String formatPercentage(dynamic value, dynamic total,
      {int decimals = 1}) {
    final percentage = calculatePercentage(value, total);
    return '${percentage.toStringAsFixed(decimals)}%';
  }

  /// Aggregates data by line
  static List<Map<String, dynamic>> aggregateByLine(
    List<dynamic> data,
    String lineIdField,
    String lineNameField,
    String valueField,
  ) {
    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final lineid = item[lineIdField]?.toString() ?? 'unknown';
        final linename = item[lineNameField]?.toString() ?? 'Unknown';
        final value = item[valueField] ?? 0;

        if (!aggregated.containsKey(lineid)) {
          aggregated[lineid] = {
            'lineid': lineid,
            'linename': linename,
            'value': 0,
          };
        }

        final num val =
            value is num ? value : (double.tryParse(value.toString()) ?? 0);
        aggregated[lineid]!['value'] =
            (aggregated[lineid]!['value'] as num) + val;
      }
    }

    return aggregated.values.toList()
      ..sort((a, b) => (b['value'] as num).compareTo(a['value'] as num));
  }

  /// Gets date range for preset periods
  static Map<String, DateTime> getDateRange(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period) {
      case 'today':
        return {
          'start': today,
          'end': today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        };
      case 'last7days':
        return {
          'start': today.subtract(const Duration(days: 6)),
          'end': today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        };
      case 'last30days':
        return {
          'start': today.subtract(const Duration(days: 29)),
          'end': today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        };
      case 'last90days':
        return {
          'start': today.subtract(const Duration(days: 89)),
          'end': today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        };
      case 'thisMonth':
        return {
          'start': DateTime(now.year, now.month, 1),
          'end': DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(seconds: 1)),
        };
      case 'lastMonth':
        return {
          'start': DateTime(now.year, now.month - 1, 1),
          'end': DateTime(now.year, now.month, 1)
              .subtract(const Duration(seconds: 1)),
        };
      default:
        return {
          'start': today.subtract(const Duration(days: 29)),
          'end': today
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1)),
        };
    }
  }

  /// Formats date range string
  static String formatDateRange(DateTime start, DateTime end) {
    final startStr = formatDate(start, format: 'MMM dd');
    final endStr = formatDate(end, format: 'MMM dd, yyyy');
    return '$startStr - $endStr';
  }

  /// Determines appropriate groupBy based on date range
  static String determineGroupBy(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    if (days <= 7) return 'day';
    if (days <= 30) return 'day';
    if (days <= 90) return 'week';
    return 'month';
  }
}
