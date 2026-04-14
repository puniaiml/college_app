import 'dart:developer';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

/// Core offline database for entire Shiksha Hub project
/// Caches: Notes, Timetable, Results, Exams, ChatMate, all features
class OfflineDatabase {
  static final OfflineDatabase _instance = OfflineDatabase._internal();
  static Database? _database;

  factory OfflineDatabase() {
    return _instance;
  }

  OfflineDatabase._internal();

  /// Get database instance
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }

  /// Initialize SQLite database with all required tables
  Future<Database> _initializeDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'shiksha_hub_offline.db');

      log('📦 Initializing offline database at: $path');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
      );
    } catch (e) {
      log('❌ Database initialization error: $e');
      rethrow;
    }
  }

  /// Create all required tables for complete Shiksha Hub
  Future<void> _createTables(Database db, int version) async {
    try {
      // ==================== NOTES TABLES ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          branch TEXT,
          semester INTEGER,
          subject TEXT,
          uploadedBy TEXT,
          uploadedAt INTEGER,
          fileUrl TEXT,
          fileName TEXT,
          fileSize INTEGER,
          downloadCount INTEGER DEFAULT 0,
          rating REAL DEFAULT 0,
          description TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_favorites (
          id TEXT PRIMARY KEY,
          noteId TEXT,
          userId TEXT,
          addedAt INTEGER,
          syncStatus TEXT DEFAULT 'pending'
        )
      ''');

      // ==================== TIMETABLE TABLES ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS timetable (
          id TEXT PRIMARY KEY,
          day TEXT NOT NULL,
          startTime TEXT,
          endTime TEXT,
          subject TEXT,
          room TEXT,
          faculty TEXT,
          branch TEXT,
          semester INTEGER,
          type TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      // ==================== RESULTS TABLES ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS results (
          id TEXT PRIMARY KEY,
          studentRoll TEXT,
          semester INTEGER,
          subject TEXT,
          marks REAL,
          maxMarks REAL,
          grade TEXT,
          examDate TEXT,
          publishedDate TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS cgpa (
          id TEXT PRIMARY KEY,
          studentRoll TEXT,
          totalSemesters INTEGER,
          cgpa REAL,
          currentSgpa REAL,
          lastUpdated INTEGER,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      // ==================== EXAMS TABLES ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_schedules (
          id TEXT PRIMARY KEY,
          examName TEXT NOT NULL,
          examDate TEXT,
          startTime TEXT,
          endTime TEXT,
          subject TEXT,
          room TEXT,
          rollNo TEXT,
          semester INTEGER,
          examType TEXT,
          status TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS exam_syllabus (
          id TEXT PRIMARY KEY,
          examId TEXT,
          subject TEXT,
          topic TEXT,
          description TEXT,
          weightage REAL,
          importance TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      // ==================== CHATMATE TABLES ====================
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
          channelId TEXT,
          isSynced INTEGER DEFAULT 1,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
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
          channelId TEXT,
          createdAt INTEGER,
          status TEXT DEFAULT 'pending'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS channels (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          subject TEXT,
          description TEXT,
          createdBy TEXT,
          memberCount INTEGER DEFAULT 0,
          lastMessage TEXT,
          lastMessageTime INTEGER,
          isMember INTEGER DEFAULT 0,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      // ==================== USER PROFILE TABLES ====================
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
          semester INTEGER,
          userType TEXT,
          isFocusMode INTEGER DEFAULT 0,
          pushToken TEXT,
          cachedAt INTEGER,
          syncStatus TEXT DEFAULT 'synced'
        )
      ''');

      // ==================== SYNC QUEUE ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id TEXT PRIMARY KEY,
          operation TEXT NOT NULL,
          entityType TEXT NOT NULL,
          entityId TEXT,
          data TEXT,
          createdAt INTEGER,
          status TEXT DEFAULT 'pending',
          retryCount INTEGER DEFAULT 0,
          lastRetryAt INTEGER
        )
      ''');

      // ==================== OFFLINE CACHE METADATA ====================
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_metadata (
          key TEXT PRIMARY KEY,
          value TEXT,
          lastUpdated INTEGER,
          expiresAt INTEGER
        )
      ''');

      log('✅ All database tables created successfully');
    } catch (e) {
      log('❌ Table creation error: $e');
      rethrow;
    }
  }

  /// Generic insert/update method
  Future<void> saveData(
    String table,
    Map<String, dynamic> data, {
    String syncStatus = 'synced',
  }) async {
    try {
      final db = await database;
      data['cachedAt'] = DateTime.now().millisecondsSinceEpoch;
      data['syncStatus'] = syncStatus;

      await db.insert(
        table,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      log('💾 Data saved to $table');
    } catch (e) {
      log('❌ Error saving data to $table: $e');
    }
  }

  /// Batch insert for multiple records
  Future<void> saveDataBatch(
    String table,
    List<Map<String, dynamic>> dataList, {
    String syncStatus = 'synced',
  }) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final data in dataList) {
        data['cachedAt'] = now;
        data['syncStatus'] = syncStatus;
        batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      await batch.commit();
      log('💾 Batch saved ${dataList.length} records to $table');
    } catch (e) {
      log('❌ Error batch saving to $table: $e');
    }
  }

  /// Retrieve data from cache
  Future<List<Map<String, dynamic>>> getData(
    String table, {
    String? whereClause,
    List<dynamic>? whereArgs,
    String orderBy = 'cachedAt DESC',
  }) async {
    try {
      final db = await database;
      return await db.query(
        table,
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: orderBy,
      );
    } catch (e) {
      log('❌ Error retrieving data from $table: $e');
      return [];
    }
  }

  /// Retrieve single record
  Future<Map<String, dynamic>?> getDataSingle(
    String table, {
    required String whereClause,
    required List<dynamic> whereArgs,
  }) async {
    try {
      final db = await database;
      final results = await db.query(
        table,
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      return results.isEmpty ? null : results.first;
    } catch (e) {
      log('❌ Error retrieving single record from $table: $e');
      return null;
    }
  }

  /// Delete data from cache
  Future<void> deleteData(
    String table, {
    String? whereClause,
    List<dynamic>? whereArgs,
  }) async {
    try {
      final db = await database;
      await db.delete(
        table,
        where: whereClause,
        whereArgs: whereArgs,
      );

      log('🗑️  Data deleted from $table');
    } catch (e) {
      log('❌ Error deleting from $table: $e');
    }
  }

  /// Add operation to sync queue
  Future<void> queueSyncOperation({
    required String operation,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final db = await database;
      final id = '${entityType}_${DateTime.now().millisecondsSinceEpoch}';

      await db.insert(
        'sync_queue',
        {
          'id': id,
          'operation': operation,
          'entityType': entityType,
          'entityId': entityId,
          'data': data != null ? _jsonEncode(data) : null,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'status': 'pending',
          'retryCount': 0,
        },
      );

      log('📤 Operation queued for sync: $operation ($entityType)');
    } catch (e) {
      log('❌ Error queuing operation: $e');
    }
  }

  /// Get pending sync operations
  Future<List<Map<String, dynamic>>> getPendingSyncOperations() async {
    try {
      final db = await database;
      return await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'createdAt ASC',
      );
    } catch (e) {
      log('❌ Error retrieving sync queue: $e');
      return [];
    }
  }

  /// Mark operation as synced
  Future<void> markOperationSynced(String operationId) async {
    try {
      final db = await database;
      await db.update(
        'sync_queue',
        {
          'status': 'synced',
          'lastRetryAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [operationId],
      );

      log('✅ Operation synced: $operationId');
    } catch (e) {
      log('❌ Error marking operation as synced: $e');
    }
  }

  /// Update retry count for failed operation
  Future<void> incrementRetryCount(String operationId) async {
    try {
      final db = await database;
      await db.rawUpdate(
        'UPDATE sync_queue SET retryCount = retryCount + 1, lastRetryAt = ? WHERE id = ?',
        [DateTime.now().millisecondsSinceEpoch, operationId],
      );

      log('🔄 Retry count incremented for: $operationId');
    } catch (e) {
      log('❌ Error incrementing retry count: $e');
    }
  }

  /// Set cache expiration metadata
  Future<void> setCacheMetadata(String key, String value, {Duration? expiresIn}) async {
    try {
      final db = await database;
      final expiresAt = expiresIn != null
          ? DateTime.now().add(expiresIn).millisecondsSinceEpoch
          : null;

      await db.insert(
        'cache_metadata',
        {
          'key': key,
          'value': value,
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': expiresAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log('❌ Error setting cache metadata: $e');
    }
  }

  /// Get cache metadata
  Future<String?> getCacheMetadata(String key) async {
    try {
      final db = await database;
      final result = await db.query(
        'cache_metadata',
        where: 'key = ?',
        whereArgs: [key],
      );

      if (result.isEmpty) return null;

      final metadata = result.first;
      final expiresAt = metadata['expiresAt'] as int?;

      // Check if expired
      if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
        await deleteData('cache_metadata', whereClause: 'key = ?', whereArgs: [key]);
        return null;
      }

      return metadata['value'] as String?;
    } catch (e) {
      log('❌ Error getting cache metadata: $e');
      return null;
    }
  }

  /// Get total database size
  Future<int> getDatabaseSize() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'shiksha_hub_offline.db');
      final file = File(path);

      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      log('❌ Error getting database size: $e');
      return 0;
    }
  }

  /// Get cache statistics
  Future<Map<String, int>> getCacheStats() async {
    try {
      final db = await database;

      final stats = {
        'notes': Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) as count FROM notes'))!,
        'timetable':
            Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) as count FROM timetable'))!,
        'results':
            Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) as count FROM results'))!,
        'exams': Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) as count FROM exam_schedules'))!,
        'messages': Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) as count FROM messages'))!,
        'drafts': Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) as count FROM draft_messages'))!,
        'pendingSync': Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) as count FROM sync_queue WHERE status = "pending"'))!,
      };

      log('📊 Cache stats: $stats');
      return stats;
    } catch (e) {
      log('❌ Error getting cache stats: $e');
      return {};
    }
  }

  /// Clear all offline data (logout)
  Future<void> clearAllOfflineData() async {
    try {
      final db = await database;

      final tables = [
        'notes',
        'note_favorites',
        'timetable',
        'results',
        'cgpa',
        'exam_schedules',
        'exam_syllabus',
        'messages',
        'draft_messages',
        'channels',
        'user_profiles',
        'sync_queue',
        'cache_metadata',
      ];

      for (final table in tables) {
        await db.delete(table);
      }

      log('🗑️  All offline data cleared');
    } catch (e) {
      log('❌ Error clearing offline data: $e');
    }
  }

  /// Clear specific cache (e.g., notes only)
  Future<void> clearCache(String table) async {
    try {
      final db = await database;
      await db.delete(table);
      log('🗑️  Cache cleared: $table');
    } catch (e) {
      log('❌ Error clearing cache $table: $e');
    }
  }

  /// JSON encode helper
  String _jsonEncode(Map<String, dynamic> data) {
    try {
      final entries = <String>[];
      for (final entry in data.entries) {
        final value = entry.value;
        final encoded = value is String ? '"$value"' : '$value';
        entries.add('"${entry.key}":$encoded');
      }
      return '{${entries.join(',')}}';
    } catch (e) {
      return '{}';
    }
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      log('🔐 Database closed');
    }
  }
}
