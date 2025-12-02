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
  bool _showMap = true;
  bool _mapReady = false;

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
          final stationsList = result['stations'];
          if (stationsList is List) {
            _stations = stationsList
                .whereType<Map<String, dynamic>>()
                .map((station) => Map<String, dynamic>.from(station))
                .toList();
          } else {
            _stations = [];
          }
          // Set initial map center if stations exist
          if (_stations.isNotEmpty && _selectedStation == null) {
            _selectedStation = _stations[0];
            // Center map after it's ready
            if (_mapReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _centerMapOnStation(_selectedStation!);
              });
            }
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to load stations')),
          );
        }
      }
    } catch (e) {
      print('Error loading stations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _centerMapOnStation(Map<String, dynamic> station) {
    if (!_mapReady) {
      // Map not ready yet, will center after map is ready
      return;
    }
    final lat = station['latitude']?.toDouble() ?? 31.9522;
    final lng = station['longitude']?.toDouble() ?? 35.2332;
    _mapController.move(LatLng(lat, lng), 15.0);
  }

  Future<void> _createOrUpdateStation({
    Map<String, dynamic>? station,
  }) async {
    // Show map picker dialog
    final result = await _showMapPickerDialog(station: station);
    if (result != null) {
      try {
        Map<String, dynamic> response;
        if (station == null) {
          response = await ApiService.createBaseStation(
            name: result['name'] as String,
            latitude: result['latitude'] as double,
            longitude: result['longitude'] as double,
            geofenceRadiusMeters: result['geofenceRadiusMeters'] as int?,
          );
        } else {
          response = await ApiService.updateBaseStation(
            stationid: station['stationid'].toString(),
            name: result['name'] as String,
            latitude: result['latitude'] as double,
            longitude: result['longitude'] as double,
            geofenceRadiusMeters: result['geofenceRadiusMeters'] as int?,
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

  Future<Map<String, dynamic>?> _showMapPickerDialog({
    Map<String, dynamic>? station,
  }) async {
    final nameController = TextEditingController(
      text: station?['name'] ?? '',
    );
    final radiusController = TextEditingController(
      text: station?['geofence_radius_meters']?.toString() ?? '100',
    );

    // Initialize location from station or default
    LatLng selectedLocation = station != null
        ? LatLng(
            station['latitude']?.toDouble() ?? 31.9522,
            station['longitude']?.toDouble() ?? 35.2332,
          )
        : _stations.isNotEmpty
            ? LatLng(
                _stations[0]['latitude']?.toDouble() ?? 31.9522,
                _stations[0]['longitude']?.toDouble() ?? 35.2332,
              )
            : const LatLng(31.9522, 35.2332);

    final pickerMapController = MapController();
    bool pickerMapReady = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  station == null ? 'Create Base Station' : 'Edit Base Station',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Map
                Expanded(
                  child: FlutterMap(
                    mapController: pickerMapController,
                    options: MapOptions(
                      initialCenter: selectedLocation,
                      initialZoom: 15.0,
                      onMapReady: () {
                        setDialogState(() {
                          pickerMapReady = true;
                        });
                      },
                      onTap: (tapPosition, point) {
                        if (pickerMapReady) {
                          setDialogState(() {
                            selectedLocation = point;
                            pickerMapController.move(point, pickerMapController.camera.zoom);
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.taxi_palestine_app',
                      ),
                      // Selected location marker
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedLocation,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                      // Geofence circle preview
                      if (radiusController.text.isNotEmpty)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: selectedLocation,
                              radius: (int.tryParse(radiusController.text) ?? 100).toDouble(),
                              color: Colors.blue.withOpacity(0.2),
                              borderColor: Colors.blue,
                              useRadiusInMeter: true,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Form fields
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'Main Station',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: selectedLocation.latitude.toStringAsFixed(6),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: selectedLocation.longitude.toStringAsFixed(6),
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                          border: OutlineInputBorder(),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(
                    labelText: 'Geofence Radius (meters)',
                    hintText: '100',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 16),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Name is required')),
                          );
                          return;
                        }
                        Navigator.pop(
                          context,
                          {
                            'name': nameController.text,
                            'latitude': selectedLocation.latitude,
                            'longitude': selectedLocation.longitude,
                            'geofenceRadiusMeters': int.tryParse(radiusController.text) ?? 100,
                          },
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response['message'] ?? 'Failed to delete')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Base Stations'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
            tooltip: _showMap ? 'Show List' : 'Show Map',
          ),
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
              : _showMap
                  ? _buildMapView()
                  : _buildListView(),
    );
  }

  Widget _buildMapView() {
    // Determine center point
    LatLng center = _selectedStation != null
        ? LatLng(
            _selectedStation!['latitude']?.toDouble() ?? 31.9522,
            _selectedStation!['longitude']?.toDouble() ?? 35.2332,
          )
        : _stations.isNotEmpty
            ? LatLng(
                _stations[0]['latitude']?.toDouble() ?? 31.9522,
                _stations[0]['longitude']?.toDouble() ?? 35.2332,
              )
            : const LatLng(31.9522, 35.2332);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onMapReady: () {
              setState(() {
                _mapReady = true;
              });
              // Center on selected station if exists
              if (_selectedStation != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _centerMapOnStation(_selectedStation!);
                });
              }
            },
            onTap: (tapPosition, point) {
              // Find nearest station or allow selection
              _selectNearestStation(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.taxi_palestine_app',
            ),
            // Base station markers
            MarkerLayer(
              markers: _stations.map((station) {
                final lat = station['latitude']?.toDouble() ?? 0.0;
                final lng = station['longitude']?.toDouble() ?? 0.0;
                final isActive = station['is_active'] == true;
                final isSelected = _selectedStation?['stationid'] == station['stationid'];

                return Marker(
                  point: LatLng(lat, lng),
                  width: 50,
                  height: 50,
                  child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedStation = station;
              });
              if (_mapReady) {
                _centerMapOnStation(station);
              }
            },
                    child: Icon(
                      Icons.location_city,
                      color: isSelected
                          ? Colors.blue
                          : (isActive ? Colors.green : Colors.grey),
                      size: 40,
                    ),
                  ),
                );
              }).toList(),
            ),
            // Geofence circles
            CircleLayer(
              circles: _stations.map((station) {
                final lat = station['latitude']?.toDouble() ?? 0.0;
                final lng = station['longitude']?.toDouble() ?? 0.0;
                final radius = station['geofence_radius_meters']?.toInt() ?? 100;
                final isSelected = _selectedStation?['stationid'] == station['stationid'];

                return CircleMarker(
                  point: LatLng(lat, lng),
                  radius: radius.toDouble(),
                  color: isSelected
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.green.withOpacity(0.2),
                  borderColor: isSelected ? Colors.blue : Colors.green,
                  useRadiusInMeter: true,
                );
              }).toList(),
            ),
          ],
        ),
        // Station info card
        if (_selectedStation != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedStation!['name'] ?? 'Unnamed Station',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _createOrUpdateStation(
                                station: _selectedStation,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteStation(_selectedStation!),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_selectedStation!['latitude']?.toStringAsFixed(6)}, '
                      'Lng: ${_selectedStation!['longitude']?.toStringAsFixed(6)}',
                    ),
                    Text(
                      'Radius: ${_selectedStation!['geofence_radius_meters']}m',
                    ),
                    Text(
                      'Status: ${_selectedStation!['is_active'] == true ? 'Active' : 'Inactive'}',
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        final isSelected = _selectedStation?['stationid'] == station['stationid'];

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          child: ListTile(
            leading: Icon(
              Icons.location_city,
              size: 40,
              color: station['is_active'] == true ? Colors.green : Colors.grey,
            ),
            title: Text(station['name'] ?? 'Unnamed Station'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lat: ${station['latitude']?.toStringAsFixed(6)}, '
                  'Lng: ${station['longitude']?.toStringAsFixed(6)}',
                ),
                Text('Radius: ${station['geofence_radius_meters']}m'),
                Text(
                  'Status: ${station['is_active'] == true ? 'Active' : 'Inactive'}',
                ),
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
                _showMap = true;
              });
              if (_mapReady) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _centerMapOnStation(station);
                });
              }
            },
          ),
        );
      },
    );
  }

  void _selectNearestStation(LatLng point) {
    if (_stations.isEmpty) return;

    double minDistance = double.infinity;
    Map<String, dynamic>? nearest;

    for (final station in _stations) {
      final lat = station['latitude']?.toDouble() ?? 0.0;
      final lng = station['longitude']?.toDouble() ?? 0.0;
      final stationPoint = LatLng(lat, lng);
      final distance = _calculateDistance(point, stationPoint);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = station;
      }
    }

    if (nearest != null && minDistance < 0.01) {
      // Within ~1km, select it
      setState(() {
        _selectedStation = nearest;
      });
      _centerMapOnStation(nearest);
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, point1, point2);
  }
}
