import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../data/app_database.dart';

const _backupTypeGroups = [
  XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
    mimeTypes: ['application/json', 'text/json'],
  ),
];

class BackupRepository {
  const BackupRepository();

  Future<String?> exportWithFilePicker() async {
    final location = await getSaveLocation(
      suggestedName: 'music-life-backup.json',
      acceptedTypeGroups: _backupTypeGroups,
    );
    if (location == null) return null;

    final content = await exportJsonBundle();
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
      name: 'music-life-backup.json',
    );
    await file.saveTo(location.path);
    return location.path;
  }

  Future<String?> importWithFilePicker() async {
    final file = await openFile(acceptedTypeGroups: _backupTypeGroups);
    if (file == null) return null;
    final content = await file.readAsString();
    await importJsonBundle(content);
    return file.path;
  }

  Future<String> exportJsonBundle() async {
    final recordings = await AppDatabase.instance.queryAllRecordings();
    final practiceLogs = await AppDatabase.instance.queryAllPracticeLogs();
    final practiceLogEntries = await AppDatabase.instance.queryAllPracticeLogEntries();
    final compositions = await AppDatabase.instance.queryAllCompositions();
    final bundle = BackupBundle.fromDatabaseRows(
      recordings: recordings,
      practiceLogs: practiceLogs,
      practiceLogEntries: practiceLogEntries,
      compositions: compositions,
    );
    return jsonEncode(bundle.toJson());
  }

  Future<void> importJsonBundle(String jsonContent) async {
    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final bundle = BackupBundle.fromJson(decoded);
    await AppDatabase.instance.replaceAllBackupData(
      recordings: bundle.recordingRows,
      practiceLogs: bundle.practiceLogRows,
      practiceLogEntries: bundle.practiceLogEntryRows,
      compositions: bundle.compositionRows,
    );
  }
}

class BackupBundle {
  BackupBundle({
    required this.recordingRows,
    required this.practiceLogRows,
    required this.practiceLogEntryRows,
    required this.compositionRows,
  });

  final List<Map<String, Object?>> recordingRows;
  final List<Map<String, Object?>> practiceLogRows;
  final List<Map<String, Object?>> practiceLogEntryRows;
  final List<Map<String, Object?>> compositionRows;

  factory BackupBundle.fromDatabaseRows({
    required List<Map<String, Object?>> recordings,
    required List<Map<String, Object?>> practiceLogs,
    required List<Map<String, Object?>> practiceLogEntries,
    required List<Map<String, Object?>> compositions,
  }) {
    return BackupBundle(
      recordingRows: recordings
          .map(
            (row) => <String, Object?>{
              'id': row['id'],
              'title': row['title'],
              'recorded_at': row['recorded_at'],
              'duration_seconds': row['duration_seconds'],
              'waveform_data': row['waveform_data'],
              'audio_file_path': row['audio_file_path'],
            },
          )
          .toList(),
      practiceLogRows: practiceLogs
          .map(
            (row) => <String, Object?>{
              'date': row['date'],
              'duration_minutes': row['duration_minutes'],
              'memo': row['memo'] ?? '',
            },
          )
          .toList(),
      practiceLogEntryRows: practiceLogEntries
          .map(
            (row) => <String, Object?>{
              'date': row['date'],
              'duration_minutes': row['duration_minutes'],
              'note': row['note'] ?? '',
            },
          )
          .toList(),
      compositionRows: compositions
          .map(
            (row) => <String, Object?>{
              'id': row['id'],
              'title': row['title'],
              'chords': row['chords'],
            },
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'recordings': recordingRows.map((row) {
        final waveform = row['waveform_data'] as Uint8List;
        return {
          'id': row['id'],
          'title': row['title'],
          'recorded_at': row['recorded_at'],
          'duration_seconds': row['duration_seconds'],
          'waveform_data_base64': base64Encode(waveform),
          'audio_file_path': row['audio_file_path'],
        };
      }).toList(),
      'practice_logs': practiceLogRows,
      'practice_log_entries': practiceLogEntryRows,
      'compositions': compositionRows,
    };
  }

  factory BackupBundle.fromJson(Map<String, dynamic> json) {
    final recordings = (json['recordings'] as List<dynamic>? ?? const [])
        .map((item) {
          final row = item as Map<String, dynamic>;
          return <String, Object?>{
            'id': row['id'] as String,
            'title': row['title'] as String,
            'recorded_at': row['recorded_at'] as String,
            'duration_seconds': row['duration_seconds'] as int,
            'waveform_data':
                base64Decode(row['waveform_data_base64'] as String),
            'audio_file_path': row['audio_file_path'] as String?,
          };
        })
        .toList();
    final practiceLogs = (json['practice_logs'] as List<dynamic>? ?? const [])
        .map((item) {
          final row = item as Map<String, dynamic>;
          return <String, Object?>{
            'date': row['date'] as String,
            'duration_minutes': row['duration_minutes'] as int,
            'memo': row['memo'] as String? ?? '',
          };
        })
        .toList();
    final practiceLogEntries =
        (json['practice_log_entries'] as List<dynamic>? ?? const []).map((item) {
      final row = item as Map<String, dynamic>;
      return <String, Object?>{
        'date': row['date'] as String,
        'duration_minutes': row['duration_minutes'] as int,
        'note': row['note'] as String? ?? '',
      };
    }).toList();
    final compositions = (json['compositions'] as List<dynamic>? ?? const [])
        .map((item) {
          final row = item as Map<String, dynamic>;
          return <String, Object?>{
            'id': row['id'] as String,
            'title': row['title'] as String,
            'chords': row['chords'] as String,
          };
        })
        .toList();
    return BackupBundle(
      recordingRows: recordings,
      practiceLogRows: practiceLogs,
      practiceLogEntryRows: practiceLogEntries,
      compositionRows: compositions,
    );
  }
}
