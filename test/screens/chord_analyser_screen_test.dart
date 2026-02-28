import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
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
}
