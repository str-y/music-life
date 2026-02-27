import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/utils/chord_utils.dart';

void main() {
  group('formatTimeHMS', () {
    test('formats midnight as 00:00:00', () {
      expect(formatTimeHMS(DateTime(2024, 1, 1, 0, 0, 0)), '00:00:00');
    });

    test('zero-pads single-digit hour, minute, and second', () {
      expect(formatTimeHMS(DateTime(2024, 6, 15, 3, 7, 9)), '03:07:09');
    });

    test('formats noon correctly', () {
      expect(formatTimeHMS(DateTime(2024, 1, 1, 12, 0, 0)), '12:00:00');
    });

    test('formats end of day as 23:59:59', () {
      expect(formatTimeHMS(DateTime(2024, 1, 1, 23, 59, 59)), '23:59:59');
    });

    test('formats a mid-day time with all two-digit components', () {
      expect(formatTimeHMS(DateTime(2024, 3, 20, 14, 30, 45)), '14:30:45');
    });

    test('ignores sub-second components', () {
      // milliseconds / microseconds should not appear in the output.
      expect(
        formatTimeHMS(DateTime(2024, 1, 1, 10, 20, 30, 500, 999)),
        '10:20:30',
      );
    });
  });
}
