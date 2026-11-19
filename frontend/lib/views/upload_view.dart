import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/drop_zone_helper.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';

enum _DropZoneVisualState { idle, dragOver, validDrop, invalidDrop }

class UploadViewScreen extends StatefulWidget {
  final VoidCallback onUploadSuccess;
  const UploadViewScreen({super.key, required this.onUploadSuccess});

  @override
  State<UploadViewScreen> createState() => _UploadViewScreenState();
}

class _UploadViewScreenState extends State<UploadViewScreen> {
  static const int _maxFileSizeBytes = 25 * 1024 * 1024; // 25 MB

  bool _isLoading = false;
  final bool _onlyThisBatch = false;
  String? _filename;
  int? _fileSizeBytes;
  int _uploadStage = 0; // 0=idle, 1=Uploading, 2=Validating Columns, 3=Ready for UPSERT
  _DropZoneVisualState _dropState = _DropZoneVisualState.idle;
  String? _dropError;
  bool _showErrorsOnly = false;

  int _totalRows = 0;
  int _validCount = 0;
  int _invalidCount = 0;
  List<dynamic> _previewRows = [];

  DropZoneSubscription? _dropSub;

  @override
  void initState() {
    super.initState();
    _dropSub = registerWebDropZone(
      onDragState: (isOver) {
        if (!mounted) return;
        setState(() {
          _dropState = isOver ? _DropZoneVisualState.dragOver : _DropZoneVisualState.idle;
        });
      },
      onFileDrop: (bytes, name, size) {
        if (!mounted) return;
        _processSelectedFile(bytes, name, size);
      },
      onInvalidFile: (name) {
        if (!mounted) return;
        setState(() {
          _dropState = _DropZoneVisualState.invalidDrop;
          _dropError = 'Unsupported file "$name". Please drop a .xlsx, .xls, or .csv file.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unsupported file "$name". Only .xlsx, .xls, and .csv are accepted.'),
            backgroundColor: AppTokens.of(context).danger,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _dropSub?.dispose();
    super.dispose();
  }

  Future<void> _loadScratchSample() async {
    setState(() {
      _isLoading = true;
      _uploadStage = 1;
      _dropState = _DropZoneVisualState.idle;
      _dropError = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _uploadStage = 2);
      final res = await ApiService.loadScratchSample();
      final rows = res['rows'] ?? [];
      if (!mounted) return;
      setState(() {
        _filename = res['filename'] ?? 'Chillers Database_V1.xlsx';
        _fileSizeBytes = null;
        _totalRows = res['totalRows'] ?? 0;
        _validCount = res['validCount'] ?? 0;
        _invalidCount = res['invalidCount'] ?? 0;
        _previewRows = rows;
        _uploadStage = 3;
        _isLoading = false;
        _showErrorsOnly = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _uploadStage = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading sample: $e'), backgroundColor: AppTokens.of(context).danger),
      );
    }
  }

  Future<void> _pickAndUploadCustomFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    await _processSelectedFile(file.bytes!, file.name, file.size);
  }

  Future<void> _processSelectedFile(Uint8List bytes, String filename, int sizeBytes) async {
    if (sizeBytes > _maxFileSizeBytes) {
      setState(() {
        _dropState = _DropZoneVisualState.invalidDrop;
        _dropError = 'File "$filename" exceeds the 25 MB limit (${_formatBytes(sizeBytes)}).';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _filename = filename;
      _fileSizeBytes = sizeBytes;
      _dropState = _DropZoneVisualState.validDrop;
      _dropError = null;
      _uploadStage = 1;
    });

    try {
      // Transition to stage 2 while awaiting server validation response
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _isLoading && _uploadStage == 1) {
          setState(() => _uploadStage = 2);
        }
      });

      final res = await ApiService.uploadExcelFile(bytes, filename);
      final rows = res['rows'] ?? [];
      if (!mounted) return;
      setState(() {
        _filename = res['filename'] ?? filename;
        _totalRows = res['totalRows'] ?? 0;
        _validCount = res['validCount'] ?? 0;
        _invalidCount = res['invalidCount'] ?? 0;
        _previewRows = rows;
        _uploadStage = 3;
        _isLoading = false;
        _showErrorsOnly = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _uploadStage = 0;
        _dropState = _DropZoneVisualState.invalidDrop;
        _dropError = e.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload error: $e'), backgroundColor: AppTokens.of(context).danger),
      );
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
        onlyThisBatch: _onlyThisBatch,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Successfully saved and reflected on Map!'),
          backgroundColor: AppTokens.of(context).success,
          duration: const Duration(seconds: 4),
        ),
      );
      widget.onUploadSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e'), backgroundColor: AppTokens.of(context).danger),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final filteredPreview = _showErrorsOnly
        ? _previewRows.where((r) => r['isValid'] != true).toList()
        : _previewRows;

    return Scaffold(
      backgroundColor: t.canvasBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Excel & CSV Upload & Validation Studio', style: t.displayTitle),
            SizedBox(height: t.spaceXs),
            Text(
              'Drag and drop .xlsx, .xls, or .csv datasets, inspect cell validation, and choose strict or bypassed UPSERT import.',
              style: t.bodyDefault.copyWith(color: t.textSecondary),
            ),
            SizedBox(height: t.spaceXl),

            // 2-Column Responsive Dropzone + Quick Actions Card
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 768;
                final dropzone = _buildDropzoneCard(t);
                final quickActions = _buildQuickActionsCard(t);

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dropzone,
                      SizedBox(height: t.spaceLg),
                      quickActions,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: dropzone),
                    SizedBox(width: t.spaceLg),
                    Expanded(flex: 2, child: quickActions),
                  ],
                );
              },
            ),

            // Staged Upload / Validation Progress Indicator
            if (_uploadStage > 0 || _isLoading) ...[
              SizedBox(height: t.spaceLg),
              _buildStagedProgressCard(t),
            ],

            SizedBox(height: t.spaceXl),

            if (_isLoading)
              AppSkeleton.tableRows(context, rowCount: 6)
            else if (_previewRows.isNotEmpty) ...[
              // KPI Cards Summary
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 768;
                  final cards = [
                    _buildSummaryKpi(t, 'Uploaded File', _filename ?? '-', t.accentPrimary, Icons.file_present),
                    _buildSummaryKpi(t, 'Total Rows', '$_totalRows', t.achievement, Icons.table_rows),
                    _buildSummaryKpi(t, 'Valid Rows', '$_validCount', t.success, Icons.check_circle),
                    _buildSummaryKpi(t, 'Incomplete / Missing', '$_invalidCount', t.danger, Icons.warning),
                  ];
                  if (isNarrow) {
                    return Wrap(
                      spacing: t.spaceMd,
                      runSpacing: t.spaceMd,
                      children: cards.map((c) => SizedBox(width: (constraints.maxWidth - t.spaceMd) / 2, child: c)).toList(),
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: cards[0]),
                      SizedBox(width: t.spaceLg),
                      Expanded(child: cards[1]),
                      SizedBox(width: t.spaceLg),
                      Expanded(child: cards[2]),
                      SizedBox(width: t.spaceLg),
                      Expanded(child: cards[3]),
                    ],
                  );
                },
              ),
              SizedBox(height: t.spaceXl),

              // Save Action Buttons & Batch Settings Bar
              Container(
                padding: EdgeInsets.all(t.spaceLg),
                decoration: BoxDecoration(
                  color: t.surfaceElevated,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceMd),
                      decoration: BoxDecoration(
                        color: t.canvasBg,
                        borderRadius: BorderRadius.circular(t.radiusSm),
                        border: Border.all(color: t.success.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sync_alt, color: t.success, size: 22),
                          SizedBox(width: t.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Master Dataset Incremental Sync (UPSERT)', style: t.cardTitle),
                                const SizedBox(height: 2),
                                Text(
                                  'Uploaded records will increment and update the master dataset: existing chillers (by Chiller Code) will be updated, and new chillers will be appended without losing previous records.',
                                  style: t.caption,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: t.spaceMd),
                    Wrap(
                      spacing: t.spaceMd,
                      runSpacing: t.spaceMd,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, color: t.caution, size: 20),
                            SizedBox(width: t.spaceSm),
                            Text(
                              'Review missing cells below. Choose strict validation or bypass validation.',
                              style: t.bodyDefault.copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: t.spaceMd,
                          runSpacing: t.spaceSm,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _confirmSave(bypassValidation: false),
                              icon: const Icon(Icons.verified, color: Colors.white, size: 18),
                              label: Text('Confirm Upload ($_validCount Clean Rows)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSm)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _confirmSave(bypassValidation: true),
                              icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                              label: Text('Bypass Validation & Save All ($_totalRows Rows)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: t.caution,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSm)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.spaceXl),

              // Preview Header + All Rows | Errors Only Toggle
              Wrap(
                spacing: t.spaceMd,
                runSpacing: t.spaceSm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Data Preview & Validation Report', style: t.sectionTitle.copyWith(fontSize: 18)),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: t.surfaceElevated,
                      borderRadius: BorderRadius.circular(t.radiusSm),
                      border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPreviewFilterChip(
                          t: t,
                          selected: !_showErrorsOnly,
                          label: 'All Rows (${_previewRows.length})',
                          color: t.accentPrimary,
                          onTap: () => setState(() => _showErrorsOnly = false),
                        ),
                        _buildPreviewFilterChip(
                          t: t,
                          selected: _showErrorsOnly,
                          label: 'Errors Only ($_invalidCount)',
                          color: t.danger,
                          onTap: () => setState(() => _showErrorsOnly = true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceMd),

              if (filteredPreview.isEmpty)
                AppEmptyState(
                  icon: Icons.check_circle_outline,
                  accentColor: t.success,
                  title: 'No validation errors found',
                  subtitle: 'All $_totalRows uploaded rows passed column and coordinate validation.',
                  primaryLabel: 'Show All Rows',
                  primaryIcon: Icons.table_rows,
                  onPrimaryPressed: () => setState(() => _showErrorsOnly = false),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: t.surfaceElevated,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(t.surfaceHeader),
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columns: [
                        DataColumn(label: Text('Row #', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Chiller Code', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Branch', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Customer Type', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Efficiency', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Latitude', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Longitude', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Missing Fields / Warnings', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredPreview.take(100).map((r) {
                        final bool isValid = r['isValid'] == true;
                        final List<dynamic> missing = r['missingFields'] ?? [];

                        return DataRow(
                          cells: [
                            DataCell(Text('${r['rowIndex']}', style: t.bodyDefault.copyWith(color: t.textSecondary))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isValid ? t.success : t.danger).withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isValid ? 'Valid' : 'Incomplete',
                                  style: TextStyle(
                                    color: isValid ? t.success : t.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(r['chillerCode'] ?? '-', style: t.bodyDefault.copyWith(fontWeight: FontWeight.w600))),
                            DataCell(Text(r['branch'] ?? '-', style: t.bodyDefault.copyWith(color: t.textSecondary))),
                            DataCell(Text(r['customerType'] ?? '-', style: t.bodyDefault.copyWith(color: t.textSecondary))),
                            DataCell(Text(r['efficiency'] ?? '-', style: t.bodyDefault.copyWith(color: t.textSecondary))),
                            DataCell(Text(
                              r['latitude']?.toString() ?? 'MISSING',
                              style: t.bodyDefault.copyWith(color: r['latitude'] != null ? t.textSecondary : t.danger),
                            )),
                            DataCell(Text(
                              r['longitude']?.toString() ?? 'MISSING',
                              style: t.bodyDefault.copyWith(color: r['longitude'] != null ? t.textSecondary : t.danger),
                            )),
                            DataCell(
                              missing.isNotEmpty
                                  ? Wrap(
                                      spacing: 4,
                                      children: missing.take(3).map((m) {
                                        return Chip(
                                          label: Text(m.toString(), style: TextStyle(color: t.danger, fontSize: 10)),
                                          backgroundColor: t.danger.withValues(alpha: 0.14),
                                          padding: EdgeInsets.zero,
                                        );
                                      }).toList(),
                                    )
                                  : Text('None', style: t.caption.copyWith(color: t.textMuted)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (filteredPreview.length > 100)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Showing first 100 preview rows out of ${filteredPreview.length} matching rows.',
                      style: t.caption.copyWith(color: t.textMuted),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropzoneCard(AppTokens t) {
    Color borderColor;
    Color fillColor;
    switch (_dropState) {
      case _DropZoneVisualState.dragOver:
        borderColor = t.accentPrimary;
        fillColor = t.accentPrimary.withValues(alpha: 0.12);
        break;
      case _DropZoneVisualState.validDrop:
        borderColor = t.success;
        fillColor = t.success.withValues(alpha: 0.08);
        break;
      case _DropZoneVisualState.invalidDrop:
        borderColor = t.danger;
        fillColor = t.danger.withValues(alpha: 0.08);
        break;
      case _DropZoneVisualState.idle:
        borderColor = t.borderSubtle;
        fillColor = t.surfaceElevated;
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(t.radiusMd),
      onTap: _isLoading ? null : _pickAndUploadCustomFile,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: borderColor, radius: t.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 168),
          padding: EdgeInsets.all(t.spaceXl),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(t.radiusMd),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _dropState == _DropZoneVisualState.invalidDrop
                      ? Icons.error_outline
                      : Icons.cloud_upload_outlined,
                  size: 44,
                  color: _dropState == _DropZoneVisualState.invalidDrop ? t.danger : t.accentPrimary,
                ),
                SizedBox(height: t.spaceMd),
                Text(
                  'Drag & drop your .xlsx, .xls, or .csv file here',
                  textAlign: TextAlign.center,
                  style: t.sectionTitle,
                ),
                SizedBox(height: t.spaceXs),
                Text(
                  'or click to browse files (max 25 MB)',
                  textAlign: TextAlign.center,
                  style: t.caption,
                ),
                if (_dropError != null) ...[
                  SizedBox(height: t.spaceSm),
                  Text(
                    _dropError!,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(color: t.danger, fontWeight: FontWeight.w600),
                  ),
                ],
                SizedBox(height: t.spaceMd),
                Wrap(
                  spacing: t.spaceSm,
                  children: ['.XLSX', '.XLS', '.CSV'].map((fmt) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.accentPrimary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(t.radiusPill),
                        border: Border.all(color: t.accentPrimary.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        fmt,
                        style: TextStyle(color: t.accentPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(AppTokens t) {
    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: EdgeInsets.all(t.spaceLg),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('QUICK ACTIONS', style: t.eyebrow),
          SizedBox(height: t.spaceMd),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadScratchSample,
            icon: const Icon(Icons.bolt, color: Colors.black, size: 20),
            label: const Text(
              'Quick Load Sample Excel',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd)),
            ),
          ),
          SizedBox(height: t.spaceMd),
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _pickAndUploadCustomFile,
            icon: Icon(Icons.folder_open_outlined, color: t.accentPrimary, size: 18),
            label: Text(
              'Browse Files (.xlsx, .xls, .csv)',
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: t.accentPrimary, width: t.borderWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagedProgressCard(AppTokens t) {
    final double? progress = _uploadStage == 3 ? 1.0 : (_uploadStage == 2 ? 0.65 : null);
    return Container(
      padding: EdgeInsets.all(t.spaceLg),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _uploadStage == 3 ? Icons.check_circle : Icons.upload_file,
                color: _uploadStage == 3 ? t.success : t.accentPrimary,
                size: 20,
              ),
              SizedBox(width: t.spaceSm),
              Expanded(
                child: Text(
                  _filename ?? 'Preparing upload...',
                  style: t.cardTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_fileSizeBytes != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.accentPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(t.radiusPill),
                  ),
                  child: Text(
                    _formatBytes(_fileSizeBytes!),
                    style: TextStyle(color: t.accentPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          SizedBox(height: t.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: _uploadStage == 3 ? t.success : t.accentPrimary,
              backgroundColor: t.borderSubtle,
            ),
          ),
          SizedBox(height: t.spaceMd),
          Wrap(
            spacing: t.spaceLg,
            runSpacing: t.spaceXs,
            children: [
              _buildStageStep(t, 1, '1. Uploading'),
              _buildStageStep(t, 2, '2. Validating Columns'),
              _buildStageStep(t, 3, '3. Ready for UPSERT'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageStep(AppTokens t, int step, String label) {
    final bool done = _uploadStage > step || (_uploadStage == 3 && step == 3);
    final bool active = _uploadStage == step && _uploadStage < 3;
    final color = done ? t.success : (active ? t.accentPrimary : t.textMuted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          done ? Icons.check_circle : (active ? Icons.autorenew : Icons.radio_button_unchecked),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: t.caption.copyWith(
            color: color,
            fontWeight: (done || active) ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewFilterChip({
    required AppTokens t,
    required bool selected,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected ? Border.all(color: color.withValues(alpha: 0.7)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : t.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryKpi(AppTokens t, String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(t.spaceLg),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: t.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: t.metricNum.copyWith(color: color, fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dashLength = 8.0;
    const gapLength = 5.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
