import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/url_launcher.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_feedback.dart';
import '../widgets/dashboard_widgets.dart';
import 'customer_360_drawer.dart';
import 'form_filler_dialog.dart';

class DashboardViewScreen extends StatefulWidget {
  final void Function({String? branchFilter, bool routeMode})? onOpenMap;
  final VoidCallback? onOpenTable;
  final VoidCallback? onOpenUpload;
  final VoidCallback? onOpenAssign;
  final VoidCallback? onOpenResponses;

  const DashboardViewScreen({
    super.key,
    this.onOpenMap,
    this.onOpenTable,
    this.onOpenUpload,
    this.onOpenAssign,
    this.onOpenResponses,
  });

  @override
  State<DashboardViewScreen> createState() => DashboardViewScreenState();
}

class DashboardViewScreenState extends State<DashboardViewScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMsg;
  DateTime? _lastSynced;

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _chillers = [];
  List<Map<String, dynamic>> _pendingResponses = [];

  // Interactive UI state
  String? _selectedBranch;
  int _branchMetricMode = 0; // 0 = YTD Ach %, 1 = Visit Rate %
  int _healthMode = 0; // 0 = Condition, 1 = Efficiency
  int _watchlistMode = 0; // 0 = At-Risk, 1 = Top Performing
  String _agentFilter = 'All'; // All, Re-opened, Maintenance, Unvisited
  String _techFilter = 'All'; // All, Scrap, Requires Maintenance

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> reload({bool showSpinner = false}) async {
    await _loadDashboard(showSpinner: showSpinner);
  }

  Future<void> _loadDashboard({bool showSpinner = false}) async {
    if (!mounted) return;
    setState(() {
      if (_stats == null || showSpinner) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _errorMsg = null;
    });

    try {
      final statsFuture = ApiService.fetchDashboardStats(branch: _selectedBranch);
      final chillersFuture = ApiService.fetchChillers().catchError((_) => <dynamic>[]);
      final responsesFuture = (ApiService.isSupervisor || ApiService.isAdmin)
          ? ApiService.fetchFormResponses(status: 'submitted').catchError((_) => <Map<String, dynamic>>[])
          : Future.value(<Map<String, dynamic>>[]);

      final results = await Future.wait([statsFuture, chillersFuture, responsesFuture]);
      if (!mounted) return;

      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _chillers = (results[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _pendingResponses = List<Map<String, dynamic>>.from(results[2] as List);
        _lastSynced = DateTime.now();
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  String _greetingText() {
    final hour = DateTime.now().hour;
    final user = ApiService.currentUser ?? {};
    final fullName = (user['name'] ?? user['username'] ?? 'Team').toString().trim();
    final firstName = fullName.split(RegExp(r'\s+')).first;
    if (hour < 12) return 'Good morning, $firstName';
    if (hour < 17) return 'Good afternoon, $firstName';
    return 'Good evening, $firstName';
  }

  String _roleEyebrow() {
    if (ApiService.isOwner) return 'EXECUTIVE OVERVIEW';
    if (ApiService.isRegionalManager) return 'REGIONAL COMMAND';
    if (ApiService.isAdmin) return 'OPERATIONS COMMAND';
    if (ApiService.isSupervisor) return 'BRANCH SUPERVISOR';
    if (ApiService.isTechnician) return 'MAINTENANCE QUEUE';
    return 'MY FIELD DAY';
  }

  String _formatSyncLabel() {
    if (_lastSynced == null) return 'Syncing...';
    final diff = DateTime.now().difference(_lastSynced!);
    if (diff.inSeconds < 60) return 'Updated just now';
    return 'Updated ${diff.inMinutes}m ago';
  }

  String _formatCompactCurrency(num val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: t.canvasBg,
      child: Column(
        children: [
          if (_isRefreshing)
            LinearProgressIndicator(
              minHeight: 2,
              color: t.accentPrimary,
              backgroundColor: t.accentPrimary.withValues(alpha: 0.15),
            ),
          Expanded(
            child: RefreshIndicator(
              color: t.accentPrimary,
              onRefresh: () => _loadDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: isMobile ? t.spaceLg : t.spaceXl,
                  vertical: t.spaceLg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildGreetingHeader(t, isMobile),
                        if (_errorMsg != null) ...[
                          SizedBox(height: t.spaceLg),
                          _buildErrorBanner(t),
                        ],
                        SizedBox(height: t.spaceXl),
                        if (_isLoading && _stats == null)
                          _buildLoadingSkeleton(t, isMobile)
                        else if (_stats == null)
                          AppEmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Dashboard unavailable',
                            subtitle: _errorMsg ?? 'Could not load dashboard metrics.',
                            primaryLabel: 'Retry',
                            onPrimaryPressed: () => _loadDashboard(showSpinner: true),
                          )
                        else
                          _buildRoleBody(t, isMobile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingHeader(AppTokens t, bool isMobile) {
    final user = ApiService.currentUser ?? {};
    final branch = user['branch']?.toString();
    final area = user['agentArea']?.toString();
    final contextParts = <String>[
      if (_selectedBranch != null) 'Filter: $_selectedBranch'
      else if (branch != null && branch.isNotEmpty) 'Branch: $branch'
      else if (area != null && area.isNotEmpty) area,
      _formatSyncLabel(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_roleEyebrow(), style: t.eyebrow),
              SizedBox(height: t.spaceXs),
              Text(_greetingText(), style: t.displayTitle),
              SizedBox(height: t.spaceXs),
              Text(contextParts.join(' • '), style: t.caption),
            ],
          ),
        ),
        if (_selectedBranch != null) ...[
          ActionChip(
            label: Text('Branch: $_selectedBranch', style: t.caption.copyWith(color: t.accentPrimary)),
            avatar: Icon(Icons.close, size: 14, color: t.accentPrimary),
            backgroundColor: t.accentPrimary.withValues(alpha: 0.12),
            side: BorderSide(color: t.accentPrimary.withValues(alpha: 0.4)),
            onPressed: () {
              setState(() => _selectedBranch = null);
              _loadDashboard();
            },
          ),
          SizedBox(width: t.spaceSm),
        ],
        Semantics(
          button: true,
          label: 'Refresh dashboard',
          child: IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Refresh Dashboard',
            icon: Icon(Icons.refresh_rounded, color: t.textSecondary),
            onPressed: _isRefreshing ? null : () => _loadDashboard(),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(AppTokens t) {
    return Container(
      padding: EdgeInsets.all(t.spaceMd),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: BorderDirectional(
          start: BorderSide(color: t.danger, width: 4),
          top: BorderSide(color: t.danger.withValues(alpha: 0.3)),
          end: BorderSide(color: t.danger.withValues(alpha: 0.3)),
          bottom: BorderSide(color: t.danger.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: t.danger, size: 20),
          SizedBox(width: t.spaceMd),
          Expanded(
            child: Text(_errorMsg!, style: t.bodyDefault),
          ),
          TextButton(
            onPressed: () => _loadDashboard(showSpinner: true),
            child: Text('Retry', style: TextStyle(color: t.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton(AppTokens t, bool isMobile) {
    return Column(
      children: [
        GridView.count(
          crossAxisCount: isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: t.spaceLg,
          mainAxisSpacing: t.spaceLg,
          childAspectRatio: isMobile ? 1.35 : 1.7,
          children: List.generate(
            4,
            (_) => AppSkeleton.box(height: 110, borderRadius: t.radiusLg),
          ),
        ),
        SizedBox(height: t.spaceXl),
        AppSkeleton.box(height: 240, borderRadius: t.radiusLg),
        SizedBox(height: t.spaceLg),
        AppSkeleton.box(height: 220, borderRadius: t.radiusLg),
      ],
    );
  }

  Widget _buildRoleBody(AppTokens t, bool isMobile) {
    final kpis = Map<String, dynamic>.from(_stats?['kpis'] ?? {});
    final int totalAssets = (kpis['totalAssets'] as num?)?.toInt() ?? 0;

    if (totalAssets == 0) {
      return AppEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No chillers in your scope yet',
        subtitle: ApiService.isAdmin
            ? 'Upload your Master Excel dataset to populate fleet analytics and maps.'
            : 'No chillers are currently assigned to your scope. Contact your administrator.',
        primaryLabel: ApiService.isAdmin && widget.onOpenUpload != null ? 'Upload Master Excel' : null,
        onPrimaryPressed: ApiService.isAdmin ? widget.onOpenUpload : null,
      );
    }

    if (ApiService.isTechnician) {
      return _buildTechnicianWorkspace(t, isMobile);
    }
    if (ApiService.isAgent) {
      return _buildAgentWorkspace(t, isMobile);
    }
    if (ApiService.isSupervisor) {
      return _buildSupervisorWorkspace(t, isMobile);
    }
    return _buildExecutiveWorkspace(t, isMobile);
  }

  // ===========================================================================
  // ROLE 1: OWNER / REGIONAL MANAGER / ADMIN COMMAND CENTER
  // ===========================================================================

  Widget _buildExecutiveWorkspace(AppTokens t, bool isMobile) {
    final kpis = Map<String, dynamic>.from(_stats?['kpis'] ?? {});
    final int totalAssets = (kpis['totalAssets'] as num?)?.toInt() ?? 0;
    final int visitedCount = (kpis['visitedCount'] as num?)?.toInt() ?? 0;
    final double completionRate = (kpis['completionRate'] as num?)?.toDouble() ?? 0.0;
    final double avgAch = (kpis['avgAchievement'] as num?)?.toDouble() ?? 0.0;
    final num ytdTotal = (kpis['ytdInvoiceTotal'] as num?) ?? 0;
    final int maintAlerts = ((kpis['requiresMaintenance'] as num?)?.toInt() ?? 0) +
        ((kpis['scrapCount'] as num?)?.toInt() ?? 0);

    final branches = List<Map<String, dynamic>>.from(
      (_stats?['branchLeaderboard'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    final Color achColor = avgAch >= 85 ? t.success : (avgAch >= 65 ? t.caution : t.danger);
    final double width = MediaQuery.of(context).size.width;
    final int kpiCols = width >= 1100 ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: kpiCols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: isMobile ? t.spaceMd : t.spaceLg,
          mainAxisSpacing: isMobile ? t.spaceMd : t.spaceLg,
          childAspectRatio: isMobile ? 1.25 : 1.65,
          children: [
            HeroKpiCard(
              label: 'Total Assets',
              value: '$totalAssets',
              subtitle: 'Across ${branches.length} branches',
              badgeText: 'YTD ${_formatCompactCurrency(ytdTotal)}',
              badgeColor: t.accentPrimary,
              icon: Icons.ac_unit_rounded,
              accent: t.accentPrimary,
              onTap: widget.onOpenTable,
            ),
            HeroKpiCard(
              label: 'YTD Achievement',
              value: '${avgAch.toStringAsFixed(1)}%',
              subtitle: 'Fleet mean',
              badgeText: avgAch >= 85 ? 'On Target' : (avgAch >= 65 ? 'Near Target' : 'Below Target'),
              badgeColor: achColor,
              icon: Icons.trending_up_rounded,
              accent: t.achievement,
            ),
            HeroKpiCard(
              label: 'Active Visit Rate',
              value: '${completionRate.toStringAsFixed(1)}%',
              subtitle: '$visitedCount of $totalAssets visited',
              icon: Icons.verified_outlined,
              accent: t.success,
              onTap: () => widget.onOpenMap?.call(branchFilter: _selectedBranch),
            ),
            HeroKpiCard(
              label: 'Maint. Alerts',
              value: '$maintAlerts',
              subtitle: 'Maint. + Scrap',
              badgeText: maintAlerts > 0 ? 'Needs Action' : 'Healthy',
              badgeColor: maintAlerts > 0 ? t.danger : t.success,
              icon: Icons.build_circle_outlined,
              accent: maintAlerts > 0 ? t.warning : t.success,
              onTap: () => widget.onOpenMap?.call(branchFilter: _selectedBranch),
            ),
          ],
        ),
        SizedBox(height: t.spaceXl),
        if (width >= 900)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: _buildBranchPerformanceCard(t, branches)),
              SizedBox(width: t.spaceLg),
              Expanded(flex: 5, child: _buildFleetHealthCard(t, totalAssets)),
            ],
          )
        else ...[
          _buildBranchPerformanceCard(t, branches),
          SizedBox(height: t.spaceLg),
          _buildFleetHealthCard(t, totalAssets),
        ],
        SizedBox(height: t.spaceXl),
        _buildChillerWatchlistCard(t),
      ],
    );
  }

  Widget _buildBranchPerformanceCard(AppTokens t, List<Map<String, dynamic>> branches) {
    final sorted = [...branches];
    if (_branchMetricMode == 1) {
      sorted.sort((a, b) => ((b['completionRate'] as num?) ?? 0).compareTo((a['completionRate'] as num?) ?? 0));
    }
    final topBranches = sorted.take(8).toList();
    final items = topBranches.map((b) {
      final name = (b['branch'] ?? 'Unassigned').toString();
      final val = _branchMetricMode == 0
          ? ((b['avgAchievement'] as num?)?.toDouble() ?? 0.0)
          : ((b['completionRate'] as num?)?.toDouble() ?? 0.0);
      return MiniBarItem(
        label: name,
        value: val,
        valueLabel: '${val.toStringAsFixed(1)}%',
        tooltipText: '$name • ${b['totalAssets']} chillers • ${val.toStringAsFixed(1)}%',
      );
    }).toList();

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: t.spaceSm,
            runSpacing: t.spaceSm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Branch Performance', style: t.sectionTitle),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('YTD Ach %')),
                  ButtonSegment(value: 1, label: Text('Visit Rate %')),
                ],
                selected: {_branchMetricMode},
                onSelectionChanged: (sel) => setState(() => _branchMetricMode = sel.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(t.caption),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),
          MiniBarChart(
            items: items,
            selectedLabel: _selectedBranch,
            onSelect: (branchName) {
              setState(() {
                _selectedBranch = _selectedBranch == branchName ? null : branchName;
              });
              _loadDashboard();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFleetHealthCard(AppTokens t, int totalAssets) {
    final cond = Map<String, dynamic>.from(_stats?['conditionBreakdown'] ?? {});
    final eff = Map<String, dynamic>.from(_stats?['efficiencyBuckets'] ?? {});

    final List<DonutSegment> segments = _healthMode == 0
        ? [
            DonutSegment(label: 'Operational', count: (cond['operational'] as num?)?.toInt() ?? 0, color: t.success),
            DonutSegment(label: 'Requires Maint.', count: (cond['requiresMaintenance'] as num?)?.toInt() ?? 0, color: t.warning),
            DonutSegment(label: 'Scrap', count: (cond['scrap'] as num?)?.toInt() ?? 0, color: t.danger),
          ]
        : [
            DonutSegment(label: 'Performing', count: (eff['performing'] as num?)?.toInt() ?? 0, color: t.success),
            DonutSegment(label: 'Underperforming', count: (eff['underperforming'] as num?)?.toInt() ?? 0, color: t.warning),
            DonutSegment(label: 'Critical', count: (eff['critical'] as num?)?.toInt() ?? 0, color: t.danger),
            DonutSegment(label: 'Other / N/A', count: (eff['other'] as num?)?.toInt() ?? 0, color: t.textMuted),
          ];

    final segTotal = segments.fold<int>(0, (s, e) => s + e.count);

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: t.spaceSm,
            runSpacing: t.spaceSm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Fleet Health Breakdown', style: t.sectionTitle),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Condition')),
                  ButtonSegment(value: 1, label: Text('Efficiency')),
                ],
                selected: {_healthMode},
                onSelectionChanged: (sel) => setState(() => _healthMode = sel.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(t.caption),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: DonutChartPainter(
                    segments: segments,
                    emptyTrackColor: t.borderSubtle,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('$totalAssets', style: t.sectionTitle),
                        ),
                        Text('Assets', style: t.caption),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: t.spaceLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((s) {
                    final pct = segTotal > 0 ? (s.count / segTotal * 100).toStringAsFixed(0) : '0';
                    return Padding(
                      padding: EdgeInsets.only(bottom: t.spaceSm),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                          ),
                          SizedBox(width: t.spaceSm),
                          Expanded(child: Text(s.label, style: t.bodyDefault, overflow: TextOverflow.ellipsis)),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('${s.count} ($pct%)', style: t.metricNum.copyWith(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(t.radiusPill),
            child: SizedBox(
              height: 8,
              child: Row(
                children: segments.where((s) => s.count > 0).map((s) {
                  return Expanded(
                    flex: s.count,
                    child: Tooltip(
                      message: '${s.label}: ${s.count}',
                      child: Container(color: s.color),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChillerWatchlistCard(AppTokens t) {
    List<Map<String, dynamic>> filtered = [..._chillers];
    if (_selectedBranch != null) {
      filtered = filtered.where((c) => (c['branch'] ?? '').toString().toLowerCase() == _selectedBranch!.toLowerCase()).toList();
    }

    if (_watchlistMode == 0) {
      filtered = filtered.where((c) {
        final cond = (c['condition'] ?? '').toString().toLowerCase();
        final eff = (c['efficiency'] ?? '').toString().toLowerCase();
        return cond.contains('maint') || cond.contains('scrap') || eff.contains('critical') || eff.contains('under') || eff == 'zero';
      }).toList();
    } else {
      filtered = filtered.where((c) {
        final cond = (c['condition'] ?? 'Operational').toString().toLowerCase();
        final eff = (c['efficiency'] ?? '').toString().toLowerCase();
        return !cond.contains('maint') && !cond.contains('scrap') && eff.contains('performing') && !eff.contains('non') && !eff.contains('under');
      }).toList();
    }

    final displayList = filtered.take(5).toList();

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: t.spaceSm,
            runSpacing: t.spaceSm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Chiller Watchlist', style: t.sectionTitle),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('At-Risk')),
                  ButtonSegment(value: 1, label: Text('Top Performing')),
                ],
                selected: {_watchlistMode},
                onSelectionChanged: (sel) => setState(() => _watchlistMode = sel.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(t.caption),
                ),
              ),
            ],
          ),
          SizedBox(height: t.spaceMd),
          if (displayList.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.spaceLg),
              child: Text('No chillers match this watchlist filter.', style: t.caption),
            )
          else
            ...displayList.map((c) {
              final cond = (c['condition'] ?? 'Operational').toString();
              final eff = (c['efficiency'] ?? 'N/A').toString();
              final isCrit = cond.toLowerCase().contains('scrap') || eff.toLowerCase().contains('critical');
              final badgeColor = _watchlistMode == 1 ? t.success : (isCrit ? t.danger : t.warning);

              return Container(
                margin: EdgeInsets.only(bottom: t.spaceSm),
                padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceSm),
                decoration: BoxDecoration(
                  color: t.canvasBg,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                    ),
                    SizedBox(width: t.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (c['customerName'] ?? 'Unknown Customer').toString(),
                            style: t.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${c['chillerCode'] ?? ''} • ${c['branch'] ?? 'Unassigned'}',
                              style: t.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(t.radiusPill),
                      ),
                      child: Text(
                        _watchlistMode == 0 ? (cond.toLowerCase().contains('maint') || cond.toLowerCase().contains('scrap') ? cond : eff) : eff,
                        style: t.caption.copyWith(color: badgeColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(width: t.spaceSm),
                    TextButton(
                      onPressed: () => showCustomer360Drawer(context, chiller: c, onAuditSubmitted: _loadDashboard),
                      child: Text('360° →', style: TextStyle(color: t.accentPrimary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ===========================================================================
  // ROLE 2: SUPERVISOR REVIEW & TEAM HUB
  // ===========================================================================

  Widget _buildSupervisorWorkspace(AppTokens t, bool isMobile) {
    final kpis = Map<String, dynamic>.from(_stats?['kpis'] ?? {});
    final int totalAssets = (kpis['totalAssets'] as num?)?.toInt() ?? 0;
    final double completionRate = (kpis['completionRate'] as num?)?.toDouble() ?? 0.0;
    final int pendingReviews = (_stats?['pendingReviewsCount'] as num?)?.toInt() ?? _pendingResponses.length;
    final int maintAlerts = ((kpis['requiresMaintenance'] as num?)?.toInt() ?? 0) +
        ((kpis['scrapCount'] as num?)?.toInt() ?? 0);

    final agents = List<Map<String, dynamic>>.from(
      (_stats?['agentLeaderboard'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    )..sort((a, b) => ((a['completionRate'] as num?) ?? 0).compareTo((b['completionRate'] as num?) ?? 0));

    final double width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: width >= 1100 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: isMobile ? t.spaceMd : t.spaceLg,
          mainAxisSpacing: isMobile ? t.spaceMd : t.spaceLg,
          childAspectRatio: isMobile ? 1.25 : 1.65,
          children: [
            HeroKpiCard(
              label: 'Branch Assets',
              value: '$totalAssets',
              icon: Icons.ac_unit_rounded,
              accent: t.accentPrimary,
              onTap: widget.onOpenTable,
            ),
            HeroKpiCard(
              label: 'Visit Rate',
              value: '${completionRate.toStringAsFixed(1)}%',
              subtitle: '${kpis['visitedCount'] ?? 0} visited',
              icon: Icons.verified_outlined,
              accent: t.success,
              onTap: () => widget.onOpenMap?.call(),
            ),
            HeroKpiCard(
              label: 'Pending Reviews',
              value: '$pendingReviews',
              badgeText: pendingReviews > 0 ? 'Needs Sign-off' : 'All Clear',
              badgeColor: pendingReviews > 0 ? t.warning : t.success,
              icon: Icons.rate_review_outlined,
              accent: t.warning,
              onTap: widget.onOpenResponses,
            ),
            HeroKpiCard(
              label: 'Maint. Alerts',
              value: '$maintAlerts',
              icon: Icons.build_circle_outlined,
              accent: maintAlerts > 0 ? t.danger : t.success,
            ),
          ],
        ),
        SizedBox(height: t.spaceXl),
        if (width >= 900)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildPendingReviewsCard(t)),
              SizedBox(width: t.spaceLg),
              Expanded(child: _buildTeamProgressCard(t, agents)),
            ],
          )
        else ...[
          _buildPendingReviewsCard(t),
          SizedBox(height: t.spaceLg),
          _buildTeamProgressCard(t, agents),
        ],
      ],
    );
  }

  Widget _buildPendingReviewsCard(AppTokens t) {
    final queue = _pendingResponses.take(6).toList();
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Pending Audit Reviews', style: t.sectionTitle),
                  SizedBox(width: t.spaceSm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (queue.isEmpty ? t.success : t.warning).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(t.radiusPill),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${_pendingResponses.length}',
                        style: t.caption.copyWith(
                          color: queue.isEmpty ? t.success : t.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onOpenResponses != null)
                TextButton(
                  onPressed: widget.onOpenResponses,
                  child: Text('View All', style: TextStyle(color: t.accentPrimary)),
                ),
            ],
          ),
          SizedBox(height: t.spaceMd),
          if (queue.isEmpty)
            Container(
              padding: EdgeInsets.all(t.spaceLg),
              decoration: BoxDecoration(
                color: t.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(t.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: t.success),
                  SizedBox(width: t.spaceMd),
                  Expanded(
                    child: Text('All caught up! No pending reviews in your team.', style: t.bodyDefault),
                  ),
                ],
              ),
            )
          else
            ...queue.map((resp) {
              final respId = resp['id'];
              return Container(
                margin: EdgeInsets.only(bottom: t.spaceMd),
                padding: EdgeInsets.all(t.spaceMd),
                decoration: BoxDecoration(
                  color: t.canvasBg,
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (resp['customer_name'] ?? 'Customer').toString(),
                            style: t.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text((resp['chiller_code'] ?? '').toString(), style: t.caption),
                        ),
                      ],
                    ),
                    SizedBox(height: t.spaceXs),
                    Text(
                      'Rep: ${resp['agent_name'] ?? 'Agent'} • ${resp['form_title'] ?? 'Audit'}',
                      style: t.caption,
                    ),
                    SizedBox(height: t.spaceMd),
                    Wrap(
                      spacing: t.spaceSm,
                      runSpacing: t.spaceSm,
                      children: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('Approve'),
                          onPressed: () async {
                            try {
                              await ApiService.reviewFormResponse(
                                responseId: respId is int ? respId : int.parse(respId.toString()),
                                status: 'accepted',
                              );
                              if (!mounted) return;
                              AppToast.show(context, type: AppToastType.success, message: 'Audit approved');
                              _loadDashboard();
                            } catch (e) {
                              if (!mounted) return;
                              AppToast.show(context, type: AppToastType.error, message: e.toString().replaceFirst('Exception: ', ''));
                            }
                          },
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.warning,
                            side: BorderSide(color: t.warning),
                            minimumSize: const Size(0, 40),
                          ),
                          icon: const Icon(Icons.flag_outlined, size: 16),
                          label: const Text('Flag'),
                          onPressed: () => _showFlagReasonDialog(respId),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showFlagReasonDialog(dynamic responseId) async {
    final t = AppTokens.of(context);
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surfaceElevated,
        title: Text('Flag Audit for Correction', style: t.sectionTitle),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: t.bodyDefault,
          decoration: const InputDecoration(
            hintText: 'What needs correction?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Re-open'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.reviewFormResponse(
          responseId: responseId is int ? responseId : int.parse(responseId.toString()),
          status: 'reopened',
          adminFeedback: ctrl.text.trim(),
        );
        if (!mounted) return;
        AppToast.show(context, type: AppToastType.warning, message: 'Audit flagged and re-opened');
        _loadDashboard();
      } catch (e) {
        if (!mounted) return;
        AppToast.show(context, type: AppToastType.error, message: e.toString().replaceFirst('Exception: ', ''));
      }
    }
    ctrl.dispose();
  }

  Widget _buildTeamProgressCard(AppTokens t, List<Map<String, dynamic>> agents) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Rep Progress', style: t.sectionTitle),
          SizedBox(height: t.spaceXs),
          Text('Current Cycle Coverage', style: t.caption),
          SizedBox(height: t.spaceLg),
          if (agents.isEmpty)
            Text('No supervised agents configured.', style: t.caption)
          else
            ...agents.map((a) {
              final name = (a['agentName'] ?? 'Agent').toString();
              final visited = (a['visitedCount'] as num?)?.toInt() ?? 0;
              final assigned = (a['assignedCount'] as num?)?.toInt() ?? 0;
              final pct = (a['completionRate'] as num?)?.toDouble() ?? 0.0;
              final ach = (a['avgAchievement'] as num?)?.toDouble() ?? 0.0;
              final barColor = pct >= 80 ? t.success : (pct >= 40 ? t.accentPrimary : t.warning);

              return Padding(
                padding: EdgeInsets.only(bottom: t.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: t.accentPrimary.withValues(alpha: 0.16),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: t.caption.copyWith(color: t.accentPrimary, fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(width: t.spaceSm),
                        Expanded(child: Text(name, style: t.cardTitle, overflow: TextOverflow.ellipsis)),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('$visited / $assigned (${pct.toStringAsFixed(0)}%)', style: t.metricNum.copyWith(fontSize: 12.5)),
                        ),
                      ],
                    ),
                    SizedBox(height: t.spaceSm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(t.radiusPill),
                      child: LinearProgressIndicator(
                        value: (pct / 100).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: t.borderSubtle,
                        color: barColor,
                      ),
                    ),
                    SizedBox(height: t.spaceXs),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text('Avg Ach: ${ach.toStringAsFixed(1)}%', style: t.caption),
                    ),
                  ],
                ),
              );
            }),
          if (widget.onOpenAssign != null) ...[
            SizedBox(height: t.spaceSm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.accentPrimary,
                  side: BorderSide(color: t.accentPrimary),
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Rebalance Territories'),
                onPressed: widget.onOpenAssign,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ROLE 3: FIELD SALES REP ("MY DAY")
  // ===========================================================================

  Widget _buildAgentWorkspace(AppTokens t, bool isMobile) {
    final kpis = Map<String, dynamic>.from(_stats?['kpis'] ?? {});
    final int assigned = (kpis['totalAssets'] as num?)?.toInt() ?? 0;
    final int visited = (kpis['visitedCount'] as num?)?.toInt() ?? 0;
    final int pending = (kpis['pendingCount'] as num?)?.toInt() ?? 0;
    final double rate = (kpis['completionRate'] as num?)?.toDouble() ?? 0.0;

    final prioritized = _prioritizeAgentStops(_chillers);
    final nextStop = prioritized.isNotEmpty ? prioritized.first : null;
    final filtered = prioritized.where((c) {
      final status = (c['visitStatus'] ?? 'not_visited').toString().toLowerCase();
      final cond = (c['condition'] ?? '').toString().toLowerCase();
      if (_agentFilter == 'Re-opened') return status == 'reopened';
      if (_agentFilter == 'Maintenance') return cond.contains('maint') || cond.contains('scrap');
      if (_agentFilter == 'Unvisited') return status == 'not_visited';
      return true;
    }).take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardCard(
          topAccentColor: t.accentPrimary,
          child: Wrap(
            spacing: t.spaceXl,
            runSpacing: t.spaceLg,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TODAY\'S PROGRESS', style: t.eyebrow),
                  SizedBox(height: t.spaceMd),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _statPill('Assigned', '$assigned', t.accentPrimary, t),
                      SizedBox(width: t.spaceMd),
                      _statPill('Visited', '$visited', t.success, t),
                      SizedBox(width: t.spaceMd),
                      _statPill('Pending', '$pending', t.warning, t),
                    ],
                  ),
                ],
              ),
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: ProgressRingPainter(
                    progress: rate / 100.0,
                    trackColor: t.borderSubtle,
                    activeColor: t.success,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text('${rate.toStringAsFixed(0)}%', style: t.sectionTitle),
                        ),
                        Text('Done', style: t.caption),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nextStop != null)
                    Container(
                      width: isMobile ? double.infinity : 280,
                      padding: EdgeInsets.all(t.spaceMd),
                      margin: EdgeInsets.only(bottom: t.spaceMd),
                      decoration: BoxDecoration(
                        color: t.canvasBg,
                        borderRadius: BorderRadius.circular(t.radiusMd),
                        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NEXT PRIORITY STOP', style: t.eyebrow),
                          SizedBox(height: t.spaceXs),
                          Text(
                            (nextStop['customerName'] ?? 'Customer').toString(),
                            style: t.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              '${nextStop['chillerCode'] ?? ''} • ${nextStop['condition'] ?? 'Operational'}',
                              style: t.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: t.spaceSm,
                    runSpacing: t.spaceSm,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.accentPrimary,
                          minimumSize: const Size(0, 48),
                        ),
                        icon: const Icon(Icons.route_rounded),
                        label: const Text('Start Route'),
                        onPressed: () => widget.onOpenMap?.call(routeMode: true),
                      ),
                      if (nextStop != null)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: t.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('Log Visit'),
                          onPressed: () => _openFormFiller(nextStop),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: t.spaceXl),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: t.spaceSm,
                runSpacing: t.spaceSm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Priority Stops', style: t.sectionTitle),
                  Wrap(
                    spacing: t.spaceXs,
                    children: ['All', 'Re-opened', 'Maintenance', 'Unvisited'].map((f) {
                      final selected = _agentFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        onSelected: (_) => setState(() => _agentFilter = f),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: t.spaceMd),
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: t.spaceLg),
                  child: Text('No stops match this filter.', style: t.caption),
                )
              else
                ...filtered.map((c) {
                  final status = (c['visitStatus'] ?? 'not_visited').toString().toLowerCase();
                  final cond = (c['condition'] ?? 'Operational').toString();
                  final isReopened = status == 'reopened';
                  final isMaint = cond.toLowerCase().contains('maint') || cond.toLowerCase().contains('scrap');
                  final accent = isReopened ? t.warning : (isMaint ? t.danger : t.accentPrimary);

                  return Container(
                    margin: EdgeInsets.only(bottom: t.spaceSm),
                    decoration: BoxDecoration(
                      color: t.canvasBg,
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      border: BorderDirectional(
                        start: BorderSide(color: accent, width: 4),
                        top: BorderSide(color: t.borderSubtle),
                        end: BorderSide(color: t.borderSubtle),
                        bottom: BorderSide(color: t.borderSubtle),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => showCustomer360Drawer(context, chiller: c, onAuditSubmitted: _loadDashboard),
                      title: Text((c['customerName'] ?? 'Customer').toString(), style: t.cardTitle),
                      subtitle: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${c['chillerCode'] ?? ''} • ${isReopened ? 'Re-opened: ${c['adminFeedback'] ?? 'Check feedback'}' : cond}',
                          style: t.caption.copyWith(color: isReopened ? t.warning : t.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            tooltip: 'Log Visit',
                            icon: Icon(Icons.edit_note_rounded, color: t.success),
                            onPressed: () => _openFormFiller(c),
                          ),
                          if (c['latitude'] != null && c['longitude'] != null)
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              tooltip: 'Navigate',
                              icon: Icon(Icons.navigation_rounded, color: t.accentPrimary),
                              onPressed: () => openExternalUrl(
                                'https://www.google.com/maps/dir/?api=1&destination=${c['latitude']},${c['longitude']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _prioritizeAgentStops(List<Map<String, dynamic>> items) {
    final copy = [...items];
    int score(Map<String, dynamic> c) {
      final status = (c['visitStatus'] ?? 'not_visited').toString().toLowerCase();
      final cond = (c['condition'] ?? '').toString().toLowerCase();
      if (status == 'reopened') return 0;
      if (cond.contains('scrap') || cond.contains('maint')) return 1;
      if (status == 'not_visited') return 2;
      return 3;
    }

    copy.sort((a, b) => score(a).compareTo(score(b)));
    return copy;
  }

  void _openFormFiller(Map<String, dynamic> chiller) {
    showDialog(
      context: context,
      builder: (_) => FormFillerDialog(
        chiller: chiller,
        onSubmitted: () => _loadDashboard(),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color, AppTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(value, style: t.displayTitle.copyWith(color: color)),
        ),
        Text(label, style: t.caption),
      ],
    );
  }

  // ===========================================================================
  // ROLE 4: TECHNICIAN MAINTENANCE QUEUE
  // ===========================================================================

  Widget _buildTechnicianWorkspace(AppTokens t, bool isMobile) {
    final kpis = Map<String, dynamic>.from(_stats?['kpis'] ?? {});
    final int scrapCount = (kpis['scrapCount'] as num?)?.toInt() ?? 0;
    final int reqMaint = (kpis['requiresMaintenance'] as num?)?.toInt() ?? 0;
    final int activeOp = (kpis['activeOperational'] as num?)?.toInt() ?? 0;
    final int totalAssets = (kpis['totalAssets'] as num?)?.toInt() ?? 0;
    final double opPct = totalAssets > 0 ? (activeOp / totalAssets * 100) : 100.0;

    final queue = List<Map<String, dynamic>>.from(
      (_stats?['maintenanceQueue'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    final filtered = queue.where((item) {
      final cond = (item['condition'] ?? '').toString();
      if (_techFilter == 'Scrap') return cond == 'Scrap';
      if (_techFilter == 'Requires Maintenance') return cond == 'Requires Maintenance';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: isMobile ? 2 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: t.spaceLg,
          mainAxisSpacing: t.spaceLg,
          childAspectRatio: isMobile ? 1.3 : 1.85,
          children: [
            HeroKpiCard(
              label: 'Critical / Scrap',
              value: '$scrapCount',
              icon: Icons.dangerous_outlined,
              accent: t.danger,
            ),
            HeroKpiCard(
              label: 'Requires Maintenance',
              value: '$reqMaint',
              icon: Icons.build_circle_outlined,
              accent: t.warning,
            ),
            HeroKpiCard(
              label: 'Fleet Operational',
              value: '${opPct.toStringAsFixed(1)}%',
              subtitle: '$activeOp of $totalAssets OK',
              icon: Icons.check_circle_outline,
              accent: t.success,
            ),
          ],
        ),
        SizedBox(height: t.spaceXl),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: t.spaceSm,
                runSpacing: t.spaceSm,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Maintenance & Scrap Work Queue', style: t.sectionTitle),
                  Wrap(
                    spacing: t.spaceXs,
                    children: ['All', 'Scrap', 'Requires Maintenance'].map((f) {
                      return ChoiceChip(
                        label: Text(f == 'All' ? 'All Open (${queue.length})' : f),
                        selected: _techFilter == f,
                        onSelected: (_) => setState(() => _techFilter = f),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              if (filtered.isEmpty)
                Container(
                  padding: EdgeInsets.all(t.spaceLg),
                  decoration: BoxDecoration(
                    color: t.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: t.success),
                      SizedBox(width: t.spaceMd),
                      Expanded(
                        child: Text('All caught up! No chillers require maintenance in this filter.', style: t.bodyDefault),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map((item) {
                  final cond = (item['condition'] ?? 'Requires Maintenance').toString();
                  final isScrap = cond == 'Scrap';
                  final urgencyColor = isScrap ? t.danger : t.warning;
                  final lat = item['latitude'];
                  final lng = item['longitude'];

                  return Container(
                    margin: EdgeInsets.only(bottom: t.spaceMd),
                    padding: EdgeInsets.all(t.spaceMd),
                    decoration: BoxDecoration(
                      color: t.canvasBg,
                      borderRadius: BorderRadius.circular(t.radiusMd),
                      border: BorderDirectional(
                        start: BorderSide(color: urgencyColor, width: 4),
                        top: BorderSide(color: t.borderSubtle),
                        end: BorderSide(color: t.borderSubtle),
                        bottom: BorderSide(color: t.borderSubtle),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (item['customerName'] ?? 'Customer').toString(),
                                style: t.cardTitle,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: urgencyColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(t.radiusPill),
                              ),
                              child: Text(
                                cond,
                                style: t.caption.copyWith(color: urgencyColor, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: t.spaceXs),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${item['chillerCode'] ?? ''} • ${item['branch'] ?? 'Unassigned'}',
                            style: t.caption,
                          ),
                        ),
                        if ((item['customerAddress'] ?? '').toString().isNotEmpty) ...[
                          SizedBox(height: t.spaceXs),
                          Text(item['customerAddress'].toString(), style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                        SizedBox(height: t.spaceMd),
                        Wrap(
                          spacing: t.spaceSm,
                          runSpacing: t.spaceSm,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: t.success,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(Icons.build_rounded, size: 18),
                              label: const Text('Mark Operational / Log Repair'),
                              onPressed: () => _showRepairLogDialog(item),
                            ),
                            if (lat != null && lng != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: t.accentPrimary,
                                  side: BorderSide(color: t.accentPrimary),
                                  minimumSize: const Size(0, 44),
                                ),
                                icon: const Icon(Icons.directions_rounded, size: 18),
                                label: const Text('Navigate'),
                                onPressed: () => openExternalUrl(
                                  'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
                                ),
                              ),
                            IconButton(
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              tooltip: 'Customer 360°',
                              icon: Icon(Icons.info_outline_rounded, color: t.textSecondary),
                              onPressed: () => showCustomer360Drawer(context, chiller: item, onAuditSubmitted: _loadDashboard),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showRepairLogDialog(Map<String, dynamic> item) async {
    final t = AppTokens.of(context);
    String selectedCondition = 'Operational';
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          backgroundColor: t.surfaceElevated,
          title: Text('Log Repair / Update Condition', style: t.sectionTitle),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('${item['chillerCode'] ?? ''} — ${item['customerName'] ?? ''}', style: t.caption),
                ),
                SizedBox(height: t.spaceMd),
                DropdownButtonFormField<String>(
                  initialValue: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'New Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Operational', child: Text('Operational')),
                    DropdownMenuItem(value: 'Requires Maintenance', child: Text('Requires Maintenance')),
                    DropdownMenuItem(value: 'Scrap', child: Text('Scrap')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedCondition = v);
                  },
                ),
                SizedBox(height: t.spaceMd),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: t.bodyDefault,
                  decoration: const InputDecoration(
                    labelText: 'Repair Notes (Optional)',
                    hintText: 'Compressor serviced, thermostat calibrated...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: t.success, foregroundColor: Colors.white),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        final idOrCode = item['id'] ?? item['chillerCode'];
                        await ApiService.updateChillerCondition(
                          idOrCode,
                          selectedCondition,
                          notes: notesCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          type: AppToastType.success,
                          message: 'Condition updated to $selectedCondition',
                        );
                        _loadDashboard();
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        AppToast.show(
                          context,
                          type: AppToastType.error,
                          message: e.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Update'),
            ),
          ],
        ),
      ),
    );
    notesCtrl.dispose();
  }
}
