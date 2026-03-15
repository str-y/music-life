import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/practice_log_provider.dart';
import 'package:music_life/repositories/recording_repository.dart';

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
      expect(container.read(practiceLogProvider).asData?.value, existing);
    });
  });
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}
