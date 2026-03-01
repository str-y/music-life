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

    test('clamps averages above 1.0 to 1.0', () {
      final result = downsampleWaveform(<double>[0.0, 2.0, 3.0, 1.0], 2);

      expect(result, equals(<double>[1.0, 1.0]));
    });
  });

  group('buildLiveWaveformPreview', () {
    test('returns empty list when live amplitude data is empty', () {
      expect(buildLiveWaveformPreview(const []), isEmpty);
    });

    test('downsamples live amplitude data to target points', () {
      final result = buildLiveWaveformPreview(
        <double>[0.0, 0.5, 1.0, 1.0],
        targetPoints: 2,
      );

      expect(result, equals(<double>[0.25, 1.0]));
    });
  });
}
