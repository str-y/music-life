import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/services/service_error_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ── Data model ────────────────────────────────────────────────────────────────

/// Represents a saved composition and its chord progression.
class Composition {
  Composition({
    required this.id,
    required this.title,
    required this.chords,
  });

  factory Composition.fromJson(Map<String, dynamic> json) => Composition(
        id: json['id'] as String,
        title: json['title'] as String,
        chords:
            (json['chords'] as List).map((e) => e as String).toList(),
      );

  final String id;
  final String title;
  final List<String> chords;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'chords': chords,
      };
}

// ── Repository ────────────────────────────────────────────────────────────────

abstract interface class CompositionStore {
  Future<void> replaceAllCompositions(List<Map<String, Object?>> rows);

  Future<List<Map<String, Object?>>> queryAllCompositions();

  Future<void> insertComposition(Map<String, Object?> row);

  Future<void> deleteComposition(String id);
}

class _AppDatabaseCompositionStore implements CompositionStore {
  const _AppDatabaseCompositionStore();

  @override
  Future<void> replaceAllCompositions(List<Map<String, Object?>> rows) {
    return AppDatabase.instance.replaceAllCompositions(rows);
  }

  @override
  Future<List<Map<String, Object?>>> queryAllCompositions() {
    return AppDatabase.instance.queryAllCompositions();
  }

  @override
  Future<void> insertComposition(Map<String, Object?> row) {
    return AppDatabase.instance.insertComposition(row);
  }

  @override
  Future<void> deleteComposition(String id) {
    return AppDatabase.instance.deleteComposition(id);
  }
}

/// Persists compositions and migrates legacy stored data into SQLite.
class CompositionRepository {
  const CompositionRepository(
    this._prefs, {
    AppConfig config = const AppConfig(),
    CompositionStore store = const _AppDatabaseCompositionStore(),
  })  : _config = config,
        _store = store;

  /// Guards against concurrent migration calls.  Non-null while a migration is
  /// in progress; subsequent callers await this future instead of starting a
  /// second migration.  Set back to null when migration fails so it can be
  /// retried on the next access.
  static Completer<void>? _migrationCompleter;

  final SharedPreferences _prefs;
  final AppConfig _config;
  final CompositionStore _store;

  Future<void> _migrateIfNeeded() async {
    // Already completed successfully in this session.
    if (_migrationCompleter?.isCompleted ?? false) return;
    // Migration is already in progress – join it instead of starting another.
    if (_migrationCompleter != null) return _migrationCompleter!.future;

    _migrationCompleter = Completer<void>();
    _migrationCompleter!.future.catchError((_, _) {});
    try {
      if (_prefs.getBool(_config.compositionsMigratedStorageKey) ?? false) {
        _migrationCompleter!.complete();
        return;
      }

      // Parse data before touching the database so that a decode
      // error does not leave the database in a half-migrated state.
      final compositionRows = <Map<String, Object?>>[];
      var migrationSucceeded = true;

      final jsonStr = _prefs.getString(_config.compositionsStorageKey);
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
          ServiceErrorHandler.report(
            'CompositionRepository: migration failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      if (migrationSucceeded) {
        try {
          await _store.replaceAllCompositions(compositionRows);
          await _prefs.setBool(_config.compositionsMigratedStorageKey, true);
        } catch (e, st) {
          ServiceErrorHandler.report(
            'CompositionRepository: migration DB write failed',
            error: e,
            stackTrace: st,
          );
          migrationSucceeded = false;
        }
      }

      _migrationCompleter!.complete();
      if (!migrationSucceeded) {
        // Migration failure is non-fatal. Existing database rows may still be
        // valid, so let callers continue loading while allowing the next access
        // to transparently retry the initialization.
        _migrationCompleter = null;
      }
    } catch (e, st) {
      ServiceErrorHandler.report(
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

  /// Loads all saved compositions from the database.
  Future<List<Composition>> load() async {
    await _migrateIfNeeded();
    try {
      final rows = await _store.queryAllCompositions();
      return rows
          .map((row) => Composition(
                id: row['id']! as String,
                title: row['title']! as String,
                chords: (jsonDecode(row['chords']! as String) as List)
                    .map((e) => e as String)
                    .toList(),
              ))
          .toList();
    } catch (e, st) {
      ServiceErrorHandler.report(
        'Failed to load compositions',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Replaces all saved compositions in the database.
  Future<void> save(List<Composition> compositions) async {
    await _store.replaceAllCompositions(
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
    await _store.insertComposition({
      'id': composition.id,
      'title': composition.title,
      'chords': jsonEncode(composition.chords),
    });
  }

  /// Deletes a single composition from the database.
  /// More efficient than save() when removing one composition.
  Future<void> deleteOne(String id) async {
    await _store.deleteComposition(id);
  }

  @visibleForTesting
  static void resetMigrationStateForTesting() {
    _migrationCompleter = null;
  }
}
