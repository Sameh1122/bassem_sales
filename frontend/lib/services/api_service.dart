import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
      final List<dynamic> validList = bypassValidation
          ? rows
          : rows.where((r) => r['isValid'] != false).toList();

      final newChillers = validList.map((r) {
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

      _cachedChillers = newChillers;
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
    bool forceApi = false,
  }) async {
    if (!forceApi && _cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search);
    }

    final uri = Uri.parse('$baseUrl/chillers').replace(queryParameters: {
      if (efficiency != 'All') 'efficiency': efficiency,
      if (customerType != 'All') 'customerType': customerType,
      if (search.isNotEmpty) 'search': search,
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data is Map && data.containsKey('chillers')) {
          final list = (data['chillers'] as List<dynamic>?) ?? [];
          if (efficiency == 'All' && customerType == 'All' && search.isEmpty) {
            _cachedChillers = list;
          }
          return list;
        }
      }
    } catch (_) {
      // Fallback to cache if network fails
    }

    if (_cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search);
    }

    throw Exception('Failed to fetch chillers data');
  }

  static List<dynamic> _filterLocalChillers(
    List<dynamic> all,
    String efficiency,
    String customerType,
    String search,
  ) {
    return all.where((c) {
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
}
