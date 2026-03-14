import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RecordingEntry', () {
    final entry = RecordingEntry(
      id: 'abc123',
      title: 'Session 1',
      recordedAt: DateTime(2024, 3, 15, 10, 30),
      durationSeconds: 125,
      waveformData: const [0.1, 0.5, 0.9],
    );

    test('formattedDuration pads minutes and seconds', () {
      expect(entry.formattedDuration, '02:05');
    });

    test('formattedDuration for zero seconds is 00:00', () {
      final zero = RecordingEntry(
        id: 'z',
        title: 'Zero',
        recordedAt: DateTime(2024),
        durationSeconds: 0,
        waveformData: const [],
      );
      expect(zero.formattedDuration, '00:00');
    });

    test('toJson produces expected map', () {
      final json = entry.toJson();
      expect(json['id'], 'abc123');
      expect(json['title'], 'Session 1');
      expect(json['recordedAt'], '2024-03-15T10:30:00.000');
      expect(json['durationSeconds'], 125);
      expect(json['waveformData'], [0.1, 0.5, 0.9]);
    });

    test('fromJson round-trips through toJson', () {
      final restored = RecordingEntry.fromJson(entry.toJson());
      expect(restored.id, entry.id);
      expect(restored.title, entry.title);
      expect(restored.recordedAt, entry.recordedAt);
      expect(restored.durationSeconds, entry.durationSeconds);
      expect(restored.waveformData, entry.waveformData);
    });

    test('fromJson accepts integer waveform values', () {
      final json = {
        'id': 'x',
        'title': 'X',
        'recordedAt': '2024-01-01T00:00:00.000',
        'durationSeconds': 10,
        'waveformData': [0, 1],
      };
      final restored = RecordingEntry.fromJson(json);
      expect(restored.waveformData, [0.0, 1.0]);
    });
  });

  group('PracticeLogEntry', () {
    final entry = PracticeLogEntry(
      date: DateTime(2024, 6, 1),
      durationMinutes: 45,
      memo: 'Scales and arpeggios',
    );

    test('toJson produces expected map', () {
      final json = entry.toJson();
      expect(json['date'], '2024-06-01T00:00:00.000');
      expect(json['durationMinutes'], 45);
      expect(json['memo'], 'Scales and arpeggios');
    });

    test('fromJson round-trips through toJson', () {
      final restored = PracticeLogEntry.fromJson(entry.toJson());
      expect(restored.date, entry.date);
      expect(restored.durationMinutes, entry.durationMinutes);
      expect(restored.memo, entry.memo);
    });

    test('fromJson defaults memo to empty string when absent', () {
      final json = {
        'date': '2024-06-01T00:00:00.000',
        'durationMinutes': 30,
      };
      final restored = PracticeLogEntry.fromJson(json);
      expect(restored.memo, '');
    });
  });

  group('RecordingRepository migration', () {
    late SharedPreferences prefs;
    late AppConfig config;
    late List<Map<String, Object?>> currentRecordingRows;
    late List<Map<String, Object?>> currentPracticeLogRows;
    late int replaceAllDataCalls;
    late int diskSpaceChecks;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      config = const AppConfig(
        recordingsStorageKey: 'test_recordings_v1',
        practiceLogsStorageKey: 'test_practice_logs_v1',
        recordingsMigratedStorageKey: 'test_db_migrated_v1',
      );
      currentRecordingRows = <Map<String, Object?>>[];
      currentPracticeLogRows = <Map<String, Object?>>[];
      replaceAllDataCalls = 0;
      diskSpaceChecks = 0;
      RecordingRepository.resetMigrationStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    tearDown(() {
      RecordingRepository.resetMigrationStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    RecordingRepository createRepository({
      Future<void> Function(int requiredBytes)? ensureMigrationDiskSpace,
      Future<bool> Function(String key, bool value)? persistBool,
    }) {
      return RecordingRepository(
        prefs,
        config: config,
        ensureMigrationDiskSpace:
            ensureMigrationDiskSpace ??
            (requiredBytes) async {
              diskSpaceChecks += 1;
              expect(requiredBytes, greaterThan(0));
            },
        persistBool: persistBool,
        replaceAllData: ({
          required recordings,
          required practiceLogs,
        }) async {
          replaceAllDataCalls += 1;
          currentRecordingRows = recordings.map(_cloneRow).toList();
          currentPracticeLogRows = practiceLogs.map(_cloneRow).toList();
        },
        queryAllRecordings: () async =>
            currentRecordingRows.map(_cloneRow).toList(),
        queryAllPracticeLogs: () async =>
            currentPracticeLogRows.map(_cloneRow).toList(),
      );
    }

    test('migrates legacy data and preserves metadata plus audio file paths',
        () async {
      final recording = RecordingEntry(
        id: 'rec-1',
        title: 'Morning scales',
        recordedAt: DateTime(2024, 4, 5, 7, 30),
        durationSeconds: 95,
        waveformData: const [0.25, 0.5, 0.75],
        audioFilePath: '/recordings/morning-scales.m4a',
      );
      final practiceLog = PracticeLogEntry(
        date: DateTime(2024, 4, 5),
        durationMinutes: 40,
        memo: 'Focused on timing',
      );
      await prefs.setString(
        config.recordingsStorageKey,
        jsonEncode([recording.toJson()]),
      );
      await prefs.setString(
        config.practiceLogsStorageKey,
        jsonEncode([practiceLog.toJson()]),
      );

      final repository = createRepository();

      final migratedRecordings = await repository.loadRecordings();
      final migratedPracticeLogs = await repository.loadPracticeLogs();

      expect(replaceAllDataCalls, 1);
      expect(diskSpaceChecks, 1);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isTrue);
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isNull,
      );
      expect(migratedRecordings, hasLength(1));
      expect(migratedPracticeLogs, hasLength(1));
      expect(migratedRecordings.single.id, recording.id);
      expect(migratedRecordings.single.title, recording.title);
      expect(migratedRecordings.single.recordedAt, recording.recordedAt);
      expect(migratedRecordings.single.durationSeconds, recording.durationSeconds);
      expect(migratedRecordings.single.waveformData, recording.waveformData);
      expect(migratedRecordings.single.audioFilePath, recording.audioFilePath);
      expect(migratedPracticeLogs.single.date, practiceLog.date);
      expect(
        migratedPracticeLogs.single.durationMinutes,
        practiceLog.durationMinutes,
      );
      expect(migratedPracticeLogs.single.memo, practiceLog.memo);
    });

    test('retries an interrupted migration after completion persistence fails',
        () async {
      final recording = RecordingEntry(
        id: 'rec-retry',
        title: 'Retry me',
        recordedAt: DateTime(2024, 6, 7, 8, 9),
        durationSeconds: 45,
        waveformData: const [0.1, 0.2],
        audioFilePath: '/recordings/retry.m4a',
      );
      await prefs.setString(
        config.recordingsStorageKey,
        jsonEncode([recording.toJson()]),
      );

      var completionAttempts = 0;
      final firstRepository = createRepository(
        persistBool: (key, value) async {
          if (key == config.recordingsMigratedStorageKey) {
            completionAttempts += 1;
            if (completionAttempts == 1) {
              throw StateError('Simulated persistence failure after DB write');
            }
          }
          return prefs.setBool(key, value);
        },
      );

      final firstLoad = await firstRepository.loadRecordings();

      expect(firstLoad.single.audioFilePath, recording.audioFilePath);
      expect(replaceAllDataCalls, 1);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isNot(true));
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isTrue,
      );

      RecordingRepository.resetMigrationStateForTesting();
      final retryingRepository = createRepository();

      final secondLoad = await retryingRepository.loadRecordings();

      expect(secondLoad.single.audioFilePath, recording.audioFilePath);
      expect(replaceAllDataCalls, 2);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isTrue);
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isNull,
      );
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('interrupted migration detected; retrying'),
        ),
        isTrue,
      );
    });

    test('skips database writes when disk space verification fails', () async {
      final existingRecording = RecordingEntry(
        id: 'existing',
        title: 'Existing DB row',
        recordedAt: DateTime(2024, 1, 2, 3, 4),
        durationSeconds: 30,
        waveformData: const [0.9],
        audioFilePath: '/recordings/existing.m4a',
      );
      currentRecordingRows = [_recordingRow(existingRecording)];
      await prefs.setString(
        config.recordingsStorageKey,
        jsonEncode([
          RecordingEntry(
            id: 'legacy',
            title: 'Legacy payload',
            recordedAt: DateTime(2024, 5, 6, 7, 8),
            durationSeconds: 60,
            waveformData: const [0.4, 0.5],
            audioFilePath: '/recordings/legacy.m4a',
          ).toJson(),
        ]),
      );

      final repository = createRepository(
        ensureMigrationDiskSpace: (requiredBytes) async {
          diskSpaceChecks += 1;
          throw FileSystemException('disk full');
        },
      );

      final recordings = await repository.loadRecordings();

      expect(diskSpaceChecks, 1);
      expect(replaceAllDataCalls, 0);
      expect(recordings, hasLength(1));
      expect(recordings.single.id, existingRecording.id);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isNot(true));
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isTrue,
      );
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('migration failed during disk space verification'),
        ),
        isTrue,
      );
    });
  });
}

Map<String, Object?> _recordingRow(RecordingEntry entry) {
  return {
    'id': entry.id,
    'title': entry.title,
    'recorded_at': entry.recordedAt.toIso8601String(),
    'duration_seconds': entry.durationSeconds,
    'waveform_data': _waveformToBlobForTest(entry.waveformData),
    'audio_file_path': entry.audioFilePath,
  };
}

Map<String, Object?> _cloneRow(Map<String, Object?> row) {
  return row.map((key, value) {
    if (value is Uint8List) {
      return MapEntry<String, Object?>(key, Uint8List.fromList(value));
    }
    return MapEntry<String, Object?>(key, value);
  });
}

Uint8List _waveformToBlobForTest(List<double> data) {
  final bytes = ByteData(data.length * 8);
  for (var i = 0; i < data.length; i++) {
    bytes.setFloat64(i * 8, data[i], Endian.little);
  }
  return bytes.buffer.asUint8List();
}
