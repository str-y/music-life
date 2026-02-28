import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/tuner_provider.dart';

void main() {
  // ── TunerState default values ──────────────────────────────────────────────

  group('TunerState – defaults', () {
    test('loading is true by default', () {
      const state = TunerState();
      expect(state.loading, isTrue);
    });

    test('latest is null by default', () {
      const state = TunerState();
      expect(state.latest, isNull);
    });

    test('bridgeActive is false by default', () {
      const state = TunerState();
      expect(state.bridgeActive, isFalse);
    });
  });

  // ── TunerState.copyWith ────────────────────────────────────────────────────

  group('TunerState.copyWith – field transitions', () {
    const initial = TunerState();

    test('copyWith(loading: false) transitions loading to false', () {
      final next = initial.copyWith(loading: false);
      expect(next.loading, isFalse);
    });

    test('copyWith(bridgeActive: true) enables the bridge', () {
      final next = initial.copyWith(bridgeActive: true);
      expect(next.bridgeActive, isTrue);
    });

    test('copyWith with a PitchResult sets latest', () {
      const result = PitchResult(
        noteName: 'A4',
        frequency: 440.0,
        centsOffset: 0.0,
        midiNote: 69,
      );
      final next = initial.copyWith(latest: result);
      expect(next.latest, equals(result));
    });

    test('copyWith without arguments preserves all fields', () {
      const state = TunerState(
        loading: false,
        bridgeActive: true,
      );
      final copy = state.copyWith();
      expect(copy.loading, equals(state.loading));
      expect(copy.bridgeActive, equals(state.bridgeActive));
      expect(copy.latest, equals(state.latest));
    });

    test('copyWith(clearLatest: true) clears an existing latest', () {
      const result = PitchResult(
        noteName: 'C4',
        frequency: 261.63,
        centsOffset: -2.0,
        midiNote: 60,
      );
      const stateWithLatest = TunerState(loading: false, latest: result);
      final cleared = stateWithLatest.copyWith(clearLatest: true);
      expect(cleared.latest, isNull);
    });

    test('copyWith(clearLatest: false) preserves an existing latest', () {
      const result = PitchResult(
        noteName: 'G4',
        frequency: 392.0,
        centsOffset: 3.0,
        midiNote: 67,
      );
      const stateWithLatest = TunerState(loading: false, latest: result);
      final copy = stateWithLatest.copyWith(clearLatest: false);
      expect(copy.latest, equals(result));
    });

    test('copyWith(clearLatest: true) ignores a simultaneously supplied latest',
        () {
      const existing = PitchResult(
        noteName: 'E4',
        frequency: 329.63,
        centsOffset: 1.0,
        midiNote: 64,
      );
      const stateWithLatest = TunerState(loading: false, latest: existing);
      const incoming = PitchResult(
        noteName: 'B4',
        frequency: 493.88,
        centsOffset: 0.5,
        midiNote: 71,
      );
      // clearLatest takes precedence.
      final next =
          stateWithLatest.copyWith(latest: incoming, clearLatest: true);
      expect(next.latest, isNull);
    });

    test('bridge-start success transition: loading → active', () {
      // Simulates the state sequence inside TunerNotifier._startCapture()
      // when the bridge starts successfully.
      const initial = TunerState(); // loading=true
      final starting =
          initial.copyWith(loading: true, clearLatest: true, bridgeActive: false);
      expect(starting.loading, isTrue);
      expect(starting.bridgeActive, isFalse);
      expect(starting.latest, isNull);

      const ready = TunerState(loading: false, bridgeActive: true);
      expect(ready.loading, isFalse);
      expect(ready.bridgeActive, isTrue);
    });

    test('bridge-start failure transition: loading → inactive', () {
      // Simulates the state sequence when the bridge fails to start.
      const initial = TunerState(); // loading=true
      final starting =
          initial.copyWith(loading: true, clearLatest: true, bridgeActive: false);
      expect(starting.loading, isTrue);

      const failed = TunerState(loading: false, bridgeActive: false);
      expect(failed.loading, isFalse);
      expect(failed.bridgeActive, isFalse);
    });
  });
}
