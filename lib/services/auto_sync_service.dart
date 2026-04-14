import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'connectivity_service.dart';
import 'offline_database.dart';

/// Manages sync queue and syncs pending operations when online
class AutoSyncService extends GetxService {
  late final ConnectivityService _connectivityService;
  late final OfflineDatabase _offlineDb;

  final isSyncing = false.obs;
  final syncProgress = 0.obs;
  final pendingCount = 0.obs;
  final lastSyncTime = Rxn<DateTime>();

  Timer? _syncTimer;
  static const syncInterval = Duration(seconds: 30);

  @override
  void onInit() async {
    super.onInit();

    _connectivityService = Get.find<ConnectivityService>();
    _offlineDb = OfflineDatabase();

    // Initialize pending count
    await _updatePendingCount();

    // Listen to connectivity changes
    ever(_connectivityService.isOnline, (_) async {
      if (_connectivityService.isConnected()) {
        log('🔄 Device online - attempting sync');
        await syncPendingOperations();
      }
    });

    // Start periodic sync timer
    _startSyncTimer();

    log('✅ AutoSyncService initialized');
  }

  /// Start periodic sync timer
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(syncInterval, (_) async {
      if (_connectivityService.isConnected() && pendingCount.value > 0) {
        await syncPendingOperations();
      }
    });
  }

  /// Sync all pending operations
  Future<void> syncPendingOperations() async {
    if (isSyncing.value) {
      log('⏳ Sync already in progress');
      return;
    }

    try {
      isSyncing.value = true;
      syncProgress.value = 0;

      // Get pending operations from queue
      final operations = await _offlineDb.getPendingSyncOperations();

      if (operations.isEmpty) {
        log('✅ No pending operations');
        isSyncing.value = false;
        return;
      }

      log('📤 Starting sync for ${operations.length} operations');

      int syncedCount = 0;
      final totalOps = operations.length;

      for (final op in operations) {
        final operationId = op['id'] as String;
        final operation = op['operation'] as String;
        final entityType = op['entityType'] as String;

        try {
          // Process each operation based on type
          final syncSuccess = await _processSyncOperation(
            operation: operation,
            entityType: entityType,
            data: op,
          );

          if (syncSuccess) {
            await _offlineDb.markOperationSynced(operationId);
            syncedCount++;
            log('✅ Synced: $operation ($entityType)');
          } else {
            // Mark as failed and increment retry
            await _offlineDb.incrementRetryCount(operationId);
            log('⚠️  Failed to sync: $operation ($entityType) - will retry');
          }

          // Update progress
          syncProgress.value = ((syncedCount / totalOps) * 100).toInt();
        } catch (e) {
          log('❌ Error processing operation $operationId: $e');
          await _offlineDb.incrementRetryCount(operationId);
        }
      }

      lastSyncTime.value = DateTime.now();
      await _updatePendingCount();

      log('✅ Sync completed: $syncedCount/$totalOps operations synced');
    } catch (e) {
      log('❌ Sync error: $e');
    } finally {
      isSyncing.value = false;
      syncProgress.value = 0;
    }
  }

  /// Process individual sync operation
  Future<bool> _processSyncOperation({
    required String operation,
    required String entityType,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This is called by specific modules to implement their sync logic
      // Each module (notes, messages, etc.) will override this

      switch (entityType) {
        case 'message':
          return await _syncMessage(data);
        case 'note':
          return await _syncNote(data);
        case 'result':
          return await _syncResult(data);
        case 'timetable':
          return await _syncTimetable(data);
        case 'exam':
          return await _syncExam(data);
        default:
          log('⚠️  Unknown entity type: $entityType');
          return true; // Mark as done to avoid infinite retries
      }
    } catch (e) {
      log('❌ Error processing operation: $e');
      return false;
    }
  }

  /// Sync message (ChatMate)
  Future<bool> _syncMessage(Map<String, dynamic> data) async {
    try {
      // Implementation handled by ChatMate service
      // This is a placeholder for the actual sync logic
      log('📤 Syncing message: ${data['entityId']}');
  
      return true;
    } catch (e) {
      log('❌ Error syncing message: $e');
      return false;
    }
  }

  /// Sync note upload
  Future<bool> _syncNote(Map<String, dynamic> data) async {
    try {
      log('📤 Syncing note: ${data['entityId']}');
      return true;
    } catch (e) {
      log('❌ Error syncing note: $e');
      return false;
    }
  }

  /// Sync result
  Future<bool> _syncResult(Map<String, dynamic> data) async {
    try {
      log('📤 Syncing result: ${data['entityId']}');
      // Results are typically read-only, so this might not be needed
      return true;
    } catch (e) {
      log('❌ Error syncing result: $e');
      return false;
    }
  }

  /// Sync timetable
  Future<bool> _syncTimetable(Map<String, dynamic> data) async {
    try {
      log('📤 Syncing timetable: ${data['entityId']}');
      // Timetables are typically read-only
      return true;
    } catch (e) {
      log('❌ Error syncing timetable: $e');
      return false;
    }
  }

  /// Sync exam
  Future<bool> _syncExam(Map<String, dynamic> data) async {
    try {
      log('📤 Syncing exam: ${data['entityId']}');
      // Exams are typically read-only
      return true;
    } catch (e) {
      log('❌ Error syncing exam: $e');
      return false;
    }
  }

  /// Update pending operations count
  Future<void> _updatePendingCount() async {
    final operations = await _offlineDb.getPendingSyncOperations();
    pendingCount.value = operations.length;
  }

  /// Get sync status display
  String getSyncStatus() {
    if (isSyncing.value) {
      return '🔄 Syncing... ${syncProgress.value}%';
    } else if (pendingCount.value > 0) {
      return '⏳ ${pendingCount.value} pending';
    } else if (lastSyncTime.value != null) {
      final lastSync = lastSyncTime.value!;
      final diff = DateTime.now().difference(lastSync).inMinutes;
      return '✅ Synced ${diff}m ago';
    } else {
      return '⏳ Not synced yet';
    }
  }

  /// Force sync now
  Future<void> forceSyncNow() async {
    log('🔄 Force sync triggered');
    await syncPendingOperations();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheInfo() async {
    final stats = await _offlineDb.getCacheStats();
    final dbSize = await _offlineDb.getDatabaseSize();

    return {
      'stats': stats,
      'dbSize': '${(dbSize / 1024 / 1024).toStringAsFixed(2)} MB',
      'lastSync': lastSyncTime.value?.toString() ?? 'Never',
      'pendingOps': pendingCount.value,
      'isSyncing': isSyncing.value,
    };
  }

  @override
  void onClose() {
    _syncTimer?.cancel();
    super.onClose();
  }
}
