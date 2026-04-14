import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart';
import 'package:mime/mime.dart';

import '../models/chat_user.dart';
import '../models/message.dart';
import 'notification_access_token.dart';
import '../services/notification_service.dart';

class APIs {
  static FirebaseAuth get auth => FirebaseAuth.instance;

  static FirebaseFirestore firestore = FirebaseFirestore.instance;

  static FirebaseStorage storage = FirebaseStorage.instance;

  static late ChatUser me;

  static User get user => auth.currentUser!;

  static FirebaseMessaging fMessaging = FirebaseMessaging.instance;

  static final Map<String, UploadTask> _activeUploads = {};

  static Future<void> getFirebaseMessagingToken() async {
    await fMessaging.requestPermission();

    await fMessaging.getToken().then((t) {
      if (t != null) {
        me.pushToken = t;
        log('Push Token: $t');
      }
    });
  }

  static Future<void> cancelUpload(String uploadKey) async {
    try {
      final task = _activeUploads.remove(uploadKey);
      if (task != null) {
        await task.cancel();
        log('Upload cancelled: $uploadKey');
      }
    } catch (e) {
      log('cancelUploadError: $e');
    }
  }

  static Future<void> sendPushNotification(
      ChatUser chatUser, String msg) async {
    try {
      final body = {
        "message": {
          "token": chatUser.pushToken,
          "notification": {
            "title": me.name,
            "body": msg,
          },
        }
      };

      const projectID = 'college-app-e6cec';

      final bearerToken = await NotificationAccessToken.getToken;

      log('bearerToken: $bearerToken');

      if (bearerToken == null) return;

      var res = await post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/$projectID/messages:send'),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader: 'Bearer $bearerToken'
        },
        body: jsonEncode(body),
      );

      log('Response status: ${res.statusCode}');
      log('Response body: ${res.body}');
    } catch (e) {
      log('\nsendPushNotificationE: $e');
    }
  }

  static Future<bool> userExists() async {
    return (await firestore.collection('users').doc(user.uid).get()).exists;
  }

  static Future<bool> addChatUser(String email) async {
    final data = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    log('data: ${data.docs}');

    if (data.docs.isNotEmpty && data.docs.first.id != user.uid) {
      log('user exists: ${data.docs.first.data()}');

      firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(data.docs.first.id)
          .set({});

      return true;
    } else {
      return false;
    }
  }

  static Future<void> getSelfInfo() async {
    try {
      final metaSnap = await firestore.collection('user_metadata').doc(user.uid).get();
      if (metaSnap.exists) {
        try {
          final meta = metaSnap.data()!;
          final userType = (meta['userType'] ?? '').toString();
          final collectionPath = _getCollectionPath(userType);
          if (collectionPath.isNotEmpty) {
            final profileSnap = await firestore.collection('users').doc(collectionPath).collection('data').doc(user.uid).get();
            if (profileSnap.exists) {
              me = ChatUser.fromJson(profileSnap.data()!);
              await getFirebaseMessagingToken();
              await updateActiveStatus(true);
              log('My Data (users/$collectionPath/data/{uid}): ${profileSnap.data()}');
              return;
            }
          }
        } catch (e) {
          log('user_metadata parse error: $e');
        }
      }

      final doc = await firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        me = ChatUser.fromJson(doc.data()!);
        await getFirebaseMessagingToken();
        await updateActiveStatus(true);
        log('My Data (users/{uid}): ${doc.data()}');
        return;
      }

      final candidates = ['students', 'faculty', 'college_staff', 'department_head', 'pending_students', 'admins'];
      for (final coll in candidates) {
        final nested = await firestore.collection('users').doc(coll).collection('data').doc(user.uid).get();
        if (nested.exists) {
          me = ChatUser.fromJson(nested.data()!);
          await getFirebaseMessagingToken();
          await updateActiveStatus(true);
          log('My Data (users/$coll/data/{uid}): ${nested.data()}');
          return;
        }
      }

      me = ChatUser(
          id: user.uid,
          name: user.displayName ?? '',
          email: user.email ?? '',
          about: "Hey, I'm using ChatMate!",
          image: user.photoURL ?? '',
          createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
          isOnline: false,
          lastActive: DateTime.now().millisecondsSinceEpoch.toString(),
          pushToken: '');

      await firestore.collection('users').doc(user.uid).set(me.toJson(), SetOptions(merge: true));
      await getFirebaseMessagingToken();
      await updateActiveStatus(true);
      log('My Data (fallback from Firebase User): ${me.toJson()}');

    } catch (e) {
      log('getSelfInfoE: $e');
      try {
        await createUser();
        await getSelfInfo();
      } catch (e2) {
        log('createUser fallback failed: $e2');
      }
    }
  }

  static Future<void> createUser() async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final chatUser = ChatUser(
        id: user.uid,
        name: user.displayName.toString(),
        email: user.email.toString(),
        about: "Hey, I'm using ChatMate!",
        image: user.photoURL.toString(),
        createdAt: time,
        isOnline: false,
        lastActive: time,
        pushToken: '');

    return await firestore
        .collection('users')
        .doc(user.uid)
        .set(chatUser.toJson());
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getMyUsersId() {
    return firestore
        .collection('users')
        .doc(user.uid)
        .collection('my_users')
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllUsers(
      List<String> userIds) {
    log('\nUserIds: $userIds');

    return firestore
        .collection('users')
        .where('id',
            whereIn: userIds.isEmpty
                ? ['']
                : userIds)
        .snapshots();
  }

  static Future<bool> checkChatConnectionExists(String userId1, String userId2) async {
    try {
      final doc1 = await firestore
          .collection('users')
          .doc(userId1)
          .collection('my_users')
          .doc(userId2)
          .get();
      
      final doc2 = await firestore
          .collection('users')
          .doc(userId2)
          .collection('my_users')
          .doc(userId1)
          .get();
      
      return doc1.exists && doc2.exists;
    } catch (e) {
      log('checkChatConnectionExistsError: $e');
      return false;
    }
  }

  static Future<void> ensureChatConnection(String userId1, String userId2) async {
    try {
      final alreadyConnected = await checkChatConnectionExists(userId1, userId2);
      
      if (alreadyConnected) {
        log('Chat connection already exists between users');
        return;
      }

      await firestore
          .collection('users')
          .doc(userId1)
          .collection('my_users')
          .doc(userId2)
          .set({}, SetOptions(merge: true));

      await firestore
          .collection('users')
          .doc(userId2)
          .collection('my_users')
          .doc(userId1)
          .set({}, SetOptions(merge: true));

      log('Chat connection created between users');
    } catch (e) {
      log('ensureChatConnectionError: $e');
    }
  }

  static Future<void> sendFirstMessage(
      ChatUser chatUser, String msg, Type type,
      {String? repliedToMessageId, String? repliedMsg, String? repliedToUserId, MessageLabel? messageLabel}) async {
    try {
      final alreadyConnected = await checkChatConnectionExists(user.uid, chatUser.id);
      
      if (alreadyConnected) {
        log('Users already connected, sending message directly');
        await sendMessage(chatUser, msg, type,
            repliedToMessageId: repliedToMessageId,
            repliedMsg: repliedMsg,
            repliedToUserId: repliedToUserId,
            messageLabel: messageLabel);
        return;
      }

      await firestore
          .collection('users')
          .doc(chatUser.id)
          .collection('my_users')
          .doc(user.uid)
          .set({}, SetOptions(merge: true));

      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('my_users')
          .doc(chatUser.id)
          .set({}, SetOptions(merge: true));

      log('New chat connection established');

      await sendMessage(chatUser, msg, type,
          repliedToMessageId: repliedToMessageId,
          repliedMsg: repliedMsg,
          repliedToUserId: repliedToUserId,
          messageLabel: messageLabel);
    } catch (e) {
      log('sendFirstMessageError: $e');
    }
  }

  static Future<void> updateUserInfo() async {
    await firestore.collection('users').doc(user.uid).update({
      'name': me.name,
      'about': me.about,
    });
  }

  static Future<void> updateProfilePicture(File file) async {
    final ext = file.path.split('.').last;
    log('Extension: $ext');

    final ref = storage.ref().child('profile_pictures/${user.uid}.$ext');

    await ref
        .putFile(file, SettableMetadata(contentType: 'image/$ext'))
        .then((p0) {
      log('Data Transferred: ${p0.bytesTransferred / 1000} kb');
    });

    me.image = await ref.getDownloadURL();
    await firestore
        .collection('users')
        .doc(user.uid)
        .update({'image': me.image});
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getUserInfo(
      ChatUser chatUser) {
    return firestore
        .collection('users')
        .where('id', isEqualTo: chatUser.id)
        .snapshots();
  }

  static Stream<ChatUser?> getUserById(String id) async* {
    final docRef = firestore.collection('users').doc(id);
    await for (final snap in docRef.snapshots()) {
      if (snap.exists) {
        yield ChatUser.fromJson(snap.data()!);
        continue;
      }

      final candidates = ['students', 'faculty', 'college_staff', 'department_head', 'pending_students', 'admins'];
      bool yielded = false;
      for (final coll in candidates) {
        final nestedRef = firestore.collection('users').doc(coll).collection('data').doc(id);
        final nestedSnap = await nestedRef.get();
        if (nestedSnap.exists) {
          yield ChatUser.fromJson(nestedSnap.data()!);
          yielded = true;
          break;
        }
      }

      if (!yielded) yield null;
    }
  }

  static Stream<List<ChatUser>> getUsersByIds(List<String> ids) {
    final controller = StreamController<List<ChatUser>>.broadcast();
    final Map<String, ChatUser> results = {};
    final List<StreamSubscription> subs = [];

    final candidates = ['students', 'faculty', 'college_staff', 'department_head', 'pending_students', 'admins'];

    void emit() {
      controller.add(results.values.toList());
    }

    Future<void> listenForId(String id) async {
      try {
        final docRef = firestore.collection('users').doc(id);
        final docSnap = await docRef.get();
        if (docSnap.exists) {
          results[id] = ChatUser.fromJson(docSnap.data()!);
          final s = docRef.snapshots().listen((sdoc) {
            if (sdoc.exists) {
              results[id] = ChatUser.fromJson(sdoc.data()!);
            } else {
              results.remove(id);
            }
            emit();
          });
          subs.add(s);
          emit();
          return;
        }

        for (final coll in candidates) {
          final nestedRef = firestore.collection('users').doc(coll).collection('data').doc(id);
          final nestedSnap = await nestedRef.get();
          if (nestedSnap.exists) {
            results[id] = ChatUser.fromJson(nestedSnap.data()!);
            final s = nestedRef.snapshots().listen((ns) {
              if (ns.exists) {
                results[id] = ChatUser.fromJson(ns.data()!);
              } else {
                results.remove(id);
              }
              emit();
            });
            subs.add(s);
            emit();
            return;
          }
        }
      } catch (e) {
        log('getUsersByIds.listenForId error: $e');
      }
    }

    for (final id in ids) {
      if (id.trim().isEmpty) continue;
      listenForId(id);
    }

    controller.onCancel = () {
      for (final s in subs) {
        try {
          s.cancel();
        } catch (_) {}
      }
    };

    return controller.stream;
  }

  static Future<void> updateActiveStatus(bool isOnline) async {
    firestore.collection('users').doc(user.uid).update({
      'is_online': isOnline,
      'last_active': DateTime.now().millisecondsSinceEpoch.toString(),
      'push_token': me.pushToken,
    });
  }

  static Future<void> toggleFocusMode(bool enable) async {
    try {
      me.isFocusMode = enable;
      await firestore.collection('users').doc(user.uid).update({
        'isFocusMode': enable,
      });
      log('Focus mode toggled: $enable');
    } catch (e) {
      log('toggleFocusModeError: $e');
    }
  }

  static String _getCollectionPath(String userType) {
    switch (userType) {
      case 'student':
        return 'pending_students';
      case 'college_staff':
        return 'college_staff';
      case 'faculty':
        return 'faculty';
      case 'department_head':
        return 'department_head';
      default:
        return '';
    }
  }

  static String getConversationID(String id) => user.uid.hashCode <= id.hashCode
      ? '${user.uid}_$id'
      : '${id}_${user.uid}';

  static Stream<QuerySnapshot<Map<String, dynamic>>> getAllMessages(
      ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  static Future<void> createChannel(String name, {String subject = '', String description = ''}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final docRef = firestore.collection('channels').doc(now);
      final channel = {
        'id': docRef.id,
        'name': name,
        'subject': subject,
        'description': description,
        'createdBy': user.uid,
        'createdAt': now,
        'members': [user.uid],
      };
      await docRef.set(channel);
    } catch (e) {
      log('createChannelError: $e');
    }
  }

  static Future<void> joinChannel(String channelId) async {
    try {
      final ref = firestore.collection('channels').doc(channelId);
      await ref.set({
        'members': FieldValue.arrayUnion([user.uid])
      }, SetOptions(merge: true));
    } catch (e) {
      log('joinChannelError: $e');
    }
  }

  static Future<void> inviteUserToChannel(String channelId, String email) async {
    try {
      final userSnap = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        log('inviteUserToChannel: User with email $email not found');
        throw Exception('User not found');
      }

      final targetUserId = userSnap.docs.first.id;

      final now = DateTime.now().millisecondsSinceEpoch.toString();
      await firestore
          .collection('channels')
          .doc(channelId)
          .collection('invitations')
          .doc(targetUserId)
          .set({
        'invitedBy': user.uid,
        'invitedAt': now,
        'accepted': false,
      });

      try {
        final targetSnap = await firestore.collection('users').doc(targetUserId).get();
        if (targetSnap.exists) {
          final targetData = targetSnap.data()!;
          final targetUser = ChatUser.fromJson(targetData);
          final channelSnap = await firestore.collection('channels').doc(channelId).get();
          final channelName = channelSnap.data()?['name'] ?? 'a channel';
          
          await NotificationService.notifyChannelInvite(
            targetUser,
            me.name,
            channelName,
          );
        }
      } catch (e) {
        log('inviteUserToChannel push notification error: $e');
      }
    } catch (e) {
      log('inviteUserToChannelError: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getChannelMembers(String channelId) {
    return firestore
        .collection('channels')
        .doc(channelId)
        .collection('members')
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getChannelsStream() {
    return firestore.collection('channels').orderBy('createdAt', descending: true).snapshots();
  }

  static Future<List<String>> getChannelInvitations(String channelId) async {
    try {
      final snap = await firestore
          .collection('channels')
          .doc(channelId)
          .collection('invitations')
          .where('accepted', isEqualTo: false)
          .get();
      return snap.docs.map((doc) => doc.id).toList();
    } catch (e) {
      log('getChannelInvitationsError: $e');
      return [];
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getChannelMessages(String channelId) {
    return firestore
        .collection('channels/$channelId/messages')
        .orderBy('sent', descending: true)
        .snapshots();
  }

  static Future<void> sendChannelMessage(String channelId, String msg, Type type, {MessageLabel? messageLabel}) async {
    try {
      final time = DateTime.now().millisecondsSinceEpoch.toString();
      final message = Message(
        toId: channelId,
        msg: msg,
        read: '',
        type: type,
        fromId: user.uid,
        sent: time,
        messageLabel: messageLabel,
      );

      final ref = firestore.collection('channels/$channelId/messages');
      await ref.doc(time).set(message.toJson());

      await firestore.collection('channels').doc(channelId).set({
        'lastMessage': msg,
        'lastSent': time,
      }, SetOptions(merge: true));

      try {
        final channelSnap = await firestore.collection('channels').doc(channelId).get();
        if (channelSnap.exists) {
          final channelName = channelSnap.data()?['name'] ?? 'Channel';
          final members = List<String>.from(channelSnap.data()?['members'] ?? []);

          for (final memberId in members) {
            if (memberId != user.uid) {
              try {
                final memberSnap = await firestore.collection('users').doc(memberId).get();
                if (memberSnap.exists) {
                  final memberUser = ChatUser.fromJson(memberSnap.data()!);
                  await NotificationService.notifyChannelMessage(
                    memberUser,
                    channelName,
                    me.name,
                    type == Type.text ? msg : '[Image]',
                  );
                }
              } catch (e) {
                log('Error notifying member $memberId: $e');
              }
            }
          }
        }
      } catch (e) {
        log('sendChannelMessageNotificationError: $e');
      }
    } catch (e) {
      log('sendChannelMessageError: $e');
    }
  }

  static Future<void> sendMessage(
    ChatUser chatUser, String msg, Type type,
    {String? repliedToMessageId, String? repliedMsg, String? repliedToUserId, MessageLabel? messageLabel}) async {
    final time = DateTime.now().millisecondsSinceEpoch.toString();

    final Message message = Message(
      toId: chatUser.id,
      msg: msg,
      read: '',
      type: type,
      fromId: user.uid,
      sent: time,
      repliedTo: repliedToMessageId,
      repliedMsg: repliedMsg,
      repliedToUserId: repliedToUserId
    );

    final ref = firestore
        .collection('chats/${getConversationID(chatUser.id)}/messages/');

    final data = message.toJson();
    if (messageLabel != null) {
      data['message_label'] = messageLabel.toString();
    }

    await ref.doc(time).set(data).then((value) async {
      await NotificationService.notifyNewMessage(
        chatUser,
        me.name,
        type == Type.text ? msg : '[Image]',
      );

      try {
        final convId = getConversationID(chatUser.id);
        await firestore
            .collection('users')
            .doc(chatUser.id)
            .collection('unread_chats')
            .doc(convId)
            .set({
          'count': FieldValue.increment(1),
          'lastMessage': msg,
          'lastSent': time,
        }, SetOptions(merge: true));
      } catch (e) {
        log('incrementUnreadError: $e');
      }
    });
  }

  static Future<void> updateMessageReadStatus(Message message) async {
    firestore
        .collection('chats/${getConversationID(message.fromId)}/messages/')
        .doc(message.sent)
        .update({'read': DateTime.now().millisecondsSinceEpoch.toString()});
  }

  static Future<void> clearUnreadForConversation(String otherUserId) async {
    try {
      final convId = getConversationID(otherUserId);
      final docRef = firestore
          .collection('users')
          .doc(user.uid)
          .collection('unread_chats')
          .doc(convId);

      await docRef.set({'count': 0}, SetOptions(merge: true));
    } catch (e) {
      log('clearUnreadError: $e');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessage(
      ChatUser user) {
    return firestore
        .collection('chats/${getConversationID(user.id)}/messages/')
        .orderBy('sent', descending: true)
        .limit(1)
        .snapshots();
  }

  static Future<void> sendChatImage(ChatUser chatUser, File file, {void Function(double)? onProgress, String? uploadKey}) async {
    await sendFile(chatUser, file, onProgress: onProgress, uploadKey: uploadKey);
  }

  static Future<void> sendFile(ChatUser chatUser, File file, {void Function(double)? onProgress, String? uploadKey}) async {
    try {
      final ext = file.path.split('.').last;
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final storagePath = 'files/${getConversationID(chatUser.id)}/$now.$ext';

      final detectedMime = lookupMimeType(file.path) ?? 'application/octet-stream';

      final ref = storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file, SettableMetadata(contentType: detectedMime));

      if (uploadKey != null) _activeUploads[uploadKey] = uploadTask;

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((snap) {
          final total = snap.totalBytes > 0 ? snap.totalBytes : 1;
          final transferred = snap.bytesTransferred;
          try {
            onProgress(transferred / total);
          } catch (_) {}
        });
      }

      final taskSnapshot = await uploadTask;
      log('Data Transferred: ${taskSnapshot.bytesTransferred / 1000} kb');

      if (uploadKey != null) _activeUploads.remove(uploadKey);

      final url = await ref.getDownloadURL();

      final fileStat = await file.length();

      final time = DateTime.now().millisecondsSinceEpoch.toString();

      final Message message = Message(
        toId: chatUser.id,
        msg: url,
        read: '',
        type: Type.file,
        fromId: user.uid,
        sent: time,
        fileName: file.path.split('/').last,
        fileSize: fileStat,
        mimeType: detectedMime,
      );

      final refMessages = firestore.collection('chats/${getConversationID(chatUser.id)}/messages/');
      await refMessages.doc(time).set(message.toJson()).then((value) async {
        await sendPushNotification(chatUser, '[File] ${message.fileName ?? 'file'}');

        try {
          final convId = getConversationID(chatUser.id);
          await firestore
              .collection('users')
              .doc(chatUser.id)
              .collection('unread_chats')
              .doc(convId)
              .set({
            'count': FieldValue.increment(1),
            'lastMessage': message.fileName ?? '[file]',
            'lastSent': time,
          }, SetOptions(merge: true));
        } catch (e) {
          log('incrementUnreadError (file): $e');
        }
      });
    } catch (e) {
      log('sendFileError: $e');
    }
  }

  static Future<void> deleteMessage(Message message) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .delete();

    if (message.type == Type.image) {
      await storage.refFromURL(message.msg).delete();
    }
  }

  static Future<void> updateMessage(Message message, String updatedMsg) async {
    await firestore
        .collection('chats/${getConversationID(message.toId)}/messages/')
        .doc(message.sent)
        .update({'msg': updatedMsg});
  }

  static Future<void> createAssignment(
    String channelId,
    String title,
    String description,
    String dueDate,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final docRef = firestore
          .collection('channels')
          .doc(channelId)
          .collection('assignments')
          .doc(now);

      final assignment = {
        'id': docRef.id,
        'channelId': channelId,
        'title': title,
        'description': description,
        'dueDate': dueDate,
        'createdBy': user.uid,
        'createdAt': now,
        'isCompleted': false,
      };

      await docRef.set(assignment);
      log('Assignment created: $title in channel $channelId');

      try {
        final channelSnap = await firestore.collection('channels').doc(channelId).get();
        if (channelSnap.exists) {
          final channelName = channelSnap.data()?['name'] ?? 'Channel';
          final members = List<String>.from(channelSnap.data()?['members'] ?? []);

          for (final memberId in members) {
            if (memberId != user.uid) {
              try {
                final memberSnap = await firestore.collection('users').doc(memberId).get();
                if (memberSnap.exists) {
                  final memberUser = ChatUser.fromJson(memberSnap.data()!);
                  await NotificationService.notifyNewAssignment(
                    memberUser,
                    channelName,
                    title,
                    dueDate,
                  );
                }
              } catch (e) {
                log('Error notifying member $memberId: $e');
              }
            }
          }
        }
      } catch (e) {
        log('createAssignmentNotificationError: $e');
      }
    } catch (e) {
      log('createAssignmentError: $e');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getChannelAssignments(
      String channelId) {
    return firestore
        .collection('channels')
        .doc(channelId)
        .collection('assignments')
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  static Future<void> toggleAssignmentCompletion(
      String channelId, String assignmentId, bool isCompleted) async {
    try {
      await firestore
          .collection('channels')
          .doc(channelId)
          .collection('assignments')
          .doc(assignmentId)
          .update({'isCompleted': isCompleted});
    } catch (e) {
      log('toggleAssignmentCompletionError: $e');
    }
  }

  static Future<void> deleteAssignment(String channelId, String assignmentId) async {
    try {
      await firestore
          .collection('channels')
          .doc(channelId)
          .collection('assignments')
          .doc(assignmentId)
          .delete();
    } catch (e) {
      log('deleteAssignmentError: $e');
    }
  }

  static Future<void> addResource(
    String channelId,
    String title,
    String description,
    String url,
    String resourceType,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final docRef = firestore
          .collection('channels')
          .doc(channelId)
          .collection('resources')
          .doc(now);

      final resource = {
        'id': docRef.id,
        'channelId': channelId,
        'title': title,
        'description': description,
        'url': url,
        'resourceType': resourceType,
        'uploadedBy': user.uid,
        'uploadedAt': now,
      };

      await docRef.set(resource);
      log('Resource added: $title in channel $channelId');

      try {
        final channelSnap = await firestore.collection('channels').doc(channelId).get();
        if (channelSnap.exists) {
          final channelName = channelSnap.data()?['name'] ?? 'Channel';
          final members = List<String>.from(channelSnap.data()?['members'] ?? []);

          for (final memberId in members) {
            if (memberId != user.uid) {
              try {
                final memberSnap = await firestore.collection('users').doc(memberId).get();
                if (memberSnap.exists) {
                  final memberUser = ChatUser.fromJson(memberSnap.data()!);
                  await NotificationService.notifyNewResource(
                    memberUser,
                    channelName,
                    title,
                    resourceType,
                  );
                }
              } catch (e) {
                log('Error notifying member $memberId: $e');
              }
            }
          }
        }
      } catch (e) {
        log('addResourceNotificationError: $e');
      }
    } catch (e) {
      log('addResourceError: $e');
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> getChannelResources(
      String channelId) {
    return firestore
        .collection('channels')
        .doc(channelId)
        .collection('resources')
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  static Future<void> deleteResource(String channelId, String resourceId) async {
    try {
      await firestore
          .collection('channels')
          .doc(channelId)
          .collection('resources')
          .doc(resourceId)
          .delete();
    } catch (e) {
      log('deleteResourceError: $e');
    }
  }
}