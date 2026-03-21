import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/data/legacy_data_migrator.dart';
import 'package:music_life/data/waveform_codec.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// Metadata for a single recording persisted by the app.
class RecordingEntry {
  const RecordingEntry({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.durationSeconds,
    required this.waveformData,
    this.audioFilePath,
  });

  factory RecordingEntry.fromJson(Map<String, dynamic> json) {
    return RecordingEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      durationSeconds: json['durationSeconds'] as int,
      waveformData: (json['waveformData'] as List)
          .map((e) => (e as num).toDouble())
          .toList(),
      audioFilePath: json['audioFilePath'] as String?,
    );
  }

  final String id;
  final String title;
  final DateTime recordedAt;
  final int durationSeconds;

  /// Normalised amplitude values in [0.0, 1.0] used for waveform preview.
  final List<double> waveformData;
  final String? audioFilePath;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'recordedAt': recordedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'waveformData': waveformData,
        'audioFilePath': audioFilePath,
      };
}

/// Aggregated daily practice log data.
class PracticeLogEntry {
  const PracticeLogEntry({
    required this.date,
    required this.durationMinutes,
    this.memo = '',
  });

  factory PracticeLogEntry.fromJson(Map<String, dynamic> json) {
    return PracticeLogEntry(
      date: DateTime.parse(json['date'] as String),
      durationMinutes: json['durationMinutes'] as int,
      memo: json['memo'] as String? ?? '',
    );
  }

  final DateTime date;
  final int durationMinutes;
  final String memo;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'durationMinutes': durationMinutes,
        'memo': memo,
      };
}

typedef _QueryAllRows = Future<List<Map<String, Object?>>> Function();

class _WaveformCacheEntry {
  const _WaveformCacheEntry({
    required this.waveform,
    required this.byteSize,
  });

  final List<double> waveform;
  final int byteSize;
}

// ---------------------------------------------------------------------------
// Repository – persists recording metadata and practice logs via SQLite.
// A one-time migration from the legacy SharedPreferences JSON store is
// performed automatically on the first access.
// ---------------------------------------------------------------------------

/// Persists recordings and practice logs with one-time legacy migration support.
class RecordingRepository {

  /// Creates a repository backed by the supplied [prefs] instance (for migration).
  RecordingRepository(
    SharedPreferences prefs, {
    AppConfig config = const AppConfig(),
    Future<void> Function({
      required List<Map<String, Object?>> recordings,
      required List<Map<String, Object?>> practiceLogs,
    })? replaceAllData,
    Future<List<Map<String, Object?>>> Function()? queryAllRecordings,
    Future<List<Map<String, Object?>>> Function()? queryAllPracticeLogs,
    Future<void> Function(int requiredBytes)? ensureMigrationDiskSpace,
    Future<bool> Function(String key, bool value)? persistBool,
    Future<bool> Function(String key)? removeValue,
  })  : _migrator = LegacyDataMigrator(
          prefs,
          config: config,
          replaceAllData: replaceAllData ??
              AppDatabase.instance.replaceAllData,
          ensureMigrationDiskSpace: ensureMigrationDiskSpace,
          persistBool: persistBool,
          removeValue: removeValue,
        ),
        _queryAllRecordings =
            queryAllRecordings ?? AppDatabase.instance.queryAllRecordings,
        _queryAllPracticeLogs =
            queryAllPracticeLogs ?? AppDatabase.instance.queryAllPracticeLogs;
  static const int _maxWaveformCacheEntries = 256;
  static const int _maxWaveformCacheBytes = 4 * 1024 * 1024;
  // Allow one oversized waveform to use up to 2x `_maxWaveformCacheBytes`
  // before skipping caching altogether so typical recordings still benefit
  // from reuse.
  static const int _maxSingleWaveformCacheEntryMultiplier = 2;
  static const int _maxWaveformCacheEntryBytes =
      _maxWaveformCacheBytes * _maxSingleWaveformCacheEntryMultiplier;
  static final LinkedHashMap<String, _WaveformCacheEntry> _waveformCache =
      LinkedHashMap<String, _WaveformCacheEntry>();
  static int _waveformCacheBytes = 0;

  final LegacyDataMigrator _migrator;
  final _QueryAllRows _queryAllRecordings;
  final _QueryAllRows _queryAllPracticeLogs;

  static _WaveformCacheEntry? _promoteWaveformCacheEntry(String recordingId) {
    final cached = _waveformCache.remove(recordingId);
    if (cached != null) {
      _waveformCache[recordingId] = cached;
    }
    return cached;
  }

  static void _cacheWaveform(
    String recordingId,
    List<double> waveform, {
    required int byteSize,
  }) {
    final previous = _waveformCache.remove(recordingId);
    if (previous != null) {
      _waveformCacheBytes -= previous.byteSize;
    }
    if (byteSize > _maxWaveformCacheEntryBytes) {
      return;
    }

    _waveformCache[recordingId] = _WaveformCacheEntry(
      waveform: waveform,
      byteSize: byteSize,
    );
    _waveformCacheBytes += byteSize;
    if (_waveformCache.length > _maxWaveformCacheEntries ||
        _waveformCacheBytes > _maxWaveformCacheBytes) {
      _trimWaveformCache();
    }
  }

  static void _trimWaveformCache() {
    // Keep the most recently decoded waveform cached even if it alone exceeds
    // the soft memory budget so repeated reads of a large recording do not
    // thrash between decode and immediate eviction.
    while (_waveformCache.length > 1 &&
        (_waveformCache.length > _maxWaveformCacheEntries ||
            _waveformCacheBytes > _maxWaveformCacheBytes)) {
      final oldestKey = _waveformCache.keys.first;
      final removed = _waveformCache.remove(oldestKey);
      if (removed != null) {
        _waveformCacheBytes -= removed.byteSize;
      }
    }
  }

  static void _replaceWaveformCache(Iterable<RecordingEntry> recordings) {
    _clearWaveformCache();
    for (final recording in recordings.toList(growable: false).reversed) {
      _cacheWaveform(
        recording.id,
        UnmodifiableListView<double>(recording.waveformData),
        byteSize: _waveformByteSize(recording.waveformData),
      );
    }
  }

  static int _waveformByteSize(List<double> waveform) {
    return waveform.length * Float64List.bytesPerElement;
  }

  static void _clearWaveformCache() {
    _waveformCache.clear();
    _waveformCacheBytes = 0;
  }

  static List<double> _decodeWaveform(
    String recordingId,
    Uint8List blob, {
    void Function(bool hit)? onCacheAccess,
  }) {
    final cached = _promoteWaveformCacheEntry(recordingId);
    if (cached != null) {
      onCacheAccess?.call(true);
      return cached.waveform;
    }

    final waveform = UnmodifiableListView<double>(blobToWaveform(blob));
    _cacheWaveform(
      recordingId,
      waveform,
      byteSize: _waveformByteSize(waveform),
    );
    onCacheAccess?.call(false);
    return waveform;
  }

  Future<List<RecordingEntry>> loadRecordings() async {
    final stopwatch = Stopwatch()..start();
    await _migrator.migrateIfNeeded();
    final rows = await _queryAllRecordings();
    var cacheHits = 0;
    var cacheMisses = 0;
    final recordings = rows
        .map((row) => RecordingEntry(
              id: row['id']! as String,
              title: row['title']! as String,
              recordedAt: DateTime.parse(row['recorded_at']! as String),
              durationSeconds: row['duration_seconds']! as int,
              waveformData: _decodeWaveform(
                row['id']! as String,
                row['waveform_data']! as Uint8List,
                onCacheAccess: (hit) {
                  if (hit) {
                    cacheHits += 1;
                  } else {
                    cacheMisses += 1;
                  }
                },
              ),
              audioFilePath: row['audio_file_path'] as String?,
            ))
        .toList();
    stopwatch.stop();
    final rssSuffix = kDebugMode
        ? ', rss: ${_formatMemoryUsage(ProcessInfo.currentRss)}'
        : '';
    AppLogger.debug(
      'RecordingRepository: loaded ${recordings.length} recordings in '
      '${stopwatch.elapsedMilliseconds}ms '
      '(waveform cache hits: $cacheHits, misses: $cacheMisses, '
      'cache size: ${_waveformCache.length}, '
      'cache memory: ${_formatMemoryUsage(_waveformCacheBytes)}$rssSuffix)',
    );
    return recordings;
  }

  Future<void> saveRecordings(List<RecordingEntry> recordings) async {
    await AppDatabase.instance.replaceAllRecordings(
      recordings
          .map((e) => {
                'id': e.id,
                'title': e.title,
                'recorded_at': e.recordedAt.toIso8601String(),
                'duration_seconds': e.durationSeconds,
                'waveform_data': waveformToBlob(e.waveformData),
                'audio_file_path': e.audioFilePath,
              })
          .toList(),
    );
    _replaceWaveformCache(recordings);
  }

  Future<List<PracticeLogEntry>> loadPracticeLogs() async {
    await _migrator.migrateIfNeeded();
    final rows = await _queryAllPracticeLogs();
    return rows
        .map((row) => PracticeLogEntry(
              date: DateTime.parse(row['date']! as String),
              durationMinutes: row['duration_minutes']! as int,
              memo: row['memo'] as String? ?? '',
            ))
        .toList();
  }

  Future<void> savePracticeLogs(List<PracticeLogEntry> logs) async {
    await AppDatabase.instance.replaceAllPracticeLogs(
      logs
          .map((e) => {
                'date': e.date.toIso8601String(),
                'duration_minutes': e.durationMinutes,
                'memo': e.memo,
              })
          .toList(),
    );
  }

  @visibleForTesting
  static void resetMigrationStateForTesting() {
    LegacyDataMigrator.resetStateForTesting();
    _clearWaveformCache();
  }

  @visibleForTesting
  static int get waveformCacheSize => _waveformCache.length;

  @visibleForTesting
  static int get waveformCacheByteSize => _waveformCacheBytes;

  static String _formatMemoryUsage(int bytes) {
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)}MB';
  }
}
