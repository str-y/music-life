import 'package:music_life/data/app_database.dart';
abstract interface class ChordHistoryStore {
  Future<void> addEntry(Map<String, Object?> row);

  Future<List<Map<String, Object?>>> loadEntries({
    DateTime? from,
    DateTime? to,
    String chordName = '',
  });
}

class _AppDatabaseChordHistoryStore implements ChordHistoryStore {
  const _AppDatabaseChordHistoryStore();

  @override
  Future<void> addEntry(Map<String, Object?> row) {
    return AppDatabase.instance.insertChordAnalysisHistory(row);
  }

  @override
  Future<List<Map<String, Object?>>> loadEntries({
    DateTime? from,
    DateTime? to,
    String chordName = '',
  }) {
    return AppDatabase.instance.queryChordAnalysisHistory(
      from: from,
      to: to,
      chordName: chordName,
    );
  }
}

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
  const SqliteChordHistoryRepository({
    ChordHistoryStore store = const _AppDatabaseChordHistoryStore(),
  }) : _store = store;

  final ChordHistoryStore _store;

  @override
  Future<void> addEntry(ChordHistoryEntry entry) async {
    await _store.addEntry({
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
    final rows = await _store.loadEntries(
      from: rangeStart,
      to: rangeEnd,
      chordName: chordNameFilter,
    );
    return rows
        .map(
          (row) => ChordHistoryEntry(
            chord: row['chord_name']! as String,
            time: DateTime.parse(row['detected_at']! as String),
          ),
        )
        .toList();
  }
}
