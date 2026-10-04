import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  bool _isLoading = true;
  bool _hasInitialFitted = false;
  String _selectedEfficiency = 'All';
  String _selectedCustomerType = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _efficiencyOptions = ['All', 'Performing', 'Non-Performing', 'Zero'];
  final List<String> _customerTypeOptions = ['All', 'Retail', 'LS', 'SM', 'LG'];

  @override
  void initState() {
    super.initState();
    _loadChillers(forceRecenter: true);
  }

  void reload({bool forceRecenter = false, bool forceApi = false}) {
    _loadChillers(forceRecenter: forceRecenter, forceApi: forceApi);
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
    final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
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
          width: 580,
          height: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Badges
                Row(
                  children: [
                    _buildBadge('Efficiency: $efficiency', _getMarkerColor(efficiency)),
                    const SizedBox(width: 8),
                    _buildBadge('Type: $customerType', Colors.cyan),
                    const SizedBox(width: 8),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('GPS Location Coordinates', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Lat: $lat, Lng: $lng', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openGoogleMapsDirections(lat, lng),
                        icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
                        label: const Text('Open Google Maps (Start Trip)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    final LatLng centerEgypt = const LatLng(30.0444, 31.2357);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // OpenStreetMap Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _chillers.isNotEmpty
                  ? LatLng(
                      _toDouble(_chillers.first['latitude'], 30.0444),
                      _toDouble(_chillers.first['longitude'], 31.2357),
                    )
                  : centerEgypt,
              initialZoom: 6.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.chiller_analytics',
              ),
              MarkerLayer(
                markers: _chillers.where((c) {
                  final lat = _toDouble(c['latitude'], 0.0);
                  final lng = _toDouble(c['longitude'], 0.0);
                  return lat != 0.0 && lng != 0.0;
                }).map((c) {
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
                }).toList(),
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
                        'Map Locations (${_chillers.length} Pins)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),

                  // Filters
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(width: 12),

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
                      const SizedBox(width: 12),

                      // Search box
                      SizedBox(
                        width: 200,
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
                      const SizedBox(width: 8),
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
                    ],
                  ),
                ],
              ),
            ),
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
