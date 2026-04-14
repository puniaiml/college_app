import 'dart:developer';
import '../api/apis.dart';
import '../models/chat_user.dart';

/// Centralized notification service for all ChatMate events
class NotificationService {
  /// Send notification for new message in 1:1 chat
  static Future<void> notifyNewMessage(
    ChatUser recipient,
    String senderName,
    String messagePreview,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) {
        log('notifyNewMessage: Recipient push token is empty');
        return;
      }

      final fullMessage = '$senderName: $messagePreview';
      await APIs.sendPushNotification(recipient, fullMessage);
      log('✉️ Message notification sent to ${recipient.name}');
    } catch (e) {
      log('notifyNewMessageError: $e');
    }
  }

  /// Send notification for channel message
  static Future<void> notifyChannelMessage(
    ChatUser recipient,
    String channelName,
    String senderName,
    String messagePreview,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) return;

      final fullMessage = '$senderName in #$channelName: $messagePreview';
      await APIs.sendPushNotification(recipient, fullMessage);
      log('💬 Channel message notification sent to ${recipient.name}');
    } catch (e) {
      log('notifyChannelMessageError: $e');
    }
  }

  /// Send notification for channel invitation
  static Future<void> notifyChannelInvite(
    ChatUser invitee,
    String inviterName,
    String channelName,
  ) async {
    try {
      if (invitee.pushToken.isEmpty) return;

      final message = '$inviterName invited you to #$channelName';
      await APIs.sendPushNotification(invitee, message);
      log('📧 Channel invite notification sent to ${invitee.name}');
    } catch (e) {
      log('notifyChannelInviteError: $e');
    }
  }

  /// Send notification for new assignment
  static Future<void> notifyNewAssignment(
    ChatUser recipient,
    String channelName,
    String assignmentTitle,
    String dueDate,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) return;

      final message = 'New assignment "$assignmentTitle" in #$channelName (Due: $dueDate)';
      await APIs.sendPushNotification(recipient, message);
      log('📋 Assignment notification sent to ${recipient.name}');
    } catch (e) {
      log('notifyNewAssignmentError: $e');
    }
  }

  /// Send notification for assignment deadline reminder (24h before)
  static Future<void> notifyAssignmentDeadline(
    ChatUser recipient,
    String channelName,
    String assignmentTitle,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) return;

      final message = '⏰ Assignment "$assignmentTitle" in #$channelName is due tomorrow!';
      await APIs.sendPushNotification(recipient, message);
      log('⏰ Deadline reminder sent to ${recipient.name}');
    } catch (e) {
      log('notifyAssignmentDeadlineError: $e');
    }
  }

  /// Send notification for new resource
  static Future<void> notifyNewResource(
    ChatUser recipient,
    String channelName,
    String resourceTitle,
    String resourceType,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) return;

      final message = 'New $resourceType resource "$resourceTitle" in #$channelName';
      await APIs.sendPushNotification(recipient, message);
      log('📚 Resource notification sent to ${recipient.name}');
    } catch (e) {
      log('notifyNewResourceError: $e');
    }
  }

  /// Send notification for member added to channel
  static Future<void> notifyMemberAdded(
    ChatUser newMember,
    String channelName,
    String addedByName,
  ) async {
    try {
      if (newMember.pushToken.isEmpty) return;

      final message = '$addedByName added you to #$channelName';
      await APIs.sendPushNotification(newMember, message);
      log('👥 Member add notification sent to ${newMember.name}');
    } catch (e) {
      log('notifyMemberAddedError: $e');
    }
  }

  /// Send notification for focus mode status
  static Future<void> notifyFocusModeEnabled(
    ChatUser recipient,
    String userNameInFocus,
  ) async {
    try {
      if (recipient.pushToken.isEmpty) return;

      final message = '$userNameInFocus is in Focus Mode - quiet time!';
      await APIs.sendPushNotification(recipient, message);
      log('🎯 Focus mode notification sent to ${recipient.name}');
    } catch (e) {
      log('notifyFocusModeEnabledError: $e');
    }
  }

  /// Send batch notification to multiple recipients
  static Future<void> notifyBatch(
    List<ChatUser> recipients,
    String title,
    String message,
  ) async {
    try {
      log('📤 Sending batch notification to ${recipients.length} recipients');
      for (final recipient in recipients) {
        if (recipient.pushToken.isNotEmpty) {
          await APIs.sendPushNotification(recipient, message);
        }
      }
      log('✅ Batch notification sent');
    } catch (e) {
      log('notifyBatchError: $e');
    }
  }
}
