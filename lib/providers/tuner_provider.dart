import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/haptic_service_provider.dart';
// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class TunerState {
  const TunerState({
    this.loading = true,
    this.latest,
    this.bridgeActive = false,
    this.spectrumBins = const <double>[],
  });

  /// True while the bridge is being initialised.
  final bool loading;

  /// The most recently detected pitch, or `null` when no note is detected.
  final PitchResult? latest;

  /// True when the bridge started successfully and is streaming audio.
  final bool bridgeActive;

  /// Latest tuner spectrum frame computed by the background isolate.
  final List<double> spectrumBins;

  TunerState copyWith({
    bool? loading,
    PitchResult? latest,
    bool? bridgeActive,
    List<double>? spectrumBins,
    bool clearLatest = false,
  }) {
    return TunerState(
      loading: loading ?? this.loading,
      latest: clearLatest ? null : (latest ?? this.latest),
      bridgeActive: bridgeActive ?? this.bridgeActive,
      spectrumBins: spectrumBins ?? this.spectrumBins,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class TunerNotifier extends Notifier<TunerState> {
  NativePitchBridge? _bridge;
  StreamSubscription<PitchResult>? _sub;
  StreamSubscription<TunerAnalysisFrame>? _analysisSub;

  @override
  TunerState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _analysisSub?.cancel();
      final bridge = _bridge;
      _bridge = null;
      bridge?.dispose();
    });
    // Initialize capture after build finishes
    scheduleMicrotask(_startCapture);
    return const TunerState();
  }

  Future<void> _startCapture() async {
    // No need to read state here as it was just initialized in build()
    // but if we are retrying, we might want copyWith. 
    // Since we are now in a microtask, state is initialized.
    state = state.copyWith(
      loading: true,
      clearLatest: true,
      bridgeActive: false,
      spectrumBins: const [],
    );
    final bridge = ref.read(pitchBridgeFactoryProvider)();
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
      state = const TunerState(loading: false);
      return;
    }
    _analysisSub = bridge.tunerAnalysisStream.listen((analysisFrame) {
      state = state.copyWith(spectrumBins: analysisFrame.bins);
    });
    _sub = bridge.pitchStream.listen((result) {
      final previousNote = state.latest?.noteName;
      state = state.copyWith(latest: result);
      if (result.noteName != previousNote) {
        ref.read(hapticServiceProvider).selectionClick();
      }
    });
    state = state.copyWith(loading: false, bridgeActive: true);
  }

  /// Disposes the current bridge and restarts audio capture.
  Future<void> retry() async {
    _sub?.cancel();
    _sub = null;
    _analysisSub?.cancel();
    _analysisSub = null;
    _bridge?.dispose();
    _bridge = null;
    await _startCapture();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final NotifierProvider<TunerNotifier, TunerState> tunerProvider =
    NotifierProvider.autoDispose<TunerNotifier, TunerState>(
  TunerNotifier.new,
);
