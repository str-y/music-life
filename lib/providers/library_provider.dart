import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/recording_repository.dart';
import '../service_locator.dart';
import '../utils/app_logger.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class LibraryState {
  const LibraryState({
    this.recordings = const [],
    this.logs = const [],
    this.loading = true,
    this.hasError = false,
  });

  final List<RecordingEntry> recordings;
  final List<PracticeLogEntry> logs;
  final bool loading;
  final bool hasError;

  LibraryState copyWith({
    List<RecordingEntry>? recordings,
    List<PracticeLogEntry>? logs,
    bool? loading,
    bool? hasError,
  }) {
    return LibraryState(
      recordings: recordings ?? this.recordings,
      logs: logs ?? this.logs,
      loading: loading ?? this.loading,
      hasError: hasError ?? this.hasError,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LibraryNotifier extends Notifier<LibraryState> {
  @override
  LibraryState build() {
    _load();
    return const LibraryState();
  }

  RecordingRepository get _repo => ServiceLocator.instance.recordingRepository;

  Future<void> _load() async {
    state = state.copyWith(loading: true, hasError: false);
    try {
      final recordings = await _repo.loadRecordings();
      final logs = await _repo.loadPracticeLogs();
      state = LibraryState(recordings: recordings, logs: logs);
    } catch (e, st) {
      AppLogger.reportError(
        'LibraryNotifier: failed to load library data',
        error: e,
        stackTrace: st,
      );
      state = const LibraryState(loading: false, hasError: true);
    }
  }

  /// Reloads all library data from the repository.
  Future<void> reload() => _load();

  /// Prepends [entry] to the recordings list and persists the change.
  Future<void> addRecording(RecordingEntry entry) async {
    final updated = [entry, ...state.recordings];
    state = state.copyWith(recordings: updated);
    await _repo.saveRecordings(updated);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final libraryProvider =
    NotifierProvider.autoDispose<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
