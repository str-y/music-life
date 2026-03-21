import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/screens/ai_practice_insights_screen.dart';
import 'package:music_life/screens/practice_log_screen.dart';
import 'package:music_life/services/ai_practice_insights_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRecordingRepository extends Mock implements RecordingRepository {}

class _FakeAiPracticeInsightsService implements AiPracticeInsightsService {
  @override
  Future<AiPracticeInsight> analyze({
    required List<PracticeLogEntry> logs,
    required List<RecordingEntry> recordings,
    String localeCode = 'en',
    DateTime? now,
  }) async {
    return const AiPracticeInsight(
      providerLabel: 'Test AI',
      headline: 'Focus on steadier note endings this week.',
      pitchStabilitySeries: [
        AiPracticeScorePoint(label: '3/8', score: 61),
        AiPracticeScorePoint(label: '3/9', score: 64),
        AiPracticeScorePoint(label: '3/10', score: 66),
        AiPracticeScorePoint(label: '3/11', score: 68),
        AiPracticeScorePoint(label: '3/12', score: 70),
        AiPracticeScorePoint(label: '3/13', score: 72),
        AiPracticeScorePoint(label: '3/14', score: 74),
      ],
      rhythmAccuracySeries: [
        AiPracticeScorePoint(label: '3/8', score: 58),
        AiPracticeScorePoint(label: '3/9', score: 60),
        AiPracticeScorePoint(label: '3/10', score: 65),
        AiPracticeScorePoint(label: '3/11', score: 67),
        AiPracticeScorePoint(label: '3/12', score: 71),
        AiPracticeScorePoint(label: '3/13', score: 73),
        AiPracticeScorePoint(label: '3/14', score: 76),
      ],
      weeklyMenu: [
        '10 minutes of drone matching',
        'Subdivision metronome practice',
        'One recorded full run-through',
      ],
      coachingNotification:
          'AI coach: Keep the streak alive with a 20-minute rhythm block tonight.',
    );
  }
}

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [...overrides.whereType<dynamic>()],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<List<dynamic>> _baseOverrides({
  Map<String, Object> initialValues = const {},
  RecordingRepository? repository,
  AiPracticeInsightsService? service,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (repository != null)
      recordingRepositoryProvider.overrideWithValue(repository),
    if (service != null)
      aiPracticeInsightsServiceProvider.overrideWithValue(service),
  ];
}

void main() {
  group('AiPracticeInsightsScreen', () {
    testWidgets('practice log screen opens AI insights entry point', (
      tester,
    ) async {
      final repository = _MockRecordingRepository();
      when(repository.loadRecordings).thenAnswer((_) async => const []);
      when(repository.loadPracticeLogs).thenAnswer((_) async => const []);
      final overrides = await _baseOverrides(repository: repository);

      await tester.pumpWidget(
        _wrap(
          const PracticeLogScreen(),
          overrides: [...overrides.whereType<dynamic>()],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PracticeLogScreen)),
      )!;

      await tester.tap(find.byTooltip(l10n.aiPracticeInsightsTitle));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      expect(find.byType(AiPracticeInsightsScreen), findsOneWidget);
      expect(find.text(l10n.aiPracticeInsightsPremiumTitle), findsOneWidget);
    });

    testWidgets('shows generated insight cards when premium is active', (
      tester,
    ) async {
      final repository = _MockRecordingRepository();
      when(repository.loadRecordings).thenAnswer(
        (_) async => [
          RecordingEntry(
            id: 'r1',
            title: 'Take 1',
            recordedAt: DateTime(2026, 3, 14, 9),
            durationSeconds: 90,
            waveformData: const [0.1, 0.2, 0.15],
          ),
        ],
      );
      when(repository.loadPracticeLogs).thenAnswer(
        (_) async => [
          PracticeLogEntry(
            date: DateTime(2026, 3, 14),
            durationMinutes: 25,
            memo: 'Scales',
          ),
        ],
      );
      final overrides = await _baseOverrides(
        initialValues: {
          AppConfig.defaultRewardedPremiumExpiresAtStorageKey:
              '2099-01-01T00:00:00.000Z',
        },
        repository: repository,
        service: _FakeAiPracticeInsightsService(),
      );

      await tester.pumpWidget(
        _wrap(
          const AiPracticeInsightsScreen(),
          overrides: [...overrides.whereType<dynamic>()],
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(AiPracticeInsightsScreen)),
      )!;

      expect(find.text('Test AI'), findsOneWidget);
      expect(find.text(l10n.aiPracticeInsightsPitchStability), findsOneWidget);
      expect(find.text(l10n.aiPracticeInsightsRhythmAccuracy), findsOneWidget);
      expect(find.text(l10n.aiPracticeInsightsWeeklyMenu), findsOneWidget);
      expect(
        find.text('AI coach: Keep the streak alive with a 20-minute rhythm block tonight.'),
        findsOneWidget,
      );
    });
  });
}
