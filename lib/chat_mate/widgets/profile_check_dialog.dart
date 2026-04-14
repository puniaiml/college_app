import 'package:flutter/material.dart';
import '../api/apis.dart';
import '../services/profile_sync_service.dart';
import 'dialogs/profile_completion_dialog.dart';

/// Helper to check profile completion and show dialog
class ProfileCheckDialog {
  static Future<void> checkAndShowDialog(
    BuildContext context, {
    required String userType,
    VoidCallback? onProfileUpdated,
  }) async {
    try {
      // Sync profile data from main collections first
      await ProfileSyncService.syncProfileFromMainApp(APIs.user.uid);

      // Check if profile is complete
      if (!ProfileSyncService.isProfileComplete(APIs.me)) {
        if (!context.mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ProfileCompletionDialog(
            user: APIs.me,
            onProfileUpdated: onProfileUpdated ?? () {},
          ),
        );
      }
    } catch (e) {
      debugPrint('ProfileCheckDialog error: $e');
    }
  }
}
