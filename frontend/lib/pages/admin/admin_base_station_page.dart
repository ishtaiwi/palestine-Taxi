import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';

class AdminBaseStationPage extends StatefulWidget {
  const AdminBaseStationPage({super.key});

  @override
  State<AdminBaseStationPage> createState() => _AdminBaseStationPageState();
}

class _AdminBaseStationPageState extends State<AdminBaseStationPage> {
  List<Map<String, dynamic>> _stations = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedStation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getAllBaseStations();
      if (result['success'] == true) {
        setState(() {
          _stations = result['stations'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading stations: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createOrUpdateStation({
    Map<String, dynamic>? station,
  }) async {
    final nameController = TextEditingController(
      text: station?['name'] ?? '',
    );
    final latController = TextEditingController(
      text: station?['latitude']?.toString() ?? '',
    );
    final lngController = TextEditingController(
      text: station?['longitude']?.toString() ?? '',
    );
    final radiusController = TextEditingController(
      text: station?['geofence_radius_meters']?.toString() ?? '100',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(station == null ? 'Create Base Station' : 'Edit Base Station'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Main Station',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '31.9522',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '35.2332',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Geofence Radius (meters)',
                  hintText: '100',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        Map<String, dynamic> response;
        if (station == null) {
          response = await ApiService.createBaseStation(
            name: nameController.text,
            latitude: double.parse(latController.text),
            longitude: double.parse(lngController.text),
            geofenceRadiusMeters: int.parse(radiusController.text),
          );
        } else {
          response = await ApiService.updateBaseStation(
            stationid: station['stationid'].toString(),
            name: nameController.text,
            latitude: double.parse(latController.text),
            longitude: double.parse(lngController.text),
            geofenceRadiusMeters: int.parse(radiusController.text),
          );
        }

        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Success')),
            );
            _loadStations();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Error')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteStation(Map<String, dynamic> station) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Base Station'),
        content: Text('Are you sure you want to delete ${station['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final response = await ApiService.deleteBaseStation(
          station['stationid'].toString(),
        );
        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Base station deleted')),
            );
            _loadStations();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Base Stations'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createOrUpdateStation(),
            tooltip: 'Add Base Station',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No base stations found'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _createOrUpdateStation(),
                        child: const Text('Create First Base Station'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _stations.length,
                  itemBuilder: (context, index) {
                    final station = _stations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.location_city, size: 40),
                        title: Text(station['name'] ?? 'Unnamed Station'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Lat: ${station['latitude']}, Lng: ${station['longitude']}'),
                            Text(
                                'Radius: ${station['geofence_radius_meters']}m'),
                            Text(
                                'Status: ${station['is_active'] == true ? 'Active' : 'Inactive'}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _createOrUpdateStation(
                                station: station,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteStation(station),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedStation = station;
                          });
                          _mapController.move(
                            LatLng(
                              station['latitude']?.toDouble() ?? 31.9522,
                              station['longitude']?.toDouble() ?? 35.2332,
                            ),
                            15.0,
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

