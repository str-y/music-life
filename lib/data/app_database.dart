import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite database used throughout the app.
///
/// Tables:
///   - recordings          : recording metadata (RecordingEntry)
///   - practice_logs       : practice log entries shown in LibraryScreen
///   - practice_log_entries: practice log entries managed in PracticeLogScreen
///   - compositions        : composition chord progressions
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 5;

  Completer<Database>? _completer;

  Future<Database> get database {
    if (_completer == null) {
      _completer = Completer<Database>();
      _open().then(_completer!.complete, onError: _completer!.completeError);
    }
    return _completer!.future;
  }

  Future<Database> _open() async {
    return openDatabase(
      join(await getDatabasesPath(), 'music_life.db'),
      version: _schemaVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE recordings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            waveform_data BLOB NOT NULL,
            audio_file_path TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE practice_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            memo TEXT NOT NULL DEFAULT '',
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE practice_log_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE compositions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            chords TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        for (final version in _migrationPlan(
          oldVersion: oldVersion,
          newVersion: newVersion,
        )) {
          final migration = _migrations[version];
          if (migration == null) {
            throw StateError('No migration registered for version $version');
          }
          await migration(db);
        }
      },
      onDowngrade: onDatabaseVersionChangeError,
    );
  }

  // ---------------------------------------------------------------------------
  // Recordings
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllRecordings() async {
    final db = await database;
    return db.query(
      'recordings',
      where: 'is_deleted = 0',
      orderBy: 'recorded_at DESC',
    );
  }

  Future<void> insertRecording(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'recordings',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAllRecordings(List<Map<String, Object?>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'recordings',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in rows) {
        await txn.insert(
          'recordings',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Practice logs (LibraryScreen / RecordingRepository)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllPracticeLogs() async {
    final db = await database;
    return db.query(
      'practice_logs',
      where: 'is_deleted = 0',
      orderBy: 'date DESC',
    );
  }

  Future<void> replaceAllPracticeLogs(List<Map<String, Object?>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'practice_logs',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in rows) {
        await txn.insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Atomically replaces all recordings **and** practice logs in a single
  /// transaction so that both data sets move together or not at all.
  /// Used during the one-time SharedPreferences → SQLite migration.
  Future<void> replaceAllData({
    required List<Map<String, Object?>> recordings,
    required List<Map<String, Object?>> practiceLogs,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'recordings',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in recordings) {
        await txn.insert(
          'recordings',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.update(
        'practice_logs',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in practiceLogs) {
        await txn.insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Atomically replaces all backup-eligible data tables.
  Future<void> replaceAllBackupData({
    required List<Map<String, Object?>> recordings,
    required List<Map<String, Object?>> practiceLogs,
    required List<Map<String, Object?>> practiceLogEntries,
    required List<Map<String, Object?>> compositions,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'recordings',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in recordings) {
        await txn.insert(
          'recordings',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.update(
        'practice_logs',
        {'is_deleted': 1},
        where: 'is_deleted = 0',
      );
      for (final row in practiceLogs) {
        await txn.insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete('practice_log_entries');
      for (final row in practiceLogEntries) {
        await txn.insert('practice_log_entries', row);
      }
      await txn.delete('compositions');
      for (final row in compositions) {
        await txn.insert('compositions', row);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Practice log entries (PracticeLogScreen)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllPracticeLogEntries() async {
    final db = await database;
    return db.query('practice_log_entries', orderBy: 'date DESC');
  }

  Future<void> insertPracticeLogEntry(Map<String, Object?> row) async {
    final db = await database;
    await db.insert('practice_log_entries', row);
  }

  // ---------------------------------------------------------------------------
  // Compositions
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllCompositions() async {
    final db = await database;
    return db.query('compositions', orderBy: 'title ASC');
  }

  Future<void> insertComposition(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      'compositions',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteComposition(String id) async {
    final db = await database;
    await db.delete(
      'compositions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> replaceAllCompositions(List<Map<String, Object?>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('compositions');
      for (final row in rows) {
        await txn.insert(
          'compositions',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Closes the underlying SQLite connection and resets the lazy future so that
  /// the database can be re-opened on the next access.  Call this when the app
  /// is disposed to release the file handle promptly.
  Future<void> close() async {
    if (_completer != null) {
      final db = await _completer!.future;
      await db.close();
      _completer = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Migration helpers
  // ---------------------------------------------------------------------------

  static final Map<int, Future<void> Function(DatabaseExecutor)> _migrations = {
    2: _migrateV1ToV2,
    3: _migrateV2ToV3,
    4: _migrateV3ToV4,
    5: _migrateV4ToV5,
  };

  static List<int> _migrationPlan({
    required int oldVersion,
    required int newVersion,
  }) {
    return [
      for (var version = oldVersion + 1; version <= newVersion; version++)
        version,
    ];
  }

  static List<int> migrationPlanForTesting({
    required int oldVersion,
    required int newVersion,
  }) {
    return _migrationPlan(oldVersion: oldVersion, newVersion: newVersion);
  }

  /// Migrates waveform_data from JSON TEXT (v1) to binary BLOB (v2).
  ///
  /// Safe to re-run after a partial failure:
  ///   • If [recordings_new] already exists (interrupted after CREATE TABLE),
  ///     it is dropped and the migration restarts from scratch.
  ///   • If [recordings] was already dropped but [recordings_new] was not yet
  ///     renamed (interrupted between DROP and RENAME), only the rename is
  ///     performed to complete the migration.
  static Future<void> _migrateV1ToV2(DatabaseExecutor db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'"
      " AND name IN ('recordings', 'recordings_new')",
    );
    final tableNames = tables.map((r) => r['name'] as String).toSet();

    // Interrupted between DROP TABLE recordings and RENAME — just finish.
    if (!tableNames.contains('recordings') &&
        tableNames.contains('recordings_new')) {
      await db.execute(
          'ALTER TABLE recordings_new RENAME TO recordings');
      return;
    }

    // Drop any leftover partial table so the migration can restart cleanly.
    await db.execute('DROP TABLE IF EXISTS recordings_new');

    await db.execute('''
      CREATE TABLE recordings_new (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        waveform_data BLOB NOT NULL
      )
    ''');
    final rows = await db.query('recordings');
    for (final row in rows) {
      final jsonStr = row['waveform_data'] as String;
      final doubles = (jsonDecode(jsonStr) as List)
          .map((e) => (e as num).toDouble())
          .toList();
      // Encoding matches _waveformToBlob in recording_repository.dart.
      final byteData = ByteData(doubles.length * 8);
      for (var i = 0; i < doubles.length; i++) {
        byteData.setFloat64(i * 8, doubles[i], Endian.little);
      }
      await db.insert('recordings_new', {
        'id': row['id'],
        'title': row['title'],
        'recorded_at': row['recorded_at'],
        'duration_seconds': row['duration_seconds'],
        'waveform_data': byteData.buffer.asUint8List(),
      });
    }
    await db.execute('DROP TABLE recordings');
    await db.execute('ALTER TABLE recordings_new RENAME TO recordings');
  }

  static Future<void> _migrateV2ToV3(DatabaseExecutor db) async {
    await _ensureSoftDeleteColumn(db, table: 'recordings');
    await _ensureSoftDeleteColumn(db, table: 'practice_logs');
  }

  static Future<void> _migrateV3ToV4(DatabaseExecutor db) async {
    await _ensureAudioFilePathColumn(db);
  }

  static Future<void> _ensureSoftDeleteColumn(
    DatabaseExecutor db, {
    required String table,
  }) async {
    final tableInfoQuery = switch (table) {
      'recordings' => 'PRAGMA table_info(recordings)',
      'practice_logs' => 'PRAGMA table_info(practice_logs)',
      _ => throw ArgumentError.value(table, 'table', 'Unsupported table'),
    };
    final addSoftDeleteColumnQuery = switch (table) {
      'recordings' =>
        'ALTER TABLE recordings ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
      'practice_logs' =>
        'ALTER TABLE practice_logs ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
      _ => throw ArgumentError.value(table, 'table', 'Unsupported table'),
    };
    final columns = await db.rawQuery(tableInfoQuery);
    final hasIsDeleted = columns.any((row) => row['name'] == 'is_deleted');
    if (!hasIsDeleted) {
      await db.execute(addSoftDeleteColumnQuery);
    }
  }

  static Future<void> _ensureAudioFilePathColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(recordings)');
    final hasAudioPath = columns.any((row) => row['name'] == 'audio_file_path');
    if (!hasAudioPath) {
      await db.execute('ALTER TABLE recordings ADD COLUMN audio_file_path TEXT');
    }
  }

  static Future<void> _migrateV4ToV5(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS compositions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        chords TEXT NOT NULL
      )
    ''');
  }
}
