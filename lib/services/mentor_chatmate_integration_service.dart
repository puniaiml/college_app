import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Integration service for Mentor-Mentee Management with ChatMate
/// Handles automated notifications, channel creation, and communication
class MentorChatMateIntegrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send ChatMate message when mentor adds a student
  /// Creates a 1:1 chat notification about mentorship assignment
  static Future<void> notifyMenteeAssignment({
    required String mentorId,
    required String mentorName,
    required String studentId,
    required String studentName,
    required String branchName,
    Map<String, dynamic>? mentorData,
    Map<String, dynamic>? studentData,
  }) async {
    try {
      log('📨 Sending mentee assignment notification to $studentName');

      // Sync both users to ChatMate if data is provided
      if (mentorData != null) {
        await _syncUserToChatMate(mentorId, mentorData);
      }
      if (studentData != null) {
        await _syncUserToChatMate(studentId, studentData);
      }

      // Establish bidirectional chat connection
      await _ensureChatConnection(mentorId, studentId);

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final conversationId = _getConversationID(mentorId, studentId);

      final message = '''
👨‍🏫 *Mentorship Assignment*

Hello $studentName!

You have been assigned to *$mentorName* as your mentor for the *$branchName* department.

Your mentor will:
- Guide you through your academic journey
- Track your progress and performance
- Schedule regular mentorship meetings
- Provide academic and career guidance

*You can now chat directly with your mentor here in ChatMate!*

Feel free to reach out for any support or guidance!

Best wishes for your academic journey! 🎓
''';

      final messageData = {
        'toId': studentId,
        'msg': message,
        'read': '',
        'type': 'text',
        'fromId': mentorId,
        'sent': timestamp,
      };

      // Create the message in the conversation
      await _firestore
          .collection('chats/$conversationId/messages')
          .doc(timestamp)
          .set(messageData);

      // CRITICAL FIX: Update the last message timestamp for both users
      // This ensures the conversation appears in both chat lists
      await _updateConversationTimestamp(conversationId, message, timestamp);

      log('✅ Mentee assignment notification sent successfully');
      log('✅ Chat connection established - mentor and student can now chat');
    } catch (e) {
      log('❌ notifyMenteeAssignmentError: $e');
    }
  }

  /// Update conversation timestamp to ensure it appears in chat lists
  /// Uses merge to avoid overwriting existing connection data
  static Future<void> _updateConversationTimestamp(
    String conversationId,
    String lastMessage,
    String timestamp,
  ) async {
    try {
      // Extract user IDs from conversation ID
      final parts = conversationId.split('_');
      if (parts.length != 2) return;

      final userId1 = parts[0];
      final userId2 = parts[1];

      // Truncate message for preview
      final messagePreview = lastMessage.length > 50 
          ? lastMessage.substring(0, 50) 
          : lastMessage;

      // Update my_users for both users using merge to preserve existing data
      await _firestore
          .collection('users')
          .doc(userId1)
          .collection('my_users')
          .doc(userId2)
          .set({
        'lastMessage': messagePreview,
        'lastSent': timestamp,
      }, SetOptions(merge: true));

      await _firestore
          .collection('users')
          .doc(userId2)
          .collection('my_users')
          .doc(userId1)
          .set({
        'lastMessage': messagePreview,
        'lastSent': timestamp,
      }, SetOptions(merge: true));

      log('✅ Conversation timestamp updated for both users (using merge)');
    } catch (e) {
      log('❌ updateConversationTimestampError: $e');
    }
  }

  /// Send ChatMate message when a meeting is scheduled
  static Future<void> notifyMeetingScheduled({
    required String mentorId,
    required String mentorName,
    required List<String> studentIds,
    required String meetingTitle,
    required String meetingDescription,
    required DateTime meetingDate,
  }) async {
    try {
      log('📅 Sending meeting notification to ${studentIds.length} students');

      final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(meetingDate);
      final timeStr = DateFormat('h:mm a').format(meetingDate);

      for (final studentId in studentIds) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final conversationId = _getConversationID(mentorId, studentId);

        final message = '''
📅 *Meeting Scheduled*

Hi! Your mentor *$mentorName* has scheduled a meeting:

📌 *Title:* $meetingTitle

📝 *Details:*
${meetingDescription.isNotEmpty ? meetingDescription : 'No additional details provided'}

🗓️ *Date:* $dateStr
⏰ *Time:* $timeStr

Please mark your calendar and be prepared for the meeting.

See you there! 👋
''';

        final messageData = {
          'toId': studentId,
          'msg': message,
          'read': '',
          'type': 'text',
          'fromId': mentorId,
          'sent': timestamp,
          'message_label': 'reference',
        };

        await _firestore
            .collection('chats/$conversationId/messages')
            .doc(timestamp)
            .set(messageData);

        // Update conversation timestamp
        await _updateConversationTimestamp(conversationId, 'Meeting scheduled: $meetingTitle', timestamp);

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      log('✅ Meeting notifications sent to all students');
    } catch (e) {
      log('❌ notifyMeetingScheduledError: $e');
    }
  }

  /// Send ChatMate message when a progress report is added
  static Future<void> notifyProgressReportAdded({
    required String mentorId,
    required String mentorName,
    required String studentId,
    required String studentName,
    required int semester,
    double? cgpa,
    int? attendance,
    String? remarks,
  }) async {
    try {
      log('📊 Sending progress report notification to $studentName');

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final conversationId = _getConversationID(mentorId, studentId);

      final cgpaText = cgpa != null ? '📈 *CGPA:* ${cgpa.toStringAsFixed(2)}' : '';
      final attendanceText = attendance != null ? '📊 *Attendance:* $attendance%' : '';
      final remarksText = remarks != null && remarks.isNotEmpty ? '\n💬 *Remarks:*\n$remarks' : '';

      final message = '''
📊 *Progress Report Added*

Hello $studentName!

Your mentor *$mentorName* has added a progress report for *Semester $semester*.

$cgpaText
$attendanceText$remarksText

${_getEncouragementMessage(cgpa, attendance)}

Keep up the great work! 🌟

You can view detailed semester-wise performance in the mentor-mentee management section.
''';

      final messageData = {
        'toId': studentId,
        'msg': message,
        'read': '',
        'type': 'text',
        'fromId': mentorId,
        'sent': timestamp,
        'message_label': 'summary',
      };

      await _firestore
          .collection('chats/$conversationId/messages')
          .doc(timestamp)
          .set(messageData);

      // Update conversation timestamp
      await _updateConversationTimestamp(conversationId, 'Progress report added for Semester $semester', timestamp);

      log('✅ Progress report notification sent successfully');
    } catch (e) {
      log('❌ notifyProgressReportAddedError: $e');
    }
  }

  /// Create or get year-wise channel for mentees
  /// Faculty/HOD is the channel creator (admin)
  static Future<String?> createYearWiseChannel({
    required String mentorId,
    required String mentorName,
    required String branchName,
    required String yearOfPassing,
    required List<String> studentIds,
  }) async {
    try {
      log('📢 Creating/updating year-wise channel for $yearOfPassing batch');

      // Check if channel already exists
      final existingChannel = await _findExistingChannel(
        mentorId: mentorId,
        yearOfPassing: yearOfPassing,
        branchName: branchName,
      );

      if (existingChannel != null) {
        log('✅ Found existing channel: ${existingChannel['id']}');
        // Update members list
        await _updateChannelMembers(existingChannel['id'], studentIds);
        return existingChannel['id'];
      }

      // Create new channel
      final channelId = DateTime.now().millisecondsSinceEpoch.toString();
      final channelName = '$branchName - Batch $yearOfPassing';
      final subject = 'Academic Guidance & Updates';
      final description = '''
Official mentorship channel for $branchName department students graduating in $yearOfPassing.

This channel is for:
• Academic announcements and updates
• Meeting schedules and reminders
• Resource sharing
• Academic guidance and support
• Assignment deadlines and notifications

Mentor: $mentorName
''';

      // Create channel document
      await _firestore.collection('channels').doc(channelId).set({
        'id': channelId,
        'name': channelName,
        'subject': subject,
        'description': description,
        'createdBy': mentorId,
        'createdAt': channelId,
        'members': [mentorId, ...studentIds],
        'yearOfPassing': yearOfPassing,
        'branchName': branchName,
        'mentorId': mentorId,
        'channelType': 'mentorship',
      });

      log('✅ Year-wise channel created: $channelName');

      // Send welcome message to channel
      await _sendChannelWelcomeMessage(
        channelId: channelId,
        mentorId: mentorId,
        mentorName: mentorName,
        channelName: channelName,
      );

      // Notify all students about channel creation
      await _notifyStudentsAboutChannel(
        mentorId: mentorId,
        mentorName: mentorName,
        studentIds: studentIds,
        channelName: channelName,
        channelId: channelId,
      );

      return channelId;
    } catch (e) {
      log('❌ createYearWiseChannelError: $e');
      return null;
    }
  }

  /// Find existing mentorship channel for a specific year and branch
  static Future<Map<String, dynamic>?> _findExistingChannel({
    required String mentorId,
    required String yearOfPassing,
    required String branchName,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('channels')
          .where('mentorId', isEqualTo: mentorId)
          .where('yearOfPassing', isEqualTo: yearOfPassing)
          .where('branchName', isEqualTo: branchName)
          .where('channelType', isEqualTo: 'mentorship')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      log('findExistingChannelError: $e');
      return null;
    }
  }

  /// Update channel members list
  static Future<void> _updateChannelMembers(
    String channelId,
    List<String> studentIds,
  ) async {
    try {
      final channelDoc = await _firestore.collection('channels').doc(channelId).get();
      
      if (!channelDoc.exists) return;

      final currentMembers = List<String>.from(channelDoc.data()?['members'] ?? []);
      final mentorId = channelDoc.data()?['createdBy'] as String?;
      
      // Merge members (mentor + students)
      final allMembers = mentorId != null ? <String>[mentorId, ...studentIds] : studentIds;
      
      // Only update if there are changes
      if (!_listsEqual(currentMembers, allMembers)) {
        await _firestore.collection('channels').doc(channelId).update({
          'members': allMembers,
          'updatedAt': DateTime.now().millisecondsSinceEpoch.toString(),
        });
        
        log('✅ Channel members updated: ${allMembers.length} members');
      }
    } catch (e) {
      log('updateChannelMembersError: $e');
    }
  }

  /// Send welcome message to newly created channel
  static Future<void> _sendChannelWelcomeMessage({
    required String channelId,
    required String mentorId,
    required String mentorName,
    required String channelName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final welcomeMessage = '''
👋 *Welcome to $channelName!*

Hello everyone! I'm *$mentorName*, your mentor for this academic journey.

This channel is created to:
✅ Share important academic updates
✅ Schedule mentorship meetings
✅ Provide study resources and materials
✅ Track your progress and support your growth
✅ Answer your academic queries

Feel free to:
• Ask questions about academics or career
• Share your concerns or challenges
• Participate in discussions
• Stay updated with announcements

Let's work together to make this academic year successful! 🎓

*Remember:* This is a professional channel for academic purposes. Please maintain respectful communication.

Best wishes! 🌟
''';

      await _firestore
          .collection('channels/$channelId/messages')
          .doc(timestamp)
          .set({
        'toId': channelId,
        'msg': welcomeMessage,
        'read': '',
        'type': 'text',
        'fromId': mentorId,
        'sent': timestamp,
        'message_label': 'reference',
      });

      // Update channel with last message
      await _firestore.collection('channels').doc(channelId).update({
        'lastMessage': 'Welcome message',
        'lastSent': timestamp,
      });

      log('✅ Welcome message sent to channel');
    } catch (e) {
      log('sendChannelWelcomeMessageError: $e');
    }
  }

  /// Notify students about channel creation via 1:1 chat
  static Future<void> _notifyStudentsAboutChannel({
    required String mentorId,
    required String mentorName,
    required List<String> studentIds,
    required String channelName,
    required String channelId,
  }) async {
    try {
      for (final studentId in studentIds) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final conversationId = _getConversationID(mentorId, studentId);

        final message = '''
📢 *Channel Invitation*

Hi! You've been added to the mentorship channel:

*#$channelName*

This channel is for academic updates, meeting schedules, resources, and direct communication with your mentor and peers.

Open ChatMate → Channels to join the conversation!

See you there! 👋
''';

        await _firestore
            .collection('chats/$conversationId/messages')
            .doc(timestamp)
            .set({
          'toId': studentId,
          'msg': message,
          'read': '',
          'type': 'text',
          'fromId': mentorId,
          'sent': timestamp,
          'message_label': 'reference',
        });

        // Update conversation timestamp
        await _updateConversationTimestamp(conversationId, 'Channel invitation: $channelName', timestamp);

        await Future.delayed(const Duration(milliseconds: 100));
      }

      log('✅ Channel notifications sent to all students');
    } catch (e) {
      log('notifyStudentsAboutChannelError: $e');
    }
  }

  /// Post announcement to year-wise channel
  static Future<void> postChannelAnnouncement({
    required String channelId,
    required String mentorId,
    required String title,
    required String message,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final formattedMessage = '''
📢 *$title*

$message

— Posted on ${DateFormat('MMM d, yyyy • h:mm a').format(DateTime.now())}
''';

      await _firestore
          .collection('channels/$channelId/messages')
          .doc(timestamp)
          .set({
        'toId': channelId,
        'msg': formattedMessage,
        'read': '',
        'type': 'text',
        'fromId': mentorId,
        'sent': timestamp,
        'message_label': 'reference',
      });

      await _firestore.collection('channels').doc(channelId).update({
        'lastMessage': title,
        'lastSent': timestamp,
      });

      log('✅ Announcement posted to channel');
    } catch (e) {
      log('postChannelAnnouncementError: $e');
    }
  }

  /// Send notification when mentee is removed
  static Future<void> notifyMenteeRemoval({
    required String mentorId,
    required String mentorName,
    required String studentId,
    required String studentName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final conversationId = _getConversationID(mentorId, studentId);

      final message = '''
📋 *Mentorship Update*

Hello $studentName,

Your mentorship with *$mentorName* has been concluded.

All your progress reports have been archived and remain accessible to you for future reference.

Thank you for your participation in the mentorship program!

If you have any questions, feel free to reach out.

Best wishes! 🎓
''';

      await _firestore
          .collection('chats/$conversationId/messages')
          .doc(timestamp)
          .set({
        'toId': studentId,
        'msg': message,
        'read': '',
        'type': 'text',
        'fromId': mentorId,
        'sent': timestamp,
      });

      // Update conversation timestamp
      await _updateConversationTimestamp(conversationId, 'Mentorship concluded', timestamp);

      log('✅ Mentee removal notification sent');
    } catch (e) {
      log('notifyMenteeRemovalError: $e');
    }
  }

  /// Ensure chat connection between mentor and student
  /// Only creates connection if it doesn't already exist to avoid duplicates
  static Future<void> _ensureChatConnection(String userId1, String userId2) async {
    try {
      // Check if connection already exists for user1 -> user2
      final user1ToUser2 = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('my_users')
          .doc(userId2)
          .get();

      // Check if connection already exists for user2 -> user1
      final user2ToUser1 = await _firestore
          .collection('users')
          .doc(userId2)
          .collection('my_users')
          .doc(userId1)
          .get();

      // Only create connections that don't exist
      if (!user1ToUser2.exists) {
        await _firestore
            .collection('users')
            .doc(userId1)
            .collection('my_users')
            .doc(userId2)
            .set({}, SetOptions(merge: true));
        log('✅ Created connection: $userId1 -> $userId2');
      } else {
        log('ℹ️ Connection already exists: $userId1 -> $userId2');
      }

      if (!user2ToUser1.exists) {
        await _firestore
            .collection('users')
            .doc(userId2)
            .collection('my_users')
            .doc(userId1)
            .set({}, SetOptions(merge: true));
        log('✅ Created connection: $userId2 -> $userId1');
      } else {
        log('ℹ️ Connection already exists: $userId2 -> $userId1');
      }

      log('✅ Chat connection ensured between users (no duplicates)');
    } catch (e) {
      log('❌ ensureChatConnectionError: $e');
    }
  }

  /// Sync user data from main app to ChatMate
  static Future<void> _syncUserToChatMate(String userId, Map<String, dynamic> userData) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      
      final existingUser = await _firestore.collection('users').doc(userId).get();
      
      if (!existingUser.exists) {
        // Create new ChatMate user profile
        await _firestore.collection('users').doc(userId).set({
          'id': userId,
          'name': userData['fullName'] ?? userData['name'] ?? 'User',
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? userData['phoneNumber'] ?? '',
          'about': userData['bio'] ?? "Hey, I'm using ChatMate!",
          'image': userData['profileImageUrl'] ?? '',
          'created_at': now,
          'is_online': false,
          'last_active': now,
          'push_token': '',
          'college': userData['collegeName'] ?? userData['college'] ?? '',
          'department': userData['branchName'] ?? userData['department'] ?? '',
          'userType': userData['userType'] ?? userData['user_type'] ?? '',
          'rollNo': userData['usn'] ?? userData['rollNo'] ?? '',
        });
        log('✅ User synced to ChatMate: ${userData['fullName'] ?? userData['name']}');
      } else {
        // Update existing ChatMate user profile
        await _firestore.collection('users').doc(userId).update({
          'name': userData['fullName'] ?? userData['name'] ?? existingUser.data()?['name'],
          'email': userData['email'] ?? existingUser.data()?['email'],
          'phone': userData['phone'] ?? userData['phoneNumber'] ?? existingUser.data()?['phone'],
          'image': userData['profileImageUrl'] ?? existingUser.data()?['image'],
          'college': userData['collegeName'] ?? userData['college'] ?? existingUser.data()?['college'],
          'department': userData['branchName'] ?? userData['department'] ?? existingUser.data()?['department'],
          'rollNo': userData['usn'] ?? userData['rollNo'] ?? existingUser.data()?['rollNo'],
        });
        log('✅ User profile updated in ChatMate: ${userData['fullName'] ?? userData['name']}');
      }
    } catch (e) {
      log('❌ syncUserToChatMateError: $e');
    }
  }

  /// Establish complete mentorship connection with proper chat setup
  static Future<bool> establishMentorshipConnection({
    required String mentorId,
    required String studentId,
    required String branchName,
  }) async {
    try {
      log('🔗 Establishing mentorship connection: $mentorId → $studentId');

      // Fetch user data from main app
      final mentorData = await fetchUserDataFromMainApp(mentorId);
      final studentData = await fetchUserDataFromMainApp(studentId);

      if (mentorData == null) {
        log('❌ Mentor data not found for: $mentorId');
        return false;
      }

      if (studentData == null) {
        log('❌ Student data not found for: $studentId');
        return false;
      }

      final mentorName = mentorData['name'] ?? mentorData['fullName'] ?? 'Your Mentor';
      final studentName = studentData['fullName'] ?? studentData['name'] ?? 'Student';

      // Send mentee assignment notification (this also syncs users and creates connection)
      await notifyMenteeAssignment(
        mentorId: mentorId,
        mentorName: mentorName,
        studentId: studentId,
        studentName: studentName,
        branchName: branchName,
        mentorData: mentorData,
        studentData: studentData,
      );

      log('✅ Mentorship connection established successfully');
      return true;
    } catch (e) {
      log('❌ establishMentorshipConnectionError: $e');
      return false;
    }
  }

  /// Fetch user data from main app collections
  static Future<Map<String, dynamic>?> fetchUserDataFromMainApp(String userId) async {
    try {
      log('🔍 Fetching user data from main app for: $userId');

      final collectionPaths = [
        'students',
        'faculty',
        'college_staff',
        'department_head',
        'pending_students',
      ];

      // Try nested collections first
      for (final collection in collectionPaths) {
        final doc = await _firestore
            .collection('users')
            .doc(collection)
            .collection('data')
            .doc(userId)
            .get();

        if (doc.exists) {
          log('✅ Found user in users/$collection/data/$userId');
          final data = doc.data()!;
          data['uid'] = userId;
          data['userType'] = collection;
          return data;
        }
      }

      // Try direct users collection
      final directDoc = await _firestore.collection('users').doc(userId).get();
      if (directDoc.exists) {
        log('✅ Found user in users/$userId');
        final data = directDoc.data()!;
        data['uid'] = userId;
        return data;
      }

      log('⚠️ User not found in any collection');
      return null;
    } catch (e) {
      log('❌ fetchUserDataError: $e');
      return null;
    }
  }

  /// Get conversation ID (same logic as ChatMate)
  static String _getConversationID(String id1, String id2) {
    return id1.hashCode <= id2.hashCode ? '${id1}_$id2' : '${id2}_$id1';
  }

  /// Get encouragement message based on performance
  static String _getEncouragementMessage(double? cgpa, int? attendance) {
    if (cgpa != null && cgpa >= 9.0 && attendance != null && attendance >= 90) {
      return '🌟 Outstanding performance! You\'re doing exceptionally well!';
    } else if (cgpa != null && cgpa >= 8.0) {
      return '👏 Great work! Keep maintaining this excellent standard!';
    } else if (cgpa != null && cgpa >= 7.0) {
      return '💪 Good progress! With consistent effort, you can achieve even better results!';
    } else if (cgpa != null && cgpa < 6.0) {
      return '📚 Let\'s work together to improve your performance. Don\'t hesitate to reach out for help!';
    } else {
      return '🎯 Keep pushing forward! Your mentor is here to support you!';
    }
  }

  /// Compare two lists for equality
  static bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.difference(set2).isEmpty && set2.difference(set1).isEmpty;
  }

  /// Batch create channels for all years under a mentor
  static Future<Map<String, String>> createAllYearChannels({
    required String mentorId,
    required String mentorName,
    required String branchName,
    required Map<String, List<String>> yearWiseStudents,
  }) async {
    final channelIds = <String, String>{};

    try {
      log('📢 Creating channels for ${yearWiseStudents.length} batches');

      for (final entry in yearWiseStudents.entries) {
        final year = entry.key;
        final students = entry.value;

        if (students.isEmpty) continue;

        final channelId = await createYearWiseChannel(
          mentorId: mentorId,
          mentorName: mentorName,
          branchName: branchName,
          yearOfPassing: year,
          studentIds: students,
        );

        if (channelId != null) {
          channelIds[year] = channelId;
        }

        // Delay between channel creations
        await Future.delayed(const Duration(milliseconds: 500));
      }

      log('✅ Created ${channelIds.length} channels successfully');
      return channelIds;
    } catch (e) {
      log('❌ createAllYearChannelsError: $e');
      return channelIds;
    }
  }
}