import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

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
    AppTheme.init();
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0)
          ),
          child: Container(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
            child: Column(
              children: [
                Text(
                  station == null ? 'Create Base Station' : 'Edit Base Station',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 19.0 : 20.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
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
                            width: isSmallScreen ? 45.0 : 50.0,
                            height: isSmallScreen ? 45.0 : 50.0,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: isSmallScreen ? 45.0 : 50.0,
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
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                // Form fields
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                    hintText: 'Main Station',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                      vertical: isSmallScreen ? 12.0 : 16.0,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: selectedLocation.latitude.toStringAsFixed(6),
                        ),
                        style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                        decoration: InputDecoration(
                          labelText: 'Latitude',
                          labelStyle: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16.0 : 20.0,
                            vertical: isSmallScreen ? 12.0 : 16.0,
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                          text: selectedLocation.longitude.toStringAsFixed(6),
                        ),
                        style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                        decoration: InputDecoration(
                          labelText: 'Longitude',
                          labelStyle: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16.0 : 20.0,
                            vertical: isSmallScreen ? 12.0 : 16.0,
                          ),
                        ),
                        readOnly: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                TextField(
                  controller: radiusController,
                  style: TextStyle(fontSize: isSmallScreen ? 14.0 : 16.0),
                  decoration: InputDecoration(
                    labelText: 'Geofence Radius (meters)',
                    labelStyle: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                    hintText: '100',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0)
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                      vertical: isSmallScreen ? 12.0 : 16.0,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                ),
                SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Name is required',
                                style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                              ),
                            ),
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
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 20.0 : 24.0,
                          vertical: isSmallScreen ? 10.0 : 12.0,
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
                      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmallScreen ? 14.0 : 16.0)
        ),
        titlePadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        contentPadding: EdgeInsets.all(isSmallScreen ? 16.0 : (isMediumScreen ? 18.0 : 20.0)),
        actionsPadding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        title: Text(
          'Delete Base Station',
          style: TextStyle(
            fontSize: isSmallScreen ? 18.0 : (isMediumScreen ? 20.0 : 22.0),
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${station['name']}?',
          style: TextStyle(
            fontSize: isSmallScreen ? 13.0 : 14.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20.0 : 24.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
            ),
            child: Text(
              'Delete',
              style: TextStyle(fontSize: isSmallScreen ? 13.0 : 14.0),
            ),
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
    // Responsive design variables
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Base Stations',
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
            icon: Icon(_showMap ? Icons.list : Icons.map),
            color: Colors.white,
            iconSize: isSmallScreen ? 20.0 : 24.0,
            onPressed: () {
              setState(() {
                _showMap = !_showMap;
              });
            },
            tooltip: _showMap ? 'Show List' : 'Show Map',
          ),
          IconButton(
            icon: Icon(Icons.add),
            color: Colors.white,
            iconSize: isSmallScreen ? 20.0 : 24.0,
            onPressed: () => _createOrUpdateStation(),
            tooltip: 'Add Base Station',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stations.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No base stations found',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16.0 : 18.0,
                            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                        ElevatedButton(
                          onPressed: () => _createOrUpdateStation(),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 20.0 : 24.0,
                              vertical: isSmallScreen ? 12.0 : 14.0,
                            ),
                          ),
                          child: Text(
                            'Create First Base Station',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.0 : 14.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _showMap
                  ? _buildMapView(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen)
                  : _buildListView(isSmallScreen: isSmallScreen, isMediumScreen: isMediumScreen),
    );
  }

  Widget _buildMapView({bool isSmallScreen = false, bool isMediumScreen = false}) {
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
                  width: isSmallScreen ? 45.0 : 50.0,
                  height: isSmallScreen ? 45.0 : 50.0,
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
                      size: isSmallScreen ? 36.0 : (isMediumScreen ? 38.0 : 40.0),
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
            bottom: isSmallScreen ? 12.0 : 16.0,
            left: isSmallScreen ? 12.0 : 16.0,
            right: isSmallScreen ? 12.0 : 16.0,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedStation!['name'] ?? 'Unnamed Station',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              iconSize: isSmallScreen ? 20.0 : 24.0,
                              padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                              constraints: BoxConstraints(
                                minWidth: isSmallScreen ? 36.0 : 48.0,
                                minHeight: isSmallScreen ? 36.0 : 48.0,
                              ),
                              onPressed: () => _createOrUpdateStation(
                                station: _selectedStation,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              iconSize: isSmallScreen ? 20.0 : 24.0,
                              padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                              constraints: BoxConstraints(
                                minWidth: isSmallScreen ? 36.0 : 48.0,
                                minHeight: isSmallScreen ? 36.0 : 48.0,
                              ),
                              onPressed: () => _deleteStation(_selectedStation!),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                    Text(
                      'Lat: ${_selectedStation!['latitude']?.toStringAsFixed(6)}, '
                      'Lng: ${_selectedStation!['longitude']?.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 13.0,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                    Text(
                      'Radius: ${_selectedStation!['geofence_radius_meters']}m',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 13.0,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                    Text(
                      'Status: ${_selectedStation!['is_active'] == true ? 'Active' : 'Inactive'}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 13.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView({bool isSmallScreen = false, bool isMediumScreen = false}) {
    final double basePadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    
    return ListView.builder(
      padding: EdgeInsets.all(basePadding),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        final isSelected = _selectedStation?['stationid'] == station['stationid'];

        return Card(
          margin: EdgeInsets.symmetric(
            horizontal: 0,
            vertical: isSmallScreen ? 6.0 : 8.0,
          ),
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0,
              vertical: isSmallScreen ? 8.0 : 12.0,
            ),
            leading: Icon(
              Icons.location_city,
              size: isSmallScreen ? 36.0 : (isMediumScreen ? 38.0 : 40.0),
              color: station['is_active'] == true ? Colors.green : Colors.grey,
            ),
            title: Text(
              station['name'] ?? 'Unnamed Station',
              style: TextStyle(
                fontSize: isSmallScreen ? 16.0 : (isMediumScreen ? 17.0 : 18.0),
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: EdgeInsets.only(top: isSmallScreen ? 4.0 : 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lat: ${station['latitude']?.toStringAsFixed(6)}, '
                    'Lng: ${station['longitude']?.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                  Text(
                    'Radius: ${station['geofence_radius_meters']}m',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                  Text(
                    'Status: ${station['is_active'] == true ? 'Active' : 'Inactive'}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11.0 : (isMediumScreen ? 12.0 : 13.0),
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  iconSize: isSmallScreen ? 20.0 : 24.0,
                  padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                  constraints: BoxConstraints(
                    minWidth: isSmallScreen ? 36.0 : 48.0,
                    minHeight: isSmallScreen ? 36.0 : 48.0,
                  ),
                  onPressed: () => _createOrUpdateStation(
                    station: station,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  iconSize: isSmallScreen ? 20.0 : 24.0,
                  padding: EdgeInsets.all(isSmallScreen ? 4.0 : 8.0),
                  constraints: BoxConstraints(
                    minWidth: isSmallScreen ? 36.0 : 48.0,
                    minHeight: isSmallScreen ? 36.0 : 48.0,
                  ),
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
