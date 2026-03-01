import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/library_provider.dart';
import 'package:music_life/repositories/recording_repository.dart';

void main() {
  group('computePracticeSummary', () {
    test('sums today minutes and counts streak from today', () {
      final summary = computePracticeSummary(
        const [
          PracticeLogEntry(date: DateTime(2026, 2, 28), durationMinutes: 20),
          PracticeLogEntry(date: DateTime(2026, 3, 1), durationMinutes: 30),
          PracticeLogEntry(date: DateTime(2026, 3, 1), durationMinutes: 15),
        ],
        now: DateTime(2026, 3, 1, 12),
      );

      expect(summary.todayMinutes, 45);
      expect(summary.streakDays, 2);
    });

    test('counts streak from yesterday when today has no log', () {
      final summary = computePracticeSummary(
        const [
          PracticeLogEntry(date: DateTime(2026, 2, 27), durationMinutes: 20),
          PracticeLogEntry(date: DateTime(2026, 2, 28), durationMinutes: 30),
        ],
        now: DateTime(2026, 3, 1, 12),
      );

      expect(summary.todayMinutes, 0);
      expect(summary.streakDays, 2);
    });
  });

  group('LibraryNotifier monthly log stats', () {
    test('aggregates practice days and total minutes by month', () async {
      final mockRepo = _MockRecordingRepository();
      when(() => mockRepo.loadRecordings()).thenAnswer((_) async => const []);
      when(() => mockRepo.loadPracticeLogs()).thenAnswer(
        (_) async => const [
          PracticeLogEntry(date: DateTime(2026, 2, 1), durationMinutes: 30),
          PracticeLogEntry(date: DateTime(2026, 2, 1), durationMinutes: 20),
          PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 40),
          PracticeLogEntry(date: DateTime(2026, 3, 2), durationMinutes: 15),
        ],
      );

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await _waitUntilLoaded(container);
      final state = container.read(libraryProvider);
      final feb = state.monthlyLogStats['2026-02'];
      final mar = state.monthlyLogStats['2026-03'];

      expect(feb, isNotNull);
      expect(feb!.practiceDays, {1, 10});
      expect(feb.totalMinutes, 90);
      expect(mar, isNotNull);
      expect(mar!.practiceDays, {2});
      expect(mar.totalMinutes, 15);
    });

    test('reuses memoized monthly stats when log entries are unchanged',
        () async {
      final mockRepo = _MockRecordingRepository();
      when(() => mockRepo.loadRecordings()).thenAnswer((_) async => const []);
      when(() => mockRepo.loadPracticeLogs()).thenAnswer(
        (_) async => const [
          PracticeLogEntry(date: DateTime(2026, 2, 1), durationMinutes: 30),
          PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 40),
        ],
      );

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await _waitUntilLoaded(container);
      final initialStats = container.read(libraryProvider).monthlyLogStats;

      await container.read(libraryProvider.notifier).reload();
      await _waitUntilLoaded(container);
      final reloadedStats = container.read(libraryProvider).monthlyLogStats;

      expect(identical(initialStats, reloadedStats), isTrue);
    });
  });
}

Future<void> _waitUntilLoaded(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    if (!container.read(libraryProvider).loading) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('libraryProvider did not finish loading');
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}
