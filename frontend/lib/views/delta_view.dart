import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeltaViewScreen extends StatefulWidget {
  const DeltaViewScreen({super.key});

  @override
  State<DeltaViewScreen> createState() => DeltaViewScreenState();
}

class DeltaViewScreenState extends State<DeltaViewScreen> {
  List<dynamic> _batches = [];
  int? _startBatchId;
  int? _endBatchId;
  bool _isLoading = false;
  Map<String, dynamic>? _deltaResult;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  void reload() {
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await ApiService.fetchBatches();
      setState(() {
        _batches = batches;
        if (batches.length >= 2) {
          _startBatchId = batches[1]['id']; // Older batch
          _endBatchId = batches[0]['id'];   // Newer batch
        } else if (batches.isNotEmpty) {
          _startBatchId = batches[0]['id'];
          _endBatchId = batches[0]['id'];
        }
      });

      if (_startBatchId != null && _endBatchId != null) {
        _compareDelta();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading upload history: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _compareDelta() async {
    if (_startBatchId == null || _endBatchId == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.fetchDelta(_startBatchId!, _endBatchId!);
      setState(() {
        _deltaResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delta comparison error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _deltaResult?['summary'] ?? {};
    final List<dynamic> added = _deltaResult?['added'] ?? [];
    final List<dynamic> removed = _deltaResult?['removed'] ?? [];
    final List<dynamic> modified = _deltaResult?['modified'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              '📊 Delta & Historical Changes View',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compare uploaded snapshot batches over time to analyze added chillers, removed items, and efficiency transitions.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Batch Picker Toolbar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  // Start Batch Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Snapshot Batch (Baseline):', style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _startBatchId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _batches.map<DropdownMenuItem<int>>((b) {
                                return DropdownMenuItem<int>(
                                  value: b['id'],
                                  child: Text('Batch #${b['id']} - ${b['filename']} (${b['uploaded_at']})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _startBatchId = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // End Batch Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Snapshot Batch (Comparison):', style: TextStyle(color: Colors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _endBatchId,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: _batches.map<DropdownMenuItem<int>>((b) {
                                return DropdownMenuItem<int>(
                                  value: b['id'],
                                  child: Text('Batch #${b['id']} - ${b['filename']} (${b['uploaded_at']})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _endBatchId = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Run Compare Button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _compareDelta,
                    icon: const Icon(Icons.compare_arrows, color: Colors.black),
                    label: const Text('Compare Delta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.cyan)))
            else if (_deltaResult != null) ...[
              // KPI Stat Cards
              Row(
                children: [
                  _buildDeltaStatCard('+ Added', '${summary['addedCount'] ?? 0}', const Color(0xFF10B981), Icons.add_circle_outline),
                  const SizedBox(width: 16),
                  _buildDeltaStatCard('- Removed', '${summary['removedCount'] ?? 0}', const Color(0xFFEF4444), Icons.remove_circle_outline),
                  const SizedBox(width: 16),
                  _buildDeltaStatCard('Δ Modified', '${summary['modifiedCount'] ?? 0}', const Color(0xFFF59E0B), Icons.published_with_changes),
                  const SizedBox(width: 16),
                  _buildDeltaStatCard('= Unchanged', '${summary['unchangedCount'] ?? 0}', Colors.blueAccent, Icons.drag_handle),
                ],
              ),
              const SizedBox(height: 32),

              // Modified Records Diff Table
              const Text('Modified Records Diff', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              if (modified.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No status or efficiency modifications detected between these two batches.', style: TextStyle(color: Colors.white60))),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modified.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, idx) {
                      final item = modified[idx];
                      final List<dynamic> changes = item['changes'] ?? [];

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                  child: Text(item['chillerCode'] ?? '-', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Text('Customer: ${item['customerName'] ?? '-'}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...changes.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_right, color: Colors.cyan, size: 18),
                                    Text('${c['field']}: ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: Text(c['oldValue']?.toString() ?? 'N/A', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.trending_flat, color: Colors.white38, size: 16),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                      child: Text(c['newValue']?.toString() ?? 'N/A', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
