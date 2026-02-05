import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer' as dev;

/// Represents a queued blood pressure reading waiting to be synced
class QueuedReading {
  final int? id;
  final int systolic;
  final int diastolic;
  final int heartRate;
  final DateTime readingDate;
  final String deviceId;
  final String userEmail;
  final DateTime queuedAt;
  final int retryCount;
  final String? lastError;

  QueuedReading({
    this.id,
    required this.systolic,
    required this.diastolic,
    required this.heartRate,
    required this.readingDate,
    required this.deviceId,
    required this.userEmail,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'systolic': systolic,
      'diastolic': diastolic,
      'heart_rate': heartRate,
      'reading_date': readingDate.toIso8601String(),
      'device_id': deviceId,
      'user_email': userEmail,
      'queued_at': queuedAt.toIso8601String(),
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory QueuedReading.fromMap(Map<String, dynamic> map) {
    return QueuedReading(
      id: map['id'] as int?,
      systolic: map['systolic'] as int,
      diastolic: map['diastolic'] as int,
      heartRate: map['heart_rate'] as int,
      readingDate: DateTime.parse(map['reading_date'] as String),
      deviceId: map['device_id'] as String,
      userEmail: map['user_email'] as String,
      queuedAt: DateTime.parse(map['queued_at'] as String),
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  QueuedReading copyWith({
    int? id,
    int? systolic,
    int? diastolic,
    int? heartRate,
    DateTime? readingDate,
    String? deviceId,
    String? userEmail,
    DateTime? queuedAt,
    int? retryCount,
    String? lastError,
  }) {
    return QueuedReading(
      id: id ?? this.id,
      systolic: systolic ?? this.systolic,
      diastolic: diastolic ?? this.diastolic,
      heartRate: heartRate ?? this.heartRate,
      readingDate: readingDate ?? this.readingDate,
      deviceId: deviceId ?? this.deviceId,
      userEmail: userEmail ?? this.userEmail,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// Service for managing offline queue of blood pressure readings
class OfflineQueueService {
  static const String _dbName = 'offline_queue.db';
  static const String _tableName = 'queued_readings';
  static const int _dbVersion = 1;
  static const int _maxRetries = 5;

  Database? _database;
  static OfflineQueueService? _instance;

  OfflineQueueService._();

  static OfflineQueueService get instance {
    _instance ??= OfflineQueueService._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    dev.log('Initializing offline queue database at: $path');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        systolic INTEGER NOT NULL,
        diastolic INTEGER NOT NULL,
        heart_rate INTEGER NOT NULL,
        reading_date TEXT NOT NULL,
        device_id TEXT NOT NULL,
        user_email TEXT NOT NULL,
        queued_at TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      )
    ''');

    // Index for faster queries
    await db.execute('''
      CREATE INDEX idx_user_email ON $_tableName(user_email)
    ''');
    await db.execute('''
      CREATE INDEX idx_queued_at ON $_tableName(queued_at)
    ''');

    dev.log('Offline queue database tables created');
  }

  /// Add a reading to the offline queue
  Future<int> queueReading({
    required int systolic,
    required int diastolic,
    required int heartRate,
    required DateTime readingDate,
    required String deviceId,
    required String userEmail,
  }) async {
    final db = await database;

    final reading = QueuedReading(
      systolic: systolic,
      diastolic: diastolic,
      heartRate: heartRate,
      readingDate: readingDate,
      deviceId: deviceId,
      userEmail: userEmail,
      queuedAt: DateTime.now(),
    );

    final id = await db.insert(_tableName, reading.toMap());
    dev.log('Queued reading ID $id for $userEmail (${systolic}/${diastolic})');
    return id;
  }

  /// Get all pending readings for a user
  Future<List<QueuedReading>> getPendingReadings({String? userEmail}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps;
    if (userEmail != null) {
      maps = await db.query(
        _tableName,
        where: 'user_email = ? AND retry_count < ?',
        whereArgs: [userEmail, _maxRetries],
        orderBy: 'queued_at ASC',
      );
    } else {
      maps = await db.query(
        _tableName,
        where: 'retry_count < ?',
        whereArgs: [_maxRetries],
        orderBy: 'queued_at ASC',
      );
    }

    return maps.map((map) => QueuedReading.fromMap(map)).toList();
  }

  /// Get count of pending readings
  Future<int> getPendingCount({String? userEmail}) async {
    final db = await database;

    final result = await db.rawQuery(
      userEmail != null
          ? 'SELECT COUNT(*) as count FROM $_tableName WHERE user_email = ? AND retry_count < ?'
          : 'SELECT COUNT(*) as count FROM $_tableName WHERE retry_count < ?',
      userEmail != null ? [userEmail, _maxRetries] : [_maxRetries],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Mark a reading as successfully synced (removes from queue)
  Future<void> markSynced(int readingId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [readingId],
    );
    dev.log('Removed synced reading ID $readingId from queue');
  }

  /// Mark a reading as failed and increment retry count
  Future<void> markFailed(int readingId, String error) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE $_tableName
      SET retry_count = retry_count + 1, last_error = ?
      WHERE id = ?
    ''', [error, readingId]);
    dev.log('Marked reading ID $readingId as failed: $error');
  }

  /// Get readings that have exceeded max retries
  Future<List<QueuedReading>> getFailedReadings({String? userEmail}) async {
    final db = await database;

    final List<Map<String, dynamic>> maps;
    if (userEmail != null) {
      maps = await db.query(
        _tableName,
        where: 'user_email = ? AND retry_count >= ?',
        whereArgs: [userEmail, _maxRetries],
        orderBy: 'queued_at ASC',
      );
    } else {
      maps = await db.query(
        _tableName,
        where: 'retry_count >= ?',
        whereArgs: [_maxRetries],
        orderBy: 'queued_at ASC',
      );
    }

    return maps.map((map) => QueuedReading.fromMap(map)).toList();
  }

  /// Reset retry count for a reading (allow retrying)
  Future<void> resetRetryCount(int readingId) async {
    final db = await database;
    await db.update(
      _tableName,
      {'retry_count': 0, 'last_error': null},
      where: 'id = ?',
      whereArgs: [readingId],
    );
    dev.log('Reset retry count for reading ID $readingId');
  }

  /// Clear all readings for a user
  Future<int> clearQueue({String? userEmail}) async {
    final db = await database;

    if (userEmail != null) {
      return await db.delete(
        _tableName,
        where: 'user_email = ?',
        whereArgs: [userEmail],
      );
    } else {
      return await db.delete(_tableName);
    }
  }

  /// Close the database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
