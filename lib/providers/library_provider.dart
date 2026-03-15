import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_controllers.dart';
import 'app_settings_provider.dart';
import 'dependency_providers.dart';
import '../repositories/recording_repository.dart';
import '../services/service_error_handler.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class LibraryState {
  const LibraryState({
    this.recordings = const [],
    this.logs = const [],
    this.monthlyLogStats = const {},
  });

  final List<RecordingEntry> recordings;
  final List<PracticeLogEntry> logs;
  final Map<String, MonthlyPracticeStats> monthlyLogStats;

  LibraryState copyWith({
    List<RecordingEntry>? recordings,
    List<PracticeLogEntry>? logs,
    Map<String, MonthlyPracticeStats>? monthlyLogStats,
  }) {
    return LibraryState(
      recordings: recordings ?? this.recordings,
      logs: logs ?? this.logs,
      monthlyLogStats: monthlyLogStats ?? this.monthlyLogStats,
    );
  }
}

class MonthlyPracticeStats {
  const MonthlyPracticeStats({
    this.practiceDays = const <int>{},
    this.totalMinutes = 0,
  });

  final Set<int> practiceDays;
  final int totalMinutes;
}

class PracticeSummaryStats {
  const PracticeSummaryStats({
    this.todayMinutes = 0,
    this.streakDays = 0,
  });

  final int todayMinutes;
  final int streakDays;
}

PracticeSummaryStats computePracticeSummary(
  List<PracticeLogEntry> logs, {
  DateTime? now,
}) {
  final today = _toDateOnly(now ?? DateTime.now());
  final uniquePracticeDates = logs.map((log) => _toDateOnly(log.date)).toSet();
  final todayMinutes = logs
      .where((log) => _toDateOnly(log.date) == today)
      .fold(0, (sum, log) => sum + log.durationMinutes);
  final yesterday = today.subtract(const Duration(days: 1));

  final streakStartDate = uniquePracticeDates.contains(today)
      ? today
      : uniquePracticeDates.contains(yesterday)
          ? yesterday
          : null;

  if (streakStartDate == null) {
    return PracticeSummaryStats(todayMinutes: todayMinutes);
  }

  var streakDays = 0;
  var cursor = streakStartDate;
  while (uniquePracticeDates.contains(cursor)) {
    streakDays++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return PracticeSummaryStats(
    todayMinutes: todayMinutes,
    streakDays: streakDays,
  );
}

DateTime _toDateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LibraryNotifier extends AsyncNotifier<LibraryState> {
  List<PracticeLogEntry> _memoizedLogs = const [];
  Map<String, MonthlyPracticeStats> _memoizedMonthlyLogStats = const {};

  @override
  Future<LibraryState> build() => _load();

  RecordingRepository get _repo => ref.read(recordingRepositoryProvider);
  Future<void> _syncCloudBackupIfEnabled() async {
    final settings = ref.read(appSettingsProvider);
    if (!settings.cloudSyncEnabled || !settings.hasRewardedPremiumAccess) {
      return;
    }
    await ref.read(cloudSyncControllerProvider).syncNow();
  }

  Future<LibraryState> _load() async {
    try {
      final recordings = await _repo.loadRecordings();
      final logs = await _repo.loadPracticeLogs();
      return LibraryState(
        recordings: recordings,
        logs: logs,
        monthlyLogStats: _monthlyLogStats(logs),
      );
    } catch (e, st) {
      ServiceErrorHandler.report(
        'LibraryNotifier: failed to load library data',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Reloads all library data from the repository.
  Future<void> reload() async {
    state = const AsyncLoading<LibraryState>();
    state = await AsyncValue.guard(_load);
  }

  /// Prepends [entry] to the recordings list and persists the change.
  Future<void> addRecording(RecordingEntry entry) async {
    final previous = state.asData?.value;
    if (previous == null) {
      throw StateError(
        'Cannot add recording: library data not loaded. '
        'Please wait for initialization to complete.',
      );
    }

    final updated = [entry, ...previous.recordings];
    state = AsyncValue.data(previous.copyWith(recordings: updated));
    try {
      await _repo.saveRecordings(updated);
      await _syncCloudBackupIfEnabled();
    } catch (e, st) {
      ServiceErrorHandler.report(
        'LibraryNotifier: failed to save recordings',
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Map<String, MonthlyPracticeStats> _monthlyLogStats(
    List<PracticeLogEntry> logs,
  ) {
    if (_areSameLogs(_memoizedLogs, logs)) return _memoizedMonthlyLogStats;

    final byMonth = <String, MonthlyPracticeStats>{};
    final practiceDaysByMonth = <String, Set<int>>{};
    final totalMinutesByMonth = <String, int>{};

    for (final log in logs) {
      final monthKey =
          '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}';
      practiceDaysByMonth
          .putIfAbsent(monthKey, () => <int>{})
          .add(log.date.day);
      totalMinutesByMonth[monthKey] =
          (totalMinutesByMonth[monthKey] ?? 0) + log.durationMinutes;
    }

    for (final entry in practiceDaysByMonth.entries) {
      byMonth[entry.key] = MonthlyPracticeStats(
        practiceDays: entry.value,
        totalMinutes: totalMinutesByMonth[entry.key] ?? 0,
      );
    }

    _memoizedLogs = logs;
    _memoizedMonthlyLogStats = byMonth;
    return byMonth;
  }

  bool _areSameLogs(List<PracticeLogEntry> a, List<PracticeLogEntry> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      if (left.date != right.date ||
          left.durationMinutes != right.durationMinutes ||
          left.memo != right.memo) {
        return false;
      }
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final libraryProvider =
    AsyncNotifierProvider.autoDispose<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);
