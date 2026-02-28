import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/app_constants.dart';
import 'package:music_life/utils/metronome_utils.dart';

void main() {
  // ── beatDurationFor ────────────────────────────────────────────────────────

  group('beatDurationFor', () {
    test('120 BPM yields 500 ms per beat', () {
      expect(beatDurationFor(120).inMilliseconds, 500);
    });

    test('60 BPM yields 1 000 ms per beat', () {
      expect(beatDurationFor(60).inMilliseconds, 1000);
    });

    test('240 BPM yields 250 ms per beat', () {
      expect(beatDurationFor(240).inMilliseconds, 250);
    });

    test('30 BPM yields 2 000 ms per beat', () {
      expect(beatDurationFor(30).inMilliseconds, 2000);
    });

    test('beat duration is positive for all valid BPM values', () {
      for (var bpm = AppConstants.metronomeMinBpm;
          bpm <= AppConstants.metronomeMaxBpm;
          bpm++) {
        expect(beatDurationFor(bpm).inMicroseconds, greaterThan(0),
            reason: 'BPM $bpm should produce a positive beat duration');
      }
    });
  });

  // ── computeGrooveTapOffset ─────────────────────────────────────────────────

  group('computeGrooveTapOffset', () {
    const beatMs = 500.0; // 120 BPM

    test('tap exactly on the beat returns 0', () {
      expect(
        computeGrooveTapOffset(elapsedMs: 0, beatMs: beatMs),
        0.0,
      );
    });

    test('tap at beat boundary (elapsed == beatMs) returns 0', () {
      // After exactly one beat the offset wraps to 0.
      final offset =
          computeGrooveTapOffset(elapsedMs: beatMs, beatMs: beatMs);
      expect(offset, 0.0);
    });

    test('tap slightly late returns a positive offset', () {
      final offset =
          computeGrooveTapOffset(elapsedMs: 50, beatMs: beatMs);
      expect(offset, 50.0);
    });

    test('tap slightly early (> half beat) wraps to a negative offset', () {
      // 450 ms elapsed out of 500 ms → 450 - 500 = -50 ms (early next beat).
      final offset =
          computeGrooveTapOffset(elapsedMs: 450, beatMs: beatMs);
      expect(offset, -50.0);
    });

    test('offset is within [-beatMs/2, +beatMs/2]', () {
      for (var elapsed = 0.0; elapsed < beatMs; elapsed += 25) {
        final offset =
            computeGrooveTapOffset(elapsedMs: elapsed, beatMs: beatMs);
        expect(offset, greaterThanOrEqualTo(-beatMs / 2));
        expect(offset, lessThanOrEqualTo(beatMs / 2));
      }
    });
  });

  // ── computeScorePenalty ────────────────────────────────────────────────────

  group('computeScorePenalty', () {
    const beatMs = 500.0; // 120 BPM

    test('perfectly on-beat tap incurs no penalty', () {
      expect(
        computeScorePenalty(offsetMs: 0, beatMs: beatMs),
        0.0,
      );
    });

    test('tap at the half-beat boundary incurs the maximum 20-point penalty',
        () {
      expect(
        computeScorePenalty(offsetMs: beatMs / 2, beatMs: beatMs),
        20.0,
      );
    });

    test('penalty scales linearly with |offsetMs|', () {
      final half = computeScorePenalty(
          offsetMs: beatMs / 4, beatMs: beatMs); // 10 pts
      final full = computeScorePenalty(
          offsetMs: beatMs / 2, beatMs: beatMs); // 20 pts
      expect(full, closeTo(2 * half, 1e-9));
    });

    test('early tap (negative offset) incurs the same penalty as a late tap',
        () {
      final late = computeScorePenalty(offsetMs: 100, beatMs: beatMs);
      final early = computeScorePenalty(offsetMs: -100, beatMs: beatMs);
      expect(late, closeTo(early, 1e-9));
    });

    test('penalty is always non-negative', () {
      for (var offset = -beatMs / 2; offset <= beatMs / 2; offset += 25) {
        expect(
          computeScorePenalty(offsetMs: offset, beatMs: beatMs),
          greaterThanOrEqualTo(0),
        );
      }
    });
  });
}
