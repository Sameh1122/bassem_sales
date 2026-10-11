import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class SystemLogsViewScreen extends StatefulWidget {
  const SystemLogsViewScreen({super.key});

  @override
  State<SystemLogsViewScreen> createState() => SystemLogsViewScreenState();
}

class SystemLogsViewScreenState extends State<SystemLogsViewScreen> {
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isClearing = false;
  bool _autoRefresh = true;
  bool _isLoggingActive = true;
  bool _isTogglingLogging = false;
  Timer? _autoRefreshTimer;

  String _selectedLevel = 'all';
  String _selectedCategory = 'all';
  int? _selectedStatusCode;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalLogs = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_autoRefresh) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted && !_isLoading) {
          _loadLogs(isSilent: true);
        }
      });
    }
  }

  void _toggleAutoRefresh(bool value) {
    setState(() {
      _autoRefresh = value;
    });
    if (_autoRefresh) {
      _startAutoRefresh();
    } else {
      _autoRefreshTimer?.cancel();
    }
  }

  Future<void> reload() async {
    await _loadLogs();
  }

  Future<void> _loadLogs({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }
    try {
      final res = await ApiService.fetchSystemLogs(
        level: _selectedLevel,
        category: _selectedCategory,
        search: _searchQuery,
        statusCode: _selectedStatusCode,
        page: _currentPage,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(res['logs'] ?? []);
          _stats = Map<String, dynamic>.from(res['stats'] ?? {});
          _totalPages = res['totalPages'] ?? 1;
          _totalLogs = res['total'] ?? 0;
          if (res.containsKey('loggingEnabled')) {
            _isLoggingActive = res['loggingEnabled'] == true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (!isSilent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading logs: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleLoggingState(bool newEnabled) async {
    setState(() => _isTogglingLogging = true);
    try {
      final updated = await ApiService.toggleLogging(newEnabled);
      if (mounted) {
        setState(() {
          _isLoggingActive = updated;
          _isTogglingLogging = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  updated ? Icons.play_circle_fill : Icons.pause_circle_filled,
                  color: updated ? const Color(0xFF10B981) : Colors.orangeAccent,
                ),
                const SizedBox(width: 8),
                Text(
                  updated
                      ? 'System Action Logging is now ACTIVE and recording all events.'
                      : 'System Action Logging has been PAUSED. No new events will be logged.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B),
            duration: const Duration(seconds: 4),
          ),
        );
        _loadLogs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingLogging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update logging state: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Clear All System Logs', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently clear the audit log history? This action will be recorded in the audit trail.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);
    try {
      await ApiService.clearSystemLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All system audit logs cleared successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        await _loadLogs();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear logs: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _exportLogs(String format) async {
    try {
      final content = await ApiService.exportSystemLogs(format: format);
      if (mounted) {
        await Clipboard.setData(ClipboardData(text: content));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${format.toUpperCase()} export copied to clipboard (${content.length} characters)'),
            backgroundColor: const Color(0xFF06B6D4),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showLogInspector(Map<String, dynamic> log) {
    final actor = log['actor'] is Map ? log['actor'] as Map<String, dynamic> : <String, dynamic>{};
    final metadata = log['metadata'] is Map ? log['metadata'] as Map<String, dynamic> : <String, dynamic>{};
    final prettyMetadata = const JsonEncoder.withIndent('  ').convert(metadata);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildLevelPill(log['level'] ?? 'INFO'),
                      const SizedBox(width: 8),
                      Text(
                        log['action'] ?? 'SYSTEM EVENT',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInspectorRow('Event ID', log['id'] ?? 'N/A'),
                      _buildInspectorRow('Timestamp', '${log['timestamp']}'),
                      _buildInspectorRow('Category', log['category'] ?? 'N/A'),
                      _buildInspectorRow('Endpoint', '${log['method']} ${log['endpoint']}'),
                      _buildInspectorRow('HTTP Status', '${log['statusCode']}'),
                      _buildInspectorRow('Duration', '${log['durationMs']} ms'),
                      const SizedBox(height: 12),
                      const Text('Actor Information', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${actor['email'] ?? 'anonymous'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('Role: ${actor['role'] ?? 'guest'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            Text('IP Address: ${actor['ip'] ?? 'unknown'}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Details & Message', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          log['details'] ?? 'No message provided',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      if (metadata.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text('Payload & Context Metadata', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: SelectableText(
                            prettyMetadata,
                            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(log)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Log entry copied to clipboard'), backgroundColor: Color(0xFF06B6D4)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy JSON'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInspectorRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERROR':
        return Colors.redAccent;
      case 'WARN':
        return Colors.orangeAccent;
      default:
        return const Color(0xFF10B981);
    }
  }

  Widget _buildLevelPill(String level) {
    final color = _getLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildKpiCard(String label, dynamic count, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${count ?? 0}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: Color(0xFF8B5CF6), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'System Action Logs & Audit Monitor',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Real-time audit trail of all system actions, data mutations, logins, and error occurrences',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Owner Logging Start/Stop Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isLoggingActive
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : Colors.orangeAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isLoggingActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.orangeAccent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLoggingActive ? Icons.radio_button_checked : Icons.pause_circle_outline,
                            color: _isLoggingActive ? const Color(0xFF10B981) : Colors.orangeAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isLoggingActive ? 'Logging Active' : 'Logging Paused',
                            style: TextStyle(
                              color: _isLoggingActive ? const Color(0xFF10B981) : Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: _isLoggingActive,
                              activeThumbColor: const Color(0xFF10B981),
                              activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                              inactiveThumbColor: Colors.orangeAccent,
                              inactiveTrackColor: Colors.orangeAccent.withValues(alpha: 0.2),
                              onChanged: _isTogglingLogging ? null : _toggleLoggingState,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Auto-refresh switch
                    FilterChip(
                      selected: _autoRefresh,
                      onSelected: _toggleAutoRefresh,
                      backgroundColor: const Color(0xFF1E293B),
                      selectedColor: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            color: _autoRefresh ? const Color(0xFF06B6D4) : Colors.white30,
                            size: 10,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _autoRefresh ? 'Live Stream' : 'Live Paused',
                            style: TextStyle(
                              color: _autoRefresh ? const Color(0xFF06B6D4) : Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Manual reload
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFF06B6D4)),
                      tooltip: 'Reload Logs',
                      onPressed: _isLoading ? null : () => _loadLogs(),
                    ),
                    // Export popup
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.download, color: Colors.cyan),
                      tooltip: 'Export Logs',
                      color: const Color(0xFF1E293B),
                      onSelected: _exportLogs,
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'json',
                          child: Row(
                            children: [
                              Icon(Icons.code, color: Colors.cyan, size: 18),
                              SizedBox(width: 8),
                              Text('Copy as JSON', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.table_view, color: Colors.greenAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Copy as CSV', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Clear logs button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 0.8),
                      ),
                      onPressed: _isClearing ? null : _clearLogs,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear Logs'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // KPI Stat Cards
            if (!isMobile) ...[
              Row(
                children: [
                  _buildKpiCard('Total System Events', _stats['totalEvents'], Icons.bar_chart, const Color(0xFF06B6D4)),
                  const SizedBox(width: 14),
                  _buildKpiCard('Success Actions (2xx)', _stats['successCount'], Icons.check_circle_outline, const Color(0xFF10B981)),
                  const SizedBox(width: 14),
                  _buildKpiCard('Warnings & Auth Alerts', _stats['warnCount'], Icons.warning_amber_rounded, Colors.orangeAccent),
                  const SizedBox(width: 14),
                  _buildKpiCard('Server Errors (5xx)', _stats['errorCount'], Icons.error_outline, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // Filters & Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search input
                  SizedBox(
                    width: 280,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by actor, action, IP...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.cyan, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.white38),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadLogs();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _currentPage = 1;
                        });
                        _loadLogs();
                      },
                    ),
                  ),

                  // Severity Filter
                  DropdownButton<String>(
                    value: _selectedLevel,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Severity: All')),
                      DropdownMenuItem(value: 'INFO', child: Text('🟢 INFO only')),
                      DropdownMenuItem(value: 'WARN', child: Text('🟡 WARN only')),
                      DropdownMenuItem(value: 'ERROR', child: Text('🔴 ERROR only')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedLevel = val;
                          _currentPage = 1;
                        });
                        _loadLogs();
                      }
                    },
                  ),

                  // Category Filter
                  DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Category: All')),
                      DropdownMenuItem(value: 'auth', child: Text('🔐 Authentication')),
                      DropdownMenuItem(value: 'upload', child: Text('📊 Excel & Batches')),
                      DropdownMenuItem(value: 'assignment', child: Text('📍 Assignments')),
                      DropdownMenuItem(value: 'agents', child: Text('👥 Sales Agents')),
                      DropdownMenuItem(value: 'forms', child: Text('📝 Forms & Visits')),
                      DropdownMenuItem(value: 'system', child: Text('⚙️ System Core')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCategory = val;
                          _currentPage = 1;
                        });
                        _loadLogs();
                      }
                    },
                  ),

                  // Status Code Filter
                  DropdownButton<int?>(
                    value: _selectedStatusCode,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Status: All')),
                      DropdownMenuItem(value: 2, child: Text('2xx Success')),
                      DropdownMenuItem(value: 4, child: Text('4xx Client Error')),
                      DropdownMenuItem(value: 5, child: Text('5xx Server Error')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedStatusCode = val;
                        _currentPage = 1;
                      });
                      _loadLogs();
                    },
                  ),

                  Text(
                    'Showing ${_logs.length} of $_totalLogs logs',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Logs Stream List
            Expanded(
              child: _isLoading && _logs.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
                  : _logs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_outlined, size: 54, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text('No audit logs found', style: TextStyle(color: Colors.white70, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery.isNotEmpty || _selectedLevel != 'all'
                                    ? 'Try resetting the filters or search query.'
                                    : 'Logs will appear automatically as actions are performed.',
                                style: const TextStyle(color: Colors.white38, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final log = _logs[idx];
                            final actor = log['actor'] is Map ? log['actor'] as Map<String, dynamic> : <String, dynamic>{};
                            final level = (log['level'] ?? 'INFO').toString();
                            final statusCode = log['statusCode'] ?? 200;
                            final time = log['timestamp']?.toString().split('T').last.split('.').first ?? '';

                            return InkWell(
                              onTap: () => _showLogInspector(log),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: level == 'ERROR'
                                        ? Colors.redAccent.withValues(alpha: 0.2)
                                        : level == 'WARN'
                                            ? Colors.orangeAccent.withValues(alpha: 0.2)
                                            : Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildLevelPill(level),
                                    const SizedBox(width: 10),
                                    // Method & endpoint chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${log['method']} ${log['endpoint']}',
                                        style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status code chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusCode >= 500
                                            ? Colors.redAccent.withValues(alpha: 0.2)
                                            : statusCode >= 400
                                                ? Colors.orangeAccent.withValues(alpha: 0.2)
                                                : Colors.greenAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$statusCode',
                                        style: TextStyle(
                                          color: statusCode >= 500
                                              ? Colors.redAccent
                                              : statusCode >= 400
                                                  ? Colors.orangeAccent
                                                  : Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Details message
                                    Expanded(
                                      child: Text(
                                        log['details'] ?? 'No message',
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Actor badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (actor['role'] == 'owner')
                                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                                            : (actor['role'] == 'admin')
                                                ? const Color(0xFF06B6D4).withValues(alpha: 0.2)
                                                : (actor['role'] == 'agent')
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                                    : Colors.white10,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${actor['email'] ?? 'anonymous'}',
                                        style: TextStyle(
                                          color: (actor['role'] == 'owner')
                                              ? const Color(0xFFA78BFA)
                                              : (actor['role'] == 'admin')
                                                  ? const Color(0xFF22D3EE)
                                                  : (actor['role'] == 'agent')
                                                      ? const Color(0xFF34D399)
                                                      : Colors.white60,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Time
                                    Text(
                                      time,
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Pagination Bar
            if (_totalPages > 1) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.white60),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _loadLogs();
                          }
                        : null,
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white60),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _loadLogs();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
