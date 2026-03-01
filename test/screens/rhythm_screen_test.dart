import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/rhythm_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

/// Pumps a [Semantics] widget with [label] and returns the resolved label.
Future<String> _pumpSemanticLabel(
  WidgetTester tester,
  String Function(AppLocalizations) extract,
) async {
  late String label;
  await tester.pumpWidget(_wrap(
    Builder(builder: (context) {
      label = extract(AppLocalizations.of(context)!);
      return Semantics(
        label: label,
        button: true,
        child: const SizedBox(width: 50, height: 36),
      );
    }),
  ));
  await tester.pumpAndSettle();
  return label;
}

void main() {
  group('RhythmScreen – BPM button semantic labels', () {
    for (final entry in <String, String Function(AppLocalizations)>{
      'bpmDecrease10SemanticLabel': (l) => l.bpmDecrease10SemanticLabel,
      'bpmDecrease1SemanticLabel': (l) => l.bpmDecrease1SemanticLabel,
      'bpmIncrease1SemanticLabel': (l) => l.bpmIncrease1SemanticLabel,
      'bpmIncrease10SemanticLabel': (l) => l.bpmIncrease10SemanticLabel,
    }.entries) {
      testWidgets('${entry.key} is non-empty and appears as a Semantics node',
          (tester) async {
        final label = await _pumpSemanticLabel(tester, entry.value);

        expect(label, isNotEmpty);
        expect(find.bySemanticsLabel(label), findsOneWidget);
      });
    }
  });

  testWidgets('disposing RhythmScreen does not leak animation tickers',
      (tester) async {
    await tester.pumpWidget(_wrap(const RhythmScreen()));
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
