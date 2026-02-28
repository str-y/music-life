import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/composition_provider.dart';
import 'package:music_life/repositories/composition_repository.dart';
import 'package:music_life/screens/composition_helper_screen.dart';
import 'package:music_life/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ServiceLocator.overrideForTesting(ServiceLocator.forTesting(
      prefs: prefs,
      pitchBridgeFactory: ({FfiErrorHandler? onError}) =>
          _FakeNativePitchBridge(),
    ));
  });

  tearDown(() {
    ServiceLocator.reset();
  });

  group('CompositionRepository', () {

    test('load returns empty list when no data is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = CompositionRepository(prefs);
      final result = await repo.load();
      expect(result, isEmpty);
    });

    test('load returns compositions when valid JSON is stored', () async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1':
            '[{"id":"1","title":"Test","chords":["C","G"]}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = CompositionRepository(prefs);
      final result = await repo.load();
      expect(result.length, 1);
      expect(result.first.title, 'Test');
      expect(result.first.chords, ['C', 'G']);
    });

    test('load returns empty list on invalid JSON instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1': '{{not valid json}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = CompositionRepository(prefs);
      final result = await repo.load();
      expect(result, isEmpty); // repository.dart line 57 returns [] on catch
    });
  });

  group('CompositionHelperScreen – error notifications', () {
    testWidgets('shows load-error SnackBar when stored data is corrupt',
        (tester) async {
      final mockRepo = _MockCompositionRepository();
      when(() => mockRepo.load()).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('test error');
      });

      late String expectedError;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          compositionRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: _wrap(
          Builder(builder: (ctx) {
            expectedError = AppLocalizations.of(ctx)!.compositionLoadError;
            return const CompositionHelperScreen();
          }),
        ),
      ));

      // Build initial frame
      await tester.pump();
      // Wait for the async error to propagate and trigger SnackBar
      await tester.pump(const Duration(milliseconds: 100));
      // Settle SnackBar animation
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(expectedError), findsOneWidget);
    });

    testWidgets('shows compositionLoadError string from localizations',
        (tester) async {
      late String errorText;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          errorText = AppLocalizations.of(context)!.compositionLoadError;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
      expect(errorText, isNotEmpty);
    });

    testWidgets('shows compositionSaveError string from localizations',
        (tester) async {
      late String errorText;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          errorText = AppLocalizations.of(context)!.compositionSaveError;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
      expect(errorText, isNotEmpty);
    });

    testWidgets('shows compositionDeleteError string from localizations',
        (tester) async {
      late String errorText;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          errorText = AppLocalizations.of(context)!.compositionDeleteError;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
      expect(errorText, isNotEmpty);
    });
  });

  group('ChordAnalyserScreen – error string localizations', () {
    testWidgets('shows chordAnalyserError string from localizations',
        (tester) async {
      late String errorText;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          errorText = AppLocalizations.of(context)!.chordAnalyserError;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();
      expect(errorText, isNotEmpty);
    });
  });
}

class _FakeNativePitchBridge extends Fake implements NativePitchBridge {}
class _MockCompositionRepository extends Mock implements CompositionRepository {}
