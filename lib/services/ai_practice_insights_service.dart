import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../repositories/recording_repository.dart';

const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
const String _openAiModel = String.fromEnvironment(
  'OPENAI_MODEL',
  defaultValue: 'gpt-4o-mini',
);
const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const String _geminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-1.5-flash',
);

class AiPracticeScorePoint {
  const AiPracticeScorePoint({
    required this.label,
    required this.score,
  });

  final String label;
  final int score;

  factory AiPracticeScorePoint.fromJson(Map<String, dynamic> json) {
    return AiPracticeScorePoint(
      label: json['label'] as String? ?? '',
      score: _clampScore((json['score'] as num?) ?? 0),
    );
  }

  Map<String, Object> toJson() => {
        'label': label,
        'score': score,
      };
}

class AiPracticeInsight {
  const AiPracticeInsight({
    required this.providerLabel,
    required this.headline,
    required this.pitchStabilitySeries,
    required this.rhythmAccuracySeries,
    required this.weeklyMenu,
    required this.coachingNotification,
  });

  final String providerLabel;
  final String headline;
  final List<AiPracticeScorePoint> pitchStabilitySeries;
  final List<AiPracticeScorePoint> rhythmAccuracySeries;
  final List<String> weeklyMenu;
  final String coachingNotification;

  factory AiPracticeInsight.fromJson(Map<String, dynamic> json) {
    return AiPracticeInsight(
      providerLabel: json['providerLabel'] as String? ?? 'AI Coach',
      headline: json['headline'] as String? ?? '',
      pitchStabilitySeries: ((json['pitchStabilitySeries'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AiPracticeScorePoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      rhythmAccuracySeries: ((json['rhythmAccuracySeries'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AiPracticeScorePoint.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      weeklyMenu: ((json['weeklyMenu'] as List?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
      coachingNotification: json['coachingNotification'] as String? ?? '',
    );
  }
}

abstract class AiPracticeInsightsService {
  Future<AiPracticeInsight> analyze({
    required List<PracticeLogEntry> logs,
    required List<RecordingEntry> recordings,
    String localeCode = 'en',
    DateTime? now,
  });
}

class HybridAiPracticeInsightsService implements AiPracticeInsightsService {
  HybridAiPracticeInsightsService({
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? HttpClient.new;

  static const Duration _requestTimeout = Duration(seconds: 12);

  final HttpClient Function() _httpClientFactory;

  @override
  Future<AiPracticeInsight> analyze({
    required List<PracticeLogEntry> logs,
    required List<RecordingEntry> recordings,
    String localeCode = 'en',
    DateTime? now,
  }) async {
    final heuristic = _buildHeuristicInsight(
      logs: logs,
      recordings: recordings,
      localeCode: localeCode,
      now: now,
    );

    final prompt = _buildPrompt(
      logs: logs,
      recordings: recordings,
      localeCode: localeCode,
      now: now ?? DateTime.now(),
    );

    try {
      if (_openAiApiKey.isNotEmpty) {
        final response = await _callOpenAi(prompt, localeCode: localeCode);
        if (response != null) return response;
      }
      if (_geminiApiKey.isNotEmpty) {
        final response = await _callGemini(prompt, localeCode: localeCode);
        if (response != null) return response;
      }
    } on FormatException {
      // Fall back to deterministic local heuristics when the remote response is
      // malformed or cannot be normalized into the expected structure.
    } on HttpException {
      // Network-backed analysis is optional. Local heuristics keep the feature
      // usable when the AI provider is unavailable.
    } on SocketException {
      // Offline devices should still receive coaching suggestions.
    } on TimeoutException {
      // Avoid blocking the UI when the remote API is slow.
    }

    return heuristic;
  }

  Future<AiPracticeInsight?> _callOpenAi(
    String prompt, {
    required String localeCode,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_openAiApiKey');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': _openAiModel,
            'temperature': 0.3,
            'messages': [
              {
                'role': 'system',
                'content': localeCode == 'ja'
                    ? 'あなたは音楽練習コーチです。必ずJSONのみで回答してください。'
                    : 'You are a music practice coach. Respond with JSON only.',
              },
              {
                'role': 'user',
                'content': prompt,
              },
            ],
          }),
        ),
      );

      final response = await request.close().timeout(_requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final choices = payload['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return null;
      final message = choices.first as Map<String, dynamic>;
      final content =
          ((message['message'] as Map<String, dynamic>?)?['content']) as String?;
      return _parseRemoteInsight(content, localeCode: localeCode);
    } finally {
      client.close(force: true);
    }
  }

  Future<AiPracticeInsight?> _callGemini(
    String prompt, {
    required String localeCode,
  }) async {
    final client = _httpClientFactory();
    try {
      final request = await client.postUrl(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$_geminiModel:generateContent?key=$_geminiApiKey',
        ),
      );
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'contents': [
              {
                'parts': [
                  {
                    'text': prompt,
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.3,
            },
          }),
        ),
      );

      final response = await request.close().timeout(_requestTimeout);
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final candidates = payload['candidates'] as List<dynamic>? ?? const [];
      if (candidates.isEmpty) return null;
      final content = candidates.first as Map<String, dynamic>;
      final parts = ((content['content'] as Map<String, dynamic>?)?['parts'])
              as List<dynamic>? ??
          const [];
      if (parts.isEmpty) return null;
      final text = (parts.first as Map<String, dynamic>)['text'] as String?;
      return _parseRemoteInsight(text, localeCode: localeCode);
    } finally {
      client.close(force: true);
    }
  }

  AiPracticeInsight? _parseRemoteInsight(
    String? rawText, {
    required String localeCode,
  }) {
    final jsonText = _extractFirstJsonObject(rawText);
    if (jsonText == null) return null;
    final payload = jsonDecode(jsonText) as Map<String, dynamic>;
    final insight = AiPracticeInsight.fromJson(payload);
    if (insight.headline.isEmpty ||
        insight.pitchStabilitySeries.isEmpty ||
        insight.rhythmAccuracySeries.isEmpty ||
        insight.weeklyMenu.isEmpty ||
        insight.coachingNotification.isEmpty) {
      return null;
    }
    return AiPracticeInsight(
      providerLabel: localeCode == 'ja'
          ? '${insight.providerLabel} 分析'
          : insight.providerLabel,
      headline: insight.headline,
      pitchStabilitySeries: insight.pitchStabilitySeries,
      rhythmAccuracySeries: insight.rhythmAccuracySeries,
      weeklyMenu: insight.weeklyMenu.take(3).toList(),
      coachingNotification: insight.coachingNotification,
    );
  }
}

AiPracticeInsight _buildHeuristicInsight({
  required List<PracticeLogEntry> logs,
  required List<RecordingEntry> recordings,
  required String localeCode,
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now();
  final dayRange = List<DateTime>.generate(
    7,
    (index) => _toDateOnly(referenceNow).subtract(Duration(days: 6 - index)),
  );
  final minutesByDay = <DateTime, int>{};
  for (final log in logs) {
    final day = _toDateOnly(log.date);
    minutesByDay.update(day, (current) => current + log.durationMinutes,
        ifAbsent: () => log.durationMinutes);
  }

  final recordingsByDay = <DateTime, List<RecordingEntry>>{};
  for (final recording in recordings) {
    final day = _toDateOnly(recording.recordedAt);
    recordingsByDay.putIfAbsent(day, () => <RecordingEntry>[]).add(recording);
  }

  final pitchSeries = <AiPracticeScorePoint>[];
  final rhythmSeries = <AiPracticeScorePoint>[];
  var previousMinutes = 0;

  for (final day in dayRange) {
    final minutes = minutesByDay[day] ?? 0;
    final dayRecordings = recordingsByDay[day] ?? const <RecordingEntry>[];
    final waveformStability = dayRecordings.isEmpty
        ? 0.58 + (minutes.clamp(0, 45) / 45) * 0.18
        : dayRecordings
                .map((entry) => _waveformStability(entry.waveformData))
                .fold<double>(0.0, (sum, value) => sum + value) /
            dayRecordings.length;

    final pitchScore = _clampScore(
      40 + waveformStability * 45 + (minutes.clamp(0, 45) / 45) * 15,
    );
    final rhythmConsistency = previousMinutes == 0 && minutes == 0
        ? 0.55
        : 1 - ((minutes - previousMinutes).abs() / 45).clamp(0, 1).toDouble();
    final rhythmScore = _clampScore(
      38 + (minutes.clamp(0, 40) / 40) * 28 + rhythmConsistency * 34,
    );

    pitchSeries.add(
      AiPracticeScorePoint(label: '${day.month}/${day.day}', score: pitchScore),
    );
    rhythmSeries.add(
      AiPracticeScorePoint(label: '${day.month}/${day.day}', score: rhythmScore),
    );
    previousMinutes = minutes;
  }

  final averagePitch = _averageScore(pitchSeries);
  final averageRhythm = _averageScore(rhythmSeries);
  final streakDays = _streakDays(logs, now: referenceNow);
  final weeklyMinutes = dayRange.fold<int>(
    0,
    (sum, day) => sum + (minutesByDay[day] ?? 0),
  );

  final weeklyMenu = localeCode == 'ja'
      ? _buildJapaneseMenu(
          averagePitch: averagePitch,
          averageRhythm: averageRhythm,
          weeklyMinutes: weeklyMinutes,
        )
      : _buildEnglishMenu(
          averagePitch: averagePitch,
          averageRhythm: averageRhythm,
          weeklyMinutes: weeklyMinutes,
        );

  final weakArea = averagePitch < averageRhythm
      ? (localeCode == 'ja' ? '音程' : 'pitch')
      : (localeCode == 'ja' ? 'リズム' : 'rhythm');
  final headline = localeCode == 'ja'
      ? '直近1週間では$weakAreaの基礎づくりが次の伸びしろです。'
      : 'Your next growth opportunity this week is tightening your $weakArea.';
  final coachingNotification = localeCode == 'ja'
      ? 'AIコーチ: ${streakDays > 0 ? '$streakDays日連続を維持中。' : ''}次回は20分だけでも良いので、${weeklyMenu.first}を最優先に取り組みましょう。'
      : 'AI coach: ${streakDays > 0 ? '$streakDays-day streak in progress. ' : ''}For your next session, prioritize ${weeklyMenu.first.toLowerCase()}.';

  return AiPracticeInsight(
    providerLabel: localeCode == 'ja' ? 'オンデバイスAIコーチ' : 'On-device AI coach',
    headline: headline,
    pitchStabilitySeries: pitchSeries,
    rhythmAccuracySeries: rhythmSeries,
    weeklyMenu: weeklyMenu,
    coachingNotification: coachingNotification,
  );
}

double _waveformStability(List<double> waveformData) {
  if (waveformData.length < 2) return 0.68;
  var totalDelta = 0.0;
  for (var i = 1; i < waveformData.length; i++) {
    totalDelta += (waveformData[i] - waveformData[i - 1]).abs();
  }
  final meanDelta = totalDelta / (waveformData.length - 1);
  return (1.0 - meanDelta.clamp(0.0, 0.9)).clamp(0.25, 0.95);
}

String _buildPrompt({
  required List<PracticeLogEntry> logs,
  required List<RecordingEntry> recordings,
  required String localeCode,
  required DateTime now,
}) {
  final recentLogs = logs
      .toList()
    ..sort((left, right) => right.date.compareTo(left.date));
  final recentRecordings = recordings
      .toList()
    ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
  final logSummary = recentLogs.take(14).map((entry) {
    return {
      'date': entry.date.toIso8601String(),
      'durationMinutes': entry.durationMinutes,
      'memo': entry.memo,
    };
  }).toList();
  final recordingSummary = recentRecordings.take(8).map((entry) {
    return {
      'date': entry.recordedAt.toIso8601String(),
      'durationSeconds': entry.durationSeconds,
      'waveformStability': _waveformStability(entry.waveformData),
    };
  }).toList();

  return '''
Analyze this musician's recent practice history and return JSON only with the exact keys:
providerLabel, headline, pitchStabilitySeries, rhythmAccuracySeries, weeklyMenu, coachingNotification.

Requirements:
- Write the response in ${localeCode == 'ja' ? 'Japanese' : 'English'}.
- pitchStabilitySeries and rhythmAccuracySeries must each contain 7 objects with keys label and score.
- score must be an integer between 0 and 100.
- weeklyMenu must contain exactly 3 concise bullet-style strings for the next 7 days.
- coachingNotification must read like a push notification.

Reference date: ${now.toIso8601String()}
Practice logs: ${jsonEncode(logSummary)}
Recordings: ${jsonEncode(recordingSummary)}
''';
}

String? _extractFirstJsonObject(String? rawText) {
  if (rawText == null || rawText.isEmpty) return null;
  final start = rawText.indexOf('{');
  final end = rawText.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  return rawText.substring(start, end + 1);
}

double _averageScore(List<AiPracticeScorePoint> series) {
  if (series.isEmpty) return 0;
  final total = series.fold<int>(0, (sum, point) => sum + point.score);
  return total / series.length;
}

int _clampScore(num value) => value.round().clamp(0, 100).toInt();

List<String> _buildEnglishMenu({
  required double averagePitch,
  required double averageRhythm,
  required int weeklyMinutes,
}) {
  return [
    if (averagePitch < 72)
      '10 minutes of long-tone pitch matching with a drone'
    else
      'Record one phrase daily and keep the most stable take',
    if (averageRhythm < 72)
      'Metronome work with quarter-note and eighth-note subdivisions'
    else
      'Accent-shift drills at a steady tempo',
    if (weeklyMinutes < 150)
      'Schedule three 20-minute micro-sessions to protect consistency'
    else
      'Finish each session with one full-song run-through',
  ];
}

List<String> _buildJapaneseMenu({
  required double averagePitch,
  required double averageRhythm,
  required int weeklyMinutes,
}) {
  return [
    if (averagePitch < 72)
      'ドローンに合わせたロングトーンを10分'
    else
      '毎日1フレーズ録音して最も安定したテイクを残す',
    if (averageRhythm < 72)
      'メトロノームで4分・8分の刻みを重点確認'
    else
      '一定テンポでアクセント位置をずらす練習',
    if (weeklyMinutes < 150)
      '20分の短時間練習を週3回確保して継続性を守る'
    else
      '各セッションの最後に通し演奏を1回入れる',
  ];
}

int _streakDays(List<PracticeLogEntry> logs, {required DateTime now}) {
  final today = _toDateOnly(now);
  final practiceDays = logs.map((log) => _toDateOnly(log.date)).toSet();
  var cursor = practiceDays.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  var streak = 0;
  while (practiceDays.contains(cursor)) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

DateTime _toDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
