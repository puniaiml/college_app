// ignore_for_file: depend_on_referenced_packages

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/message.dart';
import '../models/chat_user.dart';

/// Chat-specific offline service for messages, drafts and profiles
class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  static Database? _database;

  factory OfflineService() => _instance;

  OfflineService._internal();

  Future<Database> get database async {
    _database ??= await _init();
    return _database!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'chatmate_offline.db');
    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        toId TEXT NOT NULL,
        msg TEXT NOT NULL,
        read TEXT DEFAULT '',
        type TEXT DEFAULT 'text',
        fromId TEXT NOT NULL,
        sent TEXT NOT NULL,
        repliedTo TEXT,
        repliedMsg TEXT,
        repliedToUserId TEXT,
        fileName TEXT,
        fileSize INTEGER,
        mimeType TEXT,
        messageLabel TEXT,
        isSynced INTEGER DEFAULT 0,
        createdAt INTEGER DEFAULT 0,
        syncedAt INTEGER,
        channelId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS draft_messages (
        id TEXT PRIMARY KEY,
        toId TEXT NOT NULL,
        msg TEXT NOT NULL,
        type TEXT DEFAULT 'text',
        messageLabel TEXT,
        fileName TEXT,
        fileUrl TEXT,
        createdAt INTEGER DEFAULT 0,
        channelId TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profiles (
        uid TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        phone TEXT,
        image TEXT,
        about TEXT,
        college TEXT,
        department TEXT,
        rollNo TEXT,
        userType TEXT,
        isFocusMode INTEGER DEFAULT 0,
        pushToken TEXT,
        lastSynced INTEGER DEFAULT 0,
        createdAt TEXT DEFAULT '',
        isOnline INTEGER DEFAULT 0,
        lastActive TEXT DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        operation TEXT NOT NULL,
        entityType TEXT NOT NULL,
        entityId TEXT,
        data TEXT,
        createdAt INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        retryCount INTEGER DEFAULT 0
      )
    ''');
  }

  // --- message helpers ---
  Future<void> saveMessageOffline(Message m, {String? channelId}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${m.fromId}_${m.sent}';
    await db.insert('messages', {
      'id': id,
      'toId': m.toId,
      'msg': m.msg,
      'read': m.read,
      'type': m.type.name,
      'fromId': m.fromId,
      'sent': m.sent,
      'repliedTo': m.repliedTo,
      'repliedMsg': m.repliedMsg,
      'repliedToUserId': m.repliedToUserId,
      'fileName': m.fileName,
      'fileSize': m.fileSize,
      'mimeType': m.mimeType,
      'messageLabel': m.messageLabel?.name,
      'isSynced': 1,
      'createdAt': now,
      'channelId': channelId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getCachedMessages(String userId, {String? channelId, int limit = 100}) async {
    final db = await database;
    final maps = await db.query('messages',
        where: channelId != null ? 'channelId = ?' : '(toId = ? OR fromId = ?)',
        whereArgs: channelId != null ? [channelId] : [userId, userId],
        orderBy: 'createdAt DESC',
        limit: limit);
    return maps.map((m) => _mapToMessage(m)).toList();
  }

  Message _mapToMessage(Map<String, dynamic> m) {
    final typeStr = m['type'] as String? ?? 'text';
    Type type;
    if (typeStr == Type.image.name) {
      type = Type.image;
    } else if (typeStr == Type.file.name) {
      type = Type.file;
    } else {
      type = Type.text;
    }
    MessageLabel? label;
    final labelStr = m['messageLabel'] as String?;
    if (labelStr != null) {
      try {
        label = MessageLabel.values.firstWhere((l) => l.name == labelStr);
      } catch (_) {}
    }

    return Message(
      toId: m['toId'] as String,
      msg: m['msg'] as String,
      read: (m['read'] as String?) ?? '',
      type: type,
      fromId: m['fromId'] as String,
      sent: m['sent'] as String,
      repliedTo: m['repliedTo'] as String?,
      repliedMsg: m['repliedMsg'] as String?,
      repliedToUserId: m['repliedToUserId'] as String?,
      fileName: m['fileName'] as String?,
      fileSize: m['fileSize'] as int?,
      mimeType: m['mimeType'] as String?,
      messageLabel: label,
    );
  }

  // --- drafts ---
  Future<void> saveDraft(Map<String, dynamic> draft) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    draft['id'] ??= now.toString();
    draft['createdAt'] = now;
    draft['status'] = draft['status'] ?? 'pending';
    await db.insert('draft_messages', draft, conflictAlgorithm: ConflictAlgorithm.replace);
    await addToSyncQueue(operation: 'send_message', entityType: 'message', entityId: draft['id'], data: draft);
  }

  Future<List<Map<String, dynamic>>> getDrafts({String? toId}) async {
    final db = await database;
    if (toId != null) {
      return await db.query('draft_messages', where: 'toId = ? AND status = ?', whereArgs: [toId, 'pending'], orderBy: 'createdAt DESC');
    }
    return await db.query('draft_messages', where: 'status = ?', whereArgs: ['pending'], orderBy: 'createdAt DESC');
  }

  Future<void> removeDraft(String id) async {
    final db = await database;
    await db.delete('draft_messages', where: 'id = ?', whereArgs: [id]);
  }

  // --- profiles ---
  Future<void> saveProfile(ChatUser user) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_profiles', {
      'uid': user.id,
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'image': user.image,
      'about': user.about,
      'college': user.college,
      'department': user.department,
      'rollNo': user.rollNo,
      'userType': user.userType,
      'isFocusMode': user.isFocusMode ? 1 : 0,
      'pushToken': user.pushToken,
      'lastSynced': now,
      'createdAt': user.createdAt,
      'isOnline': user.isOnline ? 1 : 0,
      'lastActive': user.lastActive,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ChatUser?> getProfile(String uid) async {
    final db = await database;
    final rows = await db.query('user_profiles', where: 'uid = ?', whereArgs: [uid], limit: 1);
    if (rows.isEmpty) return null;
    final m = rows.first;
    return ChatUser(
      id: m['uid'] as String,
      name: m['name'] as String? ?? '',
      createdAt: m['createdAt'] as String? ?? '',
      isOnline: (m['isOnline'] as int?) == 1,
      lastActive: m['lastActive'] as String? ?? '',
      email: m['email'] as String? ?? '',
      pushToken: m['pushToken'] as String? ?? '',
      about: m['about'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      college: m['college'] as String? ?? '',
      department: m['department'] as String? ?? '',
      userType: m['userType'] as String? ?? '',
      rollNo: m['rollNo'] as String? ?? '',
      image: m['image'] as String? ?? '',
      isFocusMode: (m['isFocusMode'] as int?) == 1,
    );
  }

  // --- sync queue ---
  Future<void> addToSyncQueue({required String operation, required String entityType, String? entityId, Map<String, dynamic>? data}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${entityType}_$now';
    await db.insert('sync_queue', {
      'id': id,
      'operation': operation,
      'entityType': entityType,
      'entityId': entityId,
      'data': data != null ? _encode(data) : null,
      'createdAt': now,
      'status': 'pending',
      'retryCount': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final db = await database;
    return await db.query('sync_queue', where: 'status = ?', whereArgs: ['pending'], orderBy: 'createdAt ASC');
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update('sync_queue', {'status': 'synced', 'retryCount': 0}, where: 'id = ?', whereArgs: [id]);
  }

  String _encode(Map<String, dynamic> m) {
    try {
      return m.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
    } catch (_) {
      return '{}';
    }
  }
}
