import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Manages app connectivity state and triggers sync when online
class ConnectivityService extends GetxService {
  final Connectivity _connectivity = Connectivity();
  final isOnline = true.obs;
  final connectionType = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initConnectivity();
    _listenToConnectivityChanges();
  }

  /// Initialize connectivity status
  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      if (result.isNotEmpty) {
        _updateConnectionStatus(result.first);
      }
    } on Exception catch (e) {
      log('❌ Error checking connectivity: $e');
    }
  }

  /// Listen to connectivity changes
  void _listenToConnectivityChanges() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result.isNotEmpty) {
        _updateConnectionStatus(result.first);
      }
    });
  }

  /// Update connection status and trigger sync if needed
  void _updateConnectionStatus(ConnectivityResult result) {
    final wasOnline = isOnline.value;

    if (result == ConnectivityResult.none) {
      isOnline.value = false;
      connectionType.value = '📴 Offline';
      log('📴 Connection lost');
    } else if (result == ConnectivityResult.wifi) {
      isOnline.value = true;
      connectionType.value = '📶 WiFi';
      log('📶 Connected via WiFi');

      // Trigger sync if was offline
      if (!wasOnline) {
        _onReconnected();
      }
    } else if (result == ConnectivityResult.mobile) {
      isOnline.value = true;
      connectionType.value = '📡 Mobile Data';
      log('📡 Connected via Mobile Data');

      // Trigger sync if was offline
      if (!wasOnline) {
        _onReconnected();
      }
    }
  }

  /// Called when device reconnects to internet
  void _onReconnected() {
    log('🔄 Device reconnected! Triggering sync...');
    // This will be handled by AutoSyncService
  }

  /// Check if currently online
  bool isConnected() => isOnline.value;

  /// Get connection type description
  String getConnectionDescription() => connectionType.value;

  /// Get connection icon
  String getConnectionIcon() {
    if (!isOnline.value) return '📴';
    return connectionType.value.contains('WiFi') ? '📶' : '📡';
  }
}
