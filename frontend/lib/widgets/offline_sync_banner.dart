import 'package:flutter/material.dart';
import '../services/offline_sync_service.dart';
import '../theme/app_tokens.dart';
import 'app_feedback.dart';

class OfflineSyncBanner extends StatelessWidget {
  final bool isCompactMobile;
  final VoidCallback? onSyncCompleted;

  const OfflineSyncBanner({
    super.key,
    this.isCompactMobile = false,
    this.onSyncCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final sync = OfflineSyncService.instance;

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final count = sync.queuedCount;
        final failed = sync.failedCount;
        final isOnline = sync.isOnline;
        final isSyncing = sync.isSyncing;
        final justSynced = sync.justSyncedSuccess;

        if (isOnline && count == 0 && !isSyncing && !justSynced) {
          return const SizedBox.shrink();
        }

        Color fill;
        Color borderColor;
        Color? startAccent;
        Widget icon;
        String copy;
        Widget? trailingAction;

        if (isSyncing) {
          fill = t.surfaceElevated;
          borderColor = t.accentPrimary.withValues(alpha: 0.40);
          icon = SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.accentPrimary),
          );
          final curr = sync.syncProgressCurrent + 1;
          final total = sync.syncProgressTotal > 0 ? sync.syncProgressTotal : count;
          copy = 'Syncing audit $curr of $total...';
          trailingAction = TextButton(
            onPressed: null,
            child: Text('Syncing...', style: t.caption.copyWith(color: t.textMuted)),
          );
        } else if (justSynced && count == 0) {
          fill = t.success.withValues(alpha: 0.14);
          borderColor = t.success.withValues(alpha: 0.45);
          icon = Icon(Icons.cloud_done_rounded, size: 16, color: t.success);
          copy = 'Online · All audits synced';
        } else if (failed > 0) {
          fill = t.danger.withValues(alpha: 0.14);
          borderColor = t.danger.withValues(alpha: 0.55);
          icon = Icon(Icons.sync_problem_rounded, size: 16, color: t.danger);
          copy = 'Sync paused — $failed audit(s) need attention';
          trailingAction = OutlinedButton(
            onPressed: () => OutboxQueueSheet.show(context, onSyncCompleted: onSyncCompleted),
            style: OutlinedButton.styleFrom(
              foregroundColor: t.danger,
              side: BorderSide(color: t.danger.withValues(alpha: 0.65)),
              minimumSize: const Size(44, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('Resolve / Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          );
        } else if (!isOnline && count == 0) {
          fill = t.surfaceElevated;
          borderColor = t.borderSubtle;
          startAccent = t.caution;
          icon = Icon(Icons.cloud_off_rounded, size: 16, color: t.caution);
          copy = 'Offline — Visits will save to device queue';
        } else if (!isOnline && count > 0) {
          fill = t.caution.withValues(alpha: 0.14);
          borderColor = t.caution.withValues(alpha: 0.50);
          icon = Icon(Icons.cloud_off_rounded, size: 16, color: t.caution);
          copy = 'Offline — $count queued audit(s)';
          trailingAction = TextButton(
            onPressed: () => OutboxQueueSheet.show(context, onSyncCompleted: onSyncCompleted),
            style: TextButton.styleFrom(
              foregroundColor: t.caution,
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('View Queue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          );
        } else {
          // Online with queued items ready
          fill = t.accentPrimary.withValues(alpha: 0.14);
          borderColor = t.accentPrimary.withValues(alpha: 0.50);
          icon = Icon(Icons.cloud_upload_outlined, size: 16, color: t.accentPrimary);
          copy = 'Online — $count queued audit(s) ready';
          trailingAction = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => OutboxQueueSheet.show(context, onSyncCompleted: onSyncCompleted),
                style: TextButton.styleFrom(
                  foregroundColor: t.textPrimary,
                  minimumSize: const Size(44, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: () async {
                  final res = await sync.syncNow();
                  if (res['succeededCount'] != null && (res['succeededCount'] as int) > 0) {
                    onSyncCompleted?.call();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: t.accentPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          );
        }

        return Semantics(
          liveRegion: true,
          label: copy,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: isCompactMobile ? 40 : 38),
            decoration: BoxDecoration(
              color: fill,
              border: BorderDirectional(
                top: BorderSide(color: borderColor, width: 1),
                bottom: BorderSide(color: borderColor, width: 1),
                start: startAccent != null ? BorderSide(color: startAccent, width: 3) : BorderSide.none,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: t.spaceMd, vertical: 4),
                  child: Row(
                    children: [
                      icon,
                      SizedBox(width: t.spaceSm),
                      Expanded(
                        child: Text(
                          copy,
                          style: t.caption.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (trailingAction != null) ...[
                        SizedBox(width: t.spaceSm),
                        trailingAction,
                      ],
                    ],
                  ),
                ),
                if (isSyncing)
                  LinearProgressIndicator(
                    minHeight: 2,
                    color: t.accentPrimary,
                    backgroundColor: t.accentPrimary.withValues(alpha: 0.15),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class OutboxQueueSheet extends StatelessWidget {
  final VoidCallback? onSyncCompleted;

  const OutboxQueueSheet({super.key, this.onSyncCompleted});

  static Future<void> show(BuildContext context, {VoidCallback? onSyncCompleted}) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: AppTokens.of(context).surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: SizedBox(
            width: 520,
            height: 540,
            child: OutboxQueueSheet(onSyncCompleted: onSyncCompleted),
          ),
        ),
      );
    }
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.90,
        minChildSize: 0.40,
        builder: (_, __) => OutboxQueueSheet(onSyncCompleted: onSyncCompleted),
      ),
    );
  }

  String _formatTimestamp(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final sync = OfflineSyncService.instance;

    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final items = sync.queue;
        return Column(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(t.spaceLg, t.spaceMd, t.spaceSm, t.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Offline Outbox Queue (${items.length})',
                      style: t.sectionTitle,
                    ),
                  ),
                  if (items.isNotEmpty)
                    FilledButton.icon(
                      onPressed: (!sync.isOnline || sync.isSyncing)
                          ? null
                          : () async {
                              final res = await sync.syncNow();
                              if (res['succeededCount'] != null && (res['succeededCount'] as int) > 0) {
                                onSyncCompleted?.call();
                              }
                            },
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync All'),
                      style: FilledButton.styleFrom(
                        backgroundColor: t.accentPrimary,
                        minimumSize: const Size(44, 38),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: t.borderSubtle),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.cloud_done_outlined,
                        title: 'Outbox is empty',
                        subtitle: 'All field audits are synced with the server.',
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(t.spaceLg),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: t.spaceSm),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _buildItemCard(context, t, sync, item);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(BuildContext context, AppTokens t, OfflineSyncService sync, OutboxItem item) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (item.status) {
      case OutboxItemStatus.syncing:
        statusColor = t.accentPrimary;
        statusIcon = Icons.sync_rounded;
        statusLabel = 'Syncing';
        break;
      case OutboxItemStatus.retryNeeded:
        statusColor = t.warning;
        statusIcon = Icons.refresh_rounded;
        statusLabel = 'Retry Needed';
        break;
      case OutboxItemStatus.conflict:
        statusColor = t.danger;
        statusIcon = Icons.warning_amber_rounded;
        statusLabel = 'Conflict';
        break;
      case OutboxItemStatus.queued:
      default:
        statusColor = t.caution;
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Queued';
        break;
    }

    return Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customerName.isNotEmpty ? item.customerName : 'Chiller Condition Update',
                      style: t.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        item.chillerCode.isNotEmpty ? item.chillerCode : item.type,
                        style: t.caption.copyWith(color: t.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(t.radiusPill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: t.spaceSm),
          Wrap(
            spacing: t.spaceMd,
            runSpacing: 4,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _formatTimestamp(item.clientTimestamp),
                  style: t.caption.copyWith(color: t.textMuted),
                ),
              ),
              if (item.attachmentCount > 0)
                Text(
                  '${item.attachmentCount} photo${item.attachmentCount == 1 ? '' : 's'}',
                  style: t.caption.copyWith(color: t.textSecondary),
                ),
              if (item.geofenceVerified != null)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    item.geofenceVerified == true
                        ? 'Within 100m ✓'
                        : '${item.checkInDistanceM ?? '?'}m away',
                    style: t.caption.copyWith(
                      color: item.geofenceVerified == true ? t.success : t.caution,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
            SizedBox(height: t.spaceXs),
            Text(
              item.errorMessage!,
              style: t.caption.copyWith(color: t.danger),
            ),
          ],
          if (item.status == OutboxItemStatus.retryNeeded || item.status == OutboxItemStatus.conflict) ...[
            SizedBox(height: t.spaceSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _confirmDiscard(context, sync, item),
                  style: TextButton.styleFrom(
                    foregroundColor: t.danger,
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(item.status == OutboxItemStatus.conflict ? 'Discard Local' : 'Discard'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await sync.retryItem(item.id);
                    onSyncCompleted?.call();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accentPrimary,
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(item.status == OutboxItemStatus.conflict ? 'Keep Mine (Resubmit)' : 'Retry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context, OfflineSyncService sync, OutboxItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Queued Audit?'),
        content: Text('Remove "${item.customerName}" (${item.chillerCode}) from the local outbox? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTokens.of(ctx).danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sync.discardItem(item.id);
    }
  }
}
