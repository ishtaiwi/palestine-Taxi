import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/supabase_realtime_service.dart';
import '../../theme/app_theme.dart';

class AdminMapPage extends StatefulWidget {
  const AdminMapPage({super.key});

  @override
  State<AdminMapPage> createState() => _AdminMapPageState();
}

class _AdminMapPageState extends State<AdminMapPage> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _vehicleLocations = [];
  List<Map<String, dynamic>> _baseStations = [];
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _linePaths = [];
  String? _selectedLineId;
  bool _isLoading = true;
  bool _showBaseStationGeofence = true;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _subscribeToRealtimeUpdates();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load vehicle locations
      final locationsResult = await ApiService.getAllVehicleLocations();
      if (locationsResult['success'] == true) {
        final locationsList = locationsResult['locations'];
        if (locationsList is List) {
          setState(() {
            _vehicleLocations = locationsList
                .whereType<Map<String, dynamic>>()
                .map((loc) => Map<String, dynamic>.from(loc))
                .toList();
          });
        }
      }

      // Load base stations
      final stationsResult =
          await ApiService.getAllBaseStations(isActive: true);
      if (stationsResult['success'] == true) {
        final stationsList = stationsResult['stations'];
        if (stationsList is List) {
          setState(() {
            _baseStations = stationsList
                .whereType<Map<String, dynamic>>()
                .map((station) => Map<String, dynamic>.from(station))
                .toList();
            if (_baseStations.isNotEmpty && _center == null) {
              _center = LatLng(
                _baseStations[0]['latitude']?.toDouble() ?? 31.9522,
                _baseStations[0]['longitude']?.toDouble() ?? 35.2332,
              );
            }
          });
        }
      }

      // Load lines
      final linesResult = await ApiService.fetchActiveLines();
      setState(() {
        _lines = linesResult;
      });

      // Load line paths
      await _loadLinePaths();

      // Set center to first vehicle if no base station
      if (_center == null && _vehicleLocations.isNotEmpty) {
        final loc = _vehicleLocations[0];
        _center = LatLng(
          loc['latitude']?.toDouble() ?? 31.9522,
          loc['longitude']?.toDouble() ?? 35.2332,
        );
      }

      if (_center == null) {
        _center = const LatLng(31.9522, 35.2332); // Default to Palestine center
      }
    } catch (e) {
      print('Error loading map data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLinePaths() async {
    final paths = <Map<String, dynamic>>[];
    for (final line in _lines) {
      try {
        final pathResult =
            await ApiService.getLinePath(line['lineid'].toString());
        if (pathResult['success'] == true && pathResult['path'] != null) {
          paths.add({
            'lineid': line['lineid'],
            'path': pathResult['path'],
          });
        }
      } catch (e) {
        // Ignore errors for lines without paths
      }
    }
    setState(() {
      _linePaths = paths;
    });
  }

  void _subscribeToRealtimeUpdates() {
    // Subscribe to vehicle location updates via Supabase Realtime
    SupabaseRealtimeService.subscribeToVehicleLocations((update) {
      if (mounted) {
        setState(() {
          // Update or add vehicle location
          final vehicleid = update['vehicleid'];
          final index = _vehicleLocations.indexWhere(
            (loc) => loc['vehicleid'] == vehicleid,
          );
          if (index >= 0) {
            _vehicleLocations[index] = update;
          } else {
            _vehicleLocations.add(update);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SupabaseRealtimeService.unsubscribe();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredVehicleLocations {
    if (_selectedLineId == null) {
      return _vehicleLocations;
    }
    return _vehicleLocations.where((loc) {
      return loc['vehicle']?['lineid'] == _selectedLineId;
    }).toList();
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
          'Vehicle Tracking Map',
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
            icon: Icon(Icons.refresh),
            color: Colors.white,
            iconSize: isSmallScreen ? 20.0 : 24.0,
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : (isMediumScreen ? 14.0 : 16.0), 
                    vertical: isSmallScreen ? 6.0 : 8.0
                  ),
                  color: AppTheme.getCardBackground(0.1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Filter by Line: ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.0 : 14.0,
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _selectedLineId != null &&
                                      _lines.any((line) =>
                                          line['lineid'].toString() == _selectedLineId)
                                  ? _selectedLineId
                                  : null,
                              isExpanded: true,
                              hint: Text(
                                'All Lines',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13.0 : 14.0,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13.0 : 14.0,
                                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(
                                    'All Lines',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13.0 : 14.0,
                                    ),
                                  ),
                                ),
                                ..._lines.map((line) =>
                                    DropdownMenuItem<String>(
                                      value: line['lineid'].toString(),
                                      child: Text(
                                        line['linename'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 13.0 : 14.0,
                                        ),
                                      ),
                                    )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedLineId = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                      Row(
                        children: [
                          Text(
                            'Show Geofence: ',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13.0 : 14.0,
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          Switch(
                            value: _showBaseStationGeofence,
                            onChanged: (value) {
                              setState(() {
                                _showBaseStationGeofence = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center ?? const LatLng(31.9522, 35.2332),
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.taxi_palestine_app',
                      ),
                      // Base station markers and geofence circles
                      ..._baseStations.map((station) {
                        final lat = station['latitude']?.toDouble() ?? 0.0;
                        final lng = station['longitude']?.toDouble() ?? 0.0;

                        return MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_city,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                          ],
                        );
                      }),
                      // Geofence circles
                      if (_showBaseStationGeofence)
                        ..._baseStations.map((station) {
                          final lat = station['latitude']?.toDouble() ?? 0.0;
                          final lng = station['longitude']?.toDouble() ?? 0.0;
                          final radius =
                              station['geofence_radius_meters']?.toInt() ?? 100;

                          return CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(lat, lng),
                                radius: radius.toDouble(),
                                color: Colors.blue.withOpacity(0.2),
                                borderColor: Colors.blue,
                                useRadiusInMeter: true,
                              ),
                            ],
                          );
                        }),
                      // Line paths
                      ..._linePaths.map((linePath) {
                        final path = linePath['path'] as Map<String, dynamic>;
                        final waypoints = path['waypoints'] as List?;
                        if (waypoints == null || waypoints.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final points = waypoints
                            .map((wp) => LatLng(
                                  wp['lat']?.toDouble() ??
                                      wp['latitude']?.toDouble() ??
                                      0.0,
                                  wp['lng']?.toDouble() ??
                                      wp['longitude']?.toDouble() ??
                                      0.0,
                                ))
                            .toList();

                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              strokeWidth: 3,
                              color: Colors.orange,
                            ),
                          ],
                        );
                      }),
                      // Vehicle markers
                      MarkerLayer(
                        markers: _filteredVehicleLocations.map((location) {
                          final lat = location['latitude']?.toDouble() ?? 0.0;
                          final lng = location['longitude']?.toDouble() ?? 0.0;
                          final isAtStation = location['is_at_station'] == true;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () {
                                _showVehicleInfo(context, location);
                              },
                              child: Icon(
                                Icons.local_taxi,
                                color: isAtStation ? Colors.green : Colors.red,
                                size: 40,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Stats bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  color: AppTheme.getCardBackground(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Flexible(
                        child: _buildStatItem(
                          'Active Vehicles',
                          _filteredVehicleLocations.length.toString(),
                          Colors.blue,
                        ),
                      ),
                      Flexible(
                        child: _buildStatItem(
                          'At Base Station',
                          _filteredVehicleLocations
                              .where((loc) => loc['is_at_station'] == true)
                              .length
                              .toString(),
                          Colors.green,
                        ),
                      ),
                      Flexible(
                        child: _buildStatItem(
                          'Base Stations',
                          _baseStations.length.toString(),
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  void _showVehicleInfo(BuildContext context, Map<String, dynamic> location) {
    final vehicle = location['vehicle'];
    final driver = location['driver'];
    final isAtStation = location['is_at_station'] == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(vehicle?['plateno'] ?? 'Unknown Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver: ${driver?['user']?['fullname'] ?? 'Unknown'}'),
            Text('Phone: ${driver?['user']?['phone'] ?? 'N/A'}'),
            Text('Line: ${vehicle?['line']?['linename'] ?? 'N/A'}'),
            Text('Status: ${isAtStation ? 'At Base Station' : 'On Route'}'),
            Text(
                'Last Update: ${location['updated_at']?.toString().substring(0, 19) ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
