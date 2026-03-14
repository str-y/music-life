import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/recording_repository.dart';
import 'package:music_life/services/ai_practice_insights_service.dart';

void main() {
  group('HybridAiPracticeInsightsService', () {
    final service = HybridAiPracticeInsightsService();

    test('builds seven-point timelines and weekly menu from local data',
        () async {
      final insight = await service.analyze(
        logs: [
          PracticeLogEntry(date: DateTime(2026, 3, 10), durationMinutes: 20),
          PracticeLogEntry(date: DateTime(2026, 3, 11), durationMinutes: 30),
          PracticeLogEntry(date: DateTime(2026, 3, 13), durationMinutes: 25),
          PracticeLogEntry(date: DateTime(2026, 3, 14), durationMinutes: 35),
        ],
        recordings: [
          RecordingEntry(
            id: 'r1',
            title: 'Take 1',
            recordedAt: DateTime(2026, 3, 13, 20),
            durationSeconds: 90,
            waveformData: const [0.2, 0.25, 0.22, 0.24, 0.2],
          ),
        ],
        now: DateTime(2026, 3, 14, 12),
      );

      expect(insight.providerLabel, 'On-device AI coach');
      expect(insight.pitchStabilitySeries, hasLength(7));
      expect(insight.rhythmAccuracySeries, hasLength(7));
      expect(insight.weeklyMenu, hasLength(3));
      expect(insight.headline, isNotEmpty);
      expect(insight.coachingNotification, contains('AI coach'));
    });

    test('returns Japanese coaching copy when localeCode is ja', () async {
      final insight = await service.analyze(
        logs: [
          PracticeLogEntry(date: DateTime(2026, 3, 14), durationMinutes: 15),
        ],
        recordings: const [],
        localeCode: 'ja',
        now: DateTime(2026, 3, 14, 12),
      );

      expect(insight.providerLabel, 'オンデバイスAIコーチ');
      expect(insight.headline, contains('直近1週間'));
      expect(insight.coachingNotification, contains('AIコーチ'));
      expect(insight.weeklyMenu, hasLength(3));
    });
  });
}
