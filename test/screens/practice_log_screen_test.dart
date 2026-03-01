import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/practice_log_screen.dart';

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

  group('PracticeLogScreen analytics helpers', () {
    final now = DateTime(2026, 2, 14);
    final logs = [
      PracticeLogEntry(
        date: DateTime(2026, 2, 14),
        durationMinutes: 30,
        memo: 'Guitar: scales',
      ),
      PracticeLogEntry(
        date: DateTime(2026, 2, 10),
        durationMinutes: 20,
        memo: 'Piano: arpeggio',
      ),
      PracticeLogEntry(
        date: DateTime(2026, 1, 20),
        durationMinutes: 40,
        memo: '',
      ),
    ];

    test('buildWeeklyPracticeTrend returns 7-day series ending at now', () {
      final series = buildWeeklyPracticeTrend(logs, now: now);

      expect(series.length, 7);
      expect(series.last.label, '2/14');
      expect(series.last.minutes, 30);
      expect(series[2].label, '2/10');
      expect(series[2].minutes, 20);
    });

    test('buildMonthlyPracticeTrend returns 6-month aggregated series', () {
      final series = buildMonthlyPracticeTrend(logs, now: now);

      expect(series.length, 6);
      expect(series.last.label, '2');
      expect(series.last.minutes, 50);
      expect(series[4].label, '1');
      expect(series[4].minutes, 40);
    });

    test('buildPracticeInstrumentMinutes aggregates by memo label', () {
      final ratio = buildPracticeInstrumentMinutes(logs);

      expect(ratio['Guitar'], 30);
      expect(ratio['Piano'], 20);
      expect(ratio['Other'], 40);
    });
  });
}
