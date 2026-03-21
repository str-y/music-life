import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/backup_repository.dart';

class _FakeBackupStore implements BackupStore {
  List<Map<String, Object?>> recordings = <Map<String, Object?>>[];
  List<Map<String, Object?>> practiceLogs = <Map<String, Object?>>[];
  List<Map<String, Object?>> practiceLogEntries = <Map<String, Object?>>[];
  List<Map<String, Object?>> compositions = <Map<String, Object?>>[];

  List<Map<String, Object?>>? importedRecordings;
  List<Map<String, Object?>>? importedPracticeLogs;
  List<Map<String, Object?>>? importedPracticeLogEntries;
  List<Map<String, Object?>>? importedCompositions;
  int replaceAllCalls = 0;

  @override
  Future<List<Map<String, Object?>>> queryAllCompositions() async {
    return compositions.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<List<Map<String, Object?>>> queryAllPracticeLogEntries() async {
    return practiceLogEntries.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<List<Map<String, Object?>>> queryAllPracticeLogs() async {
    return practiceLogs.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<List<Map<String, Object?>>> queryAllRecordings() async {
    return recordings.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<void> replaceAllBackupData({
    required List<Map<String, Object?>> recordings,
    required List<Map<String, Object?>> practiceLogs,
    required List<Map<String, Object?>> practiceLogEntries,
    required List<Map<String, Object?>> compositions,
  }) async {
    replaceAllCalls += 1;
    importedRecordings = recordings.map(Map<String, Object?>.from).toList();
    importedPracticeLogs = practiceLogs.map(Map<String, Object?>.from).toList();
    importedPracticeLogEntries =
        practiceLogEntries.map(Map<String, Object?>.from).toList();
    importedCompositions = compositions.map(Map<String, Object?>.from).toList();
  }
}

void main() {
  test('BackupBundle serializes and restores waveform blob data', () {
    final source = BackupBundle.fromDatabaseRows(
      recordings: [
        {
          'id': 'r1',
          'title': 'Session',
          'recorded_at': '2026-01-01T12:00:00.000',
          'duration_seconds': 42,
          'waveform_data': Uint8List.fromList([1, 2, 3, 4]),
          'audio_file_path': '/tmp/rec-1.m4a',
        },
      ],
      practiceLogs: [
        {
          'date': '2026-01-01T00:00:00.000',
          'duration_minutes': 30,
          'memo': 'Warmup',
        },
      ],
      practiceLogEntries: [
        {
          'date': '2026-01-02T00:00:00.000',
          'duration_minutes': 20,
          'note': 'Scales',
        },
      ],
      compositions: [
        {
          'id': 'comp-1',
          'title': 'Song',
          'chords': '["C","G"]',
        },
      ],
    );

    final restored = BackupBundle.fromJson(source.toJson());

    expect(restored.recordingRows.single['id'], 'r1');
    expect(
      (restored.recordingRows.single['waveform_data']! as Uint8List).toList(),
      [1, 2, 3, 4],
    );
    expect(restored.recordingRows.single['audio_file_path'], '/tmp/rec-1.m4a');
    expect(restored.practiceLogRows.single['memo'], 'Warmup');
    expect(restored.practiceLogEntryRows.single['note'], 'Scales');
    expect(restored.compositionRows.single['chords'], '["C","G"]');
  });

  group('BackupRepository', () {
    test('exportJsonBundle includes all backup-supported tables', () async {
      final store = _FakeBackupStore()
        ..recordings = [
          {
            'id': 'r1',
            'title': 'Session',
            'recorded_at': '2026-01-01T12:00:00.000',
            'duration_seconds': 42,
            'waveform_data': Uint8List.fromList([1, 2, 3]),
            'audio_file_path': '/tmp/rec-1.m4a',
          },
        ]
        ..practiceLogs = [
          {
            'date': '2026-01-01T00:00:00.000',
            'duration_minutes': 30,
            'memo': 'Warmup',
          },
        ]
        ..practiceLogEntries = [
          {
            'date': '2026-01-02T00:00:00.000',
            'duration_minutes': 20,
            'note': 'Scales',
          },
        ]
        ..compositions = [
          {
            'id': 'comp-1',
            'title': 'Song',
            'chords': '["C","G"]',
          },
        ];
      final repository = BackupRepository(store: store);

      final jsonContent = await repository.exportJsonBundle();
      final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;

      expect(decoded['version'], 1);
      expect((decoded['recordings'] as List<dynamic>).single['id'], 'r1');
      expect((decoded['practice_logs'] as List<dynamic>).single['memo'], 'Warmup');
      expect(
        (decoded['practice_log_entries'] as List<dynamic>).single['note'],
        'Scales',
      );
      expect((decoded['compositions'] as List<dynamic>).single['id'], 'comp-1');
    });

    test('importJsonBundle replaces all backup tables from valid JSON', () async {
      final store = _FakeBackupStore();
      final repository = BackupRepository(store: store);
      final source = BackupBundle.fromDatabaseRows(
        recordings: [
          {
            'id': 'r1',
            'title': 'Session',
            'recorded_at': '2026-01-01T12:00:00.000',
            'duration_seconds': 42,
            'waveform_data': Uint8List.fromList([1, 2, 3, 4]),
            'audio_file_path': '/tmp/rec-1.m4a',
          },
        ],
        practiceLogs: [
          {
            'date': '2026-01-01T00:00:00.000',
            'duration_minutes': 30,
            'memo': 'Warmup',
          },
        ],
        practiceLogEntries: [
          {
            'date': '2026-01-02T00:00:00.000',
            'duration_minutes': 20,
            'note': 'Scales',
          },
        ],
        compositions: [
          {
            'id': 'comp-1',
            'title': 'Song',
            'chords': '["C","G"]',
          },
        ],
      );

      await repository.importJsonBundle(jsonEncode(source.toJson()));

      expect(store.replaceAllCalls, 1);
      expect(store.importedRecordings!.single['id'], 'r1');
      expect(
        (store.importedRecordings!.single['waveform_data']! as Uint8List).toList(),
        [1, 2, 3, 4],
      );
      expect(store.importedPracticeLogs!.single['memo'], 'Warmup');
      expect(store.importedPracticeLogEntries!.single['note'], 'Scales');
      expect(store.importedCompositions!.single['title'], 'Song');
    });

    test('importJsonBundle rejects corrupted JSON without writing data', () async {
      final store = _FakeBackupStore();
      final repository = BackupRepository(store: store);

      await expectLater(
        repository.importJsonBundle('{invalid json'),
        throwsA(isA<FormatException>()),
      );
      expect(store.replaceAllCalls, 0);
    });
  });
}
