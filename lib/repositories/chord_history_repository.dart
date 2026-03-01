import '../data/app_database.dart';

/// Represents a single detected chord with its timestamp.
class ChordHistoryEntry {
  const ChordHistoryEntry({
    required this.chord,
    required this.time,
  });

  final String chord;
  final DateTime time;
}

/// Contract for persisting and querying chord detection history entries.
abstract interface class ChordHistoryRepository {
  Future<void> addEntry(ChordHistoryEntry entry);

  Future<List<ChordHistoryEntry>> loadEntries({
    DateTime? day,
    String chordNameFilter = '',
  });
}

/// SQLite-backed implementation of [ChordHistoryRepository].
class SqliteChordHistoryRepository implements ChordHistoryRepository {
  const SqliteChordHistoryRepository();

  @override
  Future<void> addEntry(ChordHistoryEntry entry) async {
    await AppDatabase.instance.insertChordAnalysisHistory({
      'chord_name': entry.chord,
      'detected_at': entry.time.toIso8601String(),
    });
  }

  @override
  Future<List<ChordHistoryEntry>> loadEntries({
    DateTime? day,
    String chordNameFilter = '',
  }) async {
    final rangeStart = day == null ? null : DateTime(day.year, day.month, day.day);
    final rangeEnd = rangeStart?.add(const Duration(days: 1));
    final rows = await AppDatabase.instance.queryChordAnalysisHistory(
      from: rangeStart,
      to: rangeEnd,
      chordName: chordNameFilter,
    );
    return rows
        .map(
          (row) => ChordHistoryEntry(
            chord: row['chord_name'] as String,
            time: DateTime.parse(row['detected_at'] as String),
          ),
        )
        .toList();
  }
}
