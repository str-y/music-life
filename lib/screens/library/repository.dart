import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Repository – persists recording metadata and practice logs via
// SharedPreferences using JSON encoding.
// ---------------------------------------------------------------------------

class RecordingRepository {
  static const _recordingsKey = 'recordings_v1';
  static const _logsKey = 'practice_logs_v1';

  Future<List<RecordingEntry>> loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordingsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => RecordingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecordings(List<RecordingEntry> recordings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordingsKey,
      jsonEncode(recordings.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<PracticeLogEntry>> loadPracticeLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_logsKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => PracticeLogEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePracticeLogs(List<PracticeLogEntry> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _logsKey,
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }
}
