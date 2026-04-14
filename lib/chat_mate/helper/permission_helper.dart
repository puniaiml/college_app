import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  /// Request storage permissions for file operations
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (Platform.isIOS) {
      // iOS handles permissions differently
      final status = await Permission.photos.request();
      return status.isGranted;
    }

    // For Android 13+ (API 33+), we use different permissions
    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 13) {
        // Android 13+ - Request specific media permissions
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        
        return photos.isGranted && videos.isGranted;
      } else if (androidInfo >= 11) {
        // Android 11-12 - Request MANAGE_EXTERNAL_STORAGE if needed
        final status = await Permission.manageExternalStorage.request();
        
        if (status.isDenied || status.isPermanentlyDenied) {
          // Fallback to regular storage permission
          final storageStatus = await Permission.storage.request();
          return storageStatus.isGranted;
        }
        
        return status.isGranted;
      } else {
        // Android 10 and below - Regular storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }

    return true;
  }

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    
    if (status.isPermanentlyDenied) {
      return false;
    }
    
    return status.isGranted;
  }

  /// Request microphone permission (for voice messages)
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isPermanentlyDenied) {
      return false;
    }
    
    return status.isGranted;
  }

  /// Check if storage permission is granted
  static Future<bool> hasStoragePermission() async {
    if (Platform.isIOS) {
      return await Permission.photos.isGranted;
    }

    if (Platform.isAndroid) {
      final androidInfo = await _getAndroidVersion();
      
      if (androidInfo >= 13) {
        return await Permission.photos.isGranted && 
               await Permission.videos.isGranted;
      } else if (androidInfo >= 11) {
        final manageStorage = await Permission.manageExternalStorage.isGranted;
        if (manageStorage) return true;
        
        return await Permission.storage.isGranted;
      } else {
        return await Permission.storage.isGranted;
      }
    }

    return true;
  }

  /// Show dialog to open app settings
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667EEA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Get Android API level
  static Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;
    
    try {
      // You might need to use device_info_plus package for this
      // For now, return a safe default
      return 33; // Assume modern Android
    } catch (e) {
      log('Error getting Android version: $e');
      return 30; // Safe default
    }
  }

  /// Request all necessary permissions for chat app
  static Future<Map<String, bool>> requestAllChatPermissions(
    BuildContext context,
  ) async {
    final results = <String, bool>{};

    // Storage
    results['storage'] = await requestStoragePermission(context);
    
    // Camera
    results['camera'] = await requestCameraPermission();
    
    // Microphone (for future voice messages)
    results['microphone'] = await requestMicrophonePermission();

    return results;
  }

  /// Check and request storage permission with user-friendly dialog
  static Future<bool> checkAndRequestStorage(BuildContext context) async {
    final hasPermission = await hasStoragePermission();
    
    if (hasPermission) return true;

    final status = await requestStoragePermission(context);
    
    if (!status) {
      if (context.mounted) {
        await showPermissionDialog(
          context,
          title: 'Storage Permission Required',
          message: 'Please grant storage permission to download and view files. '
                   'You can enable it in app settings.',
        );
      }
      return false;
    }

    return true;
  }

  /// Check and request camera permission with user-friendly dialog
  static Future<bool> checkAndRequestCamera(BuildContext context) async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await showPermissionDialog(
          context,
          title: 'Camera Permission Required',
          message: 'Camera access has been permanently denied. '
                   'Please enable it in app settings to take photos.',
        );
      }
      return false;
    }

    final result = await requestCameraPermission();
    
    if (!result && context.mounted) {
      await showPermissionDialog(
        context,
        title: 'Camera Permission Required',
        message: 'Please grant camera permission to take photos.',
      );
    }

    return result;
  }
}