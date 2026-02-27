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
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE recordings (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            duration_seconds INTEGER NOT NULL,
            waveform_data BLOB NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE practice_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            memo TEXT NOT NULL DEFAULT ''
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migrate waveform_data from JSON TEXT to binary BLOB.
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
          await db.execute(
              'ALTER TABLE recordings_new RENAME TO recordings');
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Recordings
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllRecordings() async {
    final db = await database;
    return db.query('recordings', orderBy: 'recorded_at DESC');
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
      await txn.delete('recordings');
      for (final row in rows) {
        await txn.insert('recordings', row);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Practice logs (LibraryScreen / RecordingRepository)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> queryAllPracticeLogs() async {
    final db = await database;
    return db.query('practice_logs', orderBy: 'date DESC');
  }

  Future<void> replaceAllPracticeLogs(List<Map<String, Object?>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('practice_logs');
      for (final row in rows) {
        await txn.insert('practice_logs', row);
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
      await txn.delete('recordings');
      for (final row in recordings) {
        await txn.insert('recordings', row);
      }
      await txn.delete('practice_logs');
      for (final row in practiceLogs) {
        await txn.insert('practice_logs', row);
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

  /// Closes the underlying SQLite connection and resets the lazy future so that
  /// the database can be re-opened on the next access.  Call this when the app
  /// is disposed to release the file handle promptly.
  Future<void> close() async {
    if (_dbFuture != null) {
      final db = await _dbFuture!;
      await db.close();
      _dbFuture = null;
    }
  }
}
