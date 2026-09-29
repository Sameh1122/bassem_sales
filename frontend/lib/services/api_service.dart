import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Fetch dynamic column definitions
  static Future<List<dynamic>> getColumns() async {
    final response = await http.get(Uri.parse('$baseUrl/columns'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['columns'] ?? [];
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
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to load sample Excel file');
  }

  // Upload custom Excel file
  static Future<Map<String, dynamic>> uploadExcelFile(Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse('$baseUrl/excel/parse');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to upload Excel file');
  }

  // Confirm upload and save to SQLite DB
  static Future<Map<String, dynamic>> confirmUpload({
    required String filename,
    required List<dynamic> rows,
    required bool bypassValidation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/excel/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'filename': filename,
        'rows': rows,
        'bypassValidation': bypassValidation,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to confirm upload');
  }

  // Fetch chillers for Map view
  static Future<List<dynamic>> fetchChillers({
    String efficiency = 'All',
    String customerType = 'All',
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/chillers').replace(queryParameters: {
      if (efficiency != 'All') 'efficiency': efficiency,
      if (customerType != 'All') 'customerType': customerType,
      if (search.isNotEmpty) 'search': search,
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['chillers'] ?? [];
    }
    throw Exception('Failed to fetch chillers data');
  }

  // Fetch upload history batches
  static Future<List<dynamic>> fetchBatches() async {
    final response = await http.get(Uri.parse('$baseUrl/batches'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['batches'] ?? [];
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
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to compare delta batches');
  }

  // Clear active dataset
  static Future<bool> clearChillers() async {
    final response = await http.delete(Uri.parse('$baseUrl/chillers/clear'));
    return response.statusCode == 200;
  }
}
