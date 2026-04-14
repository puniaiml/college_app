import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart';
import 'package:shiksha_hub/chat_mate/api/notification_access_token.dart';

class NotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String projectID = 'college-app-e6cec';

  /// Send notification to a single user by push token
  static Future<void> sendNotificationToUser({
    required String pushToken,
    required String title,
    required String body,
    String? channelId,
  }) async {
    if (pushToken.isEmpty) {
      log('Push token is empty, skipping notification');
      return;
    }

    try {
      final bearerToken = await NotificationAccessToken.getToken;
      if (bearerToken == null) {
        log('Bearer token is null, cannot send notification');
        return;
      }

      final notificationBody = {
        "message": {
          "token": pushToken,
          "notification": {
            "title": title,
            "body": body,
          },
          if (channelId != null)
            "android": {
              "notification": {
                "channel_id": channelId,
              }
            }
        }
      };

      final res = await post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken'
        },
        body: jsonEncode(notificationBody),
      );

      if (res.statusCode == 200) {
        log('Notification sent successfully to user');
      } else {
        log('Notification failed: ${res.statusCode} - ${res.body}');
      }
    } catch (e) {
      log('sendNotificationToUser error: $e');
    }
  }

  /// Send notifications to multiple users
  static Future<void> sendNotificationsToUsers({
    required List<String> pushTokens,
    required String title,
    required String body,
    String? channelId,
  }) async {
    if (pushTokens.isEmpty) {
      log('No push tokens provided, skipping notifications');
      return;
    }

    // Send notifications in batches to avoid overwhelming the API
    const batchSize = 10;
    for (int i = 0; i < pushTokens.length; i += batchSize) {
      final batch = pushTokens.skip(i).take(batchSize).toList();
      await Future.wait(
        batch.map((token) => sendNotificationToUser(
              pushToken: token,
              title: title,
              body: body,
              channelId: channelId,
            )),
      );
      // Small delay between batches
      if (i + batchSize < pushTokens.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Get push tokens for students matching criteria
  static Future<List<String>> getStudentPushTokens({
    required String college,
    required String branch,
    required String semester,
    String? scheme,
  }) async {
    try {
      final List<String> pushTokens = [];

      // Query students from pending_students collection
      Query query = _firestore
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .where('college', isEqualTo: college)
          .where('branch', isEqualTo: branch)
          .where('semester', isEqualTo: semester);

      if (scheme != null && scheme.isNotEmpty) {
        query = query.where('scheme', isEqualTo: scheme);
      }

      final snapshot = await query.get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final pushToken = (data['push_token'] ?? data['pushToken'] ?? '').toString();
          if (pushToken.isNotEmpty) {
            pushTokens.add(pushToken);
          }
        }
      }

      log('Found ${pushTokens.length} student push tokens for $college/$branch/$semester');
      return pushTokens;
    } catch (e) {
      log('getStudentPushTokens error: $e');
      return [];
    }
  }

  /// Get push tokens for faculty matching criteria
  static Future<List<String>> getFacultyPushTokens({
    required String college,
    required String branch,
  }) async {
    try {
      final List<String> pushTokens = [];

      // Query faculty from faculty collection
      final snapshot = await _firestore
          .collection('users')
          .doc('faculty')
          .collection('data')
          .where('college', isEqualTo: college)
          .where('branch', isEqualTo: branch)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final pushToken = (data['push_token'] ?? data['pushToken'] ?? '').toString();
          if (pushToken.isNotEmpty) {
            pushTokens.add(pushToken);
          }
        }
      }

      log('Found ${pushTokens.length} faculty push tokens for $college/$branch');
      return pushTokens;
    } catch (e) {
      log('getFacultyPushTokens error: $e');
      return [];
    }
  }

  /// Get push tokens for users in a specific section (for timetable)
  static Future<List<String>> getSectionPushTokens({
    required String sectionId,
    required String college,
    required String branch,
    required String semester,
  }) async {
    try {
      final List<String> pushTokens = [];

      // Get students in the section
      final studentSnapshot = await _firestore
          .collection('users')
          .doc('pending_students')
          .collection('data')
          .where('college', isEqualTo: college)
          .where('branch', isEqualTo: branch)
          .where('semester', isEqualTo: semester)
          .where('sectionId', isEqualTo: sectionId)
          .get();

      for (var doc in studentSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final pushToken = (data['push_token'] ?? data['pushToken'] ?? '').toString();
          if (pushToken.isNotEmpty) {
            pushTokens.add(pushToken);
          }
        }
      }

      // Also get faculty who might be teaching in this section
      final facultyTokens = await getFacultyPushTokens(
        college: college,
        branch: branch,
      );
      pushTokens.addAll(facultyTokens);

      log('Found ${pushTokens.length} push tokens for section $sectionId');
      return pushTokens;
    } catch (e) {
      log('getSectionPushTokens error: $e');
      return [];
    }
  }

  /// Send notification when notes are uploaded
  static Future<void> notifyNotesUpload({
    required String college,
    required String branch,
    required String semester,
    required String subject,
    required String module,
    required String fileName,
    required String uploadedByName,
    String? scheme,
  }) async {
    try {
      // Get push tokens for students
      final studentTokens = await getStudentPushTokens(
        college: college,
        branch: branch,
        semester: semester,
        scheme: scheme,
      );

      // Get push tokens for faculty
      final facultyTokens = await getFacultyPushTokens(
        college: college,
        branch: branch,
      );

      // Combine all tokens
      final allTokens = [...studentTokens, ...facultyTokens];
      
      // Remove duplicates
      final uniqueTokens = allTokens.toSet().toList();

      if (uniqueTokens.isEmpty) {
        log('No push tokens found for notes notification');
        return;
      }

      final title = 'New Notes Uploaded';
      final body = '$uploadedByName uploaded new notes: $fileName\nSubject: $subject - Module: $module';

      await sendNotificationsToUsers(
        pushTokens: uniqueTokens,
        title: title,
        body: body,
        channelId: 'notes',
      );

      log('Notes notification sent to ${uniqueTokens.length} users');
    } catch (e) {
      log('notifyNotesUpload error: $e');
    }
  }

  /// Send notification when timetable is updated
  static Future<void> notifyTimetableUpdate({
    required String sectionId,
    required String sectionName,
    required String college,
    required String branch,
    required String semester,
    required String updatedByName,
    required String day,
  }) async {
    try {
      // Get push tokens for the section
      final tokens = await getSectionPushTokens(
        sectionId: sectionId,
        college: college,
        branch: branch,
        semester: semester,
      );

      if (tokens.isEmpty) {
        log('No push tokens found for timetable notification');
        return;
      }

      final title = 'Timetable Updated';
      final body = '$updatedByName updated the timetable for $sectionName ($day)';

      await sendNotificationsToUsers(
        pushTokens: tokens,
        title: title,
        body: body,
        channelId: 'timetable',
      );

      log('Timetable notification sent to ${tokens.length} users');
    } catch (e) {
      log('notifyTimetableUpdate error: $e');
    }
  }

  static Future<List<String>> _getRolePushTokens({
    required String roleDocId,
    String? college,
    String? branch,
  }) async {
    try {
      // Read all role users (collections are not huge typically); filter client-side to handle varying schemas
      final snap = await _firestore
          .collection('users')
          .doc(roleDocId)
          .collection('data')
          .get();

      final List<String> tokens = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final token = (data['push_token'] ?? data['pushToken'] ?? '').toString();
        if (token.isEmpty) continue;

        final dataCollege = (data['college'] ?? data['collegeName'] ?? '').toString();
        final dataBranch = (data['branch'] ?? data['branchName'] ?? '').toString();

        final collegeMatches = (college == null || college.isEmpty) || dataCollege == college;
        final branchMatches = (branch == null || branch.isEmpty) || dataBranch == branch;

        if (collegeMatches && branchMatches) {
          tokens.add(token);
        }
      }
      return tokens;
    } catch (e) {
      log('_getRolePushTokens error: $e');
      return [];
    }
  }

  // Notify HOD and Faculty: new pending student registration to review
  static Future<void> notifyPendingStudentSubmitted({
    required String college,
    required String branch,
    required String studentName,
  }) async {
    final hodTokens = await _getRolePushTokens(roleDocId: 'department_head', college: college, branch: branch);
    final facultyTokens = await _getRolePushTokens(roleDocId: 'faculty', college: college, branch: branch);
    final tokens = {...hodTokens, ...facultyTokens}.toList();
    if (tokens.isEmpty) return;

    await sendNotificationsToUsers(
      pushTokens: tokens,
      title: 'New Student Pending Approval',
      body: '$studentName submitted a registration request',
      channelId: 'notes', // reuse a high-priority channel; can create 'approvals' later
    );
  }

  // Notify a student: account approved
  static Future<void> notifyStudentApproved({
    required String studentPushToken,
    required String approvedByName,
  }) async {
    await sendNotificationToUser(
      pushToken: studentPushToken,
      title: 'Registration Approved',
      body: 'Your account was approved by $approvedByName',
      channelId: 'notes',
    );
  }

  // Notify a student: account rejected/blocked with reason
  static Future<void> notifyStudentRejected({
    required String studentPushToken,
    required String rejectedByName,
    String? reason,
  }) async {
    final reasonText = (reason == null || reason.isEmpty) ? '' : '\nReason: $reason';
    await sendNotificationToUser(
      pushToken: studentPushToken,
      title: 'Registration Rejected',
      body: 'Your registration was rejected by $rejectedByName$reasonText',
      channelId: 'notes',
    );
  }

  // Notify a student: account unblocked/activated (from blocked -> active)
  static Future<void> notifyStudentUnblocked({
    required String studentPushToken,
    required String approvedByName,
  }) async {
    await sendNotificationToUser(
      pushToken: studentPushToken,
      title: 'Account Activated',
      body: 'Your account has been activated by $approvedByName',
      channelId: 'notes',
    );
  }

  // Role-wide broadcasts helpers
  static Future<void> notifyCollegeHead({
    required String college,
    required String title,
    required String body,
  }) async {
    final tokens = await _getRolePushTokens(roleDocId: 'college_staff', college: college);
    if (tokens.isEmpty) return;
    await sendNotificationsToUsers(pushTokens: tokens, title: title, body: body, channelId: 'notes');
  }

  static Future<void> notifyAdmins({
    required String title,
    required String body,
  }) async {
    final tokens = await _getRolePushTokens(roleDocId: 'admins');
    if (tokens.isEmpty) return;
    await sendNotificationsToUsers(pushTokens: tokens, title: title, body: body, channelId: 'notes');
  }

  // Notify for exam creation
  static Future<void> notifyExamCreated({
    required String sectionId,
    required String sectionName,
    required String college,
    required String branch,
    required String semester,
    required String subject,
    required String examType,
    required String scheduledAtText,
    required String createdByName,
    int? maxMarks,
  }) async {
    final tokens = await getSectionPushTokens(
      sectionId: sectionId,
      college: college,
      branch: branch,
      semester: semester,
    );
    if (tokens.isEmpty) return;

    final title = 'New Exam Scheduled';
    final mm = maxMarks == null ? '' : ' | Max: $maxMarks';
    final body = '$subject - $examType on $scheduledAtText$mm\nBy $createdByName for $sectionName';

    await sendNotificationsToUsers(
      pushTokens: tokens,
      title: title,
      body: body,
      channelId: 'exams',
    );
  }

  // Notify for exam update
  static Future<void> notifyExamUpdated({
    required String sectionId,
    required String sectionName,
    required String college,
    required String branch,
    required String semester,
    required String subject,
    required String examType,
    required String scheduledAtText,
    required String updatedByName,
    int? maxMarks,
  }) async {
    final tokens = await getSectionPushTokens(
      sectionId: sectionId,
      college: college,
      branch: branch,
      semester: semester,
    );
    if (tokens.isEmpty) return;

    final title = 'Exam Updated';
    final mm = maxMarks == null ? '' : ' | Max: $maxMarks';
    final body = '$subject - $examType on $scheduledAtText$mm\nUpdated by $updatedByName for $sectionName';

    await sendNotificationsToUsers(
      pushTokens: tokens,
      title: title,
      body: body,
      channelId: 'exams',
    );
  }
}

