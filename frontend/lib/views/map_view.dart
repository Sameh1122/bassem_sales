import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/url_launcher.dart';
import '../services/api_service.dart';

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
  final List<String> _customerTypeOptions = ['All', 'Retail', 'LS', 'SM', 'LG'];

  // GPS / My Location State
  bool _isLocating = false;
  Position? _userPosition;
  double _selectedRadiusKm = 0.0; // 0.0 = All (No filter)
  bool _showSurroundingPanel = false;
  final List<double> _radiusOptions = [0.0, 1.0, 3.0, 5.0, 10.0, 25.0, 50.0];

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadChillers(forceRecenter: true);
  }

  Future<void> _locateUser({bool recenter = true}) async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS / Location services are turned off. Please enable them on your device/browser.'),
              backgroundColor: Colors.amber,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission was denied.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please allow location in browser site settings.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

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
            content: Text('📍 Live GPS location acquired (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not obtain live GPS location: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  double? _getDistanceMeters(dynamic chiller) {
    if (_userPosition == null) return null;
    final lat = _toDouble(chiller['latitude'], 0.0);
    final lng = _toDouble(chiller['longitude'], 0.0);
    if (lat == 0.0 || lng == 0.0) return null;
    return Geolocator.distanceBetween(_userPosition!.latitude, _userPosition!.longitude, lat, lng);
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

  void reload({bool forceRecenter = false, bool forceApi = false}) {
    _loadBatches();
    _loadChillers(forceRecenter: forceRecenter, forceApi: forceApi);
  }

  void reloadChillers() {
    _loadBatches();
    _loadChillers(forceRecenter: true);
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
    final rawData = chiller['rawData'] ?? {};
    final String code = chiller['chillerCode'] ?? 'N/A';
    final String status = chiller['chillerStatus'] ?? 'N/A';
    final String customerName = chiller['customerName'] ?? 'N/A';
    final String efficiency = chiller['efficiency'] ?? 'N/A';
    final String customerType = chiller['customerType'] ?? 'N/A';
    final double lat = _toDouble(chiller['latitude'], 30.0444);
    final double lng = _toDouble(chiller['longitude'], 31.2357);
    final double? distMeters = _getDistanceMeters(chiller);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getMarkerColor(efficiency).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.ac_unit, color: _getMarkerColor(efficiency)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Customer: $customerName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: math.min(580.0, MediaQuery.of(context).size.width - 32),
          height: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (distMeters != null)
                      _buildBadge('📍 ${_formatDistance(distMeters)} from you', const Color(0xFF06B6D4)),
                    _buildBadge('Efficiency: $efficiency', _getMarkerColor(efficiency)),
                    _buildBadge('Type: $customerType', Colors.cyan),
                    _buildBadge('Status: $status', Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Maps Directions Banner Button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.4)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GPS Location Coordinates', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Lat: $lat, Lng: $lng', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          if (distMeters != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Distance: ${_formatDistance(distMeters)}',
                                style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openGoogleMapsDirections(lat, lng),
                        icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                        label: Text(
                          _userPosition != null ? 'Start Navigation (Live GPS)' : 'Open Google Maps',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4), // Google Blue
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text('All Row Attributes (Full Record)', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...rawData.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 180,
                          child: Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value?.toString() ?? '-',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _openGoogleMapsDirections(lat, lng),
            icon: const Icon(Icons.directions, color: Colors.white, size: 16),
            label: const Text('Google Maps GPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4285F4)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final LatLng centerEgypt = const LatLng(30.0444, 31.2357);
    final displayedChillers = _getFilteredChillers();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
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
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Customer Chillers Markers
                  ...displayedChillers.map((c) {
                    final double lat = _toDouble(c['latitude']);
                    final double lng = _toDouble(c['longitude']);
                    final String eff = c['efficiency'] ?? '';
                    final Color markerColor = _getMarkerColor(eff);

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showChillerDetailsModal(c),
                        child: Container(
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: markerColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 2),
                            ],
                          ),
                          child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                        ),
                      ),
                    );
                  }),
                  // Live User Position Radar Marker
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
                  // Title + Count
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
                    ],
                  ),

                  // Filters
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
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

                      // Upload Batch / Date Filter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<dynamic>(
                            value: _selectedBatchId,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.w600),
                            icon: const Icon(Icons.history_toggle_off, color: Colors.cyan, size: 18),
                            items: [
                              const DropdownMenuItem(
                                value: 'All',
                                child: Text('📅 All Uploads (Latest Active)'),
                              ),
                              ..._batches.map((b) {
                                final id = b['id'];
                                final filename = b['filename'] ?? 'Upload';
                                final rawDate = b['uploaded_at'] ?? '';
                                String shortDate = rawDate;
                                if (rawDate.length >= 16) {
                                  shortDate = rawDate.substring(0, 16).replaceAll('T', ' ');
                                }
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text('📦 Batch #$id: $filename ($shortDate)'),
                                );
                              }).toList(),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedBatchId = val);
                                _loadChillers(forceRecenter: true, forceApi: true);
                              }
                            },
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
                // Surrounding Locations Button
                FloatingActionButton.extended(
                  heroTag: 'fab_surrounding',
                  onPressed: () {
                    setState(() {
                      _showSurroundingPanel = !_showSurroundingPanel;
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

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.cyan),
            ),
        ],
      ),
    );
  }
}
