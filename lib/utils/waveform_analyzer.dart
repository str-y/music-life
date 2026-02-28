import 'dart:math' as math;
import 'dart:typed_data';

/// Computes waveform data from a PCM 16-bit mono audio stream using RMS
/// (Root Mean Square) analysis.
///
/// Usage:
/// ```dart
/// final analyzer = WaveformAnalyzer();
/// // Feed chunks as they arrive from AudioRecorder.startStream:
/// audioStream.listen(analyzer.addChunk);
/// // After recording stops, obtain normalised bars:
/// final bars = analyzer.compute(40);
/// ```
class WaveformAnalyzer {
  final List<double> _samples = [];

  /// Feeds a raw PCM16 little-endian mono [chunk] into the analyzer.
  ///
  /// Each pair of bytes is interpreted as a signed 16-bit sample and
  /// converted to the [-1.0, 1.0] float range.
  void addChunk(Uint8List chunk) {
    for (int i = 0; i + 1 < chunk.length; i += 2) {
      int s = chunk[i] | (chunk[i + 1] << 8);
      if (s >= 0x8000) s -= 0x10000;
      _samples.add(s / 32768.0);
    }
  }

  /// Returns a list of [barCount] normalised RMS amplitude values in
  /// [0.0, 1.0].
  ///
  /// The audio buffer is divided into [barCount] equal buckets; the RMS
  /// energy of each bucket is computed and then the whole result is
  /// normalised so that the loudest bar reaches 1.0.
  ///
  /// Returns an empty list if no audio data has been added or [barCount]
  /// is zero.
  List<double> compute(int barCount) {
    if (_samples.isEmpty || barCount <= 0) return [];

    final bucketSize = _samples.length ~/ barCount;
    if (bucketSize == 0) {
      // Fewer samples than bars: return one value per sample, clamped.
      return _samples
          .take(barCount)
          .map((s) => s.abs().clamp(0.0, 1.0))
          .toList();
    }

    // Compute RMS for each bucket.
    final buckets = List.generate(barCount, (i) {
      final start = i * bucketSize;
      final end = math.min(start + bucketSize, _samples.length);
      double sumSq = 0.0;
      for (int j = start; j < end; j++) {
        sumSq += _samples[j] * _samples[j];
      }
      return math.sqrt(sumSq / (end - start));
    });

    // Normalise to [0.0, 1.0].
    final peak = buckets.reduce(math.max);
    if (peak == 0.0) return List.filled(barCount, 0.0);
    return buckets.map((v) => (v / peak).clamp(0.0, 1.0)).toList();
  }

  /// Returns `true` if no samples have been accumulated yet.
  bool get isEmpty => _samples.isEmpty;

  /// Clears all accumulated samples so the analyzer can be reused.
  void reset() => _samples.clear();
}
