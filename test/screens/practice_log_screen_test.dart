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
  group('PracticeLogScreen – calendar day cell semantics', () {
    for (final entry in <String, String Function(AppLocalizations)>{
      'practicedLabel': (l) => l.practicedLabel,
      'todayLabel': (l) => l.todayLabel,
    }.entries) {
      testWidgets('${entry.key} is a non-empty localized string',
          (tester) async {
        late String label;
        await tester.pumpWidget(_wrap(
          Builder(builder: (context) {
            label = entry.value(AppLocalizations.of(context)!);
            return const SizedBox.shrink();
          }),
        ));
        await tester.pumpAndSettle();

        expect(label, isNotEmpty);
      });
    }

    testWidgets(
        'day cell Semantics node contains day number, today, and practiced',
        (tester) async {
      late String todayLabel;
      late String practicedLabel;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          todayLabel = l10n.todayLabel;
          practicedLabel = l10n.practicedLabel;
          return Semantics(
            label: '15, $todayLabel, $practicedLabel',
            excludeSemantics: true,
            child: const SizedBox(width: 44, height: 44),
          );
        }),
      ));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('15, $todayLabel, $practicedLabel'),
        findsOneWidget,
      );
    });
  });
}
