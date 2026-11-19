import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';
import 'customer_360_drawer.dart';

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
  String _changeFilter = 'all'; // 'all', 'modified', 'added', 'removed'

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
      if (!mounted) return;
      setState(() {
        _batches = batches;
        if (batches.length >= 2) {
          _startBatchId = batches[1]['id']; // Older batch
          _endBatchId = batches[0]['id']; // Newer batch
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
        AppToast.show(context, type: AppToastType.error, message: 'Error loading upload history: $e');
      }
    }
  }

  Future<void> _compareDelta() async {
    if (_startBatchId == null || _endBatchId == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.fetchDelta(_startBatchId!, _endBatchId!);
      if (!mounted) return;
      setState(() {
        _deltaResult = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppToast.show(context, type: AppToastType.error, message: 'Delta comparison error: $e', actionLabel: 'Retry', onAction: _compareDelta);
    }
  }

  String _readField(Map<String, dynamic>? item, List<String> keys) {
    if (item == null) return '-';
    final raw = (item['raw_data_json'] ?? item['rawData']) as Map?;
    for (final k in keys) {
      if (item[k] != null && item[k].toString().trim().isNotEmpty) {
        return item[k].toString().trim();
      }
      if (raw != null) {
        for (final rk in raw.keys) {
          if (rk.toString().toLowerCase() == k.toLowerCase() &&
              raw[rk] != null &&
              raw[rk].toString().trim().isNotEmpty) {
            return raw[rk].toString().trim();
          }
        }
      }
    }
    return '-';
  }

  double? _readNum(Map<String, dynamic>? item, List<String> keys) {
    final s = _readField(item, keys);
    if (s == '-') return null;
    return double.tryParse(s.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.-]'), ''));
  }

  String _formatNum(double v) {
    final abs = v.abs();
    final str = abs >= 1000 ? abs.toStringAsFixed(0) : abs.toStringAsFixed(1);
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final decPart = parts.length > 1 && parts[1] != '0' ? '.${parts[1]}' : '';
    return '${v < 0 ? '-' : ''}$intPart$decPart';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final summary = (_deltaResult?['summary'] as Map?) ?? {};
    final List<dynamic> modified = (_deltaResult?['modified'] as List?) ?? [];
    final List<dynamic> added = (_deltaResult?['added'] as List?) ?? [];
    final List<dynamic> removed = (_deltaResult?['removed'] as List?) ?? [];

    final addedCount = summary['added'] ?? summary['addedCount'] ?? added.length;
    final removedCount = summary['removed'] ?? summary['removedCount'] ?? removed.length;
    final modifiedCount = summary['modified'] ?? summary['modifiedCount'] ?? modified.length;
    final unchangedCount = summary['unchanged'] ?? summary['unchangedCount'] ?? 0;

    final List<Map<String, dynamic>> diffEntries = [];
    if (_changeFilter == 'all' || _changeFilter == 'modified') {
      for (final m in modified) {
        diffEntries.add({'type': 'modified', 'data': m});
      }
    }
    if (_changeFilter == 'all' || _changeFilter == 'added') {
      for (final a in added) {
        diffEntries.add({'type': 'added', 'data': a});
      }
    }
    if (_changeFilter == 'all' || _changeFilter == 'removed') {
      for (final r in removed) {
        diffEntries.add({'type': 'removed', 'data': r});
      }
    }

    return Scaffold(
      backgroundColor: t.canvasBg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delta & Historical Changes', style: t.displayTitle.copyWith(fontSize: 22)),
            SizedBox(height: t.spaceXs),
            Text(
              'Compare uploaded snapshot batches over time to analyze added chillers, removed items, and condition/efficiency/YTD transitions.',
              style: t.bodyDefault.copyWith(color: t.textSecondary),
            ),
            SizedBox(height: t.spaceLg),

            // Batch Picker Toolbar
            Container(
              padding: EdgeInsets.all(t.spaceLg),
              decoration: BoxDecoration(
                color: t.surfaceElevated,
                borderRadius: BorderRadius.circular(t.radiusLg),
                border: Border.all(color: t.borderSubtle, width: t.borderWidth),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool isNarrow = constraints.maxWidth < 750;

                  final startDropdown = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Snapshot Batch (Baseline):', style: t.caption.copyWith(color: t.accentPrimary, fontWeight: FontWeight.bold)),
                      SizedBox(height: t.spaceXs),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
                        decoration: BoxDecoration(
                          color: t.canvasBg,
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          border: Border.all(color: t.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _startBatchId,
                            isExpanded: true,
                            dropdownColor: t.surfaceElevated,
                            style: t.bodyDefault,
                            items: _batches.map<DropdownMenuItem<int>>((b) {
                              return DropdownMenuItem<int>(
                                value: b['id'],
                                child: Text('Batch #${b['id']} - ${b['filename']} (${b['uploaded_at']})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _startBatchId = val),
                          ),
                        ),
                      ),
                    ],
                  );

                  final endDropdown = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Snapshot Batch (Comparison):', style: t.caption.copyWith(color: t.accentPrimary, fontWeight: FontWeight.bold)),
                      SizedBox(height: t.spaceXs),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: t.spaceMd),
                        decoration: BoxDecoration(
                          color: t.canvasBg,
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          border: Border.all(color: t.borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _endBatchId,
                            isExpanded: true,
                            dropdownColor: t.surfaceElevated,
                            style: t.bodyDefault,
                            items: _batches.map<DropdownMenuItem<int>>((b) {
                              return DropdownMenuItem<int>(
                                value: b['id'],
                                child: Text('Batch #${b['id']} - ${b['filename']} (${b['uploaded_at']})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _endBatchId = val),
                          ),
                        ),
                      ),
                    ],
                  );

                  final compareBtn = ElevatedButton.icon(
                    onPressed: _isLoading ? null : _compareDelta,
                    icon: const Icon(Icons.compare_arrows, color: Colors.black),
                    label: const Text('Compare Delta', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accentPrimary,
                      padding: EdgeInsets.symmetric(horizontal: t.spaceXl, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        startDropdown,
                        SizedBox(height: t.spaceMd),
                        endDropdown,
                        SizedBox(height: t.spaceLg),
                        compareBtn,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: startDropdown),
                      SizedBox(width: t.spaceLg),
                      Expanded(child: endDropdown),
                      SizedBox(width: t.spaceLg),
                      compareBtn,
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: t.spaceLg),

            if (_isLoading)
              AppSkeleton.listCards(context, count: 4)
            else if (_deltaResult != null) ...[
              // KPI Stat Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isSmall = constraints.maxWidth < 650;
                  final double cardWidth = isSmall ? (constraints.maxWidth - 12) / 2 : 0;

                  if (isSmall) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildDeltaStatCard(t, '+ Added', '$addedCount', t.success, Icons.add_circle_outline, width: cardWidth),
                        _buildDeltaStatCard(t, '- Removed', '$removedCount', t.danger, Icons.remove_circle_outline, width: cardWidth),
                        _buildDeltaStatCard(t, 'Δ Modified', '$modifiedCount', t.caution, Icons.published_with_changes, width: cardWidth),
                        _buildDeltaStatCard(t, '= Unchanged', '$unchangedCount', t.accentPrimary, Icons.drag_handle, width: cardWidth),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      _buildDeltaStatCard(t, '+ Added', '$addedCount', t.success, Icons.add_circle_outline),
                      SizedBox(width: t.spaceLg),
                      _buildDeltaStatCard(t, '- Removed', '$removedCount', t.danger, Icons.remove_circle_outline),
                      SizedBox(width: t.spaceLg),
                      _buildDeltaStatCard(t, 'Δ Modified', '$modifiedCount', t.caution, Icons.published_with_changes),
                      SizedBox(width: t.spaceLg),
                      _buildDeltaStatCard(t, '= Unchanged', '$unchangedCount', t.accentPrimary, Icons.drag_handle),
                    ],
                  );
                },
              ),
              SizedBox(height: t.spaceXl),

              // Filter Chips Header
              Wrap(
                spacing: t.spaceSm,
                runSpacing: t.spaceSm,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text('Visual Before → After Diff Cards', style: t.sectionTitle.copyWith(fontSize: 18)),
                  Wrap(
                    spacing: t.spaceSm,
                    children: [
                      ChoiceChip(
                        label: Text('All (${modified.length + added.length + removed.length})'),
                        selected: _changeFilter == 'all',
                        onSelected: (_) => setState(() => _changeFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: Text('Modified (${modified.length})'),
                        selected: _changeFilter == 'modified',
                        onSelected: (_) => setState(() => _changeFilter = 'modified'),
                      ),
                      ChoiceChip(
                        label: Text('Added (${added.length})'),
                        selected: _changeFilter == 'added',
                        onSelected: (_) => setState(() => _changeFilter = 'added'),
                      ),
                      ChoiceChip(
                        label: Text('Removed (${removed.length})'),
                        selected: _changeFilter == 'removed',
                        onSelected: (_) => setState(() => _changeFilter = 'removed'),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: t.spaceMd),

              if (diffEntries.isEmpty)
                const AppEmptyState(
                  icon: Icons.compare_arrows,
                  title: 'No changes detected for this filter',
                  subtitle: 'Try switching batches or selecting "All" to view other delta categories.',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: diffEntries.length,
                  separatorBuilder: (_, __) => SizedBox(height: t.spaceMd),
                  itemBuilder: (context, idx) {
                    final entry = diffEntries[idx];
                    return _buildVisualDiffCard(t, entry['type'] as String, entry['data']);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisualDiffCard(AppTokens t, String type, dynamic rawEntry) {
    final Map<String, dynamic> entry = Map<String, dynamic>.from(rawEntry as Map);
    final Map<String, dynamic>? prev = entry['previous'] is Map ? Map<String, dynamic>.from(entry['previous'] as Map) : null;
    final Map<String, dynamic>? curr = entry['current'] is Map ? Map<String, dynamic>.from(entry['current'] as Map) : null;
    final Map<String, dynamic> primary = curr ?? prev ?? entry;

    final String chillerCode = _readField(primary, ['chiller_code', 'chillerCode', 'Chiller Code']);
    final String customerName = _readField(primary, ['customer_name', 'customerName', 'Customer Name']);

    Color typeColor;
    String typeLabel;
    if (type == 'added') {
      typeColor = t.success;
      typeLabel = 'Added';
    } else if (type == 'removed') {
      typeColor = t.danger;
      typeLabel = 'Removed';
    } else {
      typeColor = t.caution;
      typeLabel = 'Modified';
    }

    final List<Widget> diffChips = [];

    if (prev != null && curr != null) {
      // 1. Condition diff
      final prevCond = _readField(prev, ['chiller_condition', 'Chiller Condition', 'Condition']);
      final currCond = _readField(curr, ['chiller_condition', 'Chiller Condition', 'Condition']);
      if (prevCond != currCond) {
        final highlight = currCond.toLowerCase().contains('scrap')
            ? t.danger
            : (currCond.toLowerCase().contains('maint') ? t.warning : t.success);
        diffChips.add(_buildBeforeAfterChip(t, 'Condition', prevCond, currCond, highlight));
      }

      // 2. Efficiency diff
      final prevEff = _readField(prev, ['efficiency', 'Month Ach. Status', 'Efficiency']);
      final currEff = _readField(curr, ['efficiency', 'Month Ach. Status', 'Efficiency']);
      if (prevEff != currEff) {
        final isUp = currEff.toLowerCase() == 'performing';
        diffChips.add(_buildBeforeAfterChip(
          t,
          'Efficiency',
          prevEff,
          currEff,
          isUp ? t.success : t.caution,
          trailingIcon: isUp ? Icons.trending_up : Icons.trending_down,
        ));
      }

      // 3. YTD Invoice numeric delta
      final prevYtd = _readNum(prev, ['ytd_invoice', 'YTD', 'YTD Invoice', 'Total Invoice']);
      final currYtd = _readNum(curr, ['ytd_invoice', 'YTD', 'YTD Invoice', 'Total Invoice']);
      if (prevYtd != null && currYtd != null && (prevYtd - currYtd).abs() > 0.01) {
        final delta = currYtd - prevYtd;
        final pct = prevYtd != 0 ? (delta / prevYtd.abs()) * 100 : 0.0;
        final isPos = delta >= 0;
        final sign = isPos ? '+' : '';
        final deltaColor = isPos ? t.success : t.danger;
        diffChips.add(
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: deltaColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('YTD Invoice: ', style: t.caption.copyWith(color: t.textSecondary, fontWeight: FontWeight.w600)),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$sign${_formatNum(delta)} / $sign${pct.toStringAsFixed(1)}%',
                    style: t.metricNum.copyWith(color: deltaColor, fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 4. Branch / other top-level changes
      final prevBranch = _readField(prev, ['branch', 'Branch']);
      final currBranch = _readField(curr, ['branch', 'Branch']);
      if (prevBranch != currBranch) {
        diffChips.add(_buildBeforeAfterChip(t, 'Branch', prevBranch, currBranch, t.accentPrimary));
      }
    } else if (entry['changes'] is List) {
      for (final c in (entry['changes'] as List)) {
        diffChips.add(_buildBeforeAfterChip(
          t,
          c['field']?.toString() ?? 'Field',
          c['oldValue']?.toString() ?? 'N/A',
          c['newValue']?.toString() ?? 'N/A',
          t.accentPrimary,
        ));
      }
    } else {
      final eff = _readField(primary, ['efficiency', 'Month Ach. Status']);
      final branch = _readField(primary, ['branch', 'Branch']);
      diffChips.add(_buildSingleInfoChip(t, 'Branch', branch, t.accentPrimary));
      diffChips.add(_buildSingleInfoChip(t, 'Efficiency', eff, eff.toLowerCase() == 'performing' ? t.success : t.caution));
    }

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
          // Card Header: Chiller Code + Customer Name + Change Type Pill + Open 360°
          Row(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: t.spaceSm, vertical: t.spaceXs),
                  decoration: BoxDecoration(
                    color: t.accentPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Text(
                    chillerCode,
                    style: t.metricNum.copyWith(color: t.accentPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              SizedBox(width: t.spaceMd),
              Expanded(
                child: Text(
                  customerName,
                  style: t.bodyDefault.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: t.spaceSm),
              Container(
                padding: EdgeInsets.symmetric(horizontal: t.spaceSm, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(color: typeColor.withValues(alpha: 0.5)),
                ),
                child: Text(typeLabel, style: TextStyle(color: typeColor, fontSize: 11.5, fontWeight: FontWeight.bold)),
              ),
              if (primary['id'] != null) ...[
                SizedBox(width: t.spaceSm),
                Semantics(
                  button: true,
                  label: 'Open 360 for $chillerCode',
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showCustomer360Drawer(context, chiller: primary);
                    },
                    icon: Icon(Icons.open_in_new, size: 14, color: t.accentPrimary),
                    label: Text('Open 360°', style: TextStyle(color: t.accentPrimary, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.accentPrimary.withValues(alpha: 0.5)),
                      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceXs),
                      minimumSize: const Size(44, 36),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (diffChips.isNotEmpty) ...[
            SizedBox(height: t.spaceMd),
            Wrap(
              spacing: t.spaceSm,
              runSpacing: t.spaceSm,
              children: diffChips,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBeforeAfterChip(
    AppTokens t,
    String label,
    String before,
    String after,
    Color highlightColor, {
    IconData? trailingIcon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
      decoration: BoxDecoration(
        color: t.canvasBg.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$label:', style: t.caption.copyWith(color: t.textSecondary, fontWeight: FontWeight.w600)),
          Text(
            before,
            style: t.caption.copyWith(color: t.textMuted, decoration: TextDecoration.lineThrough),
          ),
          Icon(Icons.arrow_forward, size: 13, color: t.textMuted, matchTextDirection: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: highlightColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailingIcon != null) ...[
                  Icon(trailingIcon, size: 13, color: highlightColor),
                  const SizedBox(width: 4),
                ],
                Text(after, style: TextStyle(color: highlightColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleInfoChip(AppTokens t, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text('$label: $value', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDeltaStatCard(AppTokens t, String label, String value, Color color, IconData icon, {double? width}) {
    final card = Container(
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
                Text(label, style: t.caption.copyWith(color: t.textSecondary)),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(value, style: t.metricNum.copyWith(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: card);
    }
    return Expanded(child: card);
  }
}
