import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/legacy_data_migrator.dart';
import 'package:music_life/data/waveform_codec.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LegacyDataMigrator', () {
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
      LegacyDataMigrator.resetStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    tearDown(() {
      LegacyDataMigrator.resetStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    LegacyDataMigrator createMigrator({
      EnsureMigrationDiskSpace? ensureMigrationDiskSpace,
      PersistBool? persistBool,
    }) {
      return LegacyDataMigrator(
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

      final migrator = createMigrator();

      await migrator.migrateIfNeeded();

      expect(replaceAllDataCalls, 1);
      expect(diskSpaceChecks, 1);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isTrue);
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isNull,
      );
      expect(currentRecordingRows, hasLength(1));
      expect(currentPracticeLogRows, hasLength(1));
      expect(currentRecordingRows.single['id'], recording.id);
      expect(currentRecordingRows.single['title'], recording.title);
      expect(currentRecordingRows.single['recorded_at'],
          recording.recordedAt.toIso8601String());
      expect(
        currentRecordingRows.single['duration_seconds'],
        recording.durationSeconds,
      );
      expect(
        blobToWaveform(currentRecordingRows.single['waveform_data']! as Uint8List),
        recording.waveformData,
      );
      expect(currentRecordingRows.single['audio_file_path'], recording.audioFilePath);
      expect(
        currentPracticeLogRows.single,
        {
          'date': practiceLog.date.toIso8601String(),
          'duration_minutes': practiceLog.durationMinutes,
          'memo': practiceLog.memo,
        },
      );
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
      final firstMigrator = createMigrator(
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

      await firstMigrator.migrateIfNeeded();

      expect(replaceAllDataCalls, 1);
      expect(prefs.getBool(config.recordingsMigratedStorageKey), isNot(true));
      expect(
        prefs.getBool('${config.recordingsMigratedStorageKey}_in_progress'),
        isTrue,
      );

      LegacyDataMigrator.resetStateForTesting();
      final retryingMigrator = createMigrator();

      await retryingMigrator.migrateIfNeeded();

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

      final migrator = createMigrator(
        ensureMigrationDiskSpace: (requiredBytes) async {
          diskSpaceChecks += 1;
          throw const FileSystemException('disk full');
        },
      );

      await migrator.migrateIfNeeded();

      expect(diskSpaceChecks, 1);
      expect(replaceAllDataCalls, 0);
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

Map<String, Object?> _cloneRow(Map<String, Object?> row) {
  return row.map((key, value) {
    if (value is Uint8List) {
      return MapEntry<String, Object?>(key, Uint8List.fromList(value));
    }
    return MapEntry<String, Object?>(key, value);
  });
}
