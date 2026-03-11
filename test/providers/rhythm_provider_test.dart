import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/providers/rhythm_provider.dart';

void main() {
  group('RhythmNotifier', () {
    test('changeBpm clamps to configured min and max values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(rhythmProvider.notifier);
      notifier.changeBpm(-500);
      expect(container.read(rhythmProvider).bpm, 30);

      notifier.changeBpm(500);
      expect(container.read(rhythmProvider).bpm, 240);
    });

    test('startMetronome emits beats from monotonic elapsed time', () {
      final factory = _FakeRhythmTickerFactory();
      var now = DateTime.utc(2026, 3, 11, 13);
      final container = ProviderContainer(
        overrides: [
          rhythmClockProvider.overrideWithValue(() => now),
          rhythmTickerFactoryProvider.overrideWithValue(factory.call),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rhythmProvider.notifier);
      notifier.startMetronome();

      expect(factory.created, hasLength(1));
      expect(factory.created.single.started, isTrue);
      expect(container.read(rhythmProvider).isPlaying, isTrue);
      expect(container.read(rhythmProvider).timingScore, 100);

      factory.created.single.emit(Duration.zero);
      expect(container.read(rhythmProvider).beatIndex, 0);

      factory.created.single.emit(const Duration(milliseconds: 1500));
      expect(container.read(rhythmProvider).beatIndex, 3);
    });

    test('changing BPM while playing restarts the ticker at the new tempo', () {
      final factory = _FakeRhythmTickerFactory();
      var now = DateTime.utc(2026, 3, 11, 13);
      final container = ProviderContainer(
        overrides: [
          rhythmClockProvider.overrideWithValue(() => now),
          rhythmTickerFactoryProvider.overrideWithValue(factory.call),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rhythmProvider.notifier);
      notifier.startMetronome();
      final firstTicker = factory.created.single;
      firstTicker.emit(Duration.zero);

      now = now.add(const Duration(seconds: 1));
      notifier.changeBpm(10);

      expect(firstTicker.disposed, isTrue);
      expect(factory.created, hasLength(2));
      expect(container.read(rhythmProvider).bpm, 130);
      expect(container.read(rhythmProvider).beatIndex, -1);

      factory.created.last.emit(Duration.zero);
      expect(container.read(rhythmProvider).beatIndex, 0);
    });

    test('onGrooveTap updates offset and score using scheduled beat timing', () {
      final factory = _FakeRhythmTickerFactory();
      var now = DateTime.utc(2026, 3, 11, 13);
      final container = ProviderContainer(
        overrides: [
          rhythmClockProvider.overrideWithValue(() => now),
          rhythmTickerFactoryProvider.overrideWithValue(factory.call),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rhythmProvider.notifier);
      notifier.startMetronome();
      factory.created.single.emit(Duration.zero);

      now = now.add(const Duration(milliseconds: 520));
      notifier.onGrooveTap();

      final state = container.read(rhythmProvider);
      expect(state.lastOffsetMs, 20);
      expect(state.timingScore, closeTo(98.4, 0.0001));
    });

    test('stopping metronome disposes ticker and ignores later taps', () {
      final factory = _FakeRhythmTickerFactory();
      var now = DateTime.utc(2026, 3, 11, 13);
      final container = ProviderContainer(
        overrides: [
          rhythmClockProvider.overrideWithValue(() => now),
          rhythmTickerFactoryProvider.overrideWithValue(factory.call),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(rhythmProvider.notifier);
      notifier.startMetronome();
      factory.created.single.emit(Duration.zero);
      notifier.stopMetronome();

      now = now.add(const Duration(milliseconds: 100));
      notifier.onGrooveTap();

      final state = container.read(rhythmProvider);
      expect(factory.created.single.disposed, isTrue);
      expect(state.isPlaying, isFalse);
      expect(state.lastOffsetMs, 0);
      expect(state.timingScore, 100);
    });
  });
}

class _FakeRhythmTickerFactory {
  final List<_FakeRhythmTicker> created = [];

  RhythmTicker call(void Function(Duration elapsed) onTick) {
    final ticker = _FakeRhythmTicker(onTick);
    created.add(ticker);
    return ticker;
  }
}

class _FakeRhythmTicker implements RhythmTicker {
  _FakeRhythmTicker(this._onTick);

  final void Function(Duration elapsed) _onTick;
  bool started = false;
  bool disposed = false;

  void emit(Duration elapsed) {
    _onTick(elapsed);
  }

  @override
  void dispose() {
    disposed = true;
  }

  @override
  void start() {
    started = true;
  }
}
