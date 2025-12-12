import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminPredictionsPage extends StatefulWidget {
  const AdminPredictionsPage({super.key});

  @override
  State<AdminPredictionsPage> createState() => _AdminPredictionsPageState();
}

class _AdminPredictionsPageState extends State<AdminPredictionsPage> {
  bool _isLoading = true;
  bool _isRetraining = false;
  String? _error;
  String? _selectedLineId;
  List<Map<String, dynamic>> _lines = [];
  Map<String, dynamic>? _predictionData;
  List<Map<String, dynamic>> _recommendations = [];
  List<Map<String, dynamic>> _filteredRecommendations = [];
  Map<String, dynamic>? _insights;
  String? _applyingRecommendationId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  TimeOfDay? _filterStartTime;
  TimeOfDay? _filterEndTime;
  bool _isFilterActive = false;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lines = await ApiService.getAllLines();
      final selectedLine =
          lines.isNotEmpty ? lines.first['lineid'] as String? : null;
      Map<String, dynamic>? predictions;
      List<Map<String, dynamic>> recommendations = [];

      if (selectedLine != null) {
        predictions = await ApiService.getRushHourPredictionsAdmin(
          lineId: selectedLine,
        );
        recommendations = await ApiService.getScheduleRecommendationsAdmin(
          lineIds: [selectedLine],
        );
      }

      final insights = await ApiService.getPredictionInsightsAdmin(limit: 5);

      setState(() {
        _lines = lines;
        _selectedLineId = selectedLine;
        _predictionData = predictions?['data'] ?? predictions;
        _recommendations = recommendations;
        _filteredRecommendations = _applyDateFilter(recommendations);
        _insights = insights['data'] ?? insights;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onLineChanged(String? lineId) async {
    if (lineId == null) return;

    setState(() {
      _selectedLineId = lineId;
      _isLoading = true;
    });

    try {
      final predictions = await ApiService.getRushHourPredictionsAdmin(
        lineId: lineId,
      );
      final recommendations = await ApiService.getScheduleRecommendationsAdmin(
        lineIds: [lineId],
      );

      setState(() {
        _predictionData = predictions['data'] ?? predictions;
        _recommendations = recommendations;
        _filteredRecommendations = _applyDateFilter(recommendations);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _applyRecommendation(Map<String, dynamic> recommendation) async {
    setState(() {
      _applyingRecommendationId = recommendation['id']?.toString();
    });

    try {
      final result = await ApiService.applyScheduleRecommendationAdmin(
        recommendation,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ?? 'Recommendation applied successfully',
          ),
          backgroundColor:
              result['success'] == true ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      if (result['success'] == true && _selectedLineId != null) {
        // Refresh recommendations after successful application
        await _onLineChanged(_selectedLineId);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error applying recommendation: ${error.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingRecommendationId = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> _applyDateFilter(
      List<Map<String, dynamic>> recommendations) {
    if (!_isFilterActive) {
      return recommendations;
    }

    return recommendations.where((rec) {
      final targetDateStr = rec['targetDate']?.toString();
      final hour = rec['hour'];

      if (targetDateStr == null) return false;

      DateTime? targetDate;
      try {
        // Try parsing as ISO date string (YYYY-MM-DD)
        targetDate = DateTime.parse(targetDateStr);
      } catch (e) {
        return false;
      }

      // Check date range
      if (_filterStartDate != null) {
        final startDate = DateTime(
          _filterStartDate!.year,
          _filterStartDate!.month,
          _filterStartDate!.day,
        );
        final targetDateOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        if (targetDateOnly.isBefore(startDate)) {
          return false;
        }
      }

      if (_filterEndDate != null) {
        final endDate = DateTime(
          _filterEndDate!.year,
          _filterEndDate!.month,
          _filterEndDate!.day,
        );
        final targetDateOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        if (targetDateOnly.isAfter(endDate)) {
          return false;
        }
      }

      // Check time range if specified
      if (_filterStartTime != null || _filterEndTime != null) {
        final recHour = hour is num
            ? hour.toInt()
            : int.tryParse(hour?.toString() ?? '0') ?? 0;

        if (_filterStartTime != null) {
          if (recHour < _filterStartTime!.hour) {
            return false;
          }
        }

        if (_filterEndTime != null) {
          if (recHour > _filterEndTime!.hour) {
            return false;
          }
        }
      }

      return true;
    }).toList();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _filterStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: AppTheme.datePickerColor,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked;
        _isFilterActive = true;
        _filteredRecommendations = _applyDateFilter(_recommendations);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _filterEndDate ?? _filterStartDate ?? DateTime.now(),
      firstDate: _filterStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: AppTheme.datePickerColor,
              onSurface: AppTheme.textPrimary,
            ),
            dialogBackgroundColor: AppTheme.getCardBackground(0.95),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterEndDate = picked;
        _isFilterActive = true;
        _filteredRecommendations = _applyDateFilter(_recommendations);
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _filterStartTime ?? const TimeOfDay(hour: 0, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: AppTheme.datePickerColor,
              onSurface: AppTheme.textPrimary,
            ),
            dialogBackgroundColor: AppTheme.getCardBackground(0.95),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterStartTime = picked;
        _isFilterActive = true;
        _filteredRecommendations = _applyDateFilter(_recommendations);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _filterEndTime ?? const TimeOfDay(hour: 23, minute: 59),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: AppTheme.datePickerColor,
              onSurface: AppTheme.textPrimary,
            ),
            dialogBackgroundColor: AppTheme.getCardBackground(0.95),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterEndTime = picked;
        _isFilterActive = true;
        _filteredRecommendations = _applyDateFilter(_recommendations);
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _filterStartDate = null;
      _filterEndDate = null;
      _filterStartTime = null;
      _filterEndTime = null;
      _isFilterActive = false;
      _filteredRecommendations = _recommendations;
    });
  }

  Future<void> _triggerRetrain() async {
    setState(() {
      _isRetraining = true;
    });

    final result = await ApiService.triggerPredictionRetrain(
      lineId: _selectedLineId,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message'] ?? 'Retrain triggered'),
        backgroundColor:
            result['success'] == false ? Colors.red : Colors.blueGrey,
      ),
    );

    setState(() {
      _isRetraining = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'AI Predictions',
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.appBarColor,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            onPressed: _isRetraining ? null : _triggerRetrain,
            tooltip: 'Retrain model',
            icon: _isRetraining
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.deepPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedLineId,
                                decoration: InputDecoration(
                                  labelText: 'Line',
                                  filled: true,
                                  fillColor: AppTheme.getCardBackground(0.1),
                                  labelStyle:
                                      TextStyle(color: AppTheme.textSecondary),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        color: AppTheme.getCardBorder(0.2)),
                                  ),
                                ),
                                dropdownColor: AppTheme.getCardBackground(0.9),
                                items: _lines
                                    .map(
                                      (line) => DropdownMenuItem<String>(
                                        value: line['lineid'] as String?,
                                        child: Text(
                                          line['name_en'] ??
                                              line['linename'] ??
                                              'Line',
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _onLineChanged,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildPredictionsSection(),
                        const SizedBox(height: 16),
                        _buildRecommendationsSection(),
                        const SizedBox(height: 16),
                        _buildInsightsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPredictionsSection() {
    final predictions =
        (_predictionData?['predictions'] as List<dynamic>?) ?? [];

    return _buildPanel(
      title: 'Upcoming Rush Hours',
      child: predictions.isEmpty
          ? Text(
              'No rush hour predictions available.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final prediction = predictions[index] as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.trending_up,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    '${prediction['date']} • ${_formatHour(prediction['hour'])}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Expected bookings: ${prediction['expectedBookings']?.toStringAsFixed(1) ?? prediction['expectedBookings']}\n'
                    'Confidence: ${(((prediction['confidence'] ?? 0) as num) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              },
              separatorBuilder: (_, __) =>
                  Divider(color: AppTheme.getCardBorder(0.12)),
              itemCount: predictions.length.clamp(0, 5),
            ),
    );
  }

  Widget _buildRecommendationsSection() {
    final displayRecommendations =
        _isFilterActive ? _filteredRecommendations : _recommendations;

    return _buildPanel(
      title: 'Recommendations',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date/Time Filter UI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.getCardBackground(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isFilterActive
                    ? Colors.orange.withOpacity(0.7)
                    : AppTheme.getCardBorder(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt,
                      size: 18,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by Date & Time',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_isFilterActive)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Start Date
                    OutlinedButton.icon(
                      onPressed: _selectStartDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _filterStartDate != null
                            ? DateFormat('MMM dd, yyyy')
                                .format(_filterStartDate!)
                            : 'Start Date',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(
                          color: AppTheme.getCardBorder(0.3),
                        ),
                      ),
                    ),
                    // End Date
                    OutlinedButton.icon(
                      onPressed: _selectEndDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _filterEndDate != null
                            ? DateFormat('MMM dd, yyyy').format(_filterEndDate!)
                            : 'End Date',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(
                          color: AppTheme.getCardBorder(0.3),
                        ),
                      ),
                    ),
                    // Start Time
                    OutlinedButton.icon(
                      onPressed: _selectStartTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        _filterStartTime != null
                            ? _filterStartTime!.format(context)
                            : 'Start Time',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(
                          color: AppTheme.getCardBorder(0.3),
                        ),
                      ),
                    ),
                    // End Time
                    OutlinedButton.icon(
                      onPressed: _selectEndTime,
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(
                        _filterEndTime != null
                            ? _filterEndTime!.format(context)
                            : 'End Time',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(
                          color: AppTheme.getCardBorder(0.3),
                        ),
                      ),
                    ),
                    // Quick filters
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.today, size: 16),
                      tooltip: 'Quick Filters',
                      color: AppTheme.getCardBackground(),
                      onSelected: (value) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        setState(() {
                          switch (value) {
                            case 'today':
                              _filterStartDate = today;
                              _filterEndDate = today;
                              break;
                            case 'tomorrow':
                              _filterStartDate =
                                  today.add(const Duration(days: 1));
                              _filterEndDate =
                                  today.add(const Duration(days: 1));
                              break;
                            case 'next7days':
                              _filterStartDate = today;
                              _filterEndDate =
                                  today.add(const Duration(days: 6));
                              break;
                            case 'next30days':
                              _filterStartDate = today;
                              _filterEndDate =
                                  today.add(const Duration(days: 29));
                              break;
                          }
                          _isFilterActive = true;
                          _filteredRecommendations =
                              _applyDateFilter(_recommendations);
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'today',
                          child: Text('Today'),
                        ),
                        const PopupMenuItem(
                          value: 'tomorrow',
                          child: Text('Tomorrow'),
                        ),
                        const PopupMenuItem(
                          value: 'next7days',
                          child: Text('Next 7 Days'),
                        ),
                        const PopupMenuItem(
                          value: 'next30days',
                          child: Text('Next 30 Days'),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_isFilterActive) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Showing ${displayRecommendations.length} of ${_recommendations.length} recommendations',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recommendations List
          if (displayRecommendations.isEmpty)
            Text(
              _recommendations.isEmpty
                  ? 'No active recommendations. Model will suggest changes once demand spikes are detected.'
                  : 'No recommendations match the selected date/time filter.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ...displayRecommendations.map((rec) {
              final recId = rec['id']?.toString() ?? '';
              return Card(
                color: AppTheme.getCardBackground(0.1),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rec['summary'] ?? 'Recommendation',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (rec['targetDate'] != null || rec['hour'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                rec['targetDate'] != null && rec['hour'] != null
                                    ? '${rec['targetDate']} • ${_formatHour(rec['hour'])}'
                                    : rec['targetDate'] != null
                                        ? rec['targetDate'].toString()
                                        : _formatHour(rec['hour']),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        rec['details'] ?? '',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              'Confidence ${(rec['confidence'] ?? rec['priority'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.orange),
                            ),
                            backgroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                          const Spacer(),
                          Chip(
                            label: Text(
                              'Utilization ${(rec['utilization'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.orange),
                            ),
                            backgroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: Colors.orange),
                            ),
                          ),
                          if (rec['totalAvailableSeats'] != null)
                            Chip(
                              label: Text(
                                'Available: ${rec['totalAvailableSeats']}',
                                style: const TextStyle(color: Colors.lightBlue),
                              ),
                              backgroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: const BorderSide(color: Colors.lightBlue),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _applyingRecommendationId == recId
                              ? null
                              : () => _applyRecommendation(rec),
                          icon: _applyingRecommendationId == recId
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle),
                          label: Text(
                            _applyingRecommendationId == recId
                                ? 'Applying...'
                                : 'Accept Recommendation',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    final topLines = (_insights?['topLines'] as List<dynamic>?) ?? [];

    return _buildPanel(
      title: 'Network Insights',
      child: topLines.isEmpty
          ? Text(
              'No demand insights yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          : Column(
              children: topLines.map((line) {
                final data = line as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.directions_transit,
                    color: Colors.lightBlueAccent,
                  ),
                  title: Text(
                    data['lineid'] ?? '',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    'Avg utilization ${(data['avgUtilization'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPanel({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.getCardBorder(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  String _formatHour(dynamic hour) {
    final intHour = (hour is num)
        ? hour.toInt()
        : int.tryParse(hour?.toString() ?? '0') ?? 0;
    return '${intHour.toString().padLeft(2, '0')}:00';
  }
}
