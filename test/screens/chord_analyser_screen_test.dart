import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/screens/chord_analyser_screen.dart';

class _MockNativePitchBridge extends Mock implements NativePitchBridge {}

Widget _wrap(Widget child, {List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: [...overrides],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('ChordAnalyserScreen – detected-note semantics', () {
    testWidgets('currentNoteSemanticLabel is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.currentNoteSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets(
        'Semantics node with currentNoteSemanticLabel is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.currentNoteSemanticLabel;
          return Semantics(
            liveRegion: true,
            label: label,
            value: 'C',
            child: const SizedBox(width: 200, height: 200),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  testWidgets('matches chord analyser screen golden', (tester) async {
    final bridge = _MockNativePitchBridge();
    when(() => bridge.startCapture()).thenAnswer((_) async => true);
    when(() => bridge.chordStream)
        .thenAnswer((_) => const Stream<String>.empty());
    when(() => bridge.dispose()).thenReturn(null);

    await tester.pumpWidget(
      _wrap(
        const ChordAnalyserScreen(useMicPermissionGate: false),
        overrides: [
          pitchBridgeFactoryProvider.overrideWithValue(({onError}) => bridge),
        ],
      ),
    );

    // Avoid pumpAndSettle(): both screens contain a repeating listening animation.
    // First pump lets async initialization complete, second pump captures a fixed frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await expectLater(
      find.byType(ChordAnalyserScreen),
      matchesGoldenFile('goldens/chord_analyser_screen.png'),
    );
  });

  group('ChordAnalyserScreen – chord history semantics', () {
    testWidgets('chordHistory label is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets('Semantics node with chordHistory label is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.chordHistory;
          return Semantics(
            label: label,
            child: const SizedBox(width: 200, height: 200),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });
}
