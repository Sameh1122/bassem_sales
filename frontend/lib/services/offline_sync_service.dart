import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage.dart';

enum OutboxItemStatus {
  queued,
  syncing,
  retryNeeded,
  conflict;

  static OutboxItemStatus fromString(String? raw) {
    switch (raw) {
      case 'syncing':
        return OutboxItemStatus.syncing;
      case 'retryNeeded':
        return OutboxItemStatus.retryNeeded;
      case 'conflict':
        return OutboxItemStatus.conflict;
      case 'queued':
      default:
        return OutboxItemStatus.queued;
    }
  }
}

class OutboxItem {
  final String id;
  final String type; // 'form_response' | 'condition'
  final String customerName;
  final String chillerCode;
  final String clientTimestamp;
  final int attachmentCount;
  final int? checkInDistanceM;
  final bool? geofenceVerified;
  final Map<String, dynamic> payload;
  OutboxItemStatus status;
  String? errorMessage;

  OutboxItem({
    required this.id,
    required this.type,
    required this.customerName,
    required this.chillerCode,
    required this.clientTimestamp,
    this.attachmentCount = 0,
    this.checkInDistanceM,
    this.geofenceVerified,
    required this.payload,
    this.status = OutboxItemStatus.queued,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'customerName': customerName,
        'chillerCode': chillerCode,
        'clientTimestamp': clientTimestamp,
        'attachmentCount': attachmentCount,
        'checkInDistanceM': checkInDistanceM,
        'geofenceVerified': geofenceVerified,
        'payload': payload,
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> json) {
    return OutboxItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'form_response').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      chillerCode: (json['chillerCode'] ?? '').toString(),
      clientTimestamp: (json['clientTimestamp'] ?? DateTime.now().toIso8601String()).toString(),
      attachmentCount: (json['attachmentCount'] is num) ? (json['attachmentCount'] as num).toInt() : 0,
      checkInDistanceM: (json['checkInDistanceM'] is num) ? (json['checkInDistanceM'] as num).toInt() : null,
      geofenceVerified: json['geofenceVerified'] is bool ? json['geofenceVerified'] as bool : null,
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : <String, dynamic>{},
      status: OutboxItemStatus.fromString(json['status']?.toString()),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

class OfflineSyncService extends ChangeNotifier {
  OfflineSyncService._();
  static final OfflineSyncService instance = OfflineSyncService._();

  static const String _outboxStorageKey = 'p6_offline_outbox_v1';
  static const String _cursorStorageKey = 'p6_sync_cursor_v1';
  static const String _deltaCacheStorageKey = 'p6_sync_cache_v1';

  final List<OutboxItem> _queue = [];
  bool _initialized = false;
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _justSyncedSuccess = false;
  int _syncProgressCurrent = 0;
  int _syncProgressTotal = 0;
  String? _lastServerTime;
  Timer? _successTimer;

  List<OutboxItem> get queue => List.unmodifiable(_queue);
  int get queuedCount => _queue.length;
  int get failedCount => _queue
      .where((e) => e.status == OutboxItemStatus.retryNeeded || e.status == OutboxItemStatus.conflict)
      .length;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get justSyncedSuccess => _justSyncedSuccess;
  int get syncProgressCurrent => _syncProgressCurrent;
  int get syncProgressTotal => _syncProgressTotal;
  String? get lastServerTime => _lastServerTime;

  String _generateIdempotencyKey(String prefix) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(999999).toString().padLeft(6, '0');
    return '${prefix}_${ts}_$rand';
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = getLocalStorage(_outboxStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _queue.clear();
          for (final item in decoded) {
            if (item is Map) {
              final parsed = OutboxItem.fromJson(Map<String, dynamic>.from(item));
              if (parsed.status == OutboxItemStatus.syncing) {
                parsed.status = OutboxItemStatus.queued;
              }
              _queue.add(parsed);
            }
          }
        }
      }
      _lastServerTime = getLocalStorage(_cursorStorageKey);
    } catch (_) {}
    notifyListeners();
  }

  void _persistQueue() {
    try {
      setLocalStorage(
        _outboxStorageKey,
        jsonEncode(_queue.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
    }
  }

  Future<OutboxItem> enqueueFormResponse({
    required int formId,
    required String chillerCode,
    required String customerName,
    required Map<String, dynamic> answers,
    List<dynamic> attachments = const [],
    double? checkInLat,
    double? checkInLng,
    int? checkInDistanceM,
    bool? geofenceVerified,
  }) async {
    await init();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'form_id': formId,
      'chiller_code': chillerCode,
      'customer_name': customerName,
      'answers': answers,
      'attachments': attachments,
      if (checkInLat != null && checkInLng != null) 'checkInLat': checkInLat,
      if (checkInLat != null && checkInLng != null) 'checkInLng': checkInLng,
    };

    final item = OutboxItem(
      id: _generateIdempotencyKey('form'),
      type: 'form_response',
      customerName: customerName,
      chillerCode: chillerCode,
      clientTimestamp: nowIso,
      attachmentCount: attachments.length,
      checkInDistanceM: checkInDistanceM,
      geofenceVerified: geofenceVerified,
      payload: payload,
      status: OutboxItemStatus.queued,
    );

    _queue.add(item);
    _justSyncedSuccess = false;
    _persistQueue();
    notifyListeners();
    return item;
  }

  Future<OutboxItem> enqueueConditionUpdate({
    required String chillerId,
    required String chillerCode,
    required String customerName,
    required String condition,
    String? notes,
  }) async {
    await init();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'chillerId': chillerId,
      'condition': condition,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    final item = OutboxItem(
      id: _generateIdempotencyKey('cond'),
      type: 'condition',
      customerName: customerName,
      chillerCode: chillerCode,
      clientTimestamp: nowIso,
      payload: payload,
      status: OutboxItemStatus.queued,
    );

    _queue.add(item);
    _justSyncedSuccess = false;
    _persistQueue();
    notifyListeners();
    return item;
  }

  Future<Map<String, dynamic>> syncNow() async {
    await init();
    if (_isSyncing || _queue.isEmpty) {
      return {'success': true, 'processedCount': 0, 'succeededCount': 0, 'failedCount': 0};
    }

    _isSyncing = true;
    _justSyncedSuccess = false;
    _syncProgressCurrent = 0;
    _syncProgressTotal = _queue.length;
    for (final item in _queue) {
      item.status = OutboxItemStatus.syncing;
      item.errorMessage = null;
    }
    notifyListeners();

    int totalSucceeded = 0;
    int totalFailed = 0;

    try {
      final pendingSnapshot = List<OutboxItem>.from(_queue);
      for (int offset = 0; offset < pendingSnapshot.length; offset += 50) {
        final chunk = pendingSnapshot.sublist(offset, min(offset + 50, pendingSnapshot.length));
        final ops = chunk
            .map((item) => {
                  'type': item.type,
                  'idempotencyKey': item.id,
                  'clientTimestamp': item.clientTimestamp,
                  'payload': item.payload,
                })
            .toList();

        final resp = await ApiService.pushSyncBatch(
          ops,
          idempotencyKey: _generateIdempotencyKey('batch'),
        );

        _isOnline = true;
        final results = resp['results'] is List ? List<dynamic>.from(resp['results'] as List) : <dynamic>[];
        final completedIds = <String>{};

        for (final r in results) {
          if (r is! Map) continue;
          final key = r['idempotencyKey']?.toString();
          final status = r['status']?.toString();
          final statusCode = r['statusCode'] is num ? (r['statusCode'] as num).toInt() : 0;
          if (key == null) continue;

          if (status == 'created' || status == 'updated' || status == 'duplicate') {
            completedIds.add(key);
            totalSucceeded++;
          } else {
            totalFailed++;
            final idx = _queue.indexWhere((q) => q.id == key);
            if (idx != -1) {
              _queue[idx].status = statusCode == 409 ? OutboxItemStatus.conflict : OutboxItemStatus.retryNeeded;
              _queue[idx].errorMessage = r['error']?.toString() ?? 'Sync failed ($statusCode)';
            }
          }
          _syncProgressCurrent++;
        }

        _queue.removeWhere((q) => completedIds.contains(q.id));
        notifyListeners();
      }

      if (_queue.isEmpty && totalSucceeded > 0) {
        _justSyncedSuccess = true;
        _successTimer?.cancel();
        _successTimer = Timer(const Duration(seconds: 3), () {
          _justSyncedSuccess = false;
          notifyListeners();
        });
      }
    } catch (e) {
      _isOnline = false;
      for (final item in _queue) {
        if (item.status == OutboxItemStatus.syncing) {
          item.status = OutboxItemStatus.retryNeeded;
          item.errorMessage = 'Connection unavailable — tap Retry when online';
        }
      }
      totalFailed = _queue.length;
    } finally {
      _isSyncing = false;
      _persistQueue();
      notifyListeners();
    }

    return {
      'success': totalFailed == 0,
      'succeededCount': totalSucceeded,
      'failedCount': totalFailed,
    };
  }

  Future<void> retryItem(String id) async {
    final idx = _queue.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _queue[idx].status = OutboxItemStatus.queued;
      _queue[idx].errorMessage = null;
      _persistQueue();
      notifyListeners();
    }
    await syncNow();
  }

  Future<void> discardItem(String id) async {
    _queue.removeWhere((e) => e.id == id);
    _persistQueue();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> pullDelta({bool forceFull = false}) async {
    try {
      final data = await ApiService.pullSync(since: forceFull ? null : _lastServerTime);
      _isOnline = true;
      final serverTime = data['serverTime']?.toString();
      if (serverTime != null && serverTime.isNotEmpty) {
        _lastServerTime = serverTime;
        setLocalStorage(_cursorStorageKey, serverTime);
      }
      setLocalStorage(_deltaCacheStorageKey, jsonEncode(data));
      notifyListeners();
      return data;
    } catch (_) {
      return null;
    }
  }
}
