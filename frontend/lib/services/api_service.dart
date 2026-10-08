import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'storage.dart';

class ApiService {
  static String get baseUrl {
    final Uri currentUri = Uri.base;
    if (currentUri.host == 'localhost' || currentUri.host == '127.0.0.1') {
      if (currentUri.port != 5000) {
        return 'http://localhost:5000/api';
      }
    }
    return '/api';
  }

  static dynamic _safeJsonDecode(String body) {
    try {
      final trimmed = body.trim();
      if (trimmed.startsWith('<')) {
        return {'error': 'Server error (HTML returned instead of JSON)'};
      }
      return jsonDecode(trimmed);
    } catch (e) {
      return {'error': 'Failed to parse JSON response: $e'};
    }
  }

  // Fetch dynamic column definitions
  static Future<List<dynamic>> getColumns() async {
    final response = await http.get(Uri.parse('$baseUrl/columns'));
    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response.body);
      if (data is Map && data.containsKey('columns')) {
        return data['columns'] ?? [];
      }
    }
    throw Exception('Failed to fetch column definitions');
  }

  // Add new column
  static Future<bool> addColumn({
    required String keyName,
    required String displayLabel,
    required String dataType,
    required bool isRequired,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/columns'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'key_name': keyName,
        'display_label': displayLabel,
        'data_type': dataType,
        'is_required': isRequired,
        'is_active': 1,
      }),
    );
    return response.statusCode == 200;
  }

  // Toggle active/required column status
  static Future<bool> toggleColumnStatus(int id, {bool? isActive, bool? isRequired}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/columns/toggle'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        if (isActive != null) 'is_active': isActive,
        if (isRequired != null) 'is_required': isRequired,
      }),
    );
    return response.statusCode == 200;
  }

  // Load sample Excel from Scratch folder
  static Future<Map<String, dynamic>> loadScratchSample() async {
    final response = await http.get(Uri.parse('$baseUrl/excel/scratch-sample'));
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null) ? decoded['error'] : 'Failed to load sample Excel file (${response.statusCode})';
    throw Exception(errorMsg);
  }

  // Upload custom Excel file via Base64 JSON payload for cross-platform cloud support
  static Future<Map<String, dynamic>> uploadExcelFile(Uint8List fileBytes, String fileName) async {
    final String base64Content = base64Encode(fileBytes);
    final response = await http.post(
      Uri.parse('$baseUrl/excel/parse'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fileBase64': base64Content,
        'filename': fileName,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null) ? decoded['error'] : 'Failed to upload Excel file (${response.statusCode})';
    throw Exception(errorMsg);
  }

  static List<dynamic>? _cachedChillers;

  static List<dynamic> _sanitizeRows(List<dynamic> rows) {
    return rows.map((r) {
      if (r is! Map) return r;
      final Map<String, dynamic> clean = {
        'rowIndex': r['rowIndex'],
        'chillerCode': r['chillerCode'],
        'latitude': r['latitude'],
        'longitude': r['longitude'],
        'customerType': r['customerType'],
        'efficiency': r['efficiency'],
        'branch': r['branch'],
        'chillerType': r['chillerType'],
        'chillerStatus': r['chillerStatus'],
        'condition': r['condition'],
        'customerName': r['customerName'],
        'customerAddress': r['customerAddress'],
        'mobileNumber': r['mobileNumber'],
        'isValid': r['isValid'],
      };
      if (r['rowObj'] is Map) {
        clean['rawData'] = Map<String, dynamic>.from(r['rowObj']);
      } else if (r['rawData'] is Map) {
        clean['rawData'] = Map<String, dynamic>.from(r['rawData']);
      }
      return clean;
    }).toList();
  }

  // Confirm upload and save to DB
  static Future<Map<String, dynamic>> confirmUpload({
    required String filename,
    required List<dynamic> rows,
    required bool bypassValidation,
  }) async {
    final cleanRows = _sanitizeRows(rows);
    final response = await http.post(
      Uri.parse('$baseUrl/excel/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'filename': filename,
        'rows': cleanRows,
        'bypassValidation': bypassValidation,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      if (decoded['chillers'] != null && decoded['chillers'] is List) {
        _cachedChillers = List<dynamic>.from(decoded['chillers']);
      } else {
        final List<dynamic> validList = bypassValidation
            ? rows
            : rows.where((r) => r['isValid'] != false).toList();

        _cachedChillers = validList.map((r) {
          final Map<String, dynamic> raw = (r['rowObj'] is Map)
              ? Map<String, dynamic>.from(r['rowObj'])
              : ((r['rawData'] is Map) ? Map<String, dynamic>.from(r['rawData']) : <String, dynamic>{});
          return {
            'id': r['rowIndex'] ?? (_cachedChillers?.length ?? 0) + 1,
            'chillerCode': r['chillerCode'] ?? '',
            'batchId': decoded['batchId'] ?? 1,
            'latitude': r['latitude'],
            'longitude': r['longitude'],
            'customerType': r['customerType'] ?? 'Retail',
            'efficiency': r['efficiency'] ?? 'Performing',
            'branch': r['branch'] ?? '',
            'chillerType': r['chillerType'] ?? '',
            'chillerStatus': r['chillerStatus'] ?? '',
            'condition': r['condition'] ?? '',
            'customerName': r['customerName'] ?? '',
            'rawData': raw,
          };
        }).toList();
      }

      if (_cachedChillers != null && _cachedChillers!.isNotEmpty) {
        setLocalStorage('chillers_dataset', jsonEncode(_cachedChillers));
      }

      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null) ? decoded['error'] : 'Failed to confirm upload (${response.statusCode})';
    throw Exception(errorMsg);
  }

  // Fetch chillers for Map view
  static Future<List<dynamic>> fetchChillers({
    String efficiency = 'All',
    String customerType = 'All',
    String search = '',
    dynamic batchId = 'All',
    bool forceApi = false,
  }) async {
    final bool hasBatchFilter = batchId != null && batchId != 'All' && batchId != 'all';

    if (!forceApi && !hasBatchFilter && _cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search, batchId);
    }

    final uri = Uri.parse('$baseUrl/chillers').replace(queryParameters: {
      if (efficiency != 'All') 'efficiency': efficiency,
      if (customerType != 'All') 'customerType': customerType,
      if (search.isNotEmpty) 'search': search,
      if (hasBatchFilter) 'batchId': batchId.toString(),
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data is Map && data.containsKey('chillers')) {
          final List<dynamic> fetched = data['chillers'] ?? [];
          if (!hasBatchFilter) {
            _cachedChillers = fetched;
            setLocalStorage('chillers_dataset', jsonEncode(fetched));
          }
          return _filterLocalChillers(fetched, efficiency, customerType, search, batchId);
        }
      }
    } catch (_) {
      // Fallback to cache if network fails
    }

    if (_cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search, batchId);
    }

    final stored = getLocalStorage('chillers_dataset');
    if (stored != null && stored.isNotEmpty) {
      try {
        final decodedStored = jsonDecode(stored);
        if (decodedStored is List && decodedStored.isNotEmpty) {
          _cachedChillers = decodedStored;
          return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search, batchId);
        }
      } catch (_) {}
    }

    return [];
  }

  static List<dynamic> _filterLocalChillers(
    List<dynamic> all,
    String efficiency,
    String customerType,
    String search, [
    dynamic batchId = 'All',
  ]) {
    final bool hasBatchFilter = batchId != null && batchId != 'All' && batchId != 'all';
    final int? filterBatchId = hasBatchFilter ? int.tryParse(batchId.toString()) : null;

    return all.where((c) {
      if (filterBatchId != null) {
        final bId = c['batchId'] ?? c['batch_id'];
        if (bId != null && bId != filterBatchId) return false;
      }
      if (efficiency != 'All') {
        final eff = (c['efficiency'] ?? '').toString().toLowerCase();
        if (eff != efficiency.toLowerCase()) return false;
      }
      if (customerType != 'All') {
        final type = (c['customerType'] ?? '').toString().toLowerCase();
        if (type != customerType.toLowerCase()) return false;
      }
      if (search.isNotEmpty) {
        final term = search.toLowerCase();
        final code = (c['chillerCode'] ?? '').toString().toLowerCase();
        final cust = (c['customerName'] ?? '').toString().toLowerCase();
        final branch = (c['branch'] ?? '').toString().toLowerCase();
        if (!code.contains(term) && !cust.contains(term) && !branch.contains(term)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Fetch upload history batches
  static Future<List<dynamic>> fetchBatches() async {
    final response = await http.get(Uri.parse('$baseUrl/batches'));
    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response.body);
      if (data is Map && data.containsKey('batches')) {
        return data['batches'] ?? [];
      }
    }
    throw Exception('Failed to fetch upload batches');
  }

  // Delete an upload batch
  static Future<Map<String, dynamic>> deleteBatch(int batchId) async {
    final response = await http.delete(Uri.parse('$baseUrl/batches/$batchId'));
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      // Invalidate cached chillers so fresh state is fetched
      _cachedChillers = null;
      removeLocalStorage('chillers_dataset');
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null)
        ? decoded['error']
        : 'Failed to delete batch #$batchId (${response.statusCode})';
    throw Exception(errorMsg);
  }

  // Fetch delta comparison between batches
  static Future<Map<String, dynamic>> fetchDelta(int startBatchId, int endBatchId) async {
    final uri = Uri.parse('$baseUrl/delta').replace(queryParameters: {
      'startBatchId': startBatchId.toString(),
      'endBatchId': endBatchId.toString(),
    });

    final response = await http.get(uri);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Failed to compare delta batches');
  }

  // Clear active dataset
  static Future<bool> clearChillers() async {
    _cachedChillers = [];
    final response = await http.delete(Uri.parse('$baseUrl/chillers/clear'));
    return response.statusCode == 200;
  }

  // ==========================================
  // Sales Agents Methods
  // ==========================================

  static Future<List<dynamic>> fetchAgents() async {
    final response = await http.get(Uri.parse('$baseUrl/agents'));
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded.containsKey('agents')) {
      return decoded['agents'] ?? [];
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to fetch sales agents');
  }

  static Future<Map<String, dynamic>> createAgent({
    required String name,
    required String area,
    String phone = '',
    String email = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/agents'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'area': area,
        'phone': phone,
        'email': email,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to create sales agent');
  }

  static Future<Map<String, dynamic>> updateAgent({
    required int id,
    required String name,
    required String area,
    String phone = '',
    String email = '',
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/agents/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'area': area,
        'phone': phone,
        'email': email,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to update sales agent');
  }

  static Future<bool> deleteAgent(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/agents/$id'));
    return response.statusCode == 200;
  }

  // ==========================================
  // Location Assignments Methods
  // ==========================================

  static Future<Map<String, dynamic>> fetchLatestBatchChillers({
    String search = '',
    String agentId = 'All',
    String assignmentStatus = 'all',
    String batchId = 'all',
  }) async {
    final uri = Uri.parse('$baseUrl/chillers/latest-batch').replace(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (agentId != 'All') 'agentId': agentId,
      if (assignmentStatus != 'all') 'assignmentStatus': assignmentStatus,
      if (batchId.isNotEmpty) 'batchId': batchId,
    });

    final response = await http.get(uri);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to fetch latest batch chillers');
  }

  static Future<Map<String, dynamic>> assignLocations({
    required int agentId,
    List<String>? chillerCodes,
    List<String>? customerNames,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assignments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'agent_id': agentId,
        if (chillerCodes != null) 'chiller_codes': chillerCodes,
        if (customerNames != null) 'customer_names': customerNames,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to assign locations');
  }

  static Future<bool> unassignLocation({String? customerName, String? chillerCode}) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/assignments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (customerName != null) 'customer_name': customerName,
        if (chillerCode != null) 'chiller_code': chillerCode,
      }),
    );
    return response.statusCode == 200;
  }
}
