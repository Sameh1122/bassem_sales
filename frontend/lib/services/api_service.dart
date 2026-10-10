import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'storage.dart';

class ApiService {
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static void initAuth() {
    _token = getLocalStorage('auth_token');
    final userJson = getLocalStorage('auth_user');
    if (userJson != null && userJson.isNotEmpty) {
      try {
        _currentUser = jsonDecode(userJson) as Map<String, dynamic>;
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty && _currentUser != null;
  static bool get isAdmin => _currentUser != null && _currentUser!['role'] == 'admin';
  static bool get isAgent => _currentUser != null && _currentUser!['role'] == 'agent';
  static Map<String, dynamic>? get currentUser => _currentUser;
  static String? get token => _token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  static Map<String, String> get _authHeaders => {
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

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

  // ==========================================
  // Authentication Methods
  // ==========================================

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      _token = decoded['token'];
      _currentUser = Map<String, dynamic>.from(decoded['user'] ?? {});
      setLocalStorage('auth_token', _token ?? '');
      setLocalStorage('auth_user', jsonEncode(_currentUser));
      // Invalidate cache on login
      _cachedChillers = null;
      removeLocalStorage('chillers_dataset');
      return Map<String, dynamic>.from(decoded);
    }
    final error = decoded is Map && decoded['error'] != null ? decoded['error'] : 'Login failed (${response.statusCode})';
    throw Exception(error);
  }

  static void logout() {
    _token = null;
    _currentUser = null;
    setLocalStorage('auth_token', '');
    setLocalStorage('auth_user', '');
    _cachedChillers = null;
    removeLocalStorage('chillers_dataset');
  }

  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: _headers,
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded);
    }
    final error = decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to change password';
    throw Exception(error);
  }

  static Future<Map<String, dynamic>> resetAgentPassword(int agentId, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-agent-password'),
      headers: _headers,
      body: jsonEncode({'agentId': agentId, 'newPassword': newPassword}),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded);
    }
    final error = decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to set agent password';
    throw Exception(error);
  }

  // ==========================================
  // Columns Definitions
  // ==========================================

  static Future<List<dynamic>> getColumns() async {
    final response = await http.get(Uri.parse('$baseUrl/columns'), headers: _authHeaders);
    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response.body);
      if (data is Map && data.containsKey('columns')) {
        return data['columns'] ?? [];
      }
    }
    throw Exception('Failed to fetch column definitions');
  }

  static Future<bool> addColumn({
    required String keyName,
    required String displayLabel,
    required String dataType,
    required bool isRequired,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/columns'),
      headers: _headers,
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

  static Future<bool> toggleColumnStatus(int id, {bool? isActive, bool? isRequired}) async {
    final Map<String, dynamic> body = {'id': id};
    if (isActive != null) body['is_active'] = isActive;
    if (isRequired != null) body['is_required'] = isRequired;
    final response = await http.post(
      Uri.parse('$baseUrl/columns/toggle'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> uploadExcelFile(Uint8List bytes, String filename) async {
    return parseExcelFile(bytes, filename);
  }

  // ==========================================
  // Excel Parsing & Ingest
  // ==========================================

  static Future<Map<String, dynamic>> parseExcelFile(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/excel/parse'));
    request.headers.addAll(_authHeaders);
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null) ? decoded['error'] : 'Failed to parse file (${response.statusCode})';
    throw Exception(errorMsg);
  }

  static Future<Map<String, dynamic>> loadScratchSample() async {
    final response = await http.get(Uri.parse('$baseUrl/excel/scratch-sample'), headers: _authHeaders);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null) ? decoded['error'] : 'Failed to load scratch sample (${response.statusCode})';
    throw Exception(errorMsg);
  }

  static List<dynamic>? _cachedChillers;

  static Future<Map<String, dynamic>> confirmUpload({
    required String filename,
    required List<dynamic> rows,
    bool bypassValidation = false,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/excel/confirm'),
      headers: _headers,
      body: jsonEncode({
        'filename': filename,
        'rows': rows,
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

  // ==========================================
  // Chillers & Map Data
  // ==========================================

  static Future<List<dynamic>> fetchChillers({
    String efficiency = 'All',
    String customerType = 'All',
    String search = '',
    dynamic batchId = 'All',
    bool forceApi = false,
  }) async {
    final bool hasBatchFilter = batchId != null && batchId != 'All' && batchId != 'all';
    // If user is Agent, ALWAYS forceApi so the server applies their restricted assigned set!
    final bool shouldForce = forceApi || isAgent;

    if (!shouldForce && !hasBatchFilter && _cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search, batchId);
    }

    final uri = Uri.parse('$baseUrl/chillers').replace(queryParameters: {
      if (efficiency != 'All') 'efficiency': efficiency,
      if (customerType != 'All') 'customerType': customerType,
      if (search.isNotEmpty) 'search': search,
      if (hasBatchFilter) 'batchId': batchId.toString(),
    });

    try {
      final response = await http.get(uri, headers: _authHeaders);
      if (response.statusCode == 200) {
        final data = _safeJsonDecode(response.body);
        if (data is Map && data.containsKey('chillers')) {
          final List<dynamic> fetched = data['chillers'] ?? [];
          if (!hasBatchFilter && !isAgent) {
            _cachedChillers = fetched;
            setLocalStorage('chillers_dataset', jsonEncode(fetched));
          }
          return _filterLocalChillers(fetched, efficiency, customerType, search, batchId);
        }
      }
    } catch (_) {
      // Fallback
    }

    if (!isAgent && _cachedChillers != null && _cachedChillers!.isNotEmpty) {
      return _filterLocalChillers(_cachedChillers!, efficiency, customerType, search, batchId);
    }

    if (!isAgent) {
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

  // ==========================================
  // Batches & Delta
  // ==========================================

  static Future<List<dynamic>> fetchBatches() async {
    final response = await http.get(Uri.parse('$baseUrl/batches'), headers: _authHeaders);
    if (response.statusCode == 200) {
      final data = _safeJsonDecode(response.body);
      if (data is Map && data.containsKey('batches')) {
        return data['batches'] ?? [];
      }
    }
    throw Exception('Failed to fetch upload batches');
  }

  static Future<Map<String, dynamic>> deleteBatch(int batchId) async {
    final response = await http.delete(Uri.parse('$baseUrl/batches/$batchId'), headers: _headers);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      _cachedChillers = null;
      removeLocalStorage('chillers_dataset');
      return decoded;
    }
    final errorMsg = (decoded is Map && decoded['error'] != null)
        ? decoded['error']
        : 'Failed to delete batch #$batchId (${response.statusCode})';
    throw Exception(errorMsg);
  }

  static Future<Map<String, dynamic>> fetchDelta(int startBatchId, int endBatchId) async {
    final uri = Uri.parse('$baseUrl/delta').replace(queryParameters: {
      'startBatchId': startBatchId.toString(),
      'endBatchId': endBatchId.toString(),
    });

    final response = await http.get(uri, headers: _authHeaders);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Failed to compare delta batches');
  }

  static Future<bool> clearChillers() async {
    _cachedChillers = [];
    final response = await http.delete(Uri.parse('$baseUrl/chillers/clear'), headers: _headers);
    return response.statusCode == 200;
  }

  // ==========================================
  // Sales Agents Methods
  // ==========================================

  static Future<List<dynamic>> fetchAgents() async {
    final response = await http.get(Uri.parse('$baseUrl/agents'), headers: _authHeaders);
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
    String password = '',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/agents'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'area': area,
        'phone': phone,
        'email': email,
        if (password.isNotEmpty) 'password': password,
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
      headers: _headers,
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
    final response = await http.delete(Uri.parse('$baseUrl/agents/$id'), headers: _headers);
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

    final response = await http.get(uri, headers: _authHeaders);
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
      headers: _headers,
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
      headers: _headers,
      body: jsonEncode({
        if (customerName != null) 'customer_name': customerName,
        if (chillerCode != null) 'chiller_code': chillerCode,
      }),
    );
    return response.statusCode == 200;
  }

  // ==========================================
  // Dynamic Forms & Audit Visits Methods
  // ==========================================

  static Future<List<Map<String, dynamic>>> fetchForms() async {
    final response = await http.get(Uri.parse('$baseUrl/forms'), headers: _authHeaders);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return List<Map<String, dynamic>>.from(decoded['forms'] ?? []);
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to fetch forms');
  }

  static Future<Map<String, dynamic>> fetchFormById(int formId) async {
    final response = await http.get(Uri.parse('$baseUrl/forms/$formId'), headers: _authHeaders);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['form'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to fetch form');
  }

  static Future<Map<String, dynamic>> createForm({
    required String title,
    String description = '',
    required List<Map<String, dynamic>> fields,
    List<int> assignedAgentIds = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forms'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'fields': fields,
        'assigned_agent_ids': assignedAgentIds,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 201 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['form'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to create form');
  }

  static Future<Map<String, dynamic>> updateForm({
    required int formId,
    required String title,
    String description = '',
    required List<Map<String, dynamic>> fields,
    List<int> assignedAgentIds = const [],
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/forms/$formId'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'description': description,
        'fields': fields,
        'assigned_agent_ids': assignedAgentIds,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['form'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to update form');
  }

  static Future<bool> deleteForm(int formId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/forms/$formId'),
      headers: _headers,
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> assignForm({
    required int formId,
    required List<int> assignedAgentIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forms/$formId/assign'),
      headers: _headers,
      body: jsonEncode({'assigned_agent_ids': assignedAgentIds}),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['form'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to assign form');
  }

  static Future<String> uploadAttachment({
    required String base64Data,
    String filename = 'photo.jpg',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/forms/upload-attachment'),
      headers: _headers,
      body: jsonEncode({
        'base64Data': base64Data,
        'filename': filename,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['url'] != null) {
      return decoded['url'] as String;
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to upload attachment');
  }

  static Future<Map<String, dynamic>> submitFormResponse({
    required int formId,
    required String chillerCode,
    required String customerName,
    required Map<String, dynamic> answers,
    List<String> attachments = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/form-responses'),
      headers: _headers,
      body: jsonEncode({
        'form_id': formId,
        'chiller_code': chillerCode,
        'customer_name': customerName,
        'answers': answers,
        'attachments': attachments,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 201 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['response'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to submit form response');
  }

  static Future<List<Map<String, dynamic>>> fetchFormResponses({
    String status = 'All',
    String search = '',
    String chillerCode = '',
    int? formId,
  }) async {
    final uri = Uri.parse('$baseUrl/form-responses').replace(queryParameters: {
      if (status != 'All') 'status': status,
      if (search.isNotEmpty) 'search': search,
      if (chillerCode.isNotEmpty) 'chiller_code': chillerCode,
      if (formId != null) 'form_id': formId.toString(),
    });
    final response = await http.get(uri, headers: _authHeaders);
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return List<Map<String, dynamic>>.from(decoded['responses'] ?? []);
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to fetch form responses');
  }

  static Future<Map<String, dynamic>> reviewFormResponse({
    required int responseId,
    required String status,
    String adminFeedback = '',
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/form-responses/$responseId/review'),
      headers: _headers,
      body: jsonEncode({
        'status': status,
        'admin_feedback': adminFeedback,
      }),
    );
    final decoded = _safeJsonDecode(response.body);
    if (response.statusCode == 200 && decoded is Map && decoded['success'] == true) {
      return Map<String, dynamic>.from(decoded['response'] ?? {});
    }
    throw Exception(decoded is Map && decoded['error'] != null ? decoded['error'] : 'Failed to review form response');
  }
}
