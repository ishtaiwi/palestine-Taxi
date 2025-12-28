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
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'AI Predictions',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
          ),
        ),
        backgroundColor: AppTheme.isDarkMode
            ? const Color(0xFF1C2541)
            : AppTheme.appBarColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: isSmallScreen ? 20.0 : 24.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(isSmallScreen ? 16.0 : 20.0),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isRetraining ? null : _triggerRetrain,
            tooltip: 'Retrain model',
            color: Colors.white,
            iconSize: isSmallScreen ? 20.0 : 24.0,
            icon: _isRetraining
                ? SizedBox(
                    width: isSmallScreen ? 16.0 : 18.0,
                    height: isSmallScreen ? 16.0 : 18.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, 
                      color: Colors.white
                    ),
                  )
                : Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(basePadding),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: isSmallScreen ? 14.0 : 16.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.deepPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(basePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
                                decoration: BoxDecoration(
                                  color: AppTheme.isDarkMode ? AppTheme.cardBackground : Colors.white,
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                                  border: Border.all(
                                    color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _selectedLineId,
                                  decoration: InputDecoration(
                                    labelText: 'Line',
                                    filled: true,
                                    fillColor: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                                    labelStyle: TextStyle(
                                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                      borderSide: BorderSide(
                                        color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                                        width: 2,
                                      ),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.directions_bus_rounded,
                                      color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                                      size: isSmallScreen ? 20.0 : 24.0,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isSmallScreen ? 16.0 : 20.0,
                                      vertical: isSmallScreen ? 12.0 : 16.0,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                    fontSize: isSmallScreen ? 14.0 : 16.0,
                                  ),
                                  dropdownColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
                                  isExpanded: true,
                                  selectedItemBuilder: (context) {
                                    return _lines.map((line) {
                                      return Text(
                                        line['name_en'] ?? line['linename'] ?? 'Line',
                                        style: TextStyle(
                                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    }).toList();
                                  },
                                  items: _lines.map((line) {
                                    final isSelected = line['lineid'] == _selectedLineId;
                                    // Generate a deterministic color based on line ID hash
                                    final int colorValue = (line['lineid'].hashCode & 0xFFFFFF) | 0xFF000000;
                                    final Color lineAccentColor = Color(colorValue).withOpacity(1.0);
                                    
                                    return DropdownMenuItem<String>(
                                      value: line['lineid'] as String?,
                                      child: Builder(
                                        builder: (context) {
                                          final screenWidth = MediaQuery.of(context).size.width;
                                          final isSmallScreen = screenWidth < 360;
                                          
                                          return Container(
                                            width: double.infinity,
                                            margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 3.0 : 4.0),
                                            padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                                            decoration: BoxDecoration(
                                              color: isSelected 
                                                  ? (AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade100)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                                              border: Border.all(
                                                color: isSelected 
                                                    ? lineAccentColor 
                                                    : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: isSmallScreen ? 3.0 : 4.0,
                                                  height: isSmallScreen ? 20.0 : 24.0,
                                                  decoration: BoxDecoration(
                                                    color: lineAccentColor,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                                                Expanded(
                                                  child: Text(
                                                    line['name_en'] ?? line['linename'] ?? 'Line',
                                                    style: TextStyle(
                                                      color: isSelected 
                                                          ? (AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)
                                                          : (AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isSelected)
                                                  Icon(
                                                    Icons.check_rounded,
                                                    color: lineAccentColor,
                                                    size: isSmallScreen ? 18.0 : 20.0,
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    // Trigger rebuild to update selected state styling
                                    (context as Element).markNeedsBuild();
                                    _onLineChanged(value);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        _buildPredictionsSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        _buildRecommendationsSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        _buildInsightsSection(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPredictionsSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final predictions =
        (_predictionData?['predictions'] as List<dynamic>?) ?? [];

    return _buildPanel(
      title: 'Upcoming Rush Hours',
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: predictions.isEmpty
          ? Text(
              'No rush hour predictions available.',
              style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final prediction = predictions[index] as Map<String, dynamic>;
                return Container(
                  padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                  decoration: BoxDecoration(
                    color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    border: Border.all(
                      color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          color: Colors.orangeAccent,
                          size: isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${prediction['date']} • ${_formatHour(prediction['hour'])}',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                            Text(
                              'Expected bookings: ${prediction['expectedBookings']?.toStringAsFixed(1) ?? prediction['expectedBookings']}\n'
                              'Confidence: ${(((prediction['confidence'] ?? 0) as num) * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                                fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => SizedBox(height: isSmallScreen ? 10.0 : 12.0),
              itemCount: predictions.length.clamp(0, 5),
            ),
    );
  }

  Widget _buildRecommendationsSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final displayRecommendations =
        _isFilterActive ? _filteredRecommendations : _recommendations;

    return _buildPanel(
      title: 'Recommendations',
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date/Time Filter UI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isFilterActive
                    ? Colors.orange.withOpacity(0.5)
                    : (AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filter by Date & Time',
                      style: TextStyle(
                        color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_isFilterActive)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Start Date
                    OutlinedButton.icon(
                      onPressed: _selectStartDate,
                      icon: Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textPrimary),
                      label: Text(
                        _filterStartDate != null
                            ? DateFormat('MMM dd, yyyy').format(_filterStartDate!)
                            : 'Start Date',
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // End Date
                    OutlinedButton.icon(
                      onPressed: _selectEndDate,
                      icon: Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textPrimary),
                      label: Text(
                        _filterEndDate != null
                            ? DateFormat('MMM dd, yyyy').format(_filterEndDate!)
                            : 'End Date',
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // Start Time
                    OutlinedButton.icon(
                      onPressed: _selectStartTime,
                      icon: Icon(Icons.access_time_rounded, size: 16, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textPrimary),
                      label: Text(
                        _filterStartTime != null
                            ? _filterStartTime!.format(context)
                            : 'Start Time',
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // End Time
                    OutlinedButton.icon(
                      onPressed: _selectEndTime,
                      icon: Icon(Icons.access_time_rounded, size: 16, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textPrimary),
                      label: Text(
                        _filterEndTime != null
                            ? _filterEndTime!.format(context)
                            : 'End Time',
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    // Quick filters
                    PopupMenuButton<String>(
                      icon: Icon(Icons.tune_rounded, size: 20, color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
                      tooltip: 'Quick Filters',
                      color: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
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
                        PopupMenuItem(
                          value: 'today',
                          child: Text('Today', style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
                        ),
                        PopupMenuItem(
                          value: 'tomorrow',
                          child: Text('Tomorrow', style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
                        ),
                        PopupMenuItem(
                          value: 'next7days',
                          child: Text('Next 7 Days', style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
                        ),
                        PopupMenuItem(
                          value: 'next30days',
                          child: Text('Next 30 Days', style: TextStyle(color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary)),
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
                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _recommendations.isEmpty
                    ? 'No active recommendations. Model will suggest changes once demand spikes are detected.'
                    : 'No recommendations match the selected date/time filter.',
                style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
              ),
            )
          else
            ...displayRecommendations.map((rec) {
              final recId = rec['id']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.isDarkMode ? Colors.orange.withOpacity(0.3) : Colors.orange.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              rec['summary'] ?? 'Recommendation',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (rec['targetDate'] != null || rec['hour'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
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
                      const SizedBox(height: 12),
                      Text(
                        rec['details'] ?? '',
                        style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTag(
                            'Confidence ${(rec['confidence'] ?? rec['priority'] ?? 0).toStringAsFixed(2)}',
                            Colors.orange,
                          ),
                          _buildTag(
                            'Utilization ${(rec['utilization'] ?? 0).toStringAsFixed(2)}',
                            Colors.blueAccent,
                          ),
                          if (rec['totalAvailableSeats'] != null)
                            _buildTag(
                              'Available: ${rec['totalAvailableSeats']}',
                              Colors.green,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
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
                              : const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _applyingRecommendationId == recId
                                ? 'Applying...'
                                : 'Accept Recommendation',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
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

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInsightsSection({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final topLines = (_insights?['topLines'] as List<dynamic>?) ?? [];

    return _buildPanel(
      title: 'Network Insights',
      isSmallScreen: isSmallScreen,
      isMediumScreen: isMediumScreen,
      child: topLines.isEmpty
          ? Text(
              'No demand insights yet.',
              style: TextStyle(color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary),
            )
          : Column(
              children: topLines.map((line) {
                final data = line as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.lightBlueAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_transit_rounded,
                          color: Colors.lightBlueAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['lineid'] ?? '',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Avg utilization ${(data['avgUtilization'] ?? 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPanel({required String title, required Widget child, bool isSmallScreen = false, bool isMediumScreen = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode ? AppTheme.cardBackground : Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(
          color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
            ),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
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
