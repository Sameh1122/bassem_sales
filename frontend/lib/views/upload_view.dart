import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class UploadViewScreen extends StatefulWidget {
  final VoidCallback onUploadSuccess;
  const UploadViewScreen({super.key, required this.onUploadSuccess});

  @override
  State<UploadViewScreen> createState() => _UploadViewScreenState();
}

class _UploadViewScreenState extends State<UploadViewScreen> {
  bool _isLoading = false;
  String? _filename;
  int _totalRows = 0;
  int _validCount = 0;
  int _invalidCount = 0;
  List<dynamic> _previewRows = [];

  Future<void> _loadScratchSample() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService.loadScratchSample();
      final rows = res['rows'] ?? [];
      setState(() {
        _filename = res['filename'] ?? 'Chillers Database_V1.xlsx';
        _totalRows = res['totalRows'] ?? 0;
        _validCount = res['validCount'] ?? 0;
        _invalidCount = res['invalidCount'] ?? 0;
        _previewRows = rows;
      });

      if (rows.isNotEmpty) {
        await _confirmSave(bypassValidation: true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sample: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _pickAndUploadCustomFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await ApiService.uploadExcelFile(file.bytes!, file.name);
      final rows = res['rows'] ?? [];
      setState(() {
        _filename = res['filename'] ?? file.name;
        _totalRows = res['totalRows'] ?? 0;
        _validCount = res['validCount'] ?? 0;
        _invalidCount = res['invalidCount'] ?? 0;
        _previewRows = rows;
      });

      if (rows.isNotEmpty) {
        await _confirmSave(bypassValidation: true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _confirmSave({required bool bypassValidation}) async {
    if (_previewRows.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.confirmUpload(
        filename: _filename ?? 'Excel_Import.xlsx',
        rows: _previewRows,
        bypassValidation: bypassValidation,
      );

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Successfully saved and reflected on Map!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
        widget.onUploadSuccess();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            const Text(
              '📥 Excel Upload & Data Validation Studio',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload spreadsheet datasets, inspect cell data validation report, and choose strict or bypassed import.',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Dropzone & Action Bar
            Row(
              children: [
                // Quick Load Sample Button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _loadScratchSample,
                  icon: const Icon(Icons.bolt, color: Colors.black, size: 20),
                  label: const Text(
                    'Quick Load Sample Excel (Bassem Folder)',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 16),

                // Custom File Picker Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickAndUploadCustomFile,
                  icon: const Icon(Icons.upload_file, color: Colors.cyan),
                  label: const Text('Browse & Upload Custom Excel (.xlsx)', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyan),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.cyan),
                ),
              )
            else if (_previewRows.isNotEmpty) ...[
              // KPI Cards Summary
              Row(
                children: [
                  _buildSummaryKpi('Uploaded File', _filename ?? '-', Colors.cyan, Icons.file_present),
                  const SizedBox(width: 16),
                  _buildSummaryKpi('Total Rows', '$_totalRows', Colors.purpleAccent, Icons.table_rows),
                  const SizedBox(width: 16),
                  _buildSummaryKpi('Valid Rows', '$_validCount', const Color(0xFF10B981), Icons.check_circle),
                  const SizedBox(width: 16),
                  _buildSummaryKpi('Incomplete / Missing', '$_invalidCount', const Color(0xFFEF4444), Icons.warning),
                ],
              ),
              const SizedBox(height: 24),

              // Save Action Buttons Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Review missing cells below. You can enforce strict validation or bypass cell validation to save 100% of data into SQLite.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Strict Upload Button
                    ElevatedButton.icon(
                      onPressed: () => _confirmSave(bypassValidation: false),
                      icon: const Icon(Icons.verified, color: Colors.white, size: 18),
                      label: Text('Confirm Upload (${_validCount} Clean Rows)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Bypass Validation Button
                    ElevatedButton.icon(
                      onPressed: () => _confirmSave(bypassValidation: true),
                      icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                      label: Text('Bypass Validation & Save All (${_totalRows} Rows)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preview Data Grid Table
              const Text('Data Preview & Validation Report', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Row #', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Status', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Chiller Code', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Branch', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Customer Type', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Efficiency', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Latitude', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Longitude', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Missing Fields / Warnings', style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold))),
                    ],
                    rows: _previewRows.take(100).map((r) {
                      final bool isValid = r['isValid'] == true;
                      final List<dynamic> missing = r['missingFields'] ?? [];

                      return DataRow(
                        cells: [
                          DataCell(Text('${r['rowIndex']}', style: const TextStyle(color: Colors.white70))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isValid ? Colors.green : Colors.red).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isValid ? 'Valid' : 'Incomplete',
                                style: TextStyle(color: isValid ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          DataCell(Text(r['chillerCode'] ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                          DataCell(Text(r['branch'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r['customerType'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r['efficiency'] ?? '-', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r['latitude']?.toString() ?? 'MISSING', style: TextStyle(color: r['latitude'] != null ? Colors.white70 : Colors.redAccent))),
                          DataCell(Text(r['longitude']?.toString() ?? 'MISSING', style: TextStyle(color: r['longitude'] != null ? Colors.white70 : Colors.redAccent))),
                          DataCell(
                            missing.isNotEmpty
                                ? Wrap(
                                    spacing: 4,
                                    children: missing.take(3).map((m) {
                                      return Chip(
                                        label: Text(m.toString(), style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                                        backgroundColor: Colors.red.withOpacity(0.15),
                                        padding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                                  )
                                : const Text('None', style: TextStyle(color: Colors.white38)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_previewRows.length > 100)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Showing first 100 preview rows out of $_totalRows total rows.', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryKpi(String label, String value, Color color, IconData icon) {
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
                  Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
