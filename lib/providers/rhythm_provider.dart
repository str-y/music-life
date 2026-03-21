import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/app_constants.dart';
import 'package:music_life/utils/metronome_utils.dart';
typedef RhythmClock = DateTime Function();
typedef RhythmTickCallback = void Function(Duration elapsed);
typedef RhythmTickerFactory = RhythmTicker Function(RhythmTickCallback onTick);

abstract interface class RhythmTicker {
  void start();
  void dispose();
}

class StopwatchRhythmTicker implements RhythmTicker {
  StopwatchRhythmTicker(this._onTick);

  final RhythmTickCallback _onTick;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;

  @override
  void start() {
    _stopwatch.start();
    _onTick(Duration.zero);
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _onTick(_stopwatch.elapsed);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }
}

class RhythmState {
  const RhythmState({
    this.bpm = 120,
    this.timeSignatureNumerator = 4,
    this.timeSignatureDenominator = 4,
    this.isPlaying = false,
    this.beatIndex = -1,
    this.lastOffsetMs = 0,
    this.timingScore = 100,
  });

  final int bpm;
  final int timeSignatureNumerator;
  final int timeSignatureDenominator;
  final bool isPlaying;
  final int beatIndex;
  final double lastOffsetMs;
  final double timingScore;

  Duration get beatDuration => metronomeBeatDurationFor(
        bpm: bpm,
        timeSignatureDenominator: timeSignatureDenominator,
      );

  RhythmState copyWith({
    int? bpm,
    int? timeSignatureNumerator,
    int? timeSignatureDenominator,
    bool? isPlaying,
    int? beatIndex,
    double? lastOffsetMs,
    double? timingScore,
  }) {
    return RhythmState(
      bpm: bpm ?? this.bpm,
      timeSignatureNumerator:
          timeSignatureNumerator ?? this.timeSignatureNumerator,
      timeSignatureDenominator:
          timeSignatureDenominator ?? this.timeSignatureDenominator,
      isPlaying: isPlaying ?? this.isPlaying,
      beatIndex: beatIndex ?? this.beatIndex,
      lastOffsetMs: lastOffsetMs ?? this.lastOffsetMs,
      timingScore: timingScore ?? this.timingScore,
    );
  }
}

final rhythmClockProvider = Provider<RhythmClock>((ref) => DateTime.now);

final rhythmTickerFactoryProvider = Provider<RhythmTickerFactory>((ref) {
  return StopwatchRhythmTicker.new;
});

class RhythmNotifier extends Notifier<RhythmState> {
  RhythmTicker? _ticker;
  DateTime? _metStartWallTime;
  DateTime? _lastBeatTime;

  @override
  RhythmState build() {
    ref.onDispose(() {
      _ticker?.dispose();
      _ticker = null;
    });
    return const RhythmState();
  }

  void startMetronome() {
    _ticker?.dispose();
    _ticker = null;
    _metStartWallTime = ref.read(rhythmClockProvider)();
    _lastBeatTime = _metStartWallTime;
    state = state.copyWith(
      isPlaying: true,
      beatIndex: -1,
      lastOffsetMs: 0,
      timingScore: 100,
    );
    final ticker = ref.read(rhythmTickerFactoryProvider)(_onMetronomeTick);
    _ticker = ticker;
    ticker.start();
  }

  void stopMetronome() {
    _ticker?.dispose();
    _ticker = null;
    state = state.copyWith(isPlaying: false);
  }

  void toggleMetronome() {
    if (state.isPlaying) {
      stopMetronome();
    } else {
      startMetronome();
    }
  }

  void changeBpm(int delta) {
    final nextBpm = _clampBpm(state.bpm + delta);
    state = state.copyWith(bpm: nextBpm);
    if (state.isPlaying) {
      startMetronome();
    }
  }

  void applyMetronomeSettings({
    required int bpm,
    required int timeSignatureNumerator,
    required int timeSignatureDenominator,
  }) {
    final shouldRestart = state.isPlaying;
    state = state.copyWith(
      bpm: _clampBpm(bpm),
      timeSignatureNumerator: timeSignatureNumerator,
      timeSignatureDenominator: timeSignatureDenominator,
    );
    if (shouldRestart) {
      startMetronome();
    }
  }

  void onGrooveTap() {
    if (!state.isPlaying || _lastBeatTime == null) {
      return;
    }

    final now = ref.read(rhythmClockProvider)();
    final beatMs = state.beatDuration.inMilliseconds.toDouble();
    final elapsedMs = now.difference(_lastBeatTime!).inMilliseconds.toDouble();
    final offset = computeGrooveTapOffset(elapsedMs: elapsedMs, beatMs: beatMs);
    final penalty = computeScorePenalty(offsetMs: offset, beatMs: beatMs);

    state = state.copyWith(
      lastOffsetMs: offset,
      timingScore: (state.timingScore - penalty).clamp(0.0, 100.0),
    );
  }

  void _onMetronomeTick(Duration elapsed) {
    final beatDuration = state.beatDuration;
    final beatIndex = elapsed.inMicroseconds ~/ beatDuration.inMicroseconds;
    if (beatIndex <= state.beatIndex || _metStartWallTime == null) {
      return;
    }

    _lastBeatTime = _metStartWallTime!.add(
      Duration(microseconds: beatIndex * beatDuration.inMicroseconds),
    );
    state = state.copyWith(beatIndex: beatIndex);
  }
}

final NotifierProvider<RhythmNotifier, RhythmState> rhythmProvider =
    NotifierProvider.autoDispose<RhythmNotifier, RhythmState>(
      RhythmNotifier.new,
    );

int _clampBpm(int bpm) {
  return bpm.clamp(
    AppConstants.metronomeMinBpm,
    AppConstants.metronomeMaxBpm,
  );
}
