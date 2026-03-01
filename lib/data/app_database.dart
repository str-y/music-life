import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

import '../utils/app_logger.dart';

/// Singleton Drift database used throughout the app.
///
/// Tables:
///   - recordings          : recording metadata (RecordingEntry)
///   - practice_logs       : practice log entries shown in LibraryScreen
///   - practice_log_entries: practice log entries managed in PracticeLogScreen
///   - compositions        : composition chord progressions
///   - chord_analysis_history: persisted chord analysis timeline
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _schemaVersion = 6;
  static const String _databasePasswordKey = 'database_password';

  Completer<_DriftDatabase>? _completer;

  Future<_DriftDatabase> get _database {
    if (_completer == null) {
      _completer = Completer<_DriftDatabase>();
      _open().then(_completer!.complete, onError: _completer!.completeError);
    }
    return _completer!.future;
  }

  Future<_DriftDatabase> _open() async {
    final dbPath = await getDatabasesPath();
    final file = File(join(dbPath, 'music_life.db'));
    final db = _DriftDatabase(NativeDatabase.createInBackground(file));
    try {
      await _verifyIntegrity(db);
      await _migrateIfNeeded(db);
      return db;
    } catch (error, stackTrace) {
      if (!_isCorruptionError(error)) rethrow;
      AppLogger.reportError(
        'Detected SQLite corruption. Recreating database.',
        error: error,
        stackTrace: stackTrace,
      );
      await db.close();
      if (await file.exists()) {
        await file.delete();
      }
      final recoveredDb = _DriftDatabase(NativeDatabase.createInBackground(file));
      await _migrateIfNeeded(recoveredDb);
      return recoveredDb;
    }
  }

  Future<void> ensureHealthy() async {
    await _database;
  }

  Future<void> _verifyIntegrity(_DriftDatabase db) async {
    final checkRows = await db.customSelect('PRAGMA quick_check').get();
    if (checkRows.length != 1) {
      throw StateError(
        'SQLite integrity check failed: found ${checkRows.length} issue reports',
      );
    }
    // PRAGMA quick_check returns a single-column row: 'ok' when healthy.
    final values = checkRows.first.data.values;
    final result = values.isEmpty ? null : values.first;
    if (!_isIntegrityCheckOk(result)) {
      throw StateError('SQLite integrity check failed: $result');
    }
  }

  static bool _isIntegrityCheckOk(Object? result) {
    return result?.toString().trim().toLowerCase() == 'ok';
  }

  static bool _isCorruptionError(Object error) {
    final message = error.toString().toLowerCase();
    if (error is StateError && message.contains('sqlite integrity check failed')) {
      return true;
    }
    return message.contains('database disk image is malformed') ||
        message.contains('file is not a database') ||
        message.contains('database corruption');
  }

  Future<void> _migrateIfNeeded(_DriftDatabase db) async {
    final versionRow =
        await db.customSelect('PRAGMA user_version').getSingle();
    final currentVersion = (versionRow.data['user_version'] as int?) ?? 0;

    if (currentVersion == 0) {
      await _createAllTables(db);
      await db.customStatement('PRAGMA user_version = $_schemaVersion');
      return;
    }

    if (currentVersion > _schemaVersion) {
      throw StateError(
        'Database version $currentVersion is newer than supported version $_schemaVersion',
      );
    }

    for (final version in _migrationPlan(
      oldVersion: currentVersion,
      newVersion: _schemaVersion,
    )) {
      final migration = _migrations[version];
      if (migration == null) {
        throw StateError('No migration registered for version $version');
      }
      await migration(db);
    }

    await db.customStatement('PRAGMA user_version = $_schemaVersion');
  }

  Future<void> _createAllTables(_DriftDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS recordings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        waveform_data BLOB NOT NULL,
        audio_file_path TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS practice_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        memo TEXT NOT NULL DEFAULT '',
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS practice_log_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS compositions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        chords TEXT NOT NULL
      )
    ''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS chord_analysis_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chord_name TEXT NOT NULL,
        detected_at TEXT NOT NULL
      )
    ''');
  }

  Future<List<Map<String, Object?>>> _select(
    String sql, {
    List<Variable> variables = const [],
  }) async {
    final db = await _database;
    final rows = await db.customSelect(sql, variables: variables).get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  Future<void> _statement(String sql, [List<Object?> args = const []]) async {
    final db = await _database;
    await db.customStatement(sql, args);
  }

  Future<void> _transaction(Future<void> Function() action) async {
    final db = await _database;
    await db.transaction(action);
  }

  Future<void> _insert(
    String table,
    Map<String, Object?> row, {
    bool replace = false,
  }) {
    final command = replace ? 'INSERT OR REPLACE' : 'INSERT';
    final columns = row.keys.join(', ');
    final placeholders = List.filled(row.length, '?').join(', ');
    return _statement(
      '$command INTO $table ($columns) VALUES ($placeholders)',
      row.values.toList(growable: false),
    );
  }

  Future<void> _update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?> whereArgs = const [],
  }) {
    final entries = values.entries.toList(growable: false);
    final assignments = entries.map((entry) => '${entry.key} = ?').join(', ');
    return _statement(
      'UPDATE $table SET $assignments WHERE $where',
      [
        ...entries.map((entry) => entry.value),
        ...whereArgs,
      ],
    );
  }

  Future<void> _delete(
    String table, {
    String? where,
    List<Object?> whereArgs = const [],
  }) {
    final clause = where == null ? '' : ' WHERE $where';
    return _statement('DELETE FROM $table$clause', whereArgs);
  }

  // ---------------------------------------------------------------------------
  // Recordings
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllRecordings() {
    return _select(
      'SELECT * FROM recordings WHERE is_deleted = 0 ORDER BY recorded_at DESC',
    );
  }

  Future<void> insertRecording(Map<String, Object?> row) {
    return _insert('recordings', row, replace: true);
  }

  Future<void> replaceAllRecordings(List<Map<String, Object?>> rows) async {
    await _transaction(() async {
      await _update('recordings', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in rows) {
        await _insert(
          'recordings',
          {...row, 'is_deleted': 0},
          replace: true,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Practice logs (LibraryScreen / RecordingRepository)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllPracticeLogs() {
    return _select(
      'SELECT * FROM practice_logs WHERE is_deleted = 0 ORDER BY date DESC',
    );
  }

  Future<void> replaceAllPracticeLogs(List<Map<String, Object?>> rows) async {
    await _transaction(() async {
      await _update('practice_logs', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in rows) {
        await _insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          replace: true,
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
    await _transaction(() async {
      await _update('recordings', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in recordings) {
        await _insert(
          'recordings',
          {...row, 'is_deleted': 0},
          replace: true,
        );
      }
      await _update('practice_logs', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in practiceLogs) {
        await _insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          replace: true,
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
    await _transaction(() async {
      await _update('recordings', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in recordings) {
        await _insert(
          'recordings',
          {...row, 'is_deleted': 0},
          replace: true,
        );
      }
      await _update('practice_logs', {'is_deleted': 1}, where: 'is_deleted = 0');
      for (final row in practiceLogs) {
        await _insert(
          'practice_logs',
          {...row, 'is_deleted': 0},
          replace: true,
        );
      }
      await _delete('practice_log_entries');
      for (final row in practiceLogEntries) {
        await _insert('practice_log_entries', row);
      }
      await _delete('compositions');
      for (final row in compositions) {
        await _insert('compositions', row);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Practice log entries (PracticeLogScreen)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllPracticeLogEntries() {
    return _select('SELECT * FROM practice_log_entries ORDER BY date DESC');
  }

  Future<void> insertPracticeLogEntry(Map<String, Object?> row) {
    return _insert('practice_log_entries', row);
  }

  // ---------------------------------------------------------------------------
  // Compositions
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllCompositions() {
    return _select('SELECT * FROM compositions ORDER BY title ASC');
  }

  Future<void> insertComposition(Map<String, Object?> row) {
    return _insert('compositions', row, replace: true);
  }

  Future<void> deleteComposition(String id) {
    return _delete('compositions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceAllCompositions(List<Map<String, Object?>> rows) async {
    await _transaction(() async {
      await _delete('compositions');
      for (final row in rows) {
        await _insert('compositions', row, replace: true);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Chord analysis history
  // ---------------------------------------------------------------------------

  Future<void> insertChordAnalysisHistory(Map<String, Object?> row) {
    return _insert('chord_analysis_history', row);
  }

  Future<List<Map<String, Object?>>> queryChordAnalysisHistory({
    DateTime? from,
    DateTime? to,
    String? chordName,
  }) {
    final clauses = <String>[];
    final variables = <Variable>[];

    if (from != null) {
      clauses.add('detected_at >= ?');
      variables.add(Variable.withString(from.toIso8601String()));
    }
    if (to != null) {
      clauses.add('detected_at < ?');
      variables.add(Variable.withString(to.toIso8601String()));
    }
    final normalizedChord = chordName?.trim();
    if (normalizedChord != null && normalizedChord.isNotEmpty) {
      clauses.add('LOWER(chord_name) LIKE ?');
      variables.add(Variable.withString('%${normalizedChord.toLowerCase()}%'));
    }

    final whereClause = clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}';
    return _select(
      'SELECT * FROM chord_analysis_history$whereClause ORDER BY detected_at DESC',
      variables: variables,
    );
  }

  /// Closes the underlying Drift connection and resets the lazy future so that
  /// the database can be re-opened on the next access. Call this when the app
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

  static final Map<int, Future<void> Function(_DriftDatabase)> _migrations = {
    2: _migrateV1ToV2,
    3: _migrateV2ToV3,
    4: _migrateV3ToV4,
    5: _migrateV4ToV5,
    6: _migrateV5ToV6,
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

  @visibleForTesting
  static Future<String> databasePasswordForTesting() {
    return _resolveDatabasePassword();
  }

  @visibleForTesting
  static bool integrityCheckResultIsOkForTesting(Object? result) {
    return _isIntegrityCheckOk(result);
  }

  @visibleForTesting
  static bool isCorruptionErrorForTesting(Object error) {
    return _isCorruptionError(error);
  }

  static Future<String> _resolveDatabasePassword() async {
    final prefs = await SharedPreferences.getInstance();
    final existingPassword = prefs.getString(_databasePasswordKey);
    if (existingPassword != null && existingPassword.isNotEmpty) {
      return existingPassword;
    }

    final random = Random.secure();
    final generatedPassword = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await prefs.setString(_databasePasswordKey, generatedPassword);
    return generatedPassword;
  }

  /// Migrates waveform_data from JSON TEXT (v1) to binary BLOB (v2).
  ///
  /// Safe to re-run after a partial failure:
  ///   • If [recordings_new] already exists (interrupted after CREATE TABLE),
  ///     it is dropped and the migration restarts from scratch.
  ///   • If [recordings] was already dropped but [recordings_new] was not yet
  ///     renamed (interrupted between DROP and RENAME), only the rename is
  ///     performed to complete the migration.
  static Future<void> _migrateV1ToV2(_DriftDatabase db) async {
    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'"
      " AND name IN ('recordings', 'recordings_new')",
    ).get();
    final tableNames = tables
        .map((row) => row.data['name'])
        .whereType<String>()
        .toSet();

    // Interrupted between DROP TABLE recordings and RENAME — just finish.
    if (!tableNames.contains('recordings') &&
        tableNames.contains('recordings_new')) {
      await db.customStatement('ALTER TABLE recordings_new RENAME TO recordings');
      return;
    }

    // Drop any leftover partial table so the migration can restart cleanly.
    await db.customStatement('DROP TABLE IF EXISTS recordings_new');

    await db.customStatement('''
      CREATE TABLE recordings_new (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        recorded_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        waveform_data BLOB NOT NULL
      )
    ''');
    final rows = await db.customSelect('SELECT * FROM recordings').get();
    for (final resultRow in rows) {
      final row = resultRow.data;
      final jsonStr = row['waveform_data'] as String;
      final doubles =
          (jsonDecode(jsonStr) as List).map((e) => (e as num).toDouble()).toList();
      // Encoding matches _waveformToBlob in recording_repository.dart.
      final byteData = ByteData(doubles.length * 8);
      for (var i = 0; i < doubles.length; i++) {
        byteData.setFloat64(i * 8, doubles[i], Endian.little);
      }
      await db.customStatement(
        '''
        INSERT INTO recordings_new (
          id,
          title,
          recorded_at,
          duration_seconds,
          waveform_data
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        [
          row['id'],
          row['title'],
          row['recorded_at'],
          row['duration_seconds'],
          byteData.buffer.asUint8List(),
        ],
      );
    }
    await db.customStatement('DROP TABLE recordings');
    await db.customStatement('ALTER TABLE recordings_new RENAME TO recordings');
  }

  static Future<void> _migrateV2ToV3(_DriftDatabase db) async {
    await _ensureSoftDeleteColumn(db, table: 'recordings');
    await _ensureSoftDeleteColumn(db, table: 'practice_logs');
  }

  static Future<void> _migrateV3ToV4(_DriftDatabase db) async {
    await _ensureAudioFilePathColumn(db);
  }

  static Future<void> _ensureSoftDeleteColumn(
    _DriftDatabase db, {
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
    final columns = await db.customSelect(tableInfoQuery).get();
    final hasIsDeleted = columns.any((row) => row.data['name'] == 'is_deleted');
    if (!hasIsDeleted) {
      await db.customStatement(addSoftDeleteColumnQuery);
    }
  }

  static Future<void> _ensureAudioFilePathColumn(_DriftDatabase db) async {
    final columns = await db.customSelect('PRAGMA table_info(recordings)').get();
    final hasAudioPath = columns.any((row) => row.data['name'] == 'audio_file_path');
    if (!hasAudioPath) {
      await db.customStatement('ALTER TABLE recordings ADD COLUMN audio_file_path TEXT');
    }
  }

  static Future<void> _migrateV4ToV5(_DriftDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS compositions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        chords TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _migrateV5ToV6(_DriftDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS chord_analysis_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chord_name TEXT NOT NULL,
        detected_at TEXT NOT NULL
      )
    ''');
  }

}

class _DriftDatabase extends DatabaseConnectionUser {
  _DriftDatabase(QueryExecutor executor)
      : super(DatabaseConnection.fromExecutor(executor));

  @override
  GeneratedDatabase get attachedDatabase => throw UnimplementedError();
}
