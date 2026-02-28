import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/screens/library_screen.dart';

void main() {
  group('downsampleWaveform', () {
    test('returns empty list when source is empty', () {
      expect(downsampleWaveform(const [], 40), isEmpty);
    });

    test('returns copy when source length is <= target points', () {
      final source = <double>[0.1, 0.3, 0.7];
      final result = downsampleWaveform(source, 3);

      expect(result, equals(source));
      expect(identical(result, source), isFalse);
    });

    test('downsamples by averaging buckets and clamps values', () {
      final result = downsampleWaveform(<double>[0.0, 0.5, 1.0, 1.5], 2);

      expect(result, equals(<double>[0.25, 1.0]));
    });
  });
}
