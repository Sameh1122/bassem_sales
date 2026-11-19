import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class GeofenceCheckInPill extends StatelessWidget {
  final double? distanceMeters;
  final bool isLocating;
  final VoidCallback? onRetry;
  final bool showNonBlockingNote;

  const GeofenceCheckInPill({
    super.key,
    this.distanceMeters,
    this.isLocating = false,
    this.onRetry,
    this.showNonBlockingNote = false,
  });

  static double calculateDistanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadiusM = 6371000.0;
    double toRad(double deg) => deg * pi / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    Color fill;
    Color borderColor;
    Widget iconWidget;
    String label;
    Color textColor;
    String? tooltip;

    if (isLocating) {
      fill = t.accentPrimary.withValues(alpha: 0.12);
      borderColor = t.accentPrimary.withValues(alpha: 0.40);
      iconWidget = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: t.accentPrimary),
      );
      label = 'Checking GPS...';
      textColor = t.accentPrimary;
    } else if (distanceMeters == null) {
      fill = t.surfaceHeader;
      borderColor = t.borderSubtle;
      iconWidget = Icon(Icons.location_disabled_rounded, size: 14, color: t.textMuted);
      label = 'GPS Unavailable';
      textColor = t.textMuted;
    } else if (distanceMeters! <= 100) {
      fill = t.success.withValues(alpha: 0.14);
      borderColor = t.success.withValues(alpha: 0.50);
      iconWidget = Icon(Icons.verified_user_rounded, size: 14, color: t.success);
      label = 'Within 100m ✓';
      textColor = t.success;
      tooltip = 'Live GPS: ${distanceMeters!.round()}m from pin';
    } else {
      fill = t.caution.withValues(alpha: 0.14);
      borderColor = t.caution.withValues(alpha: 0.50);
      iconWidget = Icon(Icons.warning_amber_rounded, size: 14, color: t.caution);
      label = 'Outside Geofence — ${_formatDistance(distanceMeters!)}';
      textColor = t.caution;
    }

    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(t.radiusPill),
        border: Border.all(color: borderColor, width: t.borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor),
            ),
          ),
          if (!isLocating && distanceMeters == null && onRetry != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(t.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.accentPrimary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (tooltip != null) {
      pill = Tooltip(message: tooltip, child: pill);
    }

    final bool outsideGeofence = !isLocating && distanceMeters != null && distanceMeters! > 100;
    if (showNonBlockingNote && outsideGeofence) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          pill,
          const SizedBox(height: 6),
          Text(
            'You are ${distanceMeters!.round()}m from the registered chiller pin. You can still submit — distance is logged for supervisor review.',
            style: TextStyle(fontSize: 11.5, color: t.caution, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return pill;
  }
}
