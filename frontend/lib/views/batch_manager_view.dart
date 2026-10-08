import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BatchManagerViewScreen extends StatefulWidget {
  final Function(dynamic batchId)? onOpenBatch;

  const BatchManagerViewScreen({super.key, this.onOpenBatch});

  @override
  State<BatchManagerViewScreen> createState() => BatchManagerViewScreenState();
}

class BatchManagerViewScreenState extends State<BatchManagerViewScreen> {
  List<dynamic> _batches = [];
  bool _isLoading = true;
  String _searchFilter = '';
  DateTime? _selectedDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  void reload() {
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _isLoading = true);
    try {
      final batches = await ApiService.fetchBatches();
      if (mounted) {
        setState(() {
          _batches = batches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load batches: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF06B6D4),
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F172A),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  Future<void> _confirmDeleteBatch(dynamic batch) async {
    final int batchId = batch['id'] ?? 0;
    final String filename = batch['filename'] ?? 'Upload #$batchId';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 10),
            Text('Delete Batch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete Batch #$batchId ("$filename")?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: const Text(
                'This will remove all associated chiller records and upload history for this batch.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete Permanently'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiService.deleteBatch(batchId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Batch #$batchId deleted successfully'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          _loadBatches();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete batch: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _openBatchInMap(dynamic batch) {
    final dynamic batchId = batch['id'];
    if (widget.onOpenBatch != null) {
      widget.onOpenBatch!(batchId);
    }
  }

  List<dynamic> get _filteredBatches {
    return _batches.where((b) {
      final String filename = (b['filename'] ?? '').toString().toLowerCase();
      final String idStr = (b['id'] ?? '').toString();
      final String uploadedAt = (b['uploaded_at'] ?? '').toString();

      // Text search filter
      if (_searchFilter.isNotEmpty) {
        final query = _searchFilter.toLowerCase();
        final matchesText = filename.contains(query) || idStr.contains(query) || uploadedAt.toLowerCase().contains(query);
        if (!matchesText) return false;
      }

      // Date picker filter
      if (_selectedDate != null && uploadedAt.isNotEmpty) {
        try {
          final dt = DateTime.parse(uploadedAt);
          final sameDay = dt.year == _selectedDate!.year &&
              dt.month == _selectedDate!.month &&
              dt.day == _selectedDate!.day;
          if (!sameDay) return false;
        } catch (_) {}
      }

      return true;
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(raw);
      final twoDigitMonth = dt.month.toString().padLeft(2, '0');
      final twoDigitDay = dt.day.toString().padLeft(2, '0');
      final twoDigitHour = dt.hour.toString().padLeft(2, '0');
      final twoDigitMinute = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
    } catch (_) {
      return raw;
    }
  }
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBatches;

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder_copy, color: Color(0xFF06B6D4), size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Upload Batch Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Filter uploaded batches by date, open their snapshot in the Map, or delete unwanted batches.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadBatches,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Text Search Input
                SizedBox(
                  width: 280,
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchFilter = val),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search filename or ID...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                      suffixIcon: _searchFilter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchFilter = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                      ),
                    ),
                  ),
                ),

                // Date Picker Filter
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16, color: Color(0xFF06B6D4)),
                  label: Text(
                    _selectedDate == null
                        ? 'Filter by Date'
                        : 'Date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: _selectedDate == null ? Colors.white70 : const Color(0xFF06B6D4),
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    side: BorderSide(
                      color: _selectedDate != null ? const Color(0xFF06B6D4) : Colors.white12,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                if (_selectedDate != null)
                  TextButton.icon(
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.close, size: 16, color: Colors.white60),
                    label: const Text('Clear Date', style: TextStyle(color: Colors.white60, fontSize: 13)),
                  ),

                // Batch Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${filtered.length} of ${_batches.length} batches',
                    style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Batches List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF06B6D4)))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 54, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 12),
                            Text(
                              _batches.isEmpty ? 'No upload batches found' : 'No batches match your filters',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                            if (_selectedDate != null || _searchFilter.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchFilter = '';
                                      _selectedDate = null;
                                    });
                                  },
                                  child: const Text('Reset Filters', style: TextStyle(color: Color(0xFF06B6D4))),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final batch = filtered[index];
                          final int batchId = batch['id'] ?? 0;
                          final String filename = batch['filename'] ?? 'Unknown File';
                          final int totalRows = batch['total_rows'] ?? 0;
                          final int validRows = batch['valid_rows'] ?? 0;
                          final int invalidRows = batch['invalid_rows'] ?? 0;
                          final bool bypassed = batch['bypassed_validation'] == 1 || batch['bypassed_validation'] == true;
                          final String uploadedAtStr = _formatDate(batch['uploaded_at']);

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                // Batch Number Avatar
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#$batchId',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // File Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              filename,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (bypassed)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Bypassed',
                                                style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 4,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.access_time, size: 14, color: Colors.white54),
                                              const SizedBox(width: 4),
                                              Text(uploadedAtStr, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.list_alt, size: 14, color: Colors.cyan),
                                              const SizedBox(width: 4),
                                              Text('$totalRows records', style: const TextStyle(color: Colors.cyan, fontSize: 12)),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text('$validRows valid', style: const TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                                            ],
                                          ),
                                          if (invalidRows > 0)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
                                                const SizedBox(width: 4),
                                                Text('$invalidRows invalid', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _openBatchInMap(batch),
                                      icon: const Icon(Icons.map_outlined, size: 16),
                                      label: const Text('Open Batch'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF06B6D4),
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: 'Delete this batch',
                                      onPressed: () => _confirmDeleteBatch(batch),
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
