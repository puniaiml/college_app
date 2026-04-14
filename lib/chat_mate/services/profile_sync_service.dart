import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_user.dart';
import '../api/apis.dart';

/// Service to sync ChatMate profile with main app user profiles
/// Fetches profile data from user-type-specific collections
class ProfileSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Map of user types to their Firestore collection paths
  static const Map<String, String> _userTypeCollections = {
    'student': 'students',
    'college_staff': 'college_staff',
    'faculty': 'faculty',
    'department_head': 'department_head',
    'admin': 'admin',
  };

  /// Sync profile data from main app to ChatUser
  /// Pulls from users/{type}/data/{uid} and updates the ChatUser
  static Future<ChatUser?> syncProfileFromMainApp(String userId) async {
    try {
      log('🔄 Starting profile sync for user: $userId');

      // First, check if we can find the user type from their profile metadata
      final userMetaSnap = await _firestore.collection('users').doc(userId).get();

      if (!userMetaSnap.exists) {
        log('❌ User metadata not found for $userId');
        return null;
      }

      final userMetaData = userMetaSnap.data() ?? {};
      String? userType = userMetaData['userType'] ?? userMetaData['user_type'];

      // If no user type found, try to infer from existing profile data
      if (userType == null || userType.isEmpty) {
        log('⚠️ User type not found, attempting to infer from profile data');
        userType = await _inferUserType(userId);
      }

      if (userType == null || userType.isEmpty) {
        log('❌ Could not determine user type for $userId');
        return null;
      }

      log('👤 User type detected: $userType');

      // Get the collection path for this user type
      final collectionPath = _userTypeCollections[userType];
      if (collectionPath == null) {
        log('❌ Unknown user type: $userType');
        return null;
      }

      // Fetch profile from users/{type}/data/{uid}
      final profileSnap = await _firestore
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(userId)
          .get();

      if (!profileSnap.exists) {
        log('⚠️ No profile found in users/$collectionPath/data/$userId');
        return null;
      }

      final profileData = profileSnap.data() ?? {};
      log('✅ Profile data fetched for $userType: $profileData');

      // Update ChatUser with synced data
      return _updateChatUserFromProfile(profileData, userType);
    } catch (e) {
      log('❌ profileSyncError: $e');
      return null;
    }
  }

  /// Infer user type by checking which collection has this user's profile
  static Future<String?> _inferUserType(String userId) async {
    try {
      for (final entry in _userTypeCollections.entries) {
        final userType = entry.key;
        final collectionPath = entry.value;

        final snap = await _firestore
            .collection('users')
            .doc(collectionPath)
            .collection('data')
            .doc(userId)
            .get();

        if (snap.exists) {
          log('✅ Found user in $userType collection');
          return userType;
        }
      }
      return null;
    } catch (e) {
      log('inferUserTypeError: $e');
      return null;
    }
  }

  /// Update ChatUser fields from profile data
  static ChatUser _updateChatUserFromProfile(
    Map<String, dynamic> profileData,
    String userType,
  ) {
    try {
      // Map profile field names to ChatUser fields
      // Different user types may use different field names

      APIs.me.phone =
          profileData['phone'] ?? profileData['phoneNumber'] ?? APIs.me.phone;
      APIs.me.college = profileData['college'] ??
          profileData['collegeName'] ??
          APIs.me.college;
      APIs.me.department =
          profileData['department'] ?? profileData['dept'] ?? APIs.me.department;
      APIs.me.rollNo = profileData['rollNo'] ??
          profileData['roll_no'] ??
          profileData['usn'] ??
          APIs.me.rollNo;
      APIs.me.userType = userType;

      // Update profile image if available
      if (profileData.containsKey('profileImageUrl') &&
          (profileData['profileImageUrl'] as String).isNotEmpty) {
        APIs.me.image = profileData['profileImageUrl'];
      }

      // Update name if available
      if (profileData.containsKey('fullName') &&
          (profileData['fullName'] as String).isNotEmpty) {
        APIs.me.name = profileData['fullName'];
      } else if (profileData.containsKey('firstName')) {
        final firstName = profileData['firstName'] ?? '';
        final lastName = profileData['lastName'] ?? '';
        APIs.me.name = '$firstName $lastName'.trim();
      }

      // Update email if available
      if (profileData.containsKey('email') &&
          (profileData['email'] as String).isNotEmpty) {
        APIs.me.email = profileData['email'];
      }

      // Update about/bio
      if (profileData.containsKey('bio') &&
          (profileData['bio'] as String).isNotEmpty) {
        APIs.me.about = profileData['bio'];
      }

      // Save updated profile to ChatMate's users collection
      _saveUpdatedProfile();

      log('✅ ChatUser updated with synced profile data');
      return APIs.me;
    } catch (e) {
      log('updateChatUserFromProfileError: $e');
      return APIs.me;
    }
  }

  /// Save the updated profile back to ChatMate's users collection
  static Future<void> _saveUpdatedProfile() async {
    try {
      await _firestore
          .collection('users')
          .doc(APIs.user.uid)
          .update(APIs.me.toJson());
      log('💾 ChatUser profile saved to Firestore');
    } catch (e) {
      log('saveUpdatedProfileError: $e');
    }
  }

  /// Listen for profile changes in main app and sync to ChatMate
  /// This creates a listener that watches the user's profile in the main app
  static Stream<ChatUser?> watchProfileChanges(
    String userId,
    String userType,
  ) {
    try {
      final collectionPath = _userTypeCollections[userType];
      if (collectionPath == null) {
        log('❌ Unknown user type for watch: $userType');
        return Stream.empty();
      }

      log('👁️ Watching profile changes for $userId ($userType)');

      return _firestore
          .collection('users')
          .doc(collectionPath)
          .collection('data')
          .doc(userId)
          .snapshots()
          .asyncMap((snap) async {
        if (snap.exists) {
          final profileData = snap.data() ?? {};
          log('🔄 Profile change detected for $userId');
          return _updateChatUserFromProfile(profileData, userType);
        }
        return null;
      });
    } catch (e) {
      log('watchProfileChangesError: $e');
      return Stream.empty();
    }
  }

  /// Check if profile is complete with essential fields
  static bool isProfileComplete(ChatUser user) {
    return user.name.isNotEmpty &&
        user.email.isNotEmpty &&
        user.phone.isNotEmpty &&
        user.college.isNotEmpty;
  }

  /// Get missing profile fields
  static List<String> getMissingFields(ChatUser user) {
    final missing = <String>[];
    if (user.name.isEmpty) missing.add('Name');
    if (user.email.isEmpty) missing.add('Email');
    if (user.phone.isEmpty) missing.add('Phone');
    if (user.college.isEmpty) missing.add('College');
    return missing;
  }
}
