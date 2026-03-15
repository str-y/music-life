import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_controllers.dart';
import '../repositories/recording_repository.dart';
import '../services/service_error_handler.dart';
import 'dependency_providers.dart';

class PracticeLogNotifier
    extends AsyncNotifier<List<PracticeLogEntry>> {
  @override
  Future<List<PracticeLogEntry>> build() => _load();

  RecordingRepository get _repo => ref.read(recordingRepositoryProvider);
  Future<void> _syncCloudBackupIfEnabled() =>
      ref.read(cloudSyncControllerProvider).syncBackupIfEligible();

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
    final previous = state.asData?.value;
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
    try {
      await _syncCloudBackupIfEnabled();
    } catch (e, st) {
      ServiceErrorHandler.report(
        'PracticeLogNotifier: cloud sync failed after adding entry',
        error: e,
        stackTrace: st,
      );
    }
  }

  List<PracticeLogEntry> _sortEntries(List<PracticeLogEntry> entries) =>
      [...entries]..sort((a, b) => b.date.compareTo(a.date));
}

final practiceLogProvider = AsyncNotifierProvider.autoDispose<
    PracticeLogNotifier, List<PracticeLogEntry>>(
  PracticeLogNotifier.new,
);
