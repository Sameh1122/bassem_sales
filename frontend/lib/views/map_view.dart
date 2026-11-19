import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/url_launcher.dart';
import '../services/api_service.dart';
import 'form_filler_dialog.dart';
import 'customer_360_drawer.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => MapViewScreenState();
}

class MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  List<dynamic> _chillers = [];
  List<dynamic> _batches = [];
  dynamic _selectedBatchId = 'All';
  bool _isLoading = true;
  bool _hasInitialFitted = false;
  String _selectedEfficiency = 'All';
  String _selectedCustomerType = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _efficiencyOptions = ['All', 'Performing', 'Non-Performing', 'Zero'];
  String _pinColorMode = 'efficiency'; // 'efficiency' | 'condition'
  String _selectedCondition = 'All';
  final List<String> _conditionOptions = ['All', 'Operational', 'Requires Maintenance', 'Scrap', 'Unspecified'];
  final List<String> _customerTypeOptions = ['All', 'Retail', 'LS', 'SM', 'LG'];

  // GPS / My Location State
  bool _isLocating = false;
  AppLocation? _userPosition;
  double _selectedRadiusKm = 0.0; // 0.0 = All (No filter)
  bool _showSurroundingPanel = false;
  final List<double> _radiusOptions = [0.0, 1.0, 3.0, 5.0, 10.0, 25.0, 50.0];
  bool _isToolbarMinimized = false;
  Map<String, dynamic>? _repKpi;
  bool _isKpiLoading = false;
  bool _kpiError = false;
  String? _selectedBranch;
  String? _kpiVisitFilter; // null | 'visited' | 'pending'

  // Smart Daily Route Planner (STORY-005)
  bool _showRoutePlanner = false;
  bool _isRouteLoading = false;
  String? _routeError;
  List<Map<String, dynamic>> _routeStops = [];
  double _routeTotalKm = 0.0;
  int _routeDriveMinutes = 0;
  int _routeSkippedNoCoords = 0;
  int _routeLimit = 10;
  bool _routePendingOnly = true;
  int? _activeRouteStopIndex;

  void openRoutePlanner() {
    if (!_showRoutePlanner) {
      setState(() {
        _showRoutePlanner = true;
        _showSurroundingPanel = false;
      });
      _loadDailyRoute();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadChillers(forceRecenter: true);
    _loadRepKpi();
  }

  Future<void> _locateUser({bool recenter = true}) async {
    setState(() => _isLocating = true);
    try {
      final position = await getCurrentUserLocation();

      if (mounted) {
        setState(() {
          _userPosition = position;
          _isLocating = false;
        });

        if (recenter) {
          _mapController.move(LatLng(position.latitude, position.longitude), 14.5);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Live GPS acquired: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        String msg = e.toString();
        if (msg.contains('Exception:')) {
          msg = msg.replaceAll('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $msg. Please allow location permissions in your browser.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  double calculateDistanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // pi / 180
    final double a = 0.5 - math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) *
        (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000.0 * math.asin(math.sqrt(a)); // in meters (Earth radius ~6371km)
  }

  double? _getDistanceMeters(dynamic chiller) {
    if (_userPosition == null) return null;
    final lat = _toDouble(chiller['latitude'], 0.0);
    final lng = _toDouble(chiller['longitude'], 0.0);
    if (lat == 0.0 || lng == 0.0) return null;
    return calculateDistanceBetween(_userPosition!.latitude, _userPosition!.longitude, lat, lng);
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  List<dynamic> _getFilteredChillers() {
    return _chillers.where((c) {
      final lat = _toDouble(c['latitude'], 0.0);
      final lng = _toDouble(c['longitude'], 0.0);
      if (lat == 0.0 || lng == 0.0) return false;

      if (_selectedBranch != null && _selectedBranch!.isNotEmpty && _selectedBranch != 'All') {
        final b = (c['branch'] ?? '').toString().trim();
        final normB = b.isEmpty ? 'Unassigned' : b;
        if (normB.toLowerCase() != _selectedBranch!.toLowerCase()) {
          return false;
        }
      }

      if (_kpiVisitFilter == 'visited') {
        final vs = (c['visitStatus'] ?? 'not_visited').toString();
        if (vs != 'submitted' && vs != 'accepted') return false;
      } else if (_kpiVisitFilter == 'pending') {
        final vs = (c['visitStatus'] ?? 'not_visited').toString();
        if (vs == 'submitted' || vs == 'accepted') return false;
      }

      if (_selectedCondition != 'All') {
        final condCat = _classifyCondition(_extractCondition(c));
        if (condCat != _selectedCondition) return false;
      }

      if (_selectedRadiusKm > 0.0 && _userPosition != null) {
        final dist = _getDistanceMeters(c);
        if (dist == null || dist > (_selectedRadiusKm * 1000.0)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<dynamic> _getSurroundingSortedChillers() {
    final list = _chillers.where((c) {
      final lat = _toDouble(c['latitude'], 0.0);
      final lng = _toDouble(c['longitude'], 0.0);
      return lat != 0.0 && lng != 0.0;
    }).toList();

    if (_userPosition != null) {
      list.sort((a, b) {
        final distA = _getDistanceMeters(a) ?? double.infinity;
        final distB = _getDistanceMeters(b) ?? double.infinity;
        return distA.compareTo(distB);
      });
      if (_selectedRadiusKm > 0.0) {
        return list.where((c) {
          final dist = _getDistanceMeters(c);
          return dist != null && dist <= (_selectedRadiusKm * 1000.0);
        }).toList();
      }
    }
    return list;
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await ApiService.fetchBatches();
      if (mounted) {
        setState(() {
          _batches = batches;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRepKpi() async {
    if (_isKpiLoading) return;
    setState(() {
      _isKpiLoading = true;
      _kpiError = false;
    });
    try {
      final kpi = await ApiService.fetchRepKpi(branch: _selectedBranch);
      if (mounted) {
        setState(() {
          _repKpi = kpi;
          _isKpiLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isKpiLoading = false;
          _kpiError = true;
        });
      }
    }
  }

  Future<void> _loadDailyRoute() async {
    setState(() {
      _isRouteLoading = true;
      _routeError = null;
    });
    try {
      final res = await ApiService.fetchDailyRoute(
        lat: _userPosition?.latitude,
        lng: _userPosition?.longitude,
        branch: _selectedBranch,
        limit: _routeLimit,
        pendingOnly: _routePendingOnly,
      );
      if (!mounted) return;
      final rawStops = (res['stops'] as List<dynamic>?) ?? [];
      setState(() {
        _routeStops = rawStops.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _routeTotalKm = _toDouble(res['totalEstimatedKm'], 0.0);
        _routeDriveMinutes = (res['estimatedDriveMinutes'] is num)
            ? (res['estimatedDriveMinutes'] as num).round()
            : int.tryParse('${res['estimatedDriveMinutes'] ?? 0}') ?? 0;
        _routeSkippedNoCoords = (res['skippedNoCoordsCount'] is num)
            ? (res['skippedNoCoordsCount'] as num).round()
            : int.tryParse('${res['skippedNoCoordsCount'] ?? 0}') ?? 0;
        _activeRouteStopIndex = _routeStops.isNotEmpty ? 0 : null;
        _isRouteLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRouteLoading = false;
          _routeError = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _recalculateRouteStats() {
    double totalKm = 0.0;
    double? prevLat = _userPosition?.latitude;
    double? prevLng = _userPosition?.longitude;

    for (int i = 0; i < _routeStops.length; i++) {
      final stop = _routeStops[i];
      final lat = _toDouble(stop['latitude'], 0.0);
      final lng = _toDouble(stop['longitude'], 0.0);
      double legKm = 0.0;
      if (prevLat != null && prevLng != null) {
        legKm = calculateDistanceBetween(prevLat, prevLng, lat, lng) / 1000.0;
      }
      totalKm += legKm;
      stop['order'] = i + 1;
      stop['legDistanceKm'] = double.parse(legKm.toStringAsFixed(2));
      stop['cumulativeKm'] = double.parse(totalKm.toStringAsFixed(2));
      prevLat = lat;
      prevLng = lng;
    }

    setState(() {
      _routeTotalKm = double.parse(totalKm.toStringAsFixed(2));
      _routeDriveMinutes = ((totalKm / 30.0) * 60.0).round();
    });
  }

  void _startGoogleMapsRoute() {
    if (_routeStops.isEmpty) return;
    final capped = _routeStops.take(10).toList();
    final dest = capped.last;
    final destStr = '${dest['latitude']},${dest['longitude']}';
    final originStr = _userPosition != null
        ? '${_userPosition!.latitude},${_userPosition!.longitude}'
        : '${capped.first['latitude']},${capped.first['longitude']}';

    final waypointsList = <String>[];
    final startIdx = _userPosition != null ? 0 : 1;
    for (int i = startIdx; i < capped.length - 1; i++) {
      waypointsList.add('${capped[i]['latitude']},${capped[i]['longitude']}');
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': originStr,
      'destination': destStr,
      if (waypointsList.isNotEmpty) 'waypoints': waypointsList.join('|'),
      'travelmode': 'driving',
    });
    openExternalUrl(uri.toString());
  }

  void reload({bool forceRecenter = false, bool forceApi = false}) {
    _loadBatches();
    _loadChillers(forceRecenter: forceRecenter, forceApi: forceApi);
    _loadRepKpi();
  }

  void reloadChillers() {
    _loadBatches();
    _loadChillers(forceRecenter: true);
    _loadRepKpi();
  }

  void selectBatch(dynamic batchId) {
    setState(() {
      _selectedBatchId = batchId;
    });
    _loadBatches();
    _loadChillers(forceRecenter: true, forceApi: true);
  }

  void _fitBoundsToChillers() {
    final validPoints = _chillers.where((c) {
      final lat = _toDouble(c['latitude'], 0.0);
      final lng = _toDouble(c['longitude'], 0.0);
      return lat != 0.0 && lng != 0.0;
    }).map((c) {
      return LatLng(_toDouble(c['latitude']), _toDouble(c['longitude']));
    }).toList();

    if (validPoints.isEmpty) return;

    if (validPoints.length == 1) {
      _mapController.move(validPoints.first, 13.0);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(validPoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48.0),
        ),
      );
    } catch (_) {
      _mapController.move(validPoints.first, 7.0);
    }
  }

  Future<void> _loadChillers({bool forceRecenter = false, bool forceApi = false}) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchChillers(
        efficiency: _selectedEfficiency,
        customerType: _selectedCustomerType,
        search: _searchQuery,
        batchId: _selectedBatchId,
        forceApi: forceApi,
      );
      setState(() {
        _chillers = data;
        _isLoading = false;
      });

      if (forceRecenter || !_hasInitialFitted) {
        _hasInitialFitted = true;
        // Allow widget tree frame to render before adjusting camera
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitBoundsToChillers();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading map data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _getMarkerColor(String efficiency) {
    final eff = efficiency.trim().toLowerCase();
    if (eff.contains('performing') && !eff.contains('non')) {
      return const Color(0xFF10B981); // Emerald Green
    } else if (eff.contains('non')) {
      return const Color(0xFFEF4444); // Rose Red
    } else if (eff.contains('zero')) {
      return const Color(0xFFF59E0B); // Amber
    }
    return const Color(0xFF6B7280); // Cool Grey
  }

  String _extractCondition(dynamic c) {
    final raw = c['rawData'] is Map ? c['rawData'] as Map : const {};
    return (c['condition'] ?? raw['Condition'] ?? raw['Condiiton'] ?? '').toString().trim();
  }

  String _classifyCondition(String rawCondition) {
    final c = rawCondition.trim().toLowerCase();
    if (c.isEmpty || c == '-' || c == 'n/a' || c == 'unknown') {
      return 'Unspecified';
    }
    if (c.contains('scrap') || c.contains('damaged') || c.contains('decommissioned')) {
      return 'Scrap';
    }
    if (c.contains('maint') || c.contains('repair')) {
      return 'Requires Maintenance';
    }
    if (c.contains('operat') || c.contains('good') || c.contains('working')) {
      return 'Operational';
    }
    return 'Unspecified';
  }

  Color _getConditionColor(String category) {
    switch (category) {
      case 'Operational':
        return const Color(0xFF10B981);
      case 'Requires Maintenance':
        return const Color(0xFFF97316);
      case 'Scrap':
        return const Color(0xFFEF4444);
      case 'Unspecified':
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getConditionIcon(String category) {
    switch (category) {
      case 'Operational':
        return Icons.check_circle_outline;
      case 'Requires Maintenance':
        return Icons.build_circle_outlined;
      case 'Scrap':
        return Icons.dangerous_outlined;
      case 'Unspecified':
      default:
        return Icons.help_outline;
    }
  }

  void _resetAllMapFilters() {
    _searchController.clear();
    setState(() {
      _selectedEfficiency = 'All';
      _selectedCondition = 'All';
      _selectedCustomerType = 'All';
      _selectedRadiusKm = 0.0;
      _selectedBranch = null;
      _kpiVisitFilter = null;
      _searchQuery = '';
    });
    _loadChillers();
  }

  void _openGoogleMapsDirections(double lat, double lng) {
    String googleMapsUrl;
    if (_userPosition != null) {
      googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&origin=${_userPosition!.latitude},${_userPosition!.longitude}&destination=$lat,$lng';
    } else {
      googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    openExternalUrl(googleMapsUrl);
  }

  double _toDouble(dynamic val, [double defaultValue = 0.0]) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? defaultValue;
  }

  void _showChillerDetailsModal(Map<String, dynamic> chiller) {
    showCustomer360Drawer(
      context,
      chiller: chiller,
      distanceMeters: _getDistanceMeters(chiller),
      userPosition: _userPosition,
      onAuditSubmitted: () => reload(forceApi: true),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSurroundingLocationsPanel(BuildContext context) {
    final surroundingList = _getSurroundingSortedChillers();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final panelWidth = isMobile ? (screenWidth - 32) : 380.0;

    return Container(
      width: panelWidth,
      constraints: const BoxConstraints(maxHeight: 460),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.4)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.near_me, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Surrounding Customers',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _userPosition != null
                            ? '${surroundingList.length} locations (sorted by proximity)'
                            : 'GPS required for distance sorting',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _showSurroundingPanel = false),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: _userPosition == null
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_searching, color: Colors.cyan, size: 44),
                        const SizedBox(height: 12),
                        const Text(
                          'Live GPS Not Detected',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enable your location to see surrounding customers sorted by distance from your current position.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _locateUser(recenter: true),
                          icon: _isLocating
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.my_location, size: 16),
                          label: Text(_isLocating ? 'Locating...' : 'Turn on GPS Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  )
                : surroundingList.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radar, color: Colors.amber, size: 40),
                            const SizedBox(height: 10),
                            const Text(
                              'No Customers Found',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRadiusKm > 0
                                  ? 'No customers within ${_selectedRadiusKm.toInt()} km. Try expanding your radius filter.'
                                  : 'No valid locations matching your current filters.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(10),
                        itemCount: surroundingList.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 12),
                        itemBuilder: (context, index) {
                          final item = surroundingList[index];
                          final customerName = item['customerName'] ?? 'Unknown Customer';
                          final code = item['chillerCode'] ?? 'N/A';
                          final eff = item['efficiency'] ?? '';
                          final lat = _toDouble(item['latitude']);
                          final lng = _toDouble(item['longitude']);
                          final distMeters = _getDistanceMeters(item);
                          final color = _getMarkerColor(eff);

                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              _mapController.move(LatLng(lat, lng), 16.0);
                              _showChillerDetailsModal(item);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.location_on, color: color, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(code, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                            const SizedBox(width: 6),
                                            Text('• $eff', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (distMeters != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatDistance(distMeters),
                                          style: const TextStyle(
                                            color: Colors.cyanAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () => _openGoogleMapsDirections(lat, lng),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4285F4),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.directions, color: Colors.white, size: 12),
                                                SizedBox(width: 3),
                                                Text('Go', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePlannerPanel(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    return Container(
      width: isMobile ? screenWidth - 32 : 380,
      constraints: BoxConstraints(
        maxHeight: isMobile ? screenHeight * 0.52 : 500,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.45)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_rounded, color: Color(0xFF06B6D4), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Smart Daily Route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(
                        '${_routeStops.length} stops • ~${_routeTotalKm.toStringAsFixed(1)} km (~$_routeDriveMinutes min)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  onPressed: () => setState(() => _showRoutePlanner = false),
                  tooltip: 'Exit Route Mode',
                ),
              ],
            ),
          ),

          if (_userPosition == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: const Color(0xFF0284C7).withValues(alpha: 0.18),
              child: Row(
                children: [
                  const Icon(Icons.gps_off, color: Color(0xFF38BDF8), size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('GPS off — routing from top priority stop.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _locateUser(recenter: false);
                      if (_userPosition != null) _loadDailyRoute();
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
                    child: const Text('Locate Me', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Text('Max:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButton<int>(
                    value: _routeLimit,
                    dropdownColor: const Color(0xFF1E293B),
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    items: const [5, 8, 10, 15, 25]
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n stops')))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _routeLimit = val);
                        _loadDailyRoute();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: const Text('Pending Only', style: TextStyle(fontSize: 11)),
                  selected: _routePendingOnly,
                  selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                  checkmarkColor: const Color(0xFF06B6D4),
                  backgroundColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(color: _routePendingOnly ? const Color(0xFF06B6D4) : Colors.white70),
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    setState(() => _routePendingOnly = val);
                    _loadDailyRoute();
                  },
                ),
              ],
            ),
          ),

          if (_routeSkippedNoCoords > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Text(
                '$_routeSkippedNoCoords assigned chillers missing GPS coordinates were excluded.',
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
              ),
            ),

          Expanded(
            child: _isRouteLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : _routeError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_routeError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              TextButton(onPressed: _loadDailyRoute, child: const Text('Retry', style: TextStyle(color: Colors.cyanAccent))),
                            ],
                          ),
                        ),
                      )
                    : _routeStops.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 32),
                                  const SizedBox(height: 8),
                                  const Text('All matching chillers are visited!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  if (_routePendingOnly) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        setState(() => _routePendingOnly = false);
                                        _loadDailyRoute();
                                      },
                                      child: const Text('Show All Chillers', style: TextStyle(color: Color(0xFF06B6D4))),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            itemCount: _routeStops.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, idx) {
                              final stop = _routeStops[idx];
                              final String vs = (stop['visitStatus'] ?? 'not_visited').toString();
                              final String eff = (stop['efficiency'] ?? '').toString();
                              final double legKm = _toDouble(stop['legDistanceKm'], 0.0);
                              final Color prioColor = vs == 'reopened'
                                  ? const Color(0xFFF97316)
                                  : eff.toLowerCase().contains('under') || eff.toLowerCase().contains('non')
                                      ? const Color(0xFFEF4444)
                                      : vs == 'not_visited'
                                          ? const Color(0xFFF59E0B)
                                          : Colors.white54;

                              return InkWell(
                                onTap: () {
                                  setState(() => _activeRouteStopIndex = idx);
                                  _mapController.move(
                                    LatLng(_toDouble(stop['latitude']), _toDouble(stop['longitude'])),
                                    15.5,
                                  );
                                  _showChillerDetailsModal(stop);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _activeRouteStopIndex == idx ? const Color(0xFF06B6D4) : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF06B6D4),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${idx + 1}',
                                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (stop['customerName'] ?? 'Unknown').toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            Text(
                                              '${stop['chillerCode'] ?? ''} • ${stop['branch'] ?? ''}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              children: [
                                                Text(
                                                  '${legKm.toStringAsFixed(1)} km',
                                                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  (stop['priorityReason'] ?? 'Standard').toString(),
                                                  style: TextStyle(color: prioColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (idx > 0)
                                            InkWell(
                                              onTap: () {
                                                final item = _routeStops.removeAt(idx);
                                                _routeStops.insert(idx - 1, item);
                                                _recalculateRouteStats();
                                              },
                                              child: const Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 18),
                                            ),
                                          if (idx < _routeStops.length - 1)
                                            InkWell(
                                              onTap: () {
                                                final item = _routeStops.removeAt(idx);
                                                _routeStops.insert(idx + 1, item);
                                                _recalculateRouteStats();
                                              },
                                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 18),
                                            ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                        onPressed: () {
                                          _routeStops.removeAt(idx);
                                          _recalculateRouteStats();
                                        },
                                        tooltip: 'Remove from route',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          if (_routeStops.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_routeStops.length > 10)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Opening first 10 stops in Google Maps',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startGoogleMapsRoute,
                      icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Start Route in Google Maps',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showBranchRollupDialog(List<dynamic> rollups) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Branch Target Rollup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _selectedBranch = null);
                _loadRepKpi();
              },
              child: const Text('All Branches', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12)),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(460.0, MediaQuery.of(ctx).size.width - 40),
          height: 360,
          child: ListView.separated(
            itemCount: rollups.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 12),
            itemBuilder: (_, idx) {
              final b = rollups[idx] as Map;
              final name = (b['branch'] ?? 'Unassigned').toString();
              final count = b['assignedCount'] ?? 0;
              final comp = _toDouble(b['completionRate'], 0.0);
              final ach = _toDouble(b['avgAchievement'], 0.0);
              final isSelected = _selectedBranch?.toLowerCase() == name.toLowerCase();

              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _selectedBranch = name);
                  _loadRepKpi();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.14) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? const Color(0xFF06B6D4) : Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Text('$count chillers', style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Text('${comp.toStringAsFixed(0)}% vis', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Text('${ach.toStringAsFixed(1)}% ach', style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (comp / 100.0).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildRepKpiStrip() {
    if (_isKpiLoading && _repKpi == null) {
      return AppSkeleton.kpiStrip(context);
    }
    final kpi = _repKpi;
    final int assigned = (kpi?['assignedCount'] ?? 0) is int ? kpi!['assignedCount'] : int.tryParse('${kpi?['assignedCount'] ?? 0}') ?? 0;
    final int visited = (kpi?['visitedCount'] ?? 0) is int ? kpi!['visitedCount'] : int.tryParse('${kpi?['visitedCount'] ?? 0}') ?? 0;
    final int pending = (kpi?['pendingCount'] ?? 0) is int ? kpi!['pendingCount'] : int.tryParse('${kpi?['pendingCount'] ?? 0}') ?? 0;
    final double? avgAch = (assigned > 0 && kpi?['avgAchievement'] is num)
        ? (kpi!['avgAchievement'] as num).toDouble()
        : null;
    final double visitedPct = assigned > 0 ? (visited / assigned) * 100.0 : 0.0;
    final String scopeLabel = kpi?['scope'] == 'territory' ? 'My Territory' : 'All Territories';
    final List<dynamic> branchRollups = (kpi?['branchRollups'] as List<dynamic>?) ?? [];
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    final pills = [
      _buildKpiPill(
        'Assigned',
        '$assigned',
        const Color(0xFF06B6D4),
        Icons.location_on_outlined,
        isActive: false,
        onTap: () => setState(() => _kpiVisitFilter = null),
      ),
      _buildKpiPill(
        'Visited',
        '$visited (${visitedPct.toStringAsFixed(0)}%)',
        const Color(0xFF10B981),
        Icons.verified_outlined,
        isActive: _kpiVisitFilter == 'visited',
        onTap: () => setState(() {
          _kpiVisitFilter = _kpiVisitFilter == 'visited' ? null : 'visited';
        }),
      ),
      _buildKpiPill(
        'Pending',
        '$pending',
        const Color(0xFFF97316),
        Icons.pending_actions_outlined,
        isActive: _kpiVisitFilter == 'pending',
        onTap: () => setState(() {
          _kpiVisitFilter = _kpiVisitFilter == 'pending' ? null : 'pending';
        }),
      ),
      Tooltip(
        message: 'Mean YTD/Monthly achievement across active chillers',
        child: _buildKpiPill(
          'Avg Ach.',
          avgAch != null ? '${avgAch.toStringAsFixed(1)}%' : 'N/A',
          avgAch != null ? const Color(0xFFA78BFA) : Colors.white60,
          Icons.trending_up_rounded,
        ),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(Icons.speed, color: Color(0xFF06B6D4), size: 18),
                  Text(
                    'Rep KPI Summary ($scopeLabel)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (ApiService.isAdmin && branchRollups.isNotEmpty)
                    InkWell(
                      onTap: () => _showBranchRollupDialog(branchRollups),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_tree_outlined, color: Color(0xFF06B6D4), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Branch: ${_selectedBranch ?? 'All'}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 15),
                          ],
                        ),
                      ),
                    ),
                  if (_kpiVisitFilter != null)
                    InputChip(
                      label: Text(
                        'Filter: ${_kpiVisitFilter == 'visited' ? 'Visited' : 'Pending'}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () => setState(() => _kpiVisitFilter = null),
                      backgroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFF06B6D4)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (_isKpiLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
                    ),
                  if (_kpiError)
                    Tooltip(
                      message: 'Failed to load KPIs. Tap to retry.',
                      child: InkWell(
                        onTap: _loadRepKpi,
                        child: const Icon(Icons.refresh, color: Color(0xFFF59E0B), size: 16),
                      ),
                    ),
                ],
              ),
              if (!isMobile)
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: pills,
                ),
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: pills[0]),
                const SizedBox(width: 8),
                Expanded(child: pills[1]),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: pills[2]),
                const SizedBox(width: 8),
                Expanded(child: pills[3]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiPill(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.28 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color : color.withValues(alpha: 0.45),
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Icons.filter_alt : icon, color: color, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$label: ',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      mouseCursor: SystemMouseCursors.click,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final LatLng centerEgypt = const LatLng(30.0444, 31.2357);
    final displayedChillers = _getFilteredChillers();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          _buildRepKpiStrip(),
          Expanded(
            child: Stack(
        children: [
          // OpenStreetMap Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: displayedChillers.isNotEmpty
                  ? LatLng(
                      _toDouble(displayedChillers.first['latitude'], 30.0444),
                      _toDouble(displayedChillers.first['longitude'], 31.2357),
                    )
                  : centerEgypt,
              initialZoom: 6.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.chiller_analytics',
              ),
              // Radius Circle Layer around Live User GPS
              if (_userPosition != null && _selectedRadiusKm > 0.0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      radius: _selectedRadiusKm * 1000.0,
                      useRadiusInMeter: true,
                      color: const Color(0xFF06B6D4).withOpacity(0.12),
                      borderColor: const Color(0xFF06B6D4),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              // Route Polyline Layer (STORY-005)
              if (_showRoutePlanner && _routeStops.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        if (_userPosition != null) LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        ..._routeStops.map((s) => LatLng(_toDouble(s['latitude']), _toDouble(s['longitude']))),
                      ],
                      strokeWidth: 7.0,
                      color: const Color(0xFF0F172A),
                    ),
                    Polyline(
                      points: [
                        if (_userPosition != null) LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        ..._routeStops.map((s) => LatLng(_toDouble(s['latitude']), _toDouble(s['longitude']))),
                      ],
                      strokeWidth: 4.0,
                      color: const Color(0xFF38BDF8),
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Customer Chillers Markers
                  ...displayedChillers.map((c) {
                    final double lat = _toDouble(c['latitude']);
                    final double lng = _toDouble(c['longitude']);
                    final String eff = c['efficiency'] ?? '';
                    final String visitStatus = (c['visitStatus'] ?? 'not_visited').toString();

                    Color markerColor;
                    IconData markerIcon;

                    if (_pinColorMode == 'condition') {
                      final condCat = _classifyCondition(_extractCondition(c));
                      markerColor = _getConditionColor(condCat);
                      markerIcon = _getConditionIcon(condCat);
                    } else if (visitStatus == 'accepted') {
                      markerColor = const Color(0xFF10B981); // Emerald Green
                      markerIcon = Icons.verified;
                    } else if (visitStatus == 'submitted') {
                      markerColor = const Color(0xFF06B6D4); // Cyan
                      markerIcon = Icons.assignment_turned_in;
                    } else if (visitStatus == 'reopened') {
                      markerColor = const Color(0xFFF97316); // Amber / Orange
                      markerIcon = Icons.priority_high;
                    } else {
                      markerColor = _getMarkerColor(eff);
                      markerIcon = Icons.location_on;
                    }

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 42,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => _showChillerDetailsModal(c),
                        child: Opacity(
                          opacity: _showRoutePlanner ? 0.35 : 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: markerColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: markerColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 2),
                              ],
                            ),
                            child: Icon(markerIcon, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  if (_showRoutePlanner)
                    ...List.generate(_routeStops.length, (idx) {
                      final stop = _routeStops[idx];
                      final double lat = _toDouble(stop['latitude']);
                      final double lng = _toDouble(stop['longitude']);
                      final bool isActive = _activeRouteStopIndex == idx;
                      final String vs = (stop['visitStatus'] ?? 'not_visited').toString();
                      final String eff = (stop['efficiency'] ?? '').toString().toLowerCase();
                      final Color ringColor = vs == 'reopened'
                          ? const Color(0xFFF97316)
                          : (eff.contains('under') || eff.contains('non') || eff.contains('critical'))
                              ? const Color(0xFFEF4444)
                              : Colors.white;
                      final double size = isActive ? 36.0 : 30.0;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: size + 4,
                        height: size + 4,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _activeRouteStopIndex = idx);
                            _mapController.move(LatLng(lat, lng), 15.5);
                            _showChillerDetailsModal(stop);
                          },
                          child: Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4),
                              shape: BoxShape.circle,
                              border: Border.all(color: isActive ? Colors.white : ringColor, width: isActive ? 3.0 : 2.0),
                              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      );
                    }),
                  // Live User GPS Marker
                  if (_userPosition != null)
                    Marker(
                      point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      width: 52,
                      height: 52,
                      child: Tooltip(
                        message: 'You are here (Live GPS Position)',
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0284C7).withOpacity(0.35),
                                border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withOpacity(0.55),
                                    blurRadius: 12,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Floating Filter Toolbar on Top
          if (_isToolbarMinimized)
            Positioned(
              top: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _isToolbarMinimized = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.cyan.withOpacity(0.6), width: 1.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, color: Colors.cyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${displayedChillers.length} Pins',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (_userPosition != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          const Text('GPS Active', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.cyan.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.expand_more, color: Colors.cyanAccent, size: 18),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Expand Filters',
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Title + Count + Minimize Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, color: Colors.cyan),
                        const SizedBox(width: 8),
                        Text(
                          'Map Locations (${displayedChillers.length} Pins)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_selectedRadiusKm > 0.0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                              ),
                              child: Text(
                                '≤ ${_selectedRadiusKm.toInt()} km',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        // Minimize Button
                        Tooltip(
                          message: 'Minimize toolbar for better map view',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _isToolbarMinimized = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.unfold_less, color: Colors.cyanAccent, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Minimize',
                                    style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Filters
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Pin Color Mode Toggle (Efficiency | Condition)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPinModeChip('efficiency', 'Efficiency', Icons.speed),
                            _buildPinModeChip('condition', 'Condition', Icons.build_circle_outlined),
                          ],
                        ),
                      ),

                      // Condition Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedCondition != 'All' ? Colors.orangeAccent : Colors.white24,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCondition,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.health_and_safety_outlined, color: Colors.orangeAccent, size: 18),
                            items: _conditionOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text('Condition: '));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCondition = val);
                              }
                            },
                          ),
                        ),
                      ),

                      // Efficiency Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedEfficiency,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.filter_alt, color: Colors.cyan, size: 18),
                            items: _efficiencyOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text('Efficiency: $opt'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedEfficiency = val);
                                _loadChillers();
                              }
                            },
                          ),
                        ),
                      ),

                      // Customer Type Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCustomerType,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.person, color: Colors.cyan, size: 18),
                            items: _customerTypeOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text('Type: $opt'));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCustomerType = val);
                                _loadChillers();
                              }
                            },
                          ),
                        ),
                      ),

                      // GPS Radius Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedRadiusKm > 0 ? Colors.cyanAccent : Colors.white24,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _selectedRadiusKm,
                            dropdownColor: const Color(0xFF1E293B),
                            style: TextStyle(
                              color: _selectedRadiusKm > 0 ? Colors.cyanAccent : Colors.white,
                              fontSize: 13,
                              fontWeight: _selectedRadiusKm > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                            icon: Icon(
                              Icons.radar,
                              color: _selectedRadiusKm > 0 ? Colors.cyanAccent : Colors.cyan,
                              size: 18,
                            ),
                            items: _radiusOptions.map((r) {
                              return DropdownMenuItem<double>(
                                value: r,
                                child: Text(r == 0.0 ? 'Radius: All' : 'Within ${r.toInt()} km'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRadiusKm = val);
                                if (val > 0 && _userPosition == null) {
                                  _locateUser(recenter: false);
                                }
                              }
                            },
                          ),
                        ),
                      ),

                      // Unified Master Dataset Badge (Single view with latest increment)
                      Tooltip(
                        message: 'Unified Master Dataset (reflects all cumulative chillers with latest increments)',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.layers_rounded, color: Colors.cyan, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                _batches.isNotEmpty
                                    ? 'Master Dataset: ${_chillers.length} Chillers (Latest: Batch #${_batches.first['id']})'
                                    : 'Master Dataset: ${_chillers.length} Chillers',
                                style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Search box
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search code/customer...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                                onPressed: () {
                                  setState(() => _searchQuery = _searchController.text.trim());
                                  _loadChillers();
                                },
                              ),
                            ),
                            onSubmitted: (val) {
                              setState(() => _searchQuery = val.trim());
                              _loadChillers();
                            },
                          ),
                        ),
                      ),

                      // Action buttons: Refresh, Fit Bounds & GPS Icon
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.cyan, size: 20),
                              tooltip: 'Refresh pins from database',
                              onPressed: () => reload(forceRecenter: true, forceApi: true),
                            ),
                            IconButton(
                              icon: const Icon(Icons.center_focus_strong, color: Colors.cyan, size: 20),
                              tooltip: 'Fit map bounds to all pins',
                              onPressed: _fitBoundsToChillers,
                            ),
                            IconButton(
                              icon: const Icon(Icons.unfold_less, color: Colors.cyan, size: 20),
                              tooltip: 'Minimize toolbar (better map view)',
                              onPressed: () => setState(() => _isToolbarMinimized = true),
                            ),
                          ],
                        ),
                      ),

                      // Dedicated "My Location" Button right in this toolbar area
                      ElevatedButton.icon(
                        onPressed: _isLocating ? null : () => _locateUser(recenter: true),
                        icon: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(color: Colors.cyanAccent, strokeWidth: 2),
                              )
                            : Icon(
                                _userPosition != null ? Icons.my_location : Icons.location_searching,
                                color: _userPosition != null ? Colors.cyanAccent : Colors.cyan,
                                size: 18,
                              ),
                        label: Text(
                          _userPosition != null ? 'My Location 📍' : 'My Location',
                          style: TextStyle(
                            color: _userPosition != null ? Colors.cyanAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _userPosition != null ? const Color(0xFF0369A1).withOpacity(0.4) : const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          side: BorderSide(
                            color: _userPosition != null ? Colors.cyanAccent : Colors.cyan.withOpacity(0.6),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),

                      // "Surrounding Locations" Toggle Button right in this toolbar area
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showSurroundingPanel = !_showSurroundingPanel;
                          });
                          if (_showSurroundingPanel && _userPosition == null) {
                            _locateUser(recenter: false);
                          }
                        },
                        icon: Icon(
                          Icons.near_me_outlined,
                          color: _showSurroundingPanel ? Colors.cyanAccent : Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          _userPosition != null
                              ? 'Surrounding (${_getSurroundingSortedChillers().length})'
                              : 'Surrounding',
                          style: TextStyle(
                            color: _showSurroundingPanel ? Colors.cyanAccent : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _showSurroundingPanel ? Colors.cyan.withOpacity(0.2) : const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          side: BorderSide(
                            color: _showSurroundingPanel ? Colors.cyanAccent : Colors.white24,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating GPS & Surrounding Buttons (Bottom-Right)
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Plan My Day Smart Daily Route FAB (STORY-005)
                FloatingActionButton.extended(
                  heroTag: 'fab_route_planner',
                  onPressed: () {
                    final next = !_showRoutePlanner;
                    setState(() {
                      _showRoutePlanner = next;
                      if (next) _showSurroundingPanel = false;
                    });
                    if (next) _loadDailyRoute();
                  },
                  backgroundColor: _showRoutePlanner ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
                  foregroundColor: _showRoutePlanner ? const Color(0xFF0F172A) : const Color(0xFF06B6D4),
                  icon: const Icon(Icons.route_rounded),
                  label: Text(
                    _showRoutePlanner ? 'Route (${_routeStops.length})' : 'Plan My Day',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                // Surrounding Locations Button
                FloatingActionButton.extended(
                  heroTag: 'fab_surrounding',
                  onPressed: () {
                    setState(() {
                      _showSurroundingPanel = !_showSurroundingPanel;
                      if (_showSurroundingPanel) _showRoutePlanner = false;
                    });
                    if (_showSurroundingPanel && _userPosition == null) {
                      _locateUser(recenter: false);
                    }
                  },
                  backgroundColor: _showSurroundingPanel ? Colors.cyanAccent : const Color(0xFF1E293B),
                  foregroundColor: _showSurroundingPanel ? const Color(0xFF0F172A) : Colors.cyanAccent,
                  icon: const Icon(Icons.near_me_outlined),
                  label: Text(
                    _userPosition != null
                        ? 'Surrounding (${_getSurroundingSortedChillers().length})'
                        : 'Surrounding Locations',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                // GPS Locate Me Button
                FloatingActionButton(
                  heroTag: 'fab_gps',
                  onPressed: _isLocating ? null : () => _locateUser(recenter: true),
                  backgroundColor: _userPosition != null ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  tooltip: 'My Live GPS Location',
                  child: _isLocating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Icon(
                          _userPosition != null ? Icons.my_location : Icons.location_searching,
                          color: _userPosition != null ? Colors.white : Colors.cyanAccent,
                        ),
                ),
              ],
            ),
          ),

          // Collapsible Surrounding Locations Panel (Bottom-Left)
          if (_showSurroundingPanel)
            Positioned(
              bottom: 24,
              left: 16,
              child: _buildSurroundingLocationsPanel(context),
            ),

          // Smart Daily Route Planner Panel (STORY-005)
          if (_showRoutePlanner)
            Positioned(
              bottom: 24,
              left: 16,
              child: _buildRoutePlannerPanel(context),
            ),

          // Dynamic Floating Map Legend (Efficiency | Condition)
          if (!_showSurroundingPanel && !_showRoutePlanner)
            Positioned(
              bottom: 24,
              left: 16,
              child: _buildMapLegend(context),
            ),

          // Empty State when no pins match
          if (!_isLoading && displayedChillers.isEmpty && !_showSurroundingPanel && !_showRoutePlanner)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _chillers.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.location_off_outlined,
                          title: 'No chiller locations loaded',
                          subtitle: 'Upload an Excel or CSV dataset to plot customer chillers on the map.',
                        )
                      : AppEmptyState.noFilterMatches(
                          onResetFilters: _resetAllMapFilters,
                        ),
                ),
              ),
            ),

          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppSkeleton.mapLoadingOverlay(context),
            ),
        ],
      ),
    ),
        ],
      ),
    );
  }

  Widget _buildPinModeChip(String mode, String label, IconData icon) {
    final bool selected = _pinColorMode == mode;
    final t = AppTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _pinColorMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.accentPrimary.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: t.accentPrimary.withValues(alpha: 0.7)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? t.accentPrimary : Colors.white60),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? t.accentPrimary : Colors.white70,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLegend(BuildContext context) {
    final t = AppTokens.of(context);
    final bool isCondition = _pinColorMode == 'condition';
    final List<({String label, Color color, IconData icon})> items = isCondition
        ? const [
            (label: 'Operational', color: Color(0xFF10B981), icon: Icons.check_circle_outline),
            (label: 'Requires Maint.', color: Color(0xFFF97316), icon: Icons.build_circle_outlined),
            (label: 'Scrap', color: Color(0xFFEF4444), icon: Icons.dangerous_outlined),
            (label: 'Unspecified', color: Color(0xFF64748B), icon: Icons.help_outline),
          ]
        : const [
            (label: 'Performing', color: Color(0xFF10B981), icon: Icons.location_on),
            (label: 'Non-Performing', color: Color(0xFFEF4444), icon: Icons.location_on),
            (label: 'Zero', color: Color(0xFFF59E0B), icon: Icons.location_on),
            (label: 'Verified', color: Color(0xFF10B981), icon: Icons.verified),
            (label: 'Submitted', color: Color(0xFF06B6D4), icon: Icons.assignment_turned_in),
            (label: 'Re-opened', color: Color(0xFFF97316), icon: Icons.priority_high),
          ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCondition ? 'CONDITION LEGEND' : 'EFFICIENCY & VISIT LEGEND',
            style: t.eyebrow.copyWith(color: t.accentPrimary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: items.map((item) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                    child: Icon(item.icon, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 5),
                  Text(item.label, style: t.caption.copyWith(color: t.textPrimary)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}