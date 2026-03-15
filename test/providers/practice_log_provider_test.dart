import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/practice_log_provider.dart';
import 'package:music_life/repositories/cloud_sync_repository.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PracticeLogNotifier', () {
    test('build resolves to AsyncData with entries sorted newest first',
        () async {
      final mockRepo = _MockRecordingRepository();
      when(() => mockRepo.loadPracticeLogs()).thenAnswer(
        (_) async => [
          PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 20),
          PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
        ],
      );

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      expect(container.read(practiceLogProvider).isLoading, isTrue);

      final entries = await container.read(practiceLogProvider.future);
      expect(
        entries.map((entry) => entry.date),
        orderedEquals([
          DateTime(2026, 2, 14),
          DateTime(2026, 2, 10),
        ]),
      );
      expect(container.read(practiceLogProvider).hasValue, isTrue);
    });

    test('build exposes AsyncError when repository load fails', () async {
      final mockRepo = _MockRecordingRepository();
      when(() => mockRepo.loadPracticeLogs()).thenThrow(Exception('load failed'));

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(practiceLogProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(practiceLogProvider).hasError, isTrue);
    });

    test('reload enters loading and updates with refreshed entries', () async {
      final mockRepo = _MockRecordingRepository();
      final reloadedEntries = Completer<List<PracticeLogEntry>>();
      var loadCallCount = 0;
      when(() => mockRepo.loadPracticeLogs()).thenAnswer((_) {
        loadCallCount += 1;
        if (loadCallCount == 1) {
          return Future.value([
            PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 20),
          ]);
        }
        return reloadedEntries.future;
      });

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);
      await container.read(practiceLogProvider.future);

      final states = <AsyncValue<List<PracticeLogEntry>>>[];
      final subscription = container.listen(
        practiceLogProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final reloadFuture = container.read(practiceLogProvider.notifier).reload();
      expect(container.read(practiceLogProvider).isLoading, isTrue);

      reloadedEntries.complete([
        PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
        PracticeLogEntry(date: DateTime(2026, 2, 12), durationMinutes: 25),
      ]);
      await reloadFuture;

      expect(states.any((state) => state.isLoading), isTrue);
      expect(
        container.read(practiceLogProvider).asData?.value.map((entry) => entry.date),
        orderedEquals([
          DateTime(2026, 2, 14),
          DateTime(2026, 2, 12),
        ]),
      );
    });

    test('reload exposes AsyncError and succeeds on retry', () async {
      final mockRepo = _MockRecordingRepository();
      var loadCallCount = 0;
      when(() => mockRepo.loadPracticeLogs()).thenAnswer((_) async {
        loadCallCount += 1;
        switch (loadCallCount) {
          case 1:
            return [
              PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 20),
            ];
          case 2:
            throw Exception('reload failed');
          default:
            return [
              PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
            ];
        }
      });

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);
      await container.read(practiceLogProvider.future);

      await container.read(practiceLogProvider.notifier).reload();
      expect(container.read(practiceLogProvider).hasError, isTrue);

      await container.read(practiceLogProvider.notifier).reload();
      expect(
        container.read(practiceLogProvider).asData?.value.map((entry) => entry.date),
        orderedEquals([DateTime(2026, 2, 14)]),
      );
    });

    test('addEntry throws StateError when data is not loaded', () async {
      final mockRepo = _MockRecordingRepository();
      when(() => mockRepo.loadPracticeLogs()).thenThrow(Exception('load failed'));

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(practiceLogProvider.future),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        container.read(practiceLogProvider.notifier).addEntry(
              PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
            ),
        throwsA(isA<StateError>()),
      );
    });

    test('addEntry rolls back state when save fails', () async {
      final mockRepo = _MockRecordingRepository();
      final existing = [
        PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 20),
      ];
      when(() => mockRepo.loadPracticeLogs()).thenAnswer((_) async => existing);
      when(() => mockRepo.savePracticeLogs(any())).thenThrow(Exception('save failed'));

      final container = ProviderContainer(
        overrides: [recordingRepositoryProvider.overrideWithValue(mockRepo)],
      );
      addTearDown(container.dispose);
      await container.read(practiceLogProvider.future);

      await expectLater(
        container.read(practiceLogProvider.notifier).addEntry(
              PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
            ),
        throwsA(isA<Exception>()),
      );
      expect(
        container.read(practiceLogProvider).asData?.value.map((entry) => entry.date),
        orderedEquals([DateTime(2026, 2, 10)]),
      );
    });

    test('addEntry rolls back state when cloud sync fails', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockRepo = _MockRecordingRepository();
      final mockCloudSyncRepository = _MockCloudSyncRepository();
      final existing = [
        PracticeLogEntry(date: DateTime(2026, 2, 10), durationMinutes: 20),
      ];
      var syncCallCount = 0;
      when(() => mockRepo.loadPracticeLogs()).thenAnswer((_) async => existing);
      when(() => mockRepo.savePracticeLogs(any())).thenAnswer((_) async {});
      when(() => mockCloudSyncRepository.syncNow()).thenAnswer((_) async {
        syncCallCount += 1;
        if (syncCallCount == 1) {
          return DateTime.utc(2030, 1, 1);
        }
        throw Exception('sync failed');
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          recordingRepositoryProvider.overrideWithValue(mockRepo),
          cloudSyncRepositoryProvider.overrideWithValue(mockCloudSyncRepository),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(premiumSettingsControllerProvider)
          .unlockRewardedPremiumFor(
            const Duration(hours: 24),
            now: DateTime.utc(2030, 1, 1),
          );
      await container.read(cloudSyncControllerProvider).setEnabled(true);
      await container.read(practiceLogProvider.future);

      await expectLater(
        container.read(practiceLogProvider.notifier).addEntry(
              PracticeLogEntry(date: DateTime(2026, 2, 14), durationMinutes: 30),
            ),
        throwsA(isA<Exception>()),
      );

      final savedEntries = verify(
        () => mockRepo.savePracticeLogs(captureAny()),
      ).captured.single as List<PracticeLogEntry>;
      expect(savedEntries.map((entry) => entry.date), [
        DateTime(2026, 2, 14),
        DateTime(2026, 2, 10),
      ]);
      expect(syncCallCount, 2);
      expect(
        container.read(practiceLogProvider).asData?.value.map((entry) => entry.date),
        orderedEquals([DateTime(2026, 2, 10)]),
      );
    });
  });
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}

class _MockCloudSyncRepository extends Mock implements CloudSyncRepository {}
