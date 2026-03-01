import '../data/app_database.dart';

class ChordHistoryEntry {
  const ChordHistoryEntry({
    required this.chord,
    required this.time,
  });

  final String chord;
  final DateTime time;
}

abstract interface class ChordHistoryRepository {
  Future<void> addEntry(ChordHistoryEntry entry);

  Future<List<ChordHistoryEntry>> loadEntries({
    DateTime? day,
    String chordNameFilter = '',
  });
}

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
