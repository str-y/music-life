import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/data/waveform_codec.dart';
import 'package:music_life/services/service_error_handler.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

typedef ReplaceAllRecordingData =
    Future<void> Function({
      required List<Map<String, Object?>> recordings,
      required List<Map<String, Object?>> practiceLogs,
    });
typedef EnsureMigrationDiskSpace = Future<void> Function(int requiredBytes);
typedef PersistBool = Future<bool> Function(String key, bool value);
typedef RemoveValue = Future<bool> Function(String key);

/// Migrates legacy recording data from SharedPreferences into SQLite.
class LegacyDataMigrator {
  LegacyDataMigrator(
    SharedPreferences prefs, {
    AppConfig config = const AppConfig(),
    ReplaceAllRecordingData? replaceAllData,
    EnsureMigrationDiskSpace? ensureMigrationDiskSpace,
    PersistBool? persistBool,
    RemoveValue? removeValue,
  })  : _prefs = prefs,
        _config = config,
        _replaceAllData = replaceAllData ??
            (AppDatabase.instance.replaceAllData),
        _ensureMigrationDiskSpace =
            ensureMigrationDiskSpace ?? _defaultEnsureMigrationDiskSpace,
        _persistBool = persistBool ?? ((key, value) => prefs.setBool(key, value)),
        _removeValue = removeValue ?? prefs.remove;

  // Writes the probe file in 1 MB chunks so the one-time preflight does not
  // allocate the entire estimated migration size in memory.
  static const int _diskSpaceCheckChunkBytes = 1024 * 1024;
  // Reserves an extra 512 KB beyond the serialized payload estimate so small
  // differences in SQLite page growth do not invalidate the preflight check.
  static const int _diskSpaceCheckSafetyMarginBytes = 512 * 1024;
  // Adds roughly 20% headroom for SQLite transaction files, index updates, and
  // page growth while the migrated rows are being written.
  static const int _diskSpaceCheckOverheadDivisor = 5;
  // Accounts for per-row SQLite metadata, page alignment, and row headers when
  // estimating scratch space from serialized payload sizes alone.
  static const int _estimatedRowOverheadBytes = 256;
  static final Uint8List _diskSpaceCheckChunk = Uint8List(
    _diskSpaceCheckChunkBytes,
  );

  /// Guards against concurrent migration calls. Non-null while a migration is
  /// in progress; subsequent callers await this future instead of starting a
  /// second migration. Set back to null when migration fails so it can be
  /// retried on the next access.
  static Completer<void>? _migrationCompleter;

  final SharedPreferences _prefs;
  final AppConfig _config;
  final ReplaceAllRecordingData _replaceAllData;
  final EnsureMigrationDiskSpace _ensureMigrationDiskSpace;
  final PersistBool _persistBool;
  final RemoveValue _removeValue;

  String get _migrationInProgressKey =>
      '${_config.recordingsMigratedStorageKey}_in_progress';

  Future<void> migrateIfNeeded() async {
    // Already completed successfully in this session.
    if (_migrationCompleter?.isCompleted ?? false) return;
    // Migration is already in progress – join it instead of starting another.
    if (_migrationCompleter != null) return _migrationCompleter!.future;

    _migrationCompleter = Completer<void>();
    _migrationCompleter!.future.catchError((_, _) {});
    try {
      if (_prefs.getBool(_config.recordingsMigratedStorageKey) ?? false) {
        AppLogger.debug('RecordingRepository: migration already completed.');
        _migrationCompleter!.complete();
        return;
      }

      if (_prefs.getBool(_migrationInProgressKey) ?? false) {
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
      var currentStage = 'legacy payload parsing';
      var migrationSucceeded = true;

      final recStr = _prefs.getString(_config.recordingsStorageKey);
      if (recStr != null) {
        try {
          final list = jsonDecode(recStr) as List<dynamic>;
          recordingRows.addAll(list.map(_recordingRowFromJson));
        } catch (e, st) {
          ServiceErrorHandler.report(
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
          logRows.addAll(list.map(_practiceLogRowFromJson));
        } catch (e, st) {
          ServiceErrorHandler.report(
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
            throw StateError(
              'Failed to persist migration in-progress state '
              'for $_migrationInProgressKey.',
            );
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
            throw StateError(
              'Failed to persist migration completion state '
              'for ${_config.recordingsMigratedStorageKey}.',
            );
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
          ServiceErrorHandler.report(
            'RecordingRepository: migration failed during $currentStage',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      _migrationCompleter!.complete();
      if (!migrationSucceeded) {
        // Migration was attempted but failed. Completing the Completer normally
        // (rather than with an error) lets concurrent callers proceed.
        _migrationCompleter = null;
      }
    } catch (e, st) {
      ServiceErrorHandler.report(
        'RecordingRepository: migration failed',
        error: e,
        stackTrace: st,
      );
      // Reset so the next caller can retry rather than receiving this error.
      final completer = _migrationCompleter;
      _migrationCompleter = null;
      completer!.completeError(e, st);
    }
  }

  static Map<String, Object?> _recordingRowFromJson(dynamic entry) {
    final json = Map<String, dynamic>.from(entry as Map);
    final waveformData = (json['waveformData'] as List<dynamic>)
        .map((value) => (value as num).toDouble())
        .toList(growable: false);
    return <String, Object?>{
      'id': json['id'] as String,
      'title': json['title'] as String,
      'recorded_at': DateTime.parse(json['recordedAt'] as String).toIso8601String(),
      'duration_seconds': json['durationSeconds'] as int,
      'waveform_data': waveformToBlob(waveformData),
      'audio_file_path': json['audioFilePath'] as String?,
    };
  }

  static Map<String, Object?> _practiceLogRowFromJson(dynamic entry) {
    final json = Map<String, dynamic>.from(entry as Map);
    return <String, Object?>{
      'date': DateTime.parse(json['date'] as String).toIso8601String(),
      'duration_minutes': json['durationMinutes'] as int,
      'memo': json['memo'] as String? ?? '',
    };
  }

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
      var remainingBytes = requiredBytes;
      while (remainingBytes > 0) {
        final nextChunkBytes = min(remainingBytes, _diskSpaceCheckChunk.length);
        await handle.writeFrom(_diskSpaceCheckChunk, 0, nextChunkBytes);
        remainingBytes -= nextChunkBytes;
      }
      await handle.flush();
    } on FileSystemException {
      rethrow;
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
        (recordingRows.length + practiceLogRows.length) * _estimatedRowOverheadBytes;
    final estimatedBytes =
        legacyPayloadBytes + rowPayloadBytes + rowOverheadBytes;
    if (estimatedBytes == 0) {
      return 0;
    }
    return estimatedBytes +
        (estimatedBytes ~/ _diskSpaceCheckOverheadDivisor) +
        _diskSpaceCheckSafetyMarginBytes;
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

  @visibleForTesting
  static void resetStateForTesting() {
    _migrationCompleter = null;
  }
}
