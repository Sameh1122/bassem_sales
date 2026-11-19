import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/url_launcher.dart';
import '../theme/app_tokens.dart';
import 'app_feedback.dart';

class AuditPhotoItem {
  final String url;
  final String? timestamp;
  final String? agentName;
  final String? chillerCode;
  final String? condition;
  final double? latitude;
  final double? longitude;
  final int? checkInDistanceM;
  final bool? geofenceVerified;

  const AuditPhotoItem({
    required this.url,
    this.timestamp,
    this.agentName,
    this.chillerCode,
    this.condition,
    this.latitude,
    this.longitude,
    this.checkInDistanceM,
    this.geofenceVerified,
  });

  bool get isGpsVerified => latitude != null && longitude != null;

  factory AuditPhotoItem.fromAttachment(
    dynamic raw, {
    String? fallbackTimestamp,
    String? fallbackAgentName,
    String? fallbackChillerCode,
    String? fallbackCondition,
    double? fallbackLat,
    double? fallbackLng,
    int? checkInDistanceM,
    bool? geofenceVerified,
  }) {
    if (raw is Map) {
      final wm = raw['watermark'] is Map ? Map<String, dynamic>.from(raw['watermark'] as Map) : const <String, dynamic>{};
      final latVal = wm['lat'] is num ? (wm['lat'] as num).toDouble() : fallbackLat;
      final lngVal = wm['lng'] is num ? (wm['lng'] as num).toDouble() : fallbackLng;
      return AuditPhotoItem(
        url: (raw['url'] ?? '').toString(),
        timestamp: (wm['capturedAt'] ?? fallbackTimestamp)?.toString(),
        agentName: (wm['agentName'] ?? fallbackAgentName)?.toString(),
        chillerCode: (wm['chillerCode'] ?? fallbackChillerCode)?.toString(),
        condition: fallbackCondition,
        latitude: latVal,
        longitude: lngVal,
        checkInDistanceM: checkInDistanceM,
        geofenceVerified: geofenceVerified,
      );
    }
    return AuditPhotoItem(
      url: raw.toString(),
      timestamp: fallbackTimestamp,
      agentName: fallbackAgentName,
      chillerCode: fallbackChillerCode,
      condition: fallbackCondition,
      latitude: fallbackLat,
      longitude: fallbackLng,
      checkInDistanceM: checkInDistanceM,
      geofenceVerified: geofenceVerified,
    );
  }
}

/// Reusable 3- or 4-column thumbnail grid + zoomable (1x-4x) Lightbox modal.
class AuditPhotoGallery extends StatelessWidget {
  final List<AuditPhotoItem> photos;
  final int columns;

  const AuditPhotoGallery({
    super.key,
    required this.photos,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    if (photos.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: t.spaceSm,
        mainAxisSpacing: t.spaceSm,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final photo = photos[index];
        final shortDate = (photo.timestamp != null && photo.timestamp!.length >= 10)
            ? photo.timestamp!.substring(0, 10)
            : (photo.timestamp ?? '');

        return Semantics(
          button: true,
          label: 'View audit photo ${index + 1} of ${photos.length}',
          child: InkWell(
            borderRadius: BorderRadius.circular(t.radiusSm),
            onTap: () => showAuditPhotoLightbox(context, photos: photos, initialIndex: index),
            child: Container(
              constraints: const BoxConstraints(minWidth: 80, minHeight: 80),
              decoration: BoxDecoration(
                color: t.canvasBg,
                borderRadius: BorderRadius.circular(t.radiusSm),
                border: Border.all(color: t.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photo.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return AppSkeleton.box(borderRadius: t.radiusSm);
                    },
                    errorBuilder: (context, _, __) => Container(
                      color: t.surfaceElevated,
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, color: t.textMuted, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            'Image unavailable',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: t.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Top-start overlay badge: Photo N/M + GPS Verified dot
                  PositionedDirectional(
                    top: 4,
                    start: 4,
                    end: 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Photo ${index + 1}/${photos.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Tooltip(
                          message: photo.isGpsVerified ? 'GPS Verified' : 'GPS Unverified',
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: photo.isGpsVerified ? t.success : t.caution,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.82),
                          ],
                        ),
                      ),
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              [
                                if ((photo.chillerCode ?? '').isNotEmpty) photo.chillerCode!,
                                if (shortDate.isNotEmpty) shortDate,
                              ].join(' · '),
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              photo.isGpsVerified
                                  ? '📍 ${photo.latitude!.toStringAsFixed(4)}, ${photo.longitude!.toStringAsFixed(4)}'
                                  : '📍 GPS Unverified',
                              style: TextStyle(
                                color: photo.isGpsVerified ? Colors.white70 : t.caution,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showAuditPhotoLightbox(
  BuildContext context, {
  required List<AuditPhotoItem> photos,
  int initialIndex = 0,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _AuditPhotoLightbox(photos: photos, initialIndex: initialIndex),
  );
}

class _AuditPhotoLightbox extends StatefulWidget {
  final List<AuditPhotoItem> photos;
  final int initialIndex;

  const _AuditPhotoLightbox({
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<_AuditPhotoLightbox> createState() => _AuditPhotoLightboxState();
}

class _AuditPhotoLightboxState extends State<_AuditPhotoLightbox> {
  late final PageController _pageController;
  late final FocusNode _focusNode;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.photos.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final photo = widget.photos[_currentIndex];

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _goTo(_currentIndex - 1);
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _goTo(_currentIndex + 1);
        }
      },
      child: Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Photo ${_currentIndex + 1} of ${widget.photos.length}  ·  Pinch or scroll to zoom (1x–4x)',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Download photo',
                          child: IconButton(
                            icon: const Icon(Icons.download, color: Colors.white),
                            tooltip: 'Download',
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            onPressed: () => openExternalUrl(photo.url),
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Close photo lightbox',
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 26),
                            tooltip: 'Close (Esc)',
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Zoomable PageView
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.photos.length,
                      onPageChanged: (idx) => setState(() => _currentIndex = idx),
                      itemBuilder: (context, idx) {
                        final item = widget.photos[idx];
                        return InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Center(
                            child: Image.network(
                              item.url,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const CircularProgressIndicator(color: Color(0xFF06B6D4));
                              },
                              errorBuilder: (context, _, __) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image_outlined, color: t.textMuted, size: 48),
                                  const SizedBox(height: 8),
                                  const Text('Image unavailable', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_currentIndex > 0)
                      PositionedDirectional(
                        start: 12,
                        child: Semantics(
                          button: true,
                          label: 'Previous photo',
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              onPressed: () => _goTo(_currentIndex - 1),
                            ),
                          ),
                        ),
                      ),
                    if (_currentIndex < widget.photos.length - 1)
                      PositionedDirectional(
                        end: 12,
                        child: Semantics(
                          button: true,
                          label: 'Next photo',
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                              onPressed: () => _goTo(_currentIndex + 1),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Watermark Metadata Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if ((photo.chillerCode ?? '').isNotEmpty)
                                  Text(
                                    photo.chillerCode!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                if ((photo.condition ?? '').isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(photo.condition!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  ),
                                if (photo.geofenceVerified != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (photo.geofenceVerified! ? t.success : t.caution).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(t.radiusPill),
                                      border: Border.all(color: (photo.geofenceVerified! ? t.success : t.caution).withValues(alpha: 0.6)),
                                    ),
                                    child: Text(
                                      photo.geofenceVerified!
                                          ? 'Within 100m ✓'
                                          : '${photo.checkInDistanceM ?? '?'}m away',
                                      style: TextStyle(
                                        color: photo.geofenceVerified! ? t.success : t.caution,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '🕒 ${photo.timestamp ?? 'Unknown time'}  ·  👤 ${photo.agentName ?? 'Field Rep'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              photo.isGpsVerified
                                  ? '📍 ${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}'
                                  : '📍 GPS coordinates not captured',
                              style: TextStyle(
                                color: photo.isGpsVerified ? t.accentPrimary : t.caution,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (photo.isGpsVerified)
                      Semantics(
                        button: true,
                        label: 'Open in Maps',
                        child: IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                          tooltip: 'Open in Maps',
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          onPressed: () => openExternalUrl(
                            'https://www.google.com/maps/search/?api=1&query=${photo.latitude},${photo.longitude}',
                          ),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => openExternalUrl(photo.url),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accentPrimary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(44, 40),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
