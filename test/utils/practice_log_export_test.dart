import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/utils/practice_log_export.dart';

void main() {
  group('buildPracticeLogCsv', () {
    test('outputs header and rows', () {
      final csv = buildPracticeLogCsv([
        PracticeLogEntry(
          date: DateTime(2026, 2, 1),
          durationMinutes: 30,
          memo: 'Scales',
        ),
      ]);

      expect(
        csv,
        'date,duration_minutes,memo\n2026/02/01,30,Scales\n',
      );
    });

    test('escapes commas, quotes, and new lines in memo', () {
      final csv = buildPracticeLogCsv([
        PracticeLogEntry(
          date: DateTime(2026, 2, 2),
          durationMinutes: 45,
          memo: 'A,"B"\nC',
        ),
      ]);

      expect(
        csv,
        'date,duration_minutes,memo\n2026/02/02,45,"A,""B""\nC"\n',
      );
    });
  });

  test('buildPracticeLogPdf returns a PDF byte stream', () {
    final pdf = buildPracticeLogPdf([
      PracticeLogEntry(
        date: DateTime(2026, 2, 3),
        durationMinutes: 25,
        memo: 'Scale "A"',
      ),
    ]);

    expect(pdf, isNotEmpty);
    expect(String.fromCharCodes(pdf.take(8)), '%PDF-1.4');
    final asText = String.fromCharCodes(pdf);
    expect(asText, contains('Practice Log'));
    expect(asText, contains('Scale "A"'));
    expect(asText, contains('%%EOF'));
  });
}
