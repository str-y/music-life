import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/repositories/composition_repository.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCompositionStore implements CompositionStore {
  List<Map<String, Object?>> queryRows = <Map<String, Object?>>[];
  List<Map<String, Object?>> lastReplacedRows = <Map<String, Object?>>[];
  Map<String, Object?>? lastInsertedRow;
  String? lastDeletedId;
  int replaceAllCalls = 0;
  int queryCalls = 0;
  int insertCalls = 0;
  int deleteCalls = 0;
  Object? replaceAllError;
  Object? queryError;

  @override
  Future<void> deleteComposition(String id) async {
    deleteCalls += 1;
    lastDeletedId = id;
  }

  @override
  Future<void> insertComposition(Map<String, Object?> row) async {
    insertCalls += 1;
    lastInsertedRow = Map<String, Object?>.from(row);
  }

  @override
  Future<List<Map<String, Object?>>> queryAllCompositions() async {
    queryCalls += 1;
    if (queryError != null) {
      throw queryError!;
    }
    return queryRows.map(Map<String, Object?>.from).toList();
  }

  @override
  Future<void> replaceAllCompositions(List<Map<String, Object?>> rows) async {
    replaceAllCalls += 1;
    if (replaceAllError != null) {
      throw replaceAllError!;
    }
    lastReplacedRows = rows.map(Map<String, Object?>.from).toList();
    queryRows = rows.map(Map<String, Object?>.from).toList();
  }
}

void main() {
  group('CompositionRepository', () {
    late SharedPreferences prefs;
    late _FakeCompositionStore store;
    late AppConfig config;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = _FakeCompositionStore();
      config = const AppConfig(
        compositionsStorageKey: 'test_compositions_v1',
        compositionsMigratedStorageKey: 'test_compositions_db_migrated_v1',
      );
      CompositionRepository.resetMigrationStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    tearDown(() {
      CompositionRepository.resetMigrationStateForTesting();
      AppLogger.clearBufferedLogs();
    });

    test('migrates legacy compositions into the database on first load', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );
      final legacyComposition = Composition(
        id: 'legacy-1',
        title: 'Legacy Song',
        chords: ['C', 'G', 'Am', 'F'],
      );
      await prefs.setString(
        config.compositionsStorageKey,
        jsonEncode([legacyComposition.toJson()]),
      );

      final compositions = await repository.load();

      expect(store.replaceAllCalls, 1);
      expect(prefs.getBool(config.compositionsMigratedStorageKey), isTrue);
      expect(compositions, hasLength(1));
      expect(compositions.single.id, legacyComposition.id);
      expect(compositions.single.title, legacyComposition.title);
      expect(compositions.single.chords, legacyComposition.chords);
      expect(store.lastReplacedRows.single, {
        'id': 'legacy-1',
        'title': 'Legacy Song',
        'chords': jsonEncode(['C', 'G', 'Am', 'F']),
      });
    });

    test('keeps querying current rows when legacy JSON is malformed', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );
      store.queryRows = [
        {
          'id': 'db-1',
          'title': 'Existing Song',
          'chords': jsonEncode(['Dm', 'G']),
        },
      ];
      await prefs.setString(config.compositionsStorageKey, '{invalid json');

      final compositions = await repository.load();

      expect(store.replaceAllCalls, 0);
      expect(prefs.getBool(config.compositionsMigratedStorageKey), isNot(true));
      expect(compositions.single.id, 'db-1');
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('CompositionRepository: migration failed'),
        ),
        isTrue,
      );
    });

    test('concurrent loads keep querying current rows when migration write fails',
        () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );
      final legacyComposition = Composition(
        id: 'legacy-write-failure',
        title: 'Legacy write failure',
        chords: ['C', 'F'],
      );
      store.queryRows = [
        {
          'id': 'db-1',
          'title': 'Existing Song',
          'chords': jsonEncode(['Dm', 'G']),
        },
      ];
      store.replaceAllError = const FileSystemException('disk full');
      await prefs.setString(
        config.compositionsStorageKey,
        jsonEncode([legacyComposition.toJson()]),
      );

      final loads = await Future.wait([
        repository.load(),
        repository.load(),
      ]);

      expect(store.replaceAllCalls, 1);
      expect(prefs.getBool(config.compositionsMigratedStorageKey), isNot(true));
      expect(loads, hasLength(2));
      expect(loads[0].single.id, 'db-1');
      expect(loads[1].single.id, 'db-1');

      store.replaceAllError = null;

      final retriedLoad = await repository.load();

      expect(store.replaceAllCalls, 2);
      expect(prefs.getBool(config.compositionsMigratedStorageKey), isTrue);
      expect(retriedLoad.single.id, legacyComposition.id);
      expect(retriedLoad.single.chords, legacyComposition.chords);
      expect(
        AppLogger.bufferedLogs.any(
          (line) =>
              line.contains('CompositionRepository: migration DB write failed'),
        ),
        isTrue,
      );
    });

    test('rethrows and logs when loading from the database fails', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );
      store.queryError = StateError('database unavailable');
      await prefs.setBool(config.compositionsMigratedStorageKey, true);

      await expectLater(
        repository.load(),
        throwsA(isA<StateError>()),
      );
      expect(
        AppLogger.bufferedLogs.any(
          (line) => line.contains('Failed to load compositions'),
        ),
        isTrue,
      );
    });

    test('save replaces all compositions with serialized chord data', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );

      await repository.save([
        Composition(
          id: 'comp-1',
          title: 'Practice Set',
          chords: ['Em', 'C', 'G', 'D'],
        ),
      ]);

      expect(store.replaceAllCalls, 1);
      expect(store.lastReplacedRows.single, {
        'id': 'comp-1',
        'title': 'Practice Set',
        'chords': jsonEncode(['Em', 'C', 'G', 'D']),
      });
    });

    test('saveOne inserts a single serialized composition row', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );

      await repository.saveOne(
        Composition(
          id: 'comp-2',
          title: 'Single Save',
          chords: ['A', 'E'],
        ),
      );

      expect(store.insertCalls, 1);
      expect(store.lastInsertedRow, {
        'id': 'comp-2',
        'title': 'Single Save',
        'chords': jsonEncode(['A', 'E']),
      });
    });

    test('deleteOne forwards the composition id to the store', () async {
      final repository = CompositionRepository(
        prefs,
        config: config,
        store: store,
      );

      await repository.deleteOne('comp-3');

      expect(store.deleteCalls, 1);
      expect(store.lastDeletedId, 'comp-3');
    });
  });

  group('Composition', () {
    final composition = Composition(
      id: 'comp1',
      title: 'My Song',
      chords: ['C', 'Am', 'F', 'G'],
    );

    test('toJson produces expected map', () {
      final json = composition.toJson();
      expect(json['id'], 'comp1');
      expect(json['title'], 'My Song');
      expect(json['chords'], ['C', 'Am', 'F', 'G']);
    });

    test('fromJson round-trips through toJson', () {
      final restored = Composition.fromJson(composition.toJson());
      expect(restored.id, composition.id);
      expect(restored.title, composition.title);
      expect(restored.chords, composition.chords);
    });

    test('fromJson with empty chords list', () {
      final json = {
        'id': 'empty',
        'title': 'Empty',
        'chords': <dynamic>[],
      };
      final restored = Composition.fromJson(json);
      expect(restored.chords, isEmpty);
    });
  });
}
