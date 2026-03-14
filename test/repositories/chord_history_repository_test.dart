import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/repositories/chord_history_repository.dart';

class _FakeChordHistoryStore implements ChordHistoryStore {
  final List<Map<String, Object?>> insertedRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> nextRows = <Map<String, Object?>>[];
  DateTime? lastFrom;
  DateTime? lastTo;
  String lastChordName = '';
  Object? addError;
  Object? loadError;

  @override
  Future<void> addEntry(Map<String, Object?> row) async {
    if (addError != null) {
      throw addError!;
    }
    insertedRows.add(Map<String, Object?>.from(row));
  }

  @override
  Future<List<Map<String, Object?>>> loadEntries({
    DateTime? from,
    DateTime? to,
    String chordName = '',
  }) async {
    lastFrom = from;
    lastTo = to;
    lastChordName = chordName;
    if (loadError != null) {
      throw loadError!;
    }
    return nextRows.map(Map<String, Object?>.from).toList();
  }
}

void main() {
  group('SqliteChordHistoryRepository', () {
    test('addEntry stores chord name and ISO timestamp', () async {
      final store = _FakeChordHistoryStore();
      final repository = SqliteChordHistoryRepository(store: store);
      final entry = ChordHistoryEntry(
        chord: 'Am7',
        time: DateTime(2026, 1, 2, 3, 4, 5),
      );

      await repository.addEntry(entry);

      expect(store.insertedRows, [
        {
          'chord_name': 'Am7',
          'detected_at': '2026-01-02T03:04:05.000',
        },
      ]);
    });

    test('loadEntries passes date range and chord filter to store', () async {
      final store = _FakeChordHistoryStore()
        ..nextRows = [
          {
            'chord_name': 'C',
            'detected_at': '2026-02-03T12:30:00.000',
          },
        ];
      final repository = SqliteChordHistoryRepository(store: store);
      final day = DateTime(2026, 2, 3, 23, 59);

      final entries = await repository.loadEntries(
        day: day,
        chordNameFilter: ' C ',
      );

      expect(store.lastFrom, DateTime(2026, 2, 3));
      expect(store.lastTo, DateTime(2026, 2, 4));
      expect(store.lastChordName, ' C ');
      expect(entries, hasLength(1));
      expect(entries.single.chord, 'C');
      expect(entries.single.time, DateTime(2026, 2, 3, 12, 30));
    });

    test('rethrows database errors from store operations', () async {
      final store = _FakeChordHistoryStore()
        ..loadError = StateError('database unavailable');
      final repository = SqliteChordHistoryRepository(store: store);

      await expectLater(
        repository.loadEntries(),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when stored timestamps are malformed', () async {
      final store = _FakeChordHistoryStore()
        ..nextRows = [
          {
            'chord_name': 'G',
            'detected_at': 'not-a-timestamp',
          },
        ];
      final repository = SqliteChordHistoryRepository(store: store);

      await expectLater(
        repository.loadEntries(),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
