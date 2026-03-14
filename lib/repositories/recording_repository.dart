import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

import '../config/app_config.dart';
import '../data/app_database.dart';
import '../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// Waveform binary encoding helpers
// ---------------------------------------------------------------------------

/// Encodes a list of [double] amplitude values as a packed IEEE 754 BLOB.
Uint8List _waveformToBlob(List<double> data) {
  final bytes = ByteData(data.length * 8);
  for (var i = 0; i < data.length; i++) {
    bytes.setFloat64(i * 8, data[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Decodes a packed IEEE 754 BLOB back to a list of [double] values.
List<double> _blobToWaveform(Uint8List blob) {
  final bytes = ByteData.sublistView(blob);
  return List.generate(blob.length ~/ 8, (i) => bytes.getFloat64(i * 8, Endian.little));
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Metadata for a single recording persisted by the app.
class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.durationSeconds,
    required this.waveformData,
    this.audioFilePath,
  });

  final String id;
  final String title;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Normalised amplitude values in [0.0, 1.0] used for waveform preview.
  final List<double> waveformData;
  final String? audioFilePath;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recordedAt': recordedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'waveformData': waveformData,
        'audioFilePath': audioFilePath,
      };

  factory RecordingEntry.fromJson(Map<String, dynamic> json) {
    return RecordingEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      waveformData: (json['waveformData'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      audioFilePath: json['audioFilePath'] as String?,
    );
  }
}

/// Aggregated daily practice log data.
class PracticeLogEntry {
  const PracticeLogEntry({
    required this.date,
    required this.durationMinutes,
    this.memo = '',
  });

  final DateTime date;
  final int durationMinutes;
  final String memo;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'memo': memo,
      };

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) {
    return PracticeLogEntry(
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['durationMinutes'] as int,
      memo: json['memo'] as String? ?? '',
    );
  }
}

typedef _ReplaceAllData =
    Future<void> Function({
      required List<Map<String, Object?>> recordings,
      required List<Map<String, Object?>> practiceLogs,
    });
typedef _QueryAllRows = Future<List<Map<String, Object?>>> Function();
typedef _EnsureMigrationDiskSpace = Future<void> Function(int requiredBytes);
typedef _PersistBool = Future<bool> Function(String key, bool value);
typedef _RemoveValue = Future<bool> Function(String key);

// ---------------------------------------------------------------------------
// Repository – persists recording metadata and practice logs via SQLite.
// A one-time migration from the legacy SharedPreferences JSON store is
// performed automatically on the first access.
// ---------------------------------------------------------------------------

/// Persists recordings and practice logs with one-time legacy migration support.
class RecordingRepository {
  static const int _diskSpaceCheckChunkBytes = 1024 * 1024;
  static const int _diskSpaceCheckSafetyMarginBytes = 512 * 1024;

  /// Creates a repository backed by the supplied [prefs] instance (for migration).
  RecordingRepository(
    SharedPreferences prefs, {
    AppConfig config = const AppConfig(),
    Future<void> Function({
      required List<Map<String, Object?>> recordings,
      required List<Map<String, Object?>> practiceLogs,
    })? replaceAllData,
    Future<List<Map<String, Object?>>> Function()? queryAllRecordings,
    Future<List<Map<String, Object?>>> Function()? queryAllPracticeLogs,
    Future<void> Function(int requiredBytes)? ensureMigrationDiskSpace,
    Future<bool> Function(String key, bool value)? persistBool,
    Future<bool> Function(String key)? removeValue,
  })  : _prefs = prefs,
        _config = config,
        _replaceAllData =
            replaceAllData ??
            ({
              required recordings,
              required practiceLogs,
            }) => AppDatabase.instance.replaceAllData(
              recordings: recordings,
              practiceLogs: practiceLogs,
            ),
        _queryAllRecordings =
            queryAllRecordings ?? AppDatabase.instance.queryAllRecordings,
        _queryAllPracticeLogs =
            queryAllPracticeLogs ?? AppDatabase.instance.queryAllPracticeLogs,
        _ensureMigrationDiskSpace =
            ensureMigrationDiskSpace ?? _defaultEnsureMigrationDiskSpace,
        _persistBool = persistBool ?? ((key, value) => prefs.setBool(key, value)),
        _removeValue = removeValue ?? prefs.remove;

  /// Guards against concurrent migration calls.  Non-null while a migration is
  /// in progress; subsequent callers await this future instead of starting a
  /// second migration.  Set back to null when migration fails so it can be
  /// retried on the next access.
  static Completer<void>? _migrationCompleter;

  final SharedPreferences _prefs;
  final AppConfig _config;
  final _ReplaceAllData _replaceAllData;
  final _QueryAllRows _queryAllRecordings;
  final _QueryAllRows _queryAllPracticeLogs;
  final _EnsureMigrationDiskSpace _ensureMigrationDiskSpace;
  final _PersistBool _persistBool;
  final _RemoveValue _removeValue;

  String get _migrationInProgressKey =>
      '${_config.recordingsMigratedStorageKey}_in_progress';

  static Future<void> _defaultEnsureMigrationDiskSpace(int requiredBytes) async {
    if (requiredBytes <= 0) {
      return;
    }

    final databasesPath = await getDatabasesPath();
    final directory = Directory(databasesPath);
    await directory.create(recursive: true);
    final probeFile = File(
      p.join(
        directory.path,
        '.recording_migration_space_check_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    RandomAccessFile? handle;
    try {
      handle = await probeFile.open(mode: FileMode.write);
      final chunk = Uint8List(_diskSpaceCheckChunkBytes);
      var remainingBytes = requiredBytes;
      while (remainingBytes > 0) {
        final nextChunkBytes = min(remainingBytes, chunk.length);
        await handle.writeFrom(chunk, 0, nextChunkBytes);
        remainingBytes -= nextChunkBytes;
      }
      await handle.flush();
    } on FileSystemException catch (error) {
      throw StateError(
        'Insufficient disk space for recording migration '
        '(${requiredBytes} bytes required): $error',
      );
    } finally {
      await handle?.close();
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
    }
  }

  static int _estimateMigrationBytes({
    required String? recordingsPayload,
    required String? practiceLogsPayload,
    required List<Map<String, Object?>> recordingRows,
    required List<Map<String, Object?>> practiceLogRows,
  }) {
    final legacyPayloadBytes =
        (recordingsPayload == null ? 0 : utf8.encode(recordingsPayload).length) +
        (practiceLogsPayload == null ? 0 : utf8.encode(practiceLogsPayload).length);
    final rowPayloadBytes =
        recordingRows.fold<int>(0, _estimateRowBytes) +
        practiceLogRows.fold<int>(0, _estimateRowBytes);
    final rowOverheadBytes =
        (recordingRows.length + practiceLogRows.length) * 256;
    final estimatedBytes =
        legacyPayloadBytes + rowPayloadBytes + rowOverheadBytes;
    if (estimatedBytes == 0) {
      return 0;
    }
    return estimatedBytes + (estimatedBytes ~/ 5) + _diskSpaceCheckSafetyMarginBytes;
  }

  static int _estimateRowBytes(int total, Map<String, Object?> row) {
    return total +
        row.values.fold<int>(0, (rowTotal, value) {
          if (value == null) {
            return rowTotal;
          }
          if (value is Uint8List) {
            return rowTotal + value.length;
          }
          if (value is String) {
            return rowTotal + utf8.encode(value).length;
          }
          return rowTotal + utf8.encode(value.toString()).length;
        });
  }

  Future<void> _migrateIfNeeded() async {
    // Already completed successfully in this session.
    if (_migrationCompleter?.isCompleted == true) return;
    // Migration is already in progress – join it instead of starting another.
    if (_migrationCompleter != null) return _migrationCompleter!.future;

    _migrationCompleter = Completer<void>();
    try {
      if (_prefs.getBool(_config.recordingsMigratedStorageKey) == true) {
        AppLogger.debug('RecordingRepository: migration already completed.');
        _migrationCompleter!.complete();
        return;
      }

      if (_prefs.getBool(_migrationInProgressKey) == true) {
        AppLogger.warning(
          'RecordingRepository: interrupted migration detected; retrying.',
        );
      } else {
        AppLogger.info('RecordingRepository: checking legacy storage migration.');
      }

      // Parse both data sets before touching the database so that a decode
      // error in one set does not leave the database in a half-migrated state.
      final recordingRows = <Map<String, Object?>>[];
      final logRows = <Map<String, Object?>>[];
      String currentStage = 'legacy payload parsing';
      var migrationSucceeded = true;

      final recStr = _prefs.getString(_config.recordingsStorageKey);
      if (recStr != null) {
        try {
          final list = jsonDecode(recStr) as List<dynamic>;
          recordingRows.addAll(
            list
                .map((e) => RecordingEntry.fromJson(e as Map<String, dynamic>))
                .map((e) => <String, Object?>{
                      'id': e.id,
                      'title': e.title,
                      'recorded_at': e.recordedAt.toIso8601String(),
                      'duration_seconds': e.durationSeconds,
                      'waveform_data': _waveformToBlob(e.waveformData),
                      'audio_file_path': e.audioFilePath,
                    }),
          );
        } catch (e, st) {
          AppLogger.reportError(
            'RecordingRepository: recording migration failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      final logStr = _prefs.getString(_config.practiceLogsStorageKey);
      if (logStr != null) {
        try {
          final list = jsonDecode(logStr) as List<dynamic>;
          logRows.addAll(
            list
                .map(
                    (e) => PracticeLogEntry.fromJson(e as Map<String, dynamic>))
                .map((e) => <String, Object?>{
                      'date': e.date.toIso8601String(),
                      'duration_minutes': e.durationMinutes,
                      'memo': e.memo,
                    }),
          );
        } catch (e, st) {
          AppLogger.reportError(
            'RecordingRepository: practice log migration failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      if (migrationSucceeded) {
        AppLogger.info(
          'RecordingRepository: prepared ${recordingRows.length} recordings '
          'and ${logRows.length} practice logs for migration.',
        );
        try {
          currentStage = 'migration state persistence';
          final inProgressSaved = await _persistBool(_migrationInProgressKey, true);
          if (!inProgressSaved) {
            throw StateError('Failed to persist migration in-progress state.');
          }

          final estimatedBytes = _estimateMigrationBytes(
            recordingsPayload: recStr,
            practiceLogsPayload: logStr,
            recordingRows: recordingRows,
            practiceLogRows: logRows,
          );
          AppLogger.info(
            'RecordingRepository: estimated migration scratch space '
            'at $estimatedBytes bytes.',
          );

          currentStage = 'disk space verification';
          await _ensureMigrationDiskSpace(estimatedBytes);
          AppLogger.info('RecordingRepository: disk space check passed.');

          currentStage = 'transactional database write';
          await _replaceAllData(
            recordings: recordingRows,
            practiceLogs: logRows,
          );
          AppLogger.info('RecordingRepository: database migration write committed.');

          currentStage = 'migration completion persistence';
          final migratedSaved = await _persistBool(
            _config.recordingsMigratedStorageKey,
            true,
          );
          if (!migratedSaved) {
            throw StateError('Failed to persist migration completion state.');
          }

          final clearedInProgress = await _removeValue(_migrationInProgressKey);
          if (!clearedInProgress) {
            AppLogger.warning(
              'RecordingRepository: migration completed but in-progress marker '
              'could not be cleared.',
            );
          }

          AppLogger.info('RecordingRepository: migration completed successfully.');
        } catch (e, st) {
          AppLogger.reportError(
            'RecordingRepository: migration failed during $currentStage',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      _migrationCompleter!.complete();
      if (!migrationSucceeded) {
        // Migration was attempted but failed.  Completing the Completer
        // normally (rather than with an error) lets concurrent callers
        // proceed to the underlying database query — migration failure is
        // non-fatal and the DB may still contain valid data from a previous
        // successful migration.  Resetting to null allows a retry on the
        // next session access.
        _migrationCompleter = null;
      }
    } catch (e, st) {
      AppLogger.reportError(
        'RecordingRepository: migration failed',
        error: e,
        stackTrace: st,
      );
      // Reset so the next caller can retry rather than receiving this error.
      final c = _migrationCompleter;
      _migrationCompleter = null;
      c!.completeError(e, st);
    }
  }

  Future<List<RecordingEntry>> loadRecordings() async {
    await _migrateIfNeeded();
    final rows = await _queryAllRecordings();
    return rows
        .map((row) => RecordingEntry(
              id: row['id'] as String,
              title: row['title'] as String,
              recordedAt: DateTime.parse(row['recorded_at'] as String),
              durationSeconds: row['duration_seconds'] as int,
              waveformData:
                  _blobToWaveform(row['waveform_data'] as Uint8List),
              audioFilePath: row['audio_file_path'] as String?,
            ))
        .toList();
  }

  Future<void> saveRecordings(List<RecordingEntry> recordings) async {
    await AppDatabase.instance.replaceAllRecordings(
      recordings
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'recorded_at': e.recordedAt.toIso8601String(),
                'duration_seconds': e.durationSeconds,
                'waveform_data': _waveformToBlob(e.waveformData),
                'audio_file_path': e.audioFilePath,
              })
          .toList(),
    );
  }

  Future<List<PracticeLogEntry>> loadPracticeLogs() async {
    await _migrateIfNeeded();
    final rows = await _queryAllPracticeLogs();
    return rows
        .map((row) => PracticeLogEntry(
              date: DateTime.parse(row['date'] as String),
              durationMinutes: row['duration_minutes'] as int,
              memo: row['memo'] as String? ?? '',
            ))
        .toList();
  }

  Future<void> savePracticeLogs(List<PracticeLogEntry> logs) async {
    await AppDatabase.instance.replaceAllPracticeLogs(
      logs
          .map((e) => {
                'date': e.date.toIso8601String(),
                'duration_minutes': e.durationMinutes,
                'memo': e.memo,
              })
          .toList(),
    );
  }

  @visibleForTesting
  static void resetMigrationStateForTesting() {
    _migrationCompleter = null;
  }
}
