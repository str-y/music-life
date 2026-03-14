import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/recording_repository.dart';
import '../services/service_error_handler.dart';
import 'dependency_providers.dart';

class PracticeLogNotifier
    extends AutoDisposeAsyncNotifier<List<PracticeLogEntry>> {
  @override
  Future<List<PracticeLogEntry>> build() => _load();

  RecordingRepository get _repo => ref.read(recordingRepositoryProvider);

  Future<List<PracticeLogEntry>> _load() async {
    try {
      return _sortEntries(await _repo.loadPracticeLogs());
    } catch (e, st) {
      ServiceErrorHandler.report(
        'PracticeLogNotifier: failed to load practice logs',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<PracticeLogEntry>>();
    state = await AsyncValue.guard(_load);
  }

  Future<void> addEntry(PracticeLogEntry entry) async {
    final previous = state.valueOrNull;
    if (previous == null) {
      throw StateError(
        'Cannot add practice log entry: data not loaded. '
        'Please wait for initialization to complete.',
      );
    }

    final updated = _sortEntries([entry, ...previous]);
    state = AsyncValue.data(updated);
    try {
      await _repo.savePracticeLogs(updated);
    } catch (e, st) {
      ServiceErrorHandler.report(
        'PracticeLogNotifier: failed to save practice log entry',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  List<PracticeLogEntry> _sortEntries(List<PracticeLogEntry> entries) =>
      [...entries]..sort((a, b) => b.date.compareTo(a.date));
}

final practiceLogProvider = AsyncNotifierProvider.autoDispose<
    PracticeLogNotifier, List<PracticeLogEntry>>(
  PracticeLogNotifier.new,
);
