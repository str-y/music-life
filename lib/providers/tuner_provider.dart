import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../native_pitch_bridge.dart';
import '../service_locator.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class TunerState {
  const TunerState({
    this.loading = true,
    this.latest,
    this.bridgeActive = false,
  });

  /// True while the bridge is being initialised.
  final bool loading;

  /// The most recently detected pitch, or `null` when no note is detected.
  final PitchResult? latest;

  /// True when the bridge started successfully and is streaming audio.
  final bool bridgeActive;

  TunerState copyWith({
    bool? loading,
    PitchResult? latest,
    bool? bridgeActive,
    bool clearLatest = false,
  }) {
    return TunerState(
      loading: loading ?? this.loading,
      latest: clearLatest ? null : (latest ?? this.latest),
      bridgeActive: bridgeActive ?? this.bridgeActive,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TunerNotifier extends Notifier<TunerState> {
  NativePitchBridge? _bridge;
  StreamSubscription<PitchResult>? _sub;

  @override
  TunerState build() {
    ref.onDispose(() {
      _sub?.cancel();
      final bridge = _bridge;
      _bridge = null;
      bridge?.dispose();
    });
    _startCapture();
    return const TunerState();
  }

  Future<void> _startCapture() async {
    state = state.copyWith(loading: true, clearLatest: true, bridgeActive: false);
    final bridge = ServiceLocator.instance.pitchBridgeFactory();
    // Assign early so the onDispose callback can dispose the bridge even if
    // the provider is disposed while [startCapture] is awaited.
    _bridge = bridge;
    final started = await bridge.startCapture();
    if (_bridge != bridge) {
      // Provider was disposed mid-flight; onDispose already cleaned up.
      return;
    }
    if (!started) {
      _bridge = null;
      bridge.dispose();
      state = const TunerState(loading: false, bridgeActive: false);
      return;
    }
    _sub = bridge.pitchStream.listen((result) {
      state = state.copyWith(latest: result);
    });
    state = const TunerState(loading: false, bridgeActive: true);
  }

  /// Disposes the current bridge and restarts audio capture.
  Future<void> retry() async {
    _sub?.cancel();
    _sub = null;
    _bridge?.dispose();
    _bridge = null;
    await _startCapture();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tunerProvider =
    NotifierProvider.autoDispose<TunerNotifier, TunerState>(
  TunerNotifier.new,
);
