import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/backup_repository.dart';

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
    );

    final restored = BackupBundle.fromJson(source.toJson());

    expect(restored.recordingRows.single['id'], 'r1');
    expect(
      restored.recordingRows.single['waveform_data'],
      Uint8List.fromList([1, 2, 3, 4]),
    );
    expect(restored.recordingRows.single['audio_file_path'], '/tmp/rec-1.m4a');
    expect(restored.practiceLogRows.single['memo'], 'Warmup');
    expect(restored.practiceLogEntryRows.single['note'], 'Scales');
  });
}
