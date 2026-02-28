import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../utils/app_logger.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class Composition {
  Composition({
    required this.id,
    required this.title,
    required this.chords,
  });

  final String id;
  final String title;
  final List<String> chords;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'chords': chords,
      };

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
        id: json['id'] as String,
        title: json['title'] as String,
        chords:
            (json['chords'] as List).map((e) => e as String).toList(),
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class CompositionRepository {
  const CompositionRepository(this._prefs);

  static const _key = 'compositions_v1';
  static const _migratedKey = 'compositions_db_migrated_v1';

  /// Guards against concurrent migration calls.  Non-null while a migration is
  /// in progress; subsequent callers await this future instead of starting a
  /// second migration.  Set back to null when migration fails so it can be
  /// retried on the next access.
  static Completer<void>? _migrationCompleter;

  final SharedPreferences _prefs;

  Future<void> _migrateIfNeeded() async {
    // Already completed successfully in this session.
    if (_migrationCompleter?.isCompleted == true) return;
    // Migration is already in progress – join it instead of starting another.
    if (_migrationCompleter != null) return _migrationCompleter!.future;

    _migrationCompleter = Completer<void>();
    try {
      if (_prefs.getBool(_migratedKey) == true) {
        _migrationCompleter!.complete();
        return;
      }

      // Parse data before touching the database so that a decode
      // error does not leave the database in a half-migrated state.
      final compositionRows = <Map<String, Object?>>[];
      var migrationSucceeded = true;

      final jsonStr = _prefs.getString(_key);
      if (jsonStr != null) {
        try {
          final list = jsonDecode(jsonStr) as List;
          compositionRows.addAll(
            list
                .map((e) => Composition.fromJson(e as Map<String, dynamic>))
                .map((c) => <String, Object?>{
                      'id': c.id,
                      'title': c.title,
                      'chords': jsonEncode(c.chords),
                    }),
          );
        } catch (e, st) {
          AppLogger.reportError(
            'CompositionRepository: migration failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      if (migrationSucceeded) {
        try {
          await AppDatabase.instance.replaceAllCompositions(compositionRows);
          await _prefs.setBool(_migratedKey, true);
        } catch (e, st) {
          AppLogger.reportError(
            'CompositionRepository: migration DB write failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      _migrationCompleter!.complete();
      if (!migrationSucceeded) {
        // Migration was attempted but failed.  Completing the Completer
        // normally (rather than with an error) lets concurrent callers
        // proceed to the underlying database query — migration failure is
        // non-fatal and the DB may still contain valid data from a previous
        // successful migration.  Resetting to null allows a retry on the
        // next session access.
        _migrationCompleter = null;
      }
    } catch (e, st) {
      AppLogger.reportError(
        'CompositionRepository: migration failed',
        error: e,
        stackTrace: st,
      );
      // Reset so the next caller can retry rather than receiving this error.
      final c = _migrationCompleter;
      _migrationCompleter = null;
      c!.completeError(e, st);
    }
  }

  Future<List<Composition>> load() async {
    await _migrateIfNeeded();
    try {
      final rows = await AppDatabase.instance.queryAllCompositions();
      return rows
          .map((row) => Composition(
                id: row['id'] as String,
                title: row['title'] as String,
                chords: (jsonDecode(row['chords'] as String) as List)
                    .map((e) => e as String)
                    .toList(),
              ))
          .toList();
    } catch (e, st) {
      AppLogger.reportError(
        'Failed to load compositions',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> save(List<Composition> compositions) async {
    await AppDatabase.instance.replaceAllCompositions(
      compositions
          .map((c) => <String, Object?>{
                'id': c.id,
                'title': c.title,
                'chords': jsonEncode(c.chords),
              })
          .toList(),
    );
  }

  /// Inserts or replaces a single composition in the database.
  /// More efficient than save() when updating one composition.
  Future<void> saveOne(Composition composition) async {
    await AppDatabase.instance.insertComposition({
      'id': composition.id,
      'title': composition.title,
      'chords': jsonEncode(composition.chords),
    });
  }

  /// Deletes a single composition from the database.
  /// More efficient than save() when removing one composition.
  Future<void> deleteOne(String id) async {
    await AppDatabase.instance.deleteComposition(id);
  }
}
