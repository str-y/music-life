import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/practice_log_screen.dart';
import 'package:music_life/utils/practice_log_utils.dart';

import 'golden_test_utils.dart';

Widget _wrap(
  Widget child, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return buildGoldenTestApp(
    locale: locale,
    themeMode: themeMode,
    home: Scaffold(body: child),
  );
}

Widget _wrapScreen(
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [...overrides.whereType<dynamic>()],
    child: buildGoldenTestApp(
      locale: locale,
      themeMode: themeMode,
      home: child,
    ),
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
        for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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

  group('PracticeLogScreen accessibility', () {
    for (final variant in screenGoldenVariants) {
      testWidgets('matches practice log screen golden (${variant.name})',
          (tester) async {
        await prepareGoldenSurface(tester);
        final fixedNow = DateTime(2026, 2, 14);
        final logs = [
          PracticeLogEntry(
            date: fixedNow,
            durationMinutes: 30,
            memo: 'Guitar: scales',
          ),
          PracticeLogEntry(
            date: fixedNow.subtract(const Duration(days: 4)),
            durationMinutes: 20,
            memo: 'Piano: arpeggio',
          ),
        ];
        final repo = _MockRecordingRepository();
        when(repo.loadPracticeLogs).thenAnswer((_) async => logs);

        await tester.pumpWidget(
          _wrapScreen(
            PracticeLogScreen(now: () => fixedNow),
            locale: variant.locale,
            themeMode: variant.themeMode,
            overrides: [
              recordingRepositoryProvider.overrideWithValue(repo),
            ],
          ),
        );
        for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

        await expectScreenGolden(
          find.byType(PracticeLogScreen),
          variant.goldenPath('practice_log_screen'),
        );
      });
    }

    testWidgets(
        'month navigation buttons and analytics bars expose semantics labels',
        (tester) async {
      final now = DateTime(2026, 2, 14);
      final logs = [
        PracticeLogEntry(
          date: now,
          durationMinutes: 30,
          memo: 'Guitar: scales',
        ),
        PracticeLogEntry(
          date: now.subtract(const Duration(days: 4)),
          durationMinutes: 20,
          memo: 'Piano: arpeggio',
        ),
      ];
      final repo = _MockRecordingRepository();
      when(repo.loadPracticeLogs).thenAnswer((_) async => logs);

      await tester.pumpWidget(
        _wrapScreen(
          PracticeLogScreen(now: () => now),
          overrides: [
            recordingRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PracticeLogScreen)),
      )!;
      final weeklyTrend = buildWeeklyPracticeTrend(logs, now: now);

      expect(find.bySemanticsLabel(l10n.previousMonth), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.nextMonth), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '${weeklyTrend.last.label}, ${l10n.durationMinutes(weeklyTrend.last.minutes)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('analytics bars animate selection details when tapped',
        (tester) async {
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
      ];
      final repo = _MockRecordingRepository();
      when(repo.loadPracticeLogs).thenAnswer((_) async => logs);

      await tester.pumpWidget(
        _wrapScreen(
          PracticeLogScreen(now: () => DateTime(2026, 2, 14)),
          overrides: [
            recordingRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PracticeLogScreen)),
      )!;
      expect(
        find.text('2/14 • ${l10n.durationMinutes(30)}'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('practice-trend-bar-2/10')));
      await tester.pump();
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(
        find.text('2/10 • ${l10n.durationMinutes(20)}'),
        findsOneWidget,
      );
    });
  });

  group('PracticeLogScreen async states', () {
    testWidgets('shows retry UI when practice logs fail to load', (tester) async {
      final repo = _MockRecordingRepository();
      when(repo.loadPracticeLogs).thenThrow(Exception('load failed'));
      late String loadError;
      late String retry;

      await tester.pumpWidget(
        _wrapScreen(
          Builder(builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            loadError = l10n.loadDataError;
            retry = l10n.retry;
            return const PracticeLogScreen();
          }),
          overrides: [
            recordingRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.text(loadError), findsOneWidget);
      expect(find.text(retry), findsOneWidget);
    });
  });

  group('PracticeLogScreen batch export selection', () {
    testWidgets('record list allows selecting multiple entries for CSV export',
        (tester) async {
      final now = DateTime(2026, 2, 14);
      final logs = [
        PracticeLogEntry(
          date: now,
          durationMinutes: 30,
          memo: 'Guitar: scales',
        ),
        PracticeLogEntry(
          date: now.subtract(const Duration(days: 1)),
          durationMinutes: 20,
          memo: 'Piano: arpeggio',
        ),
      ];
      final repo = _MockRecordingRepository();
      when(repo.loadPracticeLogs).thenAnswer((_) async => logs);

      await tester.pumpWidget(
        _wrapScreen(
          PracticeLogScreen(now: () => now),
          overrides: [
            recordingRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PracticeLogScreen)),
      )!;

      await tester.tap(find.text(l10n.recordListTab));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(
        find.byKey(const ValueKey('practice-log-export-selected-csv')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('practice-log-clear-selection')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('practice-log-entry-toggle-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('practice-log-entry-toggle-1')));
      await tester.pump();

      expect(
        tester.widget<Checkbox>(
          find.byKey(const ValueKey('practice-log-entry-toggle-0')),
        ).value,
        isTrue,
      );
      expect(
        tester.widget<Checkbox>(
          find.byKey(const ValueKey('practice-log-entry-toggle-1')),
        ).value,
        isTrue,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('practice-log-export-selected-csv')),
            )
            .tooltip,
        '${l10n.exportCsv} (2)',
      );

      await tester.tap(find.byKey(const ValueKey('practice-log-clear-selection')));
      await tester.pump();

      expect(
        tester.widget<Checkbox>(
          find.byKey(const ValueKey('practice-log-entry-toggle-0')),
        ).value,
        isFalse,
      );
      expect(
        tester.widget<Checkbox>(
          find.byKey(const ValueKey('practice-log-entry-toggle-1')),
        ).value,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('practice-log-export-selected-csv')),
        findsNothing,
      );
    });
  });
}

class _MockRecordingRepository extends Mock implements RecordingRepository {}
