import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/screens/composition_helper_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('CompositionRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty list when no data is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = CompositionRepository();
      final result = await repo.load();
      expect(result, isEmpty);
    });

    test('load returns compositions when valid JSON is stored', () async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1':
            '[{"id":"1","title":"Test","chords":["C","G"]}]',
      });
      final repo = CompositionRepository();
      final result = await repo.load();
      expect(result.length, 1);
      expect(result.first.title, 'Test');
      expect(result.first.chords, ['C', 'G']);
    });

    test('load throws on invalid JSON', () async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1': '{{not valid json}}',
      });
      final repo = CompositionRepository();
      expect(repo.load(), throwsA(anything));
    });
  });

  group('CompositionHelperScreen – error notifications', () {
    testWidgets('shows load-error SnackBar when stored data is corrupt',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'compositions_v1': '{{not valid json}}',
      });

      late String expectedError;
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          expectedError = AppLocalizations.of(ctx)!.compositionLoadError;
          return const CompositionHelperScreen();
        }),
      ));
      // Allow the async _loadSaved call to complete and the SnackBar to appear.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

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
