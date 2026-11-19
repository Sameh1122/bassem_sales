import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Pulsing skeleton placeholder widget (1100ms shimmer loop) using [AppTokens].
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double? borderRadius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  const AppSkeleton.box({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  /// Skeleton pills matching the Rep KPI Summary Strip (`84x28` rounded pills).
  static Widget kpiStrip(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: 10),
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        border: Border(bottom: BorderSide(color: t.borderSubtle, width: t.borderWidth)),
      ),
      child: Wrap(
        spacing: t.spaceSm,
        runSpacing: t.spaceSm,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppSkeleton.box(width: 180, height: 20, borderRadius: t.radiusSm),
          Wrap(
            spacing: t.spaceSm,
            runSpacing: t.spaceSm,
            children: List.generate(
              4,
              (_) => AppSkeleton.box(width: 84, height: 28, borderRadius: t.radiusPill),
            ),
          ),
        ],
      ),
    );
  }

  /// Non-blocking top progress bar + floating skeleton indicator for Map View.
  static Widget mapLoadingOverlay(BuildContext context) {
    final t = AppTokens.of(context);
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            minHeight: 2.5,
            color: t.accentPrimary,
            backgroundColor: t.accentPrimary.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
              decoration: BoxDecoration(
                color: t.surfaceElevated.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(t.radiusPill),
                border: Border.all(color: t.accentPrimary.withValues(alpha: 0.45), width: t.borderWidth),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: t.accentPrimary),
                  ),
                  SizedBox(width: t.spaceSm),
                  Text('Loading map pins...', style: t.caption.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Structured 8-row skeleton preview for Data Table View.
  static Widget tableRows(BuildContext context, {int rowCount = 8}) {
    final t = AppTokens.of(context);
    const widths = [120.0, 80.0, 60.0, 120.0, 80.0, 60.0];
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radiusMd),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
            decoration: BoxDecoration(
              color: t.surfaceHeader,
              borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusMd)),
            ),
            child: Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t.spaceMd),
                    child: AppSkeleton.box(width: widths[i % widths.length], height: 12, borderRadius: t.radiusSm),
                  ),
                ),
              ),
            ),
          ),
          ...List.generate(rowCount, (rowIdx) {
            return Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: t.spaceLg),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.borderSubtle)),
              ),
              child: Row(
                children: List.generate(5, (colIdx) {
                  final w = widths[(rowIdx + colIdx) % widths.length];
                  return Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppSkeleton.box(width: w, height: 14, borderRadius: t.radiusSm),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Structured 5-card skeleton preview for list-based admin views.
  static Widget listCards(BuildContext context, {int count = 5}) {
    final t = AppTokens.of(context);
    return Column(
      children: List.generate(count, (idx) {
        return Container(
          height: 72,
          margin: EdgeInsets.only(bottom: t.spaceMd),
          padding: EdgeInsets.all(t.spaceLg),
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radiusMd),
            border: Border.all(color: t.borderSubtle, width: t.borderWidth),
          ),
          child: Row(
            children: [
              AppSkeleton.box(width: 40, height: 40, borderRadius: t.radiusSm),
              SizedBox(width: t.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSkeleton.box(width: 180, height: 14, borderRadius: t.radiusSm),
                    SizedBox(height: t.spaceSm),
                    AppSkeleton.box(width: 110, height: 10, borderRadius: t.radiusSm),
                  ],
                ),
              ),
              AppSkeleton.box(width: 72, height: 28, borderRadius: t.radiusPill),
            ],
          ),
        );
      }),
    );
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.42, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final radius = widget.borderRadius ?? t.radiusSm;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: t.isHighContrast
              ? t.borderSubtle.withValues(alpha: 0.35)
              : t.textMuted.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Standardized empty state card differentiating "No data uploaded" vs
/// "No records match current filters" with a 1-tap reset CTA.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? primaryLabel;
  final IconData? primaryIcon;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final Color? accentColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.primaryLabel,
    this.primaryIcon,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.accentColor,
  });

  /// Convenience factory for filtered empty states with a 1-tap Reset CTA.
  factory AppEmptyState.noFilterMatches({
    Key? key,
    String title = 'No records match your current filters',
    String subtitle = 'Try clearing your search query or resetting active filter chips.',
    required VoidCallback onResetFilters,
  }) {
    return AppEmptyState(
      key: key,
      icon: Icons.filter_alt_off_outlined,
      title: title,
      subtitle: subtitle,
      primaryLabel: 'Reset Filters',
      primaryIcon: Icons.restart_alt,
      onPrimaryPressed: onResetFilters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = accentColor ?? t.accentPrimary;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radiusLg),
            border: Border.all(color: t.borderSubtle, width: t.borderWidth),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(height: t.spaceLg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.sectionTitle,
              ),
              SizedBox(height: t.spaceSm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: t.bodyDefault.copyWith(color: t.textSecondary),
              ),
              if (primaryLabel != null && onPrimaryPressed != null) ...[
                SizedBox(height: t.spaceLg),
                ElevatedButton.icon(
                  onPressed: onPrimaryPressed,
                  icon: Icon(primaryIcon ?? Icons.refresh, size: 18),
                  label: Text(primaryLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceMd),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusMd)),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondaryPressed != null) ...[
                SizedBox(height: t.spaceSm),
                TextButton(
                  onPressed: onSecondaryPressed,
                  child: Text(secondaryLabel!, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum AppToastType {
  success,
  info,
  warning,
  error,
}

/// Unified floating toast/banner helper per DESIGN_NOTES.md §7.3.
class AppToast {
  static void show(
    BuildContext context, {
    required AppToastType type,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final t = AppTokens.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    late final Color accent;
    late final IconData icon;
    late final Duration duration;

    switch (type) {
      case AppToastType.success:
        accent = t.success;
        icon = Icons.check_circle;
        duration = const Duration(seconds: 3);
        break;
      case AppToastType.info:
        accent = t.accentPrimary;
        icon = Icons.info;
        duration = const Duration(seconds: 3);
        break;
      case AppToastType.warning:
        accent = t.caution;
        icon = Icons.warning_amber;
        duration = const Duration(seconds: 5);
        break;
      case AppToastType.error:
        accent = t.danger;
        icon = Icons.error;
        duration = const Duration(seconds: 5);
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: isDesktop ? 460 : null,
        margin: isDesktop ? null : const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        content: Container(
          decoration: BoxDecoration(
            color: t.surfaceElevated,
            borderRadius: BorderRadius.circular(t.radiusMd),
            border: Border.all(color: t.borderSubtle),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsetsDirectional.fromSTEB(t.spaceMd, t.spaceMd, t.spaceSm, t.spaceMd),
            decoration: BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: accent, width: 4)),
            ),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 20),
                SizedBox(width: t.spaceMd),
                Expanded(
                  child: Text(
                    message,
                    style: t.bodyDefault.copyWith(color: t.textPrimary, fontSize: 13),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      onAction();
                    },
                    child: Text(
                      actionLabel,
                      style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                Semantics(
                  button: true,
                  label: 'Dismiss notification',
                  child: IconButton(
                    icon: Icon(Icons.close, size: 16, color: t.textMuted),
                    tooltip: 'Dismiss',
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    onPressed: () => messenger.hideCurrentSnackBar(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
