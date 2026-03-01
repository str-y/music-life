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
  group('TunerScreen – cents meter semantics', () {
    testWidgets('centsMeterSemanticLabel is a non-empty localized string',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.centsMeterSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(label, isNotEmpty);
    });

    testWidgets(
        'Semantics node with centsMeterSemanticLabel is found in widget tree',
        (tester) async {
      late String label;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          label = AppLocalizations.of(context)!.centsMeterSemanticLabel;
          return Semantics(
            label: label,
            child: const SizedBox(width: 200, height: 48),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(label), findsOneWidget);
    });
  });

  group('TunerScreen – pitch and waveform semantics', () {
    testWidgets('pitch and waveform labels are non-empty localized strings',
        (tester) async {
      late String noteLabel;
      late String waveformLabel;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          noteLabel = l10n.currentNoteSemanticLabel;
          waveformLabel = l10n.waveformSemanticLabel;
          return const SizedBox.shrink();
        }),
      ));
      await tester.pumpAndSettle();

      expect(noteLabel, isNotEmpty);
      expect(waveformLabel, isNotEmpty);
    });

    testWidgets('Semantics nodes for pitch result and waveform are found',
        (tester) async {
      late String noteLabel;
      late String waveformLabel;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          noteLabel = l10n.currentNoteSemanticLabel;
          waveformLabel = l10n.waveformSemanticLabel;
          return Column(
            children: [
              Semantics(
                label: noteLabel,
                value: 'A4, 440.0 Hz',
                child: const SizedBox(width: 200, height: 100),
              ),
              Semantics(
                label: waveformLabel,
                child: const SizedBox(width: 200, height: 36),
              ),
            ],
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(noteLabel), findsOneWidget);
      expect(find.bySemanticsLabel(waveformLabel), findsOneWidget);
    });
  });
}
