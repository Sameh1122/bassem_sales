import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/url_launcher.dart';
import 'form_filler_dialog.dart';
import '../widgets/audit_photo_gallery.dart';

Future<void> showCustomer360Drawer(
  BuildContext context, {
  required Map<String, dynamic> chiller,
  double? distanceMeters,
  AppLocation? userPosition,
  VoidCallback? onAuditSubmitted,
}) {
  final isMobile = MediaQuery.of(context).size.width < 600;
  if (isMobile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _Customer360Content(
                  chiller: chiller,
                  distanceMeters: distanceMeters,
                  userPosition: userPosition,
                  onAuditSubmitted: onAuditSubmitted,
                  scrollController: scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Customer 360',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) {
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            height: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(
                left: BorderSide(color: Colors.cyan.withValues(alpha: 0.35)),
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 24),
              ],
            ),
            child: _Customer360Content(
              chiller: chiller,
              distanceMeters: distanceMeters,
              userPosition: userPosition,
              onAuditSubmitted: onAuditSubmitted,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _Customer360Content extends StatefulWidget {
  final Map<String, dynamic> chiller;
  final double? distanceMeters;
  final AppLocation? userPosition;
  final VoidCallback? onAuditSubmitted;
  final ScrollController? scrollController;

  const _Customer360Content({
    required this.chiller,
    this.distanceMeters,
    this.userPosition,
    this.onAuditSubmitted,
    this.scrollController,
  });

  @override
  State<_Customer360Content> createState() => _Customer360ContentState();
}

class _Customer360ContentState extends State<_Customer360Content> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data360;
  bool _showAllAudits = false;

  @override
  void initState() {
    super.initState();
    _load360();
  }

  Future<void> _load360() async {
    final targetId = widget.chiller['id'] ?? widget.chiller['chillerCode'];
    if (targetId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Missing chiller identifier.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiService.fetchChiller360(targetId);
      if (mounted) {
        setState(() {
          _data360 = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  Color _getMarkerColor(String efficiency) {
    final eff = efficiency.trim().toLowerCase();
    if (eff.contains('performing') && !eff.contains('non') && !eff.contains('under')) {
      return const Color(0xFF10B981);
    } else if (eff.contains('non') || eff.contains('under') || eff.contains('critical')) {
      return const Color(0xFFEF4444);
    } else if (eff.contains('zero')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF6B7280);
  }

  double _toDouble(dynamic val, [double def = 0.0]) {
    if (val == null) return def;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? def;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }

  String _formatNumber(num val) {
    final rounded = val.round();
    final str = rounded.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (str[i] == '-') {
        buf.write('-');
        continue;
      }
      if (count > 0 && count % 3 == 0) buf.write(',');
      buf.write(str[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }

  void _openGoogleMaps(double lat, double lng) {
    final String url;
    if (widget.userPosition != null) {
      url = 'https://www.google.com/maps/dir/?api=1&origin=${widget.userPosition!.latitude},${widget.userPosition!.longitude}&destination=$lat,$lng';
    } else {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    }
    openExternalUrl(url);
  }

  void _openAuditForm(Map<String, dynamic> chiller) {
    showDialog(
      context: context,
      builder: (fCtx) => FormFillerDialog(
        chiller: chiller,
        onSubmitted: () {
          _load360();
          widget.onAuditSubmitted?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> chiller = _data360?['chiller'] is Map
        ? Map<String, dynamic>.from(_data360!['chiller'])
        : widget.chiller;
    final rawData = chiller['rawData'] is Map ? Map<String, dynamic>.from(chiller['rawData']) : <String, dynamic>{};

    final String code = (chiller['chillerCode'] ?? 'N/A').toString();
    final String customerName = (chiller['customerName'] ?? 'N/A').toString();
    final String branch = (chiller['branch'] ?? 'N/A').toString();
    final String efficiency = (chiller['efficiency'] ?? 'N/A').toString();
    final String customerType = (chiller['customerType'] ?? 'N/A').toString();
    final String status = (chiller['chillerStatus'] ?? 'N/A').toString();
    final String condition = (chiller['condition'] ?? rawData['Condiiton'] ?? rawData['Condition'] ?? 'N/A').toString();
    final String chillerType = (chiller['chillerType'] ?? rawData['Chiller Type'] ?? 'N/A').toString();
    final String serial = (rawData['Serial Number'] ?? 'N/A').toString();
    final String assignedRep = (chiller['assignedAgentName'] ?? rawData['SR Name'] ?? 'Unassigned').toString();
    final double lat = _toDouble(chiller['latitude'], 30.0444);
    final double lng = _toDouble(chiller['longitude'], 31.2357);

    final String visitStatus = (chiller['visitStatus'] ?? 'not_visited').toString();
    final bool isReopened = visitStatus == 'reopened';
    final bool isAccepted = visitStatus == 'accepted';
    final bool isSubmitted = visitStatus == 'submitted';

    final Color effColor = _getMarkerColor(efficiency);

    return Column(
      children: [
        // A. Sticky Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: effColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.ac_unit, color: effColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$code • $branch',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (isAccepted)
                    _buildBadge('✅ Verified', const Color(0xFF10B981))
                  else if (isSubmitted)
                    _buildBadge('⏳ Submitted', const Color(0xFF06B6D4))
                  else if (isReopened)
                    _buildBadge('⚠️ Re-opened', const Color(0xFFF97316))
                  else
                    _buildBadge('⭕ Not Visited', Colors.white54),
                  _buildBadge(efficiency, effColor),
                  _buildBadge(customerType, const Color(0xFF06B6D4)),
                  if (widget.distanceMeters != null)
                    _buildBadge('📍 ${_formatDistance(widget.distanceMeters!)}', const Color(0xFF38BDF8)),
                ],
              ),
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: _load360,
                          child: const Text('Retry', style: TextStyle(color: Colors.cyanAccent)),
                        ),
                      ],
                    ),
                  ),

                // B. Next Best Action (NBA) Guided Selling Card
                if (_isLoading)
                  _buildSkeletonBox(height: 92)
                else if (_data360?['nextBestAction'] is Map)
                  _buildNbaCard(Map<String, dynamic>.from(_data360!['nextBestAction']), chiller),
                const SizedBox(height: 16),

                // C. Chiller Asset Metadata & GPS Card
                _buildMetadataCard(
                  status: status,
                  condition: condition,
                  chillerType: chillerType,
                  efficiency: efficiency,
                  serial: serial,
                  assignedRep: assignedRep,
                  lat: lat,
                  lng: lng,
                ),
                const SizedBox(height: 16),

                // D. Jan-Dec Invoice Trend & Summary
                if (_isLoading)
                  _buildSkeletonBox(height: 160)
                else if (_data360?['invoiceSummary'] is Map)
                  _buildInvoiceSection(Map<String, dynamic>.from(_data360!['invoiceSummary'])),
                const SizedBox(height: 16),

                // E. Recent Visit Audit History
                if (_isLoading)
                  _buildSkeletonBox(height: 110)
                else
                  _buildVisitHistorySection(
                    (_data360?['visitHistory'] as List<dynamic>?) ?? [],
                  ),
                const SizedBox(height: 12),

                // Collapsible All Row Attributes
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        'All Row Attributes (${rawData.length} Columns)',
                        style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      iconColor: Colors.cyan,
                      collapsedIconColor: Colors.white54,
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      children: rawData.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 150,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value?.toString() ?? '-',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // F. Sticky Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAuditForm(chiller),
                  icon: Icon(
                    isReopened
                        ? Icons.replay
                        : isAccepted
                            ? Icons.verified
                            : Icons.assignment_turned_in,
                    size: 18,
                    color: Colors.black,
                  ),
                  label: Text(
                    isReopened
                        ? 'Resubmit Visit Audit'
                        : isAccepted
                            ? 'Update Audit Form'
                            : 'Complete Visit (Fill Form)',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAccepted
                        ? const Color(0xFF10B981)
                        : isReopened
                            ? const Color(0xFFF97316)
                            : const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _openGoogleMaps(lat, lng),
                icon: const Icon(Icons.directions, color: Color(0xFF4285F4), size: 18),
                label: const Text('Maps', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4285F4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSkeletonBox({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06B6D4)),
        ),
      ),
    );
  }

  Widget _buildNbaCard(Map<String, dynamic> nba, Map<String, dynamic> chiller) {
    final String priority = (nba['priority'] ?? 'low').toString().toLowerCase();
    final String actionCode = (nba['actionCode'] ?? '').toString();
    final Color severityColor = actionCode == 'reopened_audit'
        ? const Color(0xFFF97316)
        : priority == 'high'
            ? const Color(0xFFEF4444)
            : priority == 'medium'
                ? const Color(0xFF06B6D4)
                : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: severityColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor, width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: severityColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          priority == 'high' ? Icons.warning_amber_rounded : Icons.auto_awesome,
                          color: severityColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'NEXT BEST ACTION',
                          style: TextStyle(
                            color: severityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (nba['title'] ?? 'Review Account').toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (nba['reason'] ?? '').toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _openAuditForm(chiller),
                      child: Text(
                        '${nba['suggestedAction'] ?? 'Take Action'} →',
                        style: TextStyle(color: severityColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard({
    required String status,
    required String condition,
    required String chillerType,
    required String efficiency,
    required String serial,
    required String assignedRep,
    required double lat,
    required double lng,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Asset Metadata & GPS', style: TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metaItem('Chiller Status', status)),
              Expanded(child: _metaItem('Condition', condition)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metaItem('Chiller Type', chillerType)),
              Expanded(child: _metaItem('Month Ach. Status', efficiency)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metaItem('Serial / Asset ID', serial)),
              Expanded(child: _metaItem('Assigned Rep', assignedRep)),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openGoogleMaps(lat, lng),
                icon: const Icon(Icons.navigation_rounded, size: 15, color: Colors.white),
                label: const Text('Directions', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4285F4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value.isEmpty ? '-' : value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInvoiceSection(Map<String, dynamic> summary) {
    final List<dynamic> months = (summary['months'] as List<dynamic>?) ?? [];
    final double ytd = _toDouble(summary['ytd'], 0.0);
    final double avg = _toDouble(summary['avgPerMonth'], 0.0);
    final double? deltaPct = summary['latestMonthDeltaPct'] != null ? _toDouble(summary['latestMonthDeltaPct']) : null;

    double maxAmt = 0.0;
    for (final m in months) {
      final a = _toDouble((m as Map)['amount'], 0.0);
      if (a > maxAmt) maxAmt = a;
    }

    int lastNonZeroIdx = -1;
    for (int i = months.length - 1; i >= 0; i--) {
      if (_toDouble((months[i] as Map)['amount'], 0.0) > 0) {
        lastNonZeroIdx = i;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Jan–Dec Invoice Trend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            _buildBadge('YTD: ${_formatNumber(ytd)}', const Color(0xFF06B6D4)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _statBox('YTD Total', _formatNumber(ytd), Colors.white)),
            const SizedBox(width: 8),
            Expanded(child: _statBox('Avg / Month', _formatNumber(avg), const Color(0xFF06B6D4))),
            const SizedBox(width: 8),
            Expanded(
              child: _statBox(
                'MoM Change',
                deltaPct == null ? 'N/A' : '${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%',
                deltaPct == null
                    ? Colors.white38
                    : deltaPct >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (maxAmt <= 0)
          Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Text(
              'No Jan–Dec invoice history available for this record.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          Container(
            height: 108,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(months.length, (i) {
                final m = months[i] as Map;
                final double amt = _toDouble(m['amount'], 0.0);
                final String label = (m['month'] ?? '').toString();
                final double ratio = maxAmt > 0 ? (amt / maxAmt) : 0.0;
                final bool isPeak = amt > 0 && amt == maxAmt;
                final bool isDrop = i == lastNonZeroIdx && deltaPct != null && deltaPct <= -20;

                final Color barColor = amt <= 0
                    ? Colors.white12
                    : isDrop
                        ? const Color(0xFFEF4444)
                        : isPeak
                            ? const Color(0xFF10B981)
                            : const Color(0xFF06B6D4);

                return Expanded(
                  child: Tooltip(
                    message: '$label: ${_formatNumber(amt)}',
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: math.max(4.0, ratio * 64.0),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label.isNotEmpty ? label.substring(0, 1) : '',
                          style: const TextStyle(color: Colors.white54, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildVisitHistorySection(List<dynamic> history) {
    final displayed = _showAllAudits ? history : history.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Recent Visit Audits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                _buildBadge('${history.length}', const Color(0xFF06B6D4)),
              ],
            ),
            if (history.length > 5)
              TextButton(
                onPressed: () => setState(() => _showAllAudits = !_showAllAudits),
                child: Text(_showAllAudits ? 'Show less' : 'Show all (${history.length})', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, color: Colors.white38, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No visit audits recorded yet. Tap 'Complete Visit' below to log the first audit.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        else
          ...displayed.map((item) {
            final audit = item as Map;
            final String st = (audit['status'] ?? 'submitted').toString();
            final Color dotColor = st == 'accepted'
                ? const Color(0xFF10B981)
                : st == 'reopened'
                    ? const Color(0xFFF97316)
                    : const Color(0xFF06B6D4);
            final String submittedAt = (audit['submittedAt'] ?? '').toString();
            final String shortDate = submittedAt.length >= 10 ? submittedAt.substring(0, 10) : submittedAt;
            final String feedback = (audit['adminFeedback'] ?? '').toString();
            final List<String> attachments = (audit['attachments'] is List)
                ? (audit['attachments'] as List).map((e) => e.toString()).where((u) => u.isNotEmpty).toList()
                : <String>[];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${audit['formTitle'] ?? 'Visit Audit'} • $shortDate',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ),
                      _buildBadge(st.toUpperCase(), dotColor),
                    ],
                  ),
                  if ((audit['agentName'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('By: ${audit['agentName']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                  if (attachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    AuditPhotoGallery(
                      columns: 3,
                      photos: attachments.map((url) => AuditPhotoItem(
                        url: url,
                        timestamp: submittedAt,
                        agentName: audit['agentName']?.toString(),
                        chillerCode: (widget.chiller['chillerCode'] ?? widget.chiller['chiller_code'])?.toString(),
                        latitude: (audit['agentLat'] as num?)?.toDouble(),
                        longitude: (audit['agentLng'] as num?)?.toDouble(),
                      )).toList(),
                    ),
                  ],
                  if (st == 'reopened' && feedback.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.6)),
                      ),
                      child: Text('Feedback: $feedback', style: const TextStyle(color: Color(0xFFF97316), fontSize: 11)),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
