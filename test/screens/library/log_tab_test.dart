import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/library_provider.dart';
import 'package:music_life/screens/library/log_tab.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('LogTab', () {
    testWidgets('shows empty-state CTA when monthly stats are empty',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          LogTab(
            monthlyLogStatsByMonth: const {},
            onRecordPractice: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No practice records'), findsOneWidget);
      expect(find.text('Add a record with the + button'), findsOneWidget);

      await tester.tap(find.text('Record Practice'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows calendar content when monthly stats exist',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          LogTab(
            monthlyLogStatsByMonth: const {
              '2024-01': MonthlyPracticeStats(practiceDays: {1}, totalMinutes: 30),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarGrid), findsOneWidget);
      expect(find.text('No practice records'), findsNothing);
    });
  });
}
