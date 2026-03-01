import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

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

// ---------------------------------------------------------------------------
// Repository – persists recording metadata and practice logs via SQLite.
// A one-time migration from the legacy SharedPreferences JSON store is
// performed automatically on the first access.
// ---------------------------------------------------------------------------

class RecordingRepository {
  /// Creates a repository backed by the supplied [prefs] instance (for migration).
  const RecordingRepository(this._prefs, {AppConfig config = const AppConfig()})
      : _config = config;

  /// Guards against concurrent migration calls.  Non-null while a migration is
  /// in progress; subsequent callers await this future instead of starting a
  /// second migration.  Set back to null when migration fails so it can be
  /// retried on the next access.
  static Completer<void>? _migrationCompleter;

  final SharedPreferences _prefs;
  final AppConfig _config;

  Future<void> _migrateIfNeeded() async {
    // Already completed successfully in this session.
    if (_migrationCompleter?.isCompleted == true) return;
    // Migration is already in progress – join it instead of starting another.
    if (_migrationCompleter != null) return _migrationCompleter!.future;

    _migrationCompleter = Completer<void>();
    try {
      if (_prefs.getBool(_config.recordingsMigratedStorageKey) == true) {
        _migrationCompleter!.complete();
        return;
      }

      // Parse both data sets before touching the database so that a decode
      // error in one set does not leave the database in a half-migrated state.
      final recordingRows = <Map<String, Object?>>[];
      final logRows = <Map<String, Object?>>[];
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
        // Write both data sets atomically so the database never ends up with
        // recordings migrated but practice logs not (or vice versa).
        try {
          await AppDatabase.instance.replaceAllData(
            recordings: recordingRows,
            practiceLogs: logRows,
          );
          await _prefs.setBool(_config.recordingsMigratedStorageKey, true);
        } catch (e, st) {
          AppLogger.reportError(
            'RecordingRepository: migration DB write failed',
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
    final rows = await AppDatabase.instance.queryAllRecordings();
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
    final rows = await AppDatabase.instance.queryAllPracticeLogs();
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
}
