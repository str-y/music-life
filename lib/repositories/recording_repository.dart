import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';

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
  });

  final String id;
  final String title;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Normalised amplitude values in [0.0, 1.0] used for waveform preview.
  final List<double> waveformData;

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
  const RecordingRepository(this._prefs);

  static const _recordingsKey = 'recordings_v1';
  static const _logsKey = 'practice_logs_v1';
  static const _migratedKey = 'db_migrated_v1';

  /// Cached in memory so the SharedPreferences lookup only happens once per session.
  static bool _migrated = false;

  final SharedPreferences _prefs;

  Future<void> _migrateIfNeeded() async {
    if (_migrated) return;

    if (_prefs.getBool(_migratedKey) == true) {
      _migrated = true;
      return;
    }

    var migrationSucceeded = true;

    // Migrate recordings
    final recStr = _prefs.getString(_recordingsKey);
    if (recStr != null) {
      try {
        final list = jsonDecode(recStr) as List<dynamic>;
        final entries = list
            .map((e) => RecordingEntry.fromJson(e as Map<String, dynamic>))
            .toList();

        await AppDatabase.instance.replaceAllRecordings(
          entries
              .map((e) => {
                    'id': e.id,
                    'title': e.title,
                    'recorded_at': e.recordedAt.toIso8601String(),
                    'duration_seconds': e.durationSeconds,
                    'waveform_data': _waveformToBlob(e.waveformData),
                  })
              .toList(),
        );
      } catch (e, st) {
        debugPrint('RecordingRepository: recording migration failed: $e\n$st');
        migrationSucceeded = false;
      }
    }

    // Migrate practice logs
    final logStr = _prefs.getString(_logsKey);
    if (logStr != null) {
      try {
        final list = jsonDecode(logStr) as List<dynamic>;
        final entries = list
            .map((e) => PracticeLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();

        await AppDatabase.instance.replaceAllPracticeLogs(
          entries
              .map((e) => {
                    'date': e.date.toIso8601String(),
                    'duration_minutes': e.durationMinutes,
                    'memo': e.memo,
                  })
              .toList(),
        );
      } catch (e, st) {
        debugPrint('RecordingRepository: practice log migration failed: $e\n$st');
        migrationSucceeded = false;
      }
    }

    if (migrationSucceeded) {
      await _prefs.setBool(_migratedKey, true);
      _migrated = true;
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
