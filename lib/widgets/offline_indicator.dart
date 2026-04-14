// --- Clean implementation of offline indicator widgets ---

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/connectivity_service.dart';
import '../services/auto_sync_service.dart';

/// Shows a banner at the top when offline
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isConnected()) {
        return const SizedBox.shrink();
      }
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.red.shade600,
        child: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '📴 Offline Mode - Changes will sync when online',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Shows sync status and pending queue
class SyncStatusIndicator extends StatelessWidget {
  final Color? backgroundColor;
  final bool showDetails;
  const SyncStatusIndicator({super.key, this.backgroundColor, this.showDetails = false});

  @override
  Widget build(BuildContext context) {
    final autoSync = Get.find<AutoSyncService>();
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isConnected() && autoSync.pendingCount.value == 0) {
        return const SizedBox.shrink();
      }
      final icon = connectivity.isConnected()
          ? (autoSync.isSyncing.value
              ? Icons.sync
              : (autoSync.pendingCount.value > 0 ? Icons.cloud_queue : Icons.cloud_done))
          : Icons.cloud_off;
      final color = connectivity.isConnected()
          ? (autoSync.pendingCount.value > 0 ? Colors.orange : Colors.green)
          : Colors.red;
      final text = connectivity.isConnected()
          ? (autoSync.isSyncing.value
              ? 'Syncing ${autoSync.syncProgress.value}%'
              : (autoSync.pendingCount.value > 0
                  ? '⏳ ${autoSync.pendingCount.value} pending'
                  : '✅ All synced'))
          : '📴 Offline';
      return GestureDetector(
        onTap: showDetails
            ? () => _showSyncDetails(context, autoSync)
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor ?? color.withOpacity(0.1),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showSyncDetails(BuildContext context, AutoSyncService syncService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📤 Sync Details'),
        content: Obx(() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Status', syncService.getSyncStatus()),
              const SizedBox(height: 8),
              _buildDetailRow('Pending', '${syncService.pendingCount.value} operations'),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Last Sync',
                syncService.lastSyncTime.value != null
                    ? _formatTime(syncService.lastSyncTime.value!)
                    : 'Never',
              ),
              if (syncService.isSyncing.value) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: syncService.syncProgress.value / 100,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!syncService.isSyncing.value)
            ElevatedButton(
              onPressed: () {
                syncService.forceSyncNow();
                Navigator.pop(context);
              },
              child: const Text('Sync Now'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Wraps a screen with an offline banner
class OfflineModeBanner extends StatelessWidget {
  final Widget child;
  final bool showDetails;
  const OfflineModeBanner({super.key, required this.child, this.showDetails = true});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      return Stack(
        children: [
          child,
          if (!connectivity.isConnected())
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.red.shade600,
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '📴 Offline - Using cached data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (showDetails)
                      GestureDetector(
                        onTap: () => _showOfflineInfo(context),
                        child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }

  void _showOfflineInfo(BuildContext context) {
    final offlineService = Get.find<AutoSyncService>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📴 Offline Mode Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You are currently offline. Here\'s what you can do:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              _buildInfoItem('✅ View', 'See cached notes, schedules, results, messages'),
              _buildInfoItem('📝 Create Drafts', 'Write messages & notes (will sync when online)'),
              _buildInfoItem('⏳ Auto Sync', 'Changes automatically sync when you\'re online'),
              _buildInfoItem('🔄 Manual Sync', 'Use the sync button to manually sync changes'),
              const Divider(height: 20),
              Obx(() {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusRow('Pending Changes', '${offlineService.pendingCount.value} items'),
                    _buildStatusRow('Last Synced', offlineService.lastSyncTime.value != null ? _formatTime(offlineService.lastSyncTime.value!) : 'Not yet'),
                  ],
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

/// Floating action button for sync status
class SyncFloatingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const SyncFloatingButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final autoSync = Get.find<AutoSyncService>();
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isConnected() && autoSync.pendingCount.value == 0) {
        return const SizedBox.shrink();
      }
      return FloatingActionButton(
        onPressed: () {
          onPressed?.call();
          if (connectivity.isConnected()) {
            autoSync.forceSyncNow();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🔄 Syncing...')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('📴 Still offline. Changes will sync when you\'re online.')),
            );
          }
        },
        backgroundColor: connectivity.isConnected()
            ? (autoSync.isSyncing.value ? Colors.orange : Colors.blue)
            : Colors.red,
        child: autoSync.isSyncing.value
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.cloud_upload),
      );
    });
  }
}
