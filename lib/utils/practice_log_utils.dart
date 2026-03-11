import '../repositories/recording_repository.dart';

/// A single data point for practice trend charts.
class PracticeTrendPoint {
  const PracticeTrendPoint({
    required this.label,
    required this.minutes,
  });

  final String label;
  final int minutes;
}

/// Builds a 7-day practice trend series ending at [now] (defaults to today).
List<PracticeTrendPoint> buildWeeklyPracticeTrend(
  List<PracticeLogEntry> entries, {
  DateTime? now,
}) {
  final today = _toDateOnly(now ?? DateTime.now());
  final byDay = <DateTime, int>{};
  for (final entry in entries) {
    final day = _toDateOnly(entry.date);
    byDay[day] = (byDay[day] ?? 0) + entry.durationMinutes;
  }
  return List.generate(7, (index) {
    final day = today.subtract(Duration(days: 6 - index));
    return PracticeTrendPoint(
      label: '${day.month}/${day.day}',
      minutes: byDay[day] ?? 0,
    );
  });
}

/// Builds a 6-month practice trend series ending at the month of [now].
List<PracticeTrendPoint> buildMonthlyPracticeTrend(
  List<PracticeLogEntry> entries, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final currentMonth = DateTime(reference.year, reference.month);
  final byMonth = <String, int>{};
  for (final entry in entries) {
    final key = '${entry.date.year}-${entry.date.month.toString().padLeft(2, '0')}';
    byMonth[key] = (byMonth[key] ?? 0) + entry.durationMinutes;
  }
  return List.generate(6, (index) {
    final month = DateTime(currentMonth.year, currentMonth.month - (5 - index));
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return PracticeTrendPoint(
      label: '${month.month}',
      minutes: byMonth[key] ?? 0,
    );
  });
}

/// Aggregates practice minutes by instrument (up to 5 instruments), sorted
/// by total minutes descending.  The instrument label is extracted from the
/// leading portion of the entry memo using [extractInstrumentLabelFromMemo].
Map<String, int> buildPracticeInstrumentMinutes(List<PracticeLogEntry> entries) {
  final byInstrument = <String, int>{};
  for (final entry in entries) {
    final instrument = extractInstrumentLabelFromMemo(entry.memo);
    byInstrument[instrument] = (byInstrument[instrument] ?? 0) + entry.durationMinutes;
  }

  final sortedEntries = byInstrument.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in sortedEntries.take(5)) entry.key: entry.value};
}

/// Extracts a short instrument label from the leading word(s) of [memo].
///
/// The first segment before any common delimiter (`:`、`/`、`-`, etc.) is used
/// as the label.  Labels longer than 12 characters are truncated with an
/// ellipsis.  An empty or delimiter-only memo returns `'Other'`.
String extractInstrumentLabelFromMemo(String memo) {
  final normalized = memo.trim();
  if (normalized.isEmpty) return otherInstrumentLabel;
  final head = normalized
      .split(RegExp(_instrumentMemoDelimiterPattern))
      .first
      .trim();
  if (head.isEmpty) return otherInstrumentLabel;
  return head.length > 12 ? '${head.substring(0, 12)}…' : head;
}

/// The label used for practice entries whose memo does not specify an
/// instrument.
const String otherInstrumentLabel = 'Other';

// ── Private helpers ───────────────────────────────────────────────────────────

DateTime _toDateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
const _instrumentMemoDelimiterPattern = r'[:：／/\-｜|]';
