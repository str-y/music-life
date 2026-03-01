import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/library_screen.dart';

void main() {
  group('downsampleWaveform', () {
    test('returns empty list when source is empty', () {
      expect(downsampleWaveform(const [], 40), isEmpty);
    });

    test('returns copy when source length is <= target points', () {
      final source = <double>[0.1, 0.3, 0.7];
      final result = downsampleWaveform(source, 3);

      expect(result, equals(source));
      expect(identical(result, source), isFalse);
    });

    test('downsamples by averaging buckets and clamps values', () {
      final result = downsampleWaveform(<double>[0.0, 0.5, 1.0, 1.5], 2);

      expect(result, equals(<double>[0.25, 1.0]));
    });

    test('clamps averages above 1.0 to 1.0', () {
      final result = downsampleWaveform(<double>[0.0, 2.0, 3.0, 1.0], 2);

      expect(result, equals(<double>[1.0, 1.0]));
    });
  });

  group('buildLiveWaveformPreview', () {
    test('returns empty list when live amplitude data is empty', () {
      expect(buildLiveWaveformPreview(const []), isEmpty);
    });

    test('downsamples live amplitude data to target points', () {
      final result = buildLiveWaveformPreview(
        <double>[0.0, 0.5, 1.0, 1.0],
        targetPoints: 2,
      );

      expect(result, equals(<double>[0.25, 1.0]));
    });
  });

  group('LibraryScreen adaptive layout', () {
    testWidgets('shows side-by-side layout on large screens', (tester) async {
      final repo = _MockRecordingRepository();
      when(() => repo.loadRecordings()).thenAnswer((_) async => const []);
      when(() => repo.loadPracticeLogs()).thenAnswer((_) async => const []);

      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapLibraryScreen(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('library-wide-layout')), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('keeps tab layout on compact screens', (tester) async {
      final repo = _MockRecordingRepository();
      when(() => repo.loadRecordings()).thenAnswer((_) async => const []);
      when(() => repo.loadPracticeLogs()).thenAnswer((_) async => const []);

      await tester.binding.setSurfaceSize(const Size(600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_wrapLibraryScreen(repo));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byKey(const ValueKey('library-wide-layout')), findsNothing);
    });
  });
}

Widget _wrapLibraryScreen(RecordingRepository repository) {
  return ProviderScope(
    overrides: [
      recordingRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LibraryScreen(),
    ),
  );
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}
