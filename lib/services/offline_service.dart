import 'dart:developer';
import 'package:get/get.dart';
import 'offline_database.dart';
import 'auto_sync_service.dart';
import 'connectivity_service.dart';

/// Unified offline service for all Shiksha Hub modules
/// Provides simple methods for caching and retrieving offline data
class OfflineService extends GetxService {
  late final OfflineDatabase _db;
  late final AutoSyncService _syncService;
  late final ConnectivityService _connectivityService;

  @override
  void onInit() async {
    super.onInit();

    _db = OfflineDatabase();
    _syncService = Get.find<AutoSyncService>();
    _connectivityService = Get.find<ConnectivityService>();

    log('✅ OfflineService initialized');
  }

  // ==================== CONNECTIVITY ====================

  bool isOnline() => _connectivityService.isConnected();

  String getConnectionStatus() => _connectivityService.getConnectionDescription();

  String getConnectionIcon() => _connectivityService.getConnectionIcon();

  // ==================== NOTES ====================

  Future<void> cacheNotes(List<Map<String, dynamic>> notes) async {
    await _db.saveDataBatch('notes', notes, syncStatus: 'synced');
    log('💾 ${notes.length} notes cached');
  }

  Future<void> cacheNote(Map<String, dynamic> note) async {
    await _db.saveData('notes', note, syncStatus: 'synced');
  }

  Future<List<Map<String, dynamic>>> getCachedNotes({
    String? branch,
    int? semester,
  }) async {
    String? where;
    List<dynamic>? args;

    if (branch != null && semester != null) {
      where = 'branch = ? AND semester = ?';
      args = [branch, semester];
    } else if (branch != null) {
      where = 'branch = ?';
      args = [branch];
    } else if (semester != null) {
      where = 'semester = ?';
      args = [semester];
    }

    return await _db.getData('notes', whereClause: where, whereArgs: args);
  }

  Future<void> cacheFavoriteNote(String noteId, String userId) async {
    final id = '${userId}_$noteId';
    await _db.saveData('note_favorites', {
      'id': id,
      'noteId': noteId,
      'userId': userId,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getCachedFavoriteNotes(String userId) async {
    return await _db.getData('note_favorites', whereClause: 'userId = ?', whereArgs: [userId]);
  }

  // ==================== TIMETABLE ====================

  Future<void> cacheTimetable(List<Map<String, dynamic>> schedule) async {
    await _db.saveDataBatch('timetable', schedule, syncStatus: 'synced');
    log('💾 Timetable cached');
  }

  Future<List<Map<String, dynamic>>> getCachedTimetable({
    String? branch,
    int? semester,
  }) async {
    String? where;
    List<dynamic>? args;

    if (branch != null && semester != null) {
      where = 'branch = ? AND semester = ?';
      args = [branch, semester];
    }

    return await _db.getData('timetable', whereClause: where, whereArgs: args);
  }

  // ==================== RESULTS ====================

  Future<void> cacheResults(List<Map<String, dynamic>> results) async {
    await _db.saveDataBatch('results', results, syncStatus: 'synced');
    log('💾 ${results.length} results cached');
  }

  Future<List<Map<String, dynamic>>> getCachedResults(String studentRoll, {int? semester}) async {
    String? where;
    List<dynamic>? args;

    if (semester != null) {
      where = 'studentRoll = ? AND semester = ?';
      args = [studentRoll, semester];
    } else {
      where = 'studentRoll = ?';
      args = [studentRoll];
    }

    return await _db.getData('results', whereClause: where, whereArgs: args);
  }

  // ==================== CGPA ====================

  Future<void> cacheCGPA(Map<String, dynamic> cgpaData) async {
    await _db.saveData('cgpa', cgpaData, syncStatus: 'synced');
    log('💾 CGPA cached');
  }

  Future<Map<String, dynamic>?> getCachedCGPA(String studentRoll) async {
    return await _db.getDataSingle(
      'cgpa',
      whereClause: 'studentRoll = ?',
      whereArgs: [studentRoll],
    );
  }

  // ==================== EXAMS ====================

  Future<void> cacheExamSchedules(List<Map<String, dynamic>> exams) async {
    await _db.saveDataBatch('exam_schedules', exams, syncStatus: 'synced');
    log('💾 ${exams.length} exam schedules cached');
  }

  Future<List<Map<String, dynamic>>> getCachedExamSchedules({
    String? rollNo,
    int? semester,
  }) async {
    String? where;
    List<dynamic>? args;

    if (rollNo != null && semester != null) {
      where = 'rollNo = ? AND semester = ?';
      args = [rollNo, semester];
    } else if (rollNo != null) {
      where = 'rollNo = ?';
      args = [rollNo];
    } else if (semester != null) {
      where = 'semester = ?';
      args = [semester];
    }

    return await _db.getData('exam_schedules', whereClause: where, whereArgs: args);
  }

  Future<void> cacheExamSyllabus(List<Map<String, dynamic>> syllabus) async {
    await _db.saveDataBatch('exam_syllabus', syllabus, syncStatus: 'synced');
  }

  Future<List<Map<String, dynamic>>> getCachedExamSyllabus(String examId) async {
    return await _db.getData('exam_syllabus', whereClause: 'examId = ?', whereArgs: [examId]);
  }

  // ==================== CHATMATE MESSAGES ====================

  Future<void> cacheMessage(Map<String, dynamic> message) async {
    await _db.saveData('messages', message, syncStatus: 'synced');
  }

  Future<void> cacheMessages(List<Map<String, dynamic>> messages) async {
    await _db.saveDataBatch('messages', messages, syncStatus: 'synced');
    log('💾 ${messages.length} messages cached');
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String userId, {String? channelId}) async {
    String? where;
    List<dynamic>? args;

    if (channelId != null) {
      where = '(toId = ? OR fromId = ?) AND channelId = ?';
      args = [userId, userId, channelId];
    } else {
      where = 'toId = ? OR fromId = ?';
      args = [userId, userId];
    }

    return await _db.getData('messages', whereClause: where, whereArgs: args);
  }

  Future<void> cacheDraftMessage(Map<String, dynamic> draft) async {
    await _db.saveData('draft_messages', draft, syncStatus: 'pending');
    await _db.queueSyncOperation(
      operation: 'send_message',
      entityType: 'message',
      entityId: draft['id'],
      data: draft,
    );
  }

  Future<List<Map<String, dynamic>>> getCachedDraftMessages({String? toId}) async {
    String? where;
    List<dynamic>? args;

    if (toId != null) {
      where = 'toId = ? AND status = ?';
      args = [toId, 'pending'];
    } else {
      where = 'status = ?';
      args = ['pending'];
    }

    return await _db.getData('draft_messages', whereClause: where, whereArgs: args);
  }

  Future<void> deleteDraftMessage(String draftId) async {
    await _db.deleteData('draft_messages', whereClause: 'id = ?', whereArgs: [draftId]);
  }

  // ==================== CHANNELS ====================

  Future<void> cacheChannels(List<Map<String, dynamic>> channels) async {
    await _db.saveDataBatch('channels', channels, syncStatus: 'synced');
    log('💾 ${channels.length} channels cached');
  }

  Future<List<Map<String, dynamic>>> getCachedChannels() async {
    return await _db.getData('channels', whereClause: 'isMember = ?', whereArgs: [1]);
  }

  // ==================== USER PROFILES ====================

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await _db.saveData('user_profiles', profile, syncStatus: 'synced');
    log('💾 Profile cached: ${profile['name']}');
  }

  Future<void> cacheUserProfiles(List<Map<String, dynamic>> profiles) async {
    await _db.saveDataBatch('user_profiles', profiles, syncStatus: 'synced');
  }

  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) async {
    return await _db.getDataSingle(
      'user_profiles',
      whereClause: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<List<Map<String, dynamic>>> getCachedUserProfiles(String userType) async {
    return await _db.getData('user_profiles', whereClause: 'userType = ?', whereArgs: [userType]);
  }

  // ==================== SYNC QUEUE ====================

  Future<void> queueOperation({
    required String operation,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? data,
  }) async {
    await _db.queueSyncOperation(
      operation: operation,
      entityType: entityType,
      entityId: entityId,
      data: data,
    );
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    return await _syncService.getCacheInfo();
  }

  Future<void> forceSyncNow() async {
    await _syncService.forceSyncNow();
  }

  int getPendingSyncCount() => _syncService.pendingCount.value;

  String getSyncStatusText() => _syncService.getSyncStatus();

  // ==================== CACHE MANAGEMENT ====================

  Future<void> clearOfflineData() async {
    await _db.clearAllOfflineData();
    log('🗑️  All offline data cleared');
  }

  Future<void> clearCache(String table) async {
    await _db.clearCache(table);
  }

  Future<Map<String, int>> getCacheStats() async {
    return await _db.getCacheStats();
  }

  Future<int> getDatabaseSize() async {
    return await _db.getDatabaseSize();
  }

  Future<String> getDatabaseSizeFormatted() async {
    final bytes = await getDatabaseSize();
    final mb = bytes / 1024 / 1024;
    return '${mb.toStringAsFixed(2)} MB';
  }

  // ==================== UTILITY ====================

  /// Check if specific data is cached and not expired
  Future<bool> isCached(String key, {Duration? maxAge}) async {
    final cachedData = await _db.getCacheMetadata(key);

    if (cachedData == null) return false;

    if (maxAge != null) {
      final cacheTime = DateTime.parse(cachedData);
      final diff = DateTime.now().difference(cacheTime);
      return diff < maxAge;
    }

    return true;
  }

  /// Set cache with expiration
  Future<void> setCache(
    String key,
    String value, {
    Duration? expiresIn,
  }) async {
    await _db.setCacheMetadata(key, value, expiresIn: expiresIn);
  }

  /// Get cached value
  Future<String?> getCache(String key) async {
    return await _db.getCacheMetadata(key);
  }

  /// Log offline status
  void logOfflineStatus() async {
    final stats = await getCacheStats();
    final dbSize = await getDatabaseSizeFormatted();

    log('''
╔════════════════════════════════════════════════════════════╗
║          📴 OFFLINE STATUS - Shiksha Hub                   ║
╠════════════════════════════════════════════════════════════╣
║ Connection: ${getConnectionStatus().padRight(50)}
║ Sync Status: ${getSyncStatusText().padRight(48)}
║ Database Size: ${dbSize.padRight(49)}
║ ─────────────────────────────────────────────────────────
║ Cached Data:
║   • Notes: ${stats['notes'] ?? 0} items
║   • Timetable: ${stats['timetable'] ?? 0} items
║   • Results: ${stats['results'] ?? 0} items
║   • Exams: ${stats['exams'] ?? 0} items
║   • Messages: ${stats['messages'] ?? 0} items
║   • Drafts: ${stats['drafts'] ?? 0} items
║   • Pending Sync: ${stats['pendingSync'] ?? 0} operations
╚════════════════════════════════════════════════════════════╝
    ''');
  }
}
