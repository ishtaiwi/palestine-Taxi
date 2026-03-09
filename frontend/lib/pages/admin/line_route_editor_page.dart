import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/api_service.dart';
import '../../services/routing_service.dart';
import '../../theme/app_theme.dart';

class LineRouteEditorPage extends StatefulWidget {
  final String lineid;
  final String lineName;

  const LineRouteEditorPage({
    super.key,
    required this.lineid,
    required this.lineName,
  });

  @override
  State<LineRouteEditorPage> createState() => _LineRouteEditorPageState();
}

class _LineRouteEditorPageState extends State<LineRouteEditorPage> {
  final MapController _mapController = MapController();
  List<LatLng> _waypoints = [];
  List<LatLng> _routePoints = []; // Actual road route from OSRM
  String? _encodedPolyline;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCalculatingRoute = false;
  bool _hasChanges = false;
  double _totalDistance = 0;
  double _routeDuration = 0; // in seconds
  bool _isArabic = true;

  // Default center (Palestine)
  LatLng _center = const LatLng(31.9522, 35.2332);
  double _zoom = 12.0;

  // Focus node for keyboard shortcuts
  final FocusNode _focusNode = FocusNode();

  final Map<String, Map<String, String>> _texts = {
    'ar': {
      'title': 'محرر مسار الخط',
      'waypoints': 'نقاط المسار',
      'distance': 'المسافة',
      'meters': 'متر',
      'km': 'كم',
      'save': 'حفظ',
      'cancel': 'إلغاء',
      'clear': 'مسح',
      'undo': 'تراجع',
      'loading': 'جاري التحميل...',
      'saving': 'جاري الحفظ...',
      'noWaypoints': 'انقر على الخريطة لإضافة نقاط المسار',
      'success': 'تم حفظ المسار بنجاح',
      'error': 'خطأ',
      'unsavedChanges': 'تغييرات غير محفوظة',
      'unsavedMessage': 'لديك تغييرات غير محفوظة. هل تريد المغادرة؟',
      'leave': 'مغادرة',
      'stay': 'البقاء',
      'minWaypoints': 'يجب إضافة نقطتين على الأقل',
      'clickToAdd': 'انقر لإضافة نقطة',
      'dragToMove': 'اسحب لتحريك النقطة',
      'instructions': 'انقر على الخريطة لإضافة نقاط، سيتم حساب المسار تلقائياً',
      'deletePoint': 'حذف النقطة',
      'shortcuts': 'اختصارات لوحة المفاتيح',
      'shortcutUndo': 'Ctrl+Z: تراجع',
      'shortcutSave': 'Ctrl+S: حفظ',
      'shortcutClear': 'Ctrl+Shift+C: مسح الكل',
      'calculatingRoute': 'جاري حساب المسار...',
      'routeError': 'فشل حساب المسار',
      'duration': 'المدة',
      'min': 'دقيقة',
      'autoRouting': 'تتبع الطرق تلقائياً',
    },
    'en': {
      'title': 'Line Route Editor',
      'waypoints': 'Waypoints',
      'distance': 'Distance',
      'meters': 'meters',
      'km': 'km',
      'save': 'Save',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'undo': 'Undo',
      'loading': 'Loading...',
      'saving': 'Saving...',
      'noWaypoints': 'Click on the map to add waypoints',
      'success': 'Route saved successfully',
      'error': 'Error',
      'unsavedChanges': 'Unsaved Changes',
      'unsavedMessage': 'You have unsaved changes. Do you want to leave?',
      'leave': 'Leave',
      'stay': 'Stay',
      'minWaypoints': 'At least 2 waypoints are required',
      'clickToAdd': 'Click to add point',
      'dragToMove': 'Drag to move point',
      'instructions': 'Click map to add waypoints, route will be calculated automatically',
      'deletePoint': 'Delete Point',
      'shortcuts': 'Keyboard Shortcuts',
      'shortcutUndo': 'Ctrl+Z: Undo',
      'shortcutSave': 'Ctrl+S: Save',
      'shortcutClear': 'Ctrl+Shift+C: Clear all',
      'calculatingRoute': 'Calculating route...',
      'routeError': 'Failed to calculate route',
      'duration': 'Duration',
      'min': 'min',
      'autoRouting': 'Auto road routing',
    },
  };

  String t(String key) => _texts[_isArabic ? 'ar' : 'en']![key]!;

  @override
  void initState() {
    super.initState();
    AppTheme.init();
    _loadData();
    _loadLanguagePreference();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLanguagePreference() async {
    final isArabic = await ApiService.getLanguagePreference();
    setState(() {
      _isArabic = isArabic;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load existing path
      final pathResult = await ApiService.getLinePath(widget.lineid);
      if (pathResult['success'] == true && pathResult['path'] != null) {
        final path = pathResult['path'];
        final waypoints = path['waypoints'] as List?;
        final polyline = path['polyline'] as String?;
        final distance = path['distance_meters'] as num?;
        
        if (waypoints != null && waypoints.isNotEmpty) {
          _waypoints = waypoints.map((wp) {
            final lat = wp['lat']?.toDouble() ?? wp['latitude']?.toDouble() ?? 0.0;
            final lng = wp['lng']?.toDouble() ?? wp['longitude']?.toDouble() ?? 0.0;
            return LatLng(lat, lng);
          }).toList();
          
          // If we have an encoded polyline, decode it
          if (polyline != null && polyline.isNotEmpty) {
            _routePoints = RoutingService.decodePolyline(polyline);
            _encodedPolyline = polyline;
            _totalDistance = distance?.toDouble() ?? 0;
          } else if (_waypoints.length >= 2) {
            // No polyline saved, calculate route
            await _calculateRoute();
          }
          
          // Center map on waypoints
          if (_waypoints.isNotEmpty) {
            _center = _waypoints[0];
            _zoom = 14.0;
          }
        }
      }

      // Load base stations for reference
      final stationsResult = await ApiService.getAllBaseStations(isActive: true);
      if (stationsResult['success'] == true) {
        final stations = stationsResult['stations'] as List?;
        if (stations != null && stations.isNotEmpty && _waypoints.isEmpty) {
          // Center on first station if no waypoints
          final station = stations[0];
          _center = LatLng(
            station['latitude']?.toDouble() ?? 31.9522,
            station['longitude']?.toDouble() ?? 35.2332,
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading route data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _calculateRoute() async {
    if (_waypoints.length < 2) {
      setState(() {
        _routePoints = [];
        _encodedPolyline = null;
        _totalDistance = 0;
        _routeDuration = 0;
      });
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final result = await RoutingService.getRoute(_waypoints);
      
      if (result != null && mounted) {
        debugPrint('Setting route points: ${result.points.length} points');
        debugPrint('First point: ${result.points.isNotEmpty ? result.points.first : "none"}');
        debugPrint('Last point: ${result.points.length > 1 ? result.points.last : "none"}');
        setState(() {
          _routePoints = result.points;
          _encodedPolyline = result.encodedPolyline;
          _totalDistance = result.distance;
          _routeDuration = result.duration;
          _isCalculatingRoute = false;
        });
        debugPrint('After setState - _routePoints.length: ${_routePoints.length}');
      } else {
        // Fallback to straight line if routing fails
        if (mounted) {
          setState(() {
            _routePoints = List.from(_waypoints);
            _encodedPolyline = RoutingService.encodePolyline(_waypoints);
            _totalDistance = _calculateStraightLineDistance();
            _routeDuration = 0;
            _isCalculatingRoute = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t('routeError')),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error calculating route: $e');
      if (mounted) {
        setState(() {
          _routePoints = List.from(_waypoints);
          _encodedPolyline = RoutingService.encodePolyline(_waypoints);
          _totalDistance = _calculateStraightLineDistance();
          _routeDuration = 0;
          _isCalculatingRoute = false;
        });
      }
    }
  }

  double _calculateStraightLineDistance() {
    if (_waypoints.length < 2) return 0;
    
    const Distance distance = Distance();
    double total = 0;
    for (int i = 0; i < _waypoints.length - 1; i++) {
      total += distance.as(LengthUnit.Meter, _waypoints[i], _waypoints[i + 1]);
    }
    return total;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} ${t('km')}';
    }
    return '${meters.toStringAsFixed(0)} ${t('meters')}';
  }

  String _formatDuration(double seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes ${t('min')}';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours h $remainingMinutes ${t('min')}';
  }

  void _addWaypoint(LatLng point) {
    setState(() {
      _waypoints.add(point);
      _hasChanges = true;
    });
    _calculateRoute();
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      _hasChanges = true;
    });
    _calculateRoute();
  }

  void _undoLastWaypoint() {
    if (_waypoints.isNotEmpty) {
      setState(() {
        _waypoints.removeLast();
        _hasChanges = true;
      });
      _calculateRoute();
    }
  }

  void _clearAllWaypoints() {
    if (_waypoints.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
          title: Text(
            t('clear'),
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          content: Text(
            _isArabic ? 'هل تريد مسح جميع النقاط؟' : 'Clear all waypoints?',
            style: TextStyle(
              color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t('cancel'),
                style: TextStyle(
                  color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _waypoints.clear();
                  _routePoints.clear();
                  _encodedPolyline = null;
                  _totalDistance = 0;
                  _routeDuration = 0;
                  _hasChanges = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                t('clear'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveRoute() async {
    if (_waypoints.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('minWaypoints')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final waypoints = _waypoints.map((wp) => {
        'lat': wp.latitude,
        'lng': wp.longitude,
      }).toList();

      final result = await ApiService.createOrUpdateLinePath(
        lineid: widget.lineid,
        waypoints: waypoints,
        polyline: _encodedPolyline,
        distanceMeters: _totalDistance,
      );

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _hasChanges = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? t('success')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? t('error')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t('error')}: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppTheme.isDarkMode ? const Color(0xFF1C2541) : Colors.white,
        title: Text(
          t('unsavedChanges'),
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        content: Text(
          t('unsavedMessage'),
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              t('stay'),
              style: TextStyle(
                color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              t('leave'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      if (isCtrlPressed) {
        if (event.logicalKey == LogicalKeyboardKey.keyZ && !isShiftPressed) {
          _undoLastWaypoint();
        } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
          _saveRoute();
        } else if (event.logicalKey == LogicalKeyboardKey.keyC && isShiftPressed) {
          _clearAllWaypoints();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = _isArabic ? TextDirection.rtl : TextDirection.ltr;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Directionality(
        textDirection: textDirection,
        child: KeyboardListener(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            appBar: _buildAppBar(),
            body: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.appBarColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('loading'),
                          style: TextStyle(
                            color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : isDesktop
                    ? _buildDesktopLayout()
                    : isTablet
                        ? _buildTabletLayout()
                        : _buildMobileLayout(),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.isDarkMode
          ? const Color(0xFF1C2541)
          : AppTheme.appBarColor,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () async {
          if (_hasChanges) {
            final shouldPop = await _onWillPop();
            if (shouldPop && mounted) {
              Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
      title: Column(
        children: [
          Text(
            t('title'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            widget.lineName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
      actions: [
        if (_hasChanges)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.orange,
              size: 20,
            ),
          ),
        IconButton(
          icon: Icon(
            _isArabic ? Icons.language : Icons.translate,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isArabic = !_isArabic;
              ApiService.saveLanguagePreference(_isArabic);
            });
          },
        ),
        const SizedBox(width: 8),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left sidebar with controls
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(
              right: BorderSide(
                color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
          ),
          child: _buildControlPanel(),
        ),
        // Main map area
        Expanded(child: _buildMapArea()),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        // Top control bar
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
          ),
          child: _buildCompactControlBar(),
        ),
        // Map area
        Expanded(child: _buildMapArea()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        // Full screen map
        _buildMapArea(),
        // Bottom sheet style controls
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildMobileControlSheet(),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        // Stats section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatCard(
                icon: Icons.place_rounded,
                label: t('waypoints'),
                value: _waypoints.length.toString(),
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                icon: Icons.straighten_rounded,
                label: t('distance'),
                value: _formatDistance(_totalDistance),
                color: Colors.green,
              ),
              if (_routeDuration > 0) ...[
                const SizedBox(height: 12),
                _buildStatCard(
                  icon: Icons.timer_rounded,
                  label: t('duration'),
                  value: _formatDuration(_routeDuration),
                  color: Colors.orange,
                ),
              ],
            ],
          ),
        ),

        // Instructions
        Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('instructions'),
                    style: TextStyle(
                      color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Waypoints list
        Expanded(
          child: _waypoints.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 48,
                        color: AppTheme.isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t('noWaypoints'),
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? Colors.white54 : AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _waypoints.length,
                  itemBuilder: (context, index) => _buildWaypointItem(index),
                ),
        ),

        // Keyboard shortcuts info (desktop only)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
            border: Border(
              top: BorderSide(
                color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('shortcuts'),
                style: TextStyle(
                  color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${t('shortcutUndo')}\n${t('shortcutSave')}\n${t('shortcutClear')}',
                style: TextStyle(
                  color: AppTheme.isDarkMode ? Colors.white54 : AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _waypoints.isEmpty ? null : _undoLastWaypoint,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: Text(t('undo')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                        side: BorderSide(
                          color: AppTheme.isDarkMode ? Colors.white24 : AppTheme.borderColor,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _waypoints.isEmpty ? null : _clearAllWaypoints,
                      icon: const Icon(Icons.clear_all_rounded, size: 18),
                      label: Text(t('clear')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving || _waypoints.length < 2 ? null : _saveRoute,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 20),
                  label: Text(_isSaving ? t('saving') : t('save')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactControlBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Stats
          Expanded(
            child: Row(
              children: [
                _buildCompactStat(Icons.place_rounded, _waypoints.length.toString(), Colors.blue),
                const SizedBox(width: 16),
                _isCalculatingRoute
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '...',
                            style: TextStyle(
                              color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : _buildCompactStat(Icons.straighten_rounded, _formatDistance(_totalDistance), Colors.green),
              ],
            ),
          ),
          // Action buttons
          Row(
            children: [
              IconButton(
                onPressed: _waypoints.isEmpty ? null : _undoLastWaypoint,
                icon: const Icon(Icons.undo_rounded),
                tooltip: t('undo'),
              ),
              IconButton(
                onPressed: _waypoints.isEmpty ? null : _clearAllWaypoints,
                icon: const Icon(Icons.clear_all_rounded),
                color: Colors.redAccent,
                tooltip: t('clear'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving || _waypoints.length < 2 ? null : _saveRoute,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(t('save')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileControlSheet() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.isDarkMode ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactStat(Icons.place_rounded, _waypoints.length.toString(), Colors.blue),
                  _isCalculatingRoute
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '...',
                              style: TextStyle(
                                color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : _buildCompactStat(Icons.straighten_rounded, _formatDistance(_totalDistance), Colors.green),
                ],
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _waypoints.isEmpty ? null : _undoLastWaypoint,
                      icon: const Icon(Icons.undo_rounded, size: 18),
                      label: Text(t('undo')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _waypoints.length < 2 ? null : _saveRoute,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
                      label: Text(_isSaving ? t('saving') : t('save')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildWaypointItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.isDarkMode ? Colors.white12 : AppTheme.borderColor,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: index == 0
              ? Colors.green
              : index == _waypoints.length - 1
                  ? Colors.red
                  : Colors.blue,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${_waypoints[index].latitude.toStringAsFixed(5)}, ${_waypoints[index].longitude.toStringAsFixed(5)}',
          style: TextStyle(
            color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 20),
          color: Colors.redAccent,
          onPressed: () => _removeWaypoint(index),
          tooltip: t('deletePoint'),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    debugPrint('Building map - waypoints: ${_waypoints.length}, routePoints: ${_routePoints.length}');
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            onTap: (tapPosition, latLng) {
              if (!_isCalculatingRoute) {
                _addWaypoint(latLng);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.taxi_palestine_app',
            ),
            // Route polylines layer - always present, conditionally filled
            PolylineLayer(
              polylines: [
                // Waypoint connection line (thin, for reference)
                if (_waypoints.length >= 2)
                  Polyline(
                    points: List<LatLng>.from(_waypoints),
                    strokeWidth: 2,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                // Route polyline (actual road route from OSRM)
                if (_routePoints.length >= 2)
                  Polyline(
                    points: List<LatLng>.from(_routePoints),
                    strokeWidth: 6,
                    color: Colors.blue,
                  ),
              ],
            ),
            // Waypoint markers
            MarkerLayer(
              markers: _waypoints.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                final isFirst = index == 0;
                final isLast = index == _waypoints.length - 1;

                return Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onLongPress: () => _removeWaypoint(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isFirst
                            ? Colors.green
                            : isLast
                                ? Colors.red
                                : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Loading overlay when calculating route
        if (_isCalculatingRoute)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.isDarkMode ? Colors.blueAccent : AppTheme.appBarColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t('calculatingRoute'),
                        style: TextStyle(
                          color: AppTheme.isDarkMode ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Auto-routing indicator
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 16,
                  color: Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  t('autoRouting'),
                  style: TextStyle(
                    color: AppTheme.isDarkMode ? Colors.white70 : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

