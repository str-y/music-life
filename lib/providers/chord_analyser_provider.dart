import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/app_constants.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/chord_history_repository.dart';
import 'package:music_life/utils/app_logger.dart';

/// Immutable state for the chord analyser screen.
class ChordAnalyserState {
  const ChordAnalyserState({
    this.loading = true,
    this.currentChord = '---',
    this.history = const [],
    this.selectedFilterDate,
    this.chordNameFilter = '',
    this.bridgeReady = false,
    this.isListeningActive = false,
    this.errorMessage,
  });

  final bool loading;
  final String currentChord;
  final List<ChordHistoryEntry> history;
  final DateTime? selectedFilterDate;
  final String chordNameFilter;

  /// `false` when bridge failed to start (e.g. microphone permission revoked).
  final bool bridgeReady;

  /// `true` while audio is actively detected; `false` after idle timeout.
  final bool isListeningActive;

  /// Non-null when a bridge error should be surfaced to the UI as a SnackBar.
  final String? errorMessage;

  ChordAnalyserState copyWith({
    bool? loading,
    String? currentChord,
    List<ChordHistoryEntry>? history,
    Object? selectedFilterDate = _sentinel,
    String? chordNameFilter,
    bool? bridgeReady,
    bool? isListeningActive,
    Object? errorMessage = _sentinel,
  }) {
    return ChordAnalyserState(
      loading: loading ?? this.loading,
      currentChord: currentChord ?? this.currentChord,
      history: history ?? this.history,
      selectedFilterDate: selectedFilterDate == _sentinel
          ? this.selectedFilterDate
          : selectedFilterDate as DateTime?,
      chordNameFilter: chordNameFilter ?? this.chordNameFilter,
      bridgeReady: bridgeReady ?? this.bridgeReady,
      isListeningActive: isListeningActive ?? this.isListeningActive,
      errorMessage:
          errorMessage == _sentinel ? this.errorMessage : errorMessage as String?,
    );
  }

  static const _sentinel = Object();
}

// ignore: specify_nonobvious_property_types  The return type of NotifierProvider.autoDispose is not ergonomically annotatable.
final chordAnalyserProvider =
    NotifierProvider.autoDispose<ChordAnalyserNotifier, ChordAnalyserState>(
  ChordAnalyserNotifier.new,
);

/// Manages the chord analyser lifecycle: bridge, stream, timer, and history.
///
/// All resource cleanup is registered via `ref.onDispose`, so there is no need
/// for `mounted` checks in the widget layer.
class ChordAnalyserNotifier extends Notifier<ChordAnalyserState> {
  NativePitchBridge? _bridge;
  StreamSubscription<String>? _subscription;
  Timer? _idleTimer;

  /// Set to `true` by `ref.onDispose` so that in-flight async operations can
  /// bail out early without touching state after the notifier is gone.
  bool _disposed = false;

  @override
  ChordAnalyserState build() {
    ref.onDispose(() {
      _disposed = true;
      _idleTimer?.cancel();
      _subscription?.cancel();
      _bridge?.dispose();
    });
    // Schedule async ops via microtask so that build() returns first,
    // ensuring state is initialized before any reads/writes occur.
    Future.microtask(_startCapture);
    Future.microtask(_loadHistory);
    _scheduleIdleStop();
    return const ChordAnalyserState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> restartCapture() => _restartCapture();

  Future<void> applyFilter({
    required DateTime? date,
    required String chordName,
  }) async {
    state = state.copyWith(
      selectedFilterDate: date,
      chordNameFilter: chordName,
    );
    await _loadHistory();
  }

  Future<void> clearFilter() async {
    state = state.copyWith(
      selectedFilterDate: null,
      chordNameFilter: '',
    );
    await _loadHistory();
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _startCapture() async {
    state = state.copyWith(loading: true);

    final bridge = ref.read(pitchBridgeFactoryProvider)(
      onError: _onBridgeError,
    );
    final started = await bridge.startCapture();

    // Bail out if the notifier was disposed while we were awaiting.
    if (_disposed) {
      bridge.dispose();
      return;
    }

    if (!started) {
      bridge.dispose();
      // _bridge stays null → widget renders MicPermissionDeniedView.
      state = state.copyWith(loading: false, bridgeReady: false);
      return;
    }

    _bridge = bridge;
    _subscription = bridge.chordStream.listen((chord) {
      ref.read(dynamicThemeControllerProvider).updateFromChord(chord);
      _scheduleIdleStop();
      state = state.copyWith(currentChord: chord, isListeningActive: true);
      _persistAndRefresh(ChordHistoryEntry(chord: chord, time: DateTime.now()));
    });
    state = state.copyWith(loading: false, bridgeReady: true);
  }

  Future<void> _restartCapture() async {
    await _subscription?.cancel();
    _subscription = null;
    _bridge?.dispose();
    _bridge = null;
    state = state.copyWith(currentChord: '---');
    await _startCapture();
  }

  /// Fire-and-forget persist + history refresh; errors are logged internally.
  void _persistAndRefresh(ChordHistoryEntry entry) {
    _doPersistAndRefresh(entry);
  }

  Future<void> _doPersistAndRefresh(ChordHistoryEntry entry) async {
    try {
      final repository = ref.read(chordHistoryRepositoryProvider);
      await repository.addEntry(entry);
      if (!_disposed) await _loadHistory();
    } on Object catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to persist chord analysis entry',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _loadHistory() async {
    try {
      final repository = ref.read(chordHistoryRepositoryProvider);
      final entries = await repository.loadEntries(
        day: state.selectedFilterDate,
        chordNameFilter: state.chordNameFilter,
      );
      if (!_disposed) state = state.copyWith(history: entries);
    } on Object catch (error, stackTrace) {
      AppLogger.reportError(
        'Failed to load chord analysis history',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onBridgeError(Object error, StackTrace stack) {
    AppLogger.reportError(
      'Chord analyser bridge error',
      error: error,
      stackTrace: stack,
    );
    if (!_disposed) state = state.copyWith(errorMessage: 'error');
  }

  void _scheduleIdleStop() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConstants.listeningIdleTimeout, () {
      if (!_disposed) state = state.copyWith(isListeningActive: false);
    });
  }
}
