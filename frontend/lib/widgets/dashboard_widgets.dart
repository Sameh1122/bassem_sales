import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Shared elevated card container built 100% on [AppTokens].
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? topAccentColor;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.topAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isLight = !t.isHighContrast && Theme.of(context).brightness == Brightness.light;
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final effectivePadding = padding ?? EdgeInsets.all(isMobile ? t.spaceLg : 20);

    Widget content = Padding(
      padding: effectivePadding,
      child: child,
    );

    if (topAccentColor != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: topAccentColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusLg)),
            ),
          ),
          content,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceElevated,
        borderRadius: BorderRadius.circular(t.radiusLg),
        border: Border.all(color: t.borderSubtle, width: t.borderWidth),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(t.radiusLg),
              child: InkWell(
                borderRadius: BorderRadius.circular(t.radiusLg),
                onTap: onTap,
                child: content,
              ),
            )
          : content,
    );
  }
}

/// Executive / operational KPI card with tabular figures and optional tap drill-down.
class HeroKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const HeroKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
    this.badgeText,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final effectiveBadgeColor = badgeColor ?? accent;

    return Semantics(
      button: onTap != null,
      label: '$label: $value${subtitle != null ? ', $subtitle' : ''}',
      child: DashboardCard(
        padding: EdgeInsets.all(t.spaceLg),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: t.eyebrow.copyWith(color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: t.spaceSm),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(t.radiusSm),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
              ],
            ),
            SizedBox(height: t.spaceMd),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: t.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: t.spaceSm),
            Wrap(
              spacing: t.spaceSm,
              runSpacing: t.spaceXs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (badgeText != null && badgeText!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: effectiveBadgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(t.radiusPill),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        badgeText!,
                        style: t.caption.copyWith(
                          color: effectiveBadgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: t.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Smooth rounded-cap progress ring painter.
class ProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color activeColor;
  final double strokeWidth;

  const ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.activeColor,
    this.strokeWidth = 9.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    if (clamped > 0) {
      final sweepAngle = 2 * math.pi * clamped;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Data item for [MiniBarChart].
class MiniBarItem {
  final String label;
  final double value; // 0-100
  final String valueLabel;
  final String? tooltipText;

  const MiniBarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.tooltipText,
  });
}

/// Pure Flutter horizontal bar chart with threshold coloring and interactive selection.
class MiniBarChart extends StatelessWidget {
  final List<MiniBarItem> items;
  final String? selectedLabel;
  final ValueChanged<String>? onSelect;

  const MiniBarChart({
    super.key,
    required this.items,
    this.selectedLabel,
    this.onSelect,
  });

  Color _colorForValue(double v, AppTokens t) {
    if (v >= 85) return t.success;
    if (v >= 65) return t.accentPrimary;
    return t.warning;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: t.spaceXl),
        child: Center(
          child: Text('No branch performance data available', style: t.caption),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        final isSelected = selectedLabel != null &&
            selectedLabel!.toLowerCase() == item.label.toLowerCase();
        final barColor = _colorForValue(item.value, t);
        final fraction = (item.value / 100.0).clamp(0.0, 1.0);

        return Padding(
          padding: EdgeInsets.only(bottom: t.spaceSm),
          child: Tooltip(
            message: item.tooltipText ?? '${item.label}: ${item.valueLabel}',
            child: Semantics(
              button: onSelect != null,
              label: '${item.label}: ${item.valueLabel}',
              child: InkWell(
                borderRadius: BorderRadius.circular(t.radiusSm),
                onTap: onSelect != null ? () => onSelect!(item.label) : null,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: t.spaceSm, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? t.accentPrimary.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    border: isSelected
                        ? Border.all(color: t.accentPrimary, width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          item.label,
                          style: t.bodyDefault.copyWith(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: t.spaceSm),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(t.radiusSm),
                          child: Container(
                            height: 12,
                            color: t.borderSubtle.withValues(alpha: 0.4),
                            alignment: AlignmentDirectional.centerStart,
                            child: FractionallySizedBox(
                              widthFactor: fraction,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(t.radiusSm),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: t.spaceMd),
                      SizedBox(
                        width: 54,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            item.valueLabel,
                            textAlign: TextAlign.end,
                            style: t.metricNum.copyWith(
                              fontSize: 12.5,
                              color: barColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Segment descriptor for [DonutChartPainter].
class DonutSegment {
  final String label;
  final int count;
  final Color color;

  const DonutSegment({
    required this.label,
    required this.count,
    required this.color,
  });
}

/// Pure Flutter donut chart painter.
class DonutChartPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final Color emptyTrackColor;
  final double strokeWidth;

  const DonutChartPainter({
    required this.segments,
    required this.emptyTrackColor,
    this.strokeWidth = 18.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final total = segments.fold<int>(0, (sum, s) => sum + s.count);
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (total <= 0) {
      final trackPaint = Paint()
        ..color = emptyTrackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, trackPaint);
      return;
    }

    double startAngle = -math.pi / 2;
    const gapRadians = 0.04;
    final nonZero = segments.where((s) => s.count > 0).toList();
    final totalGap = nonZero.length > 1 ? gapRadians * nonZero.length : 0.0;
    final availableSweep = math.max(0.0, (2 * math.pi) - totalGap);

    for (final seg in nonZero) {
      final sweep = availableSweep * (seg.count / total);
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + (nonZero.length > 1 ? gapRadians : 0.0);
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.emptyTrackColor != emptyTrackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
