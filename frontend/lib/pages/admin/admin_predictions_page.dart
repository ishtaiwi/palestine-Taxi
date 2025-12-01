import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
  Map<String, dynamic>? _insights;
  String? _applyingRecommendationId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lines = await ApiService.getAllLines();
      final selectedLine = lines.isNotEmpty
          ? lines.first['lineid'] as String?
          : null;
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
          backgroundColor: result['success'] == true
              ? Colors.green
              : Colors.red,
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
        backgroundColor: result['success'] == false
            ? Colors.red
            : Colors.blueGrey,
      ),
    );

    setState(() {
      _isRetraining = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A1A),
      appBar: AppBar(
        title: const Text(
          'AI Predictions',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E3A5F),
        iconTheme: const IconThemeData(color: Colors.white),
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
                style: const TextStyle(color: Colors.redAccent),
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
                            decoration: const InputDecoration(
                              labelText: 'Line',
                              filled: true,
                              fillColor: Color(0xFF10152A),
                              labelStyle: TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(),
                            ),
                            dropdownColor: const Color(0xFF10152A),
                            items: _lines
                                .map(
                                  (line) => DropdownMenuItem<String>(
                                    value: line['lineid'] as String?,
                                    child: Text(
                                      line['name_en'] ??
                                          line['linename'] ??
                                          'Line',
                                      style: const TextStyle(
                                        color: Colors.white,
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
          ? const Text(
              'No rush hour predictions available.',
              style: TextStyle(color: Colors.white70),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Expected bookings: ${prediction['expectedBookings']?.toStringAsFixed(1) ?? prediction['expectedBookings']}\n'
                    'Confidence: ${(((prediction['confidence'] ?? 0) as num) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemCount: predictions.length.clamp(0, 5),
            ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty) {
      return _buildPanel(
        title: 'Recommendations',
        child: const Text(
          'No active recommendations. Model will suggest changes once demand spikes are detected.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return _buildPanel(
      title: 'Recommendations',
      child: Column(
        children: _recommendations.map((rec) {
          final recId = rec['id']?.toString() ?? '';
          return Card(
            color: const Color(0xFF0F1B2B),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec['summary'] ?? 'Recommendation',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec['details'] ?? '',
                    style: const TextStyle(color: Colors.white70),
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
                        backgroundColor: const Color(0xFF0F1B2B),
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
                        backgroundColor: const Color(0xFF0F1B2B),
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
                          backgroundColor: const Color(0xFF0F1B2B),
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
      ),
    );
  }

  Widget _buildInsightsSection() {
    final topLines = (_insights?['topLines'] as List<dynamic>?) ?? [];

    return _buildPanel(
      title: 'Network Insights',
      child: topLines.isEmpty
          ? const Text(
              'No demand insights yet.',
              style: TextStyle(color: Colors.white70),
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
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Avg utilization ${(data['avgUtilization'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
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
        color: const Color(0xFF0B1324),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
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
