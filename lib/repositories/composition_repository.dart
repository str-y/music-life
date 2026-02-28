import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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

  final SharedPreferences _prefs;

  Future<List<Composition>> load() async {
    final jsonStr = _prefs.getString(_key);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List;
      return list
          .map((e) => Composition.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      AppLogger.reportError(
        'Failed to load compositions',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<void> save(List<Composition> compositions) async {
    await _prefs.setString(
      _key,
      jsonEncode(compositions.map((c) => c.toJson()).toList()),
    );
  }
}
