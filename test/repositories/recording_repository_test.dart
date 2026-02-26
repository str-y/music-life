import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/recording_repository.dart';

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
}
