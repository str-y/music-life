import 'package:shared_preferences/shared_preferences.dart';

import 'package:music_life/config/app_config.dart';
import 'package:music_life/data/app_database.dart';
import 'package:music_life/repositories/backup_repository.dart';

abstract interface class CloudBackupStore {
  Future<void> saveBackupBundle(String jsonBundle, DateTime syncedAt);

  Future<CloudBackupSnapshot?> loadBackupSnapshot();
}

class CloudBackupSnapshot {
  const CloudBackupSnapshot({
    required this.jsonBundle,
    required this.syncedAt,
  });

  final String jsonBundle;
  final DateTime? syncedAt;
}

class _SharedPreferencesCloudBackupStore implements CloudBackupStore {
  const _SharedPreferencesCloudBackupStore(
    this._prefs,
    this._config, {
    required Future<String?> Function(String key) secureValueReader,
    required Future<void> Function(String key, String value) secureValueWriter,
  }) : _secureValueReader = secureValueReader,
       _secureValueWriter = secureValueWriter;

  final SharedPreferences _prefs;
  final AppConfig _config;
  final Future<String?> Function(String key) _secureValueReader;
  final Future<void> Function(String key, String value) _secureValueWriter;

  @override
  Future<void> saveBackupBundle(String jsonBundle, DateTime syncedAt) async {
    await _secureValueWriter(_config.cloudBackupBundleStorageKey, jsonBundle);
    await _prefs.remove(_config.cloudBackupBundleStorageKey);
    await _prefs.setString(
      _config.lastCloudSyncAtStorageKey,
      syncedAt.toIso8601String(),
    );
  }

  @override
  Future<CloudBackupSnapshot?> loadBackupSnapshot() async {
    var jsonBundle = await _secureValueReader(_config.cloudBackupBundleStorageKey);
    if (jsonBundle == null || jsonBundle.isEmpty) {
      final legacyJsonBundle = _prefs.getString(_config.cloudBackupBundleStorageKey);
      if (legacyJsonBundle != null && legacyJsonBundle.isNotEmpty) {
        await _secureValueWriter(
          _config.cloudBackupBundleStorageKey,
          legacyJsonBundle,
        );
        await _prefs.remove(_config.cloudBackupBundleStorageKey);
        jsonBundle = legacyJsonBundle;
      }
    }
    if (jsonBundle == null || jsonBundle.isEmpty) return null;
    final syncedAt = DateTime.tryParse(
      _prefs.getString(_config.lastCloudSyncAtStorageKey) ?? '',
    );
    return CloudBackupSnapshot(
      jsonBundle: jsonBundle,
      syncedAt: syncedAt,
    );
  }
}

class CloudSyncRepository {
  CloudSyncRepository({
    required BackupRepository backupRepository,
    required SharedPreferences prefs,
    AppConfig config = const AppConfig(),
    CloudBackupStore? store,
    Future<String?> Function(String key)? secureValueReader,
    Future<void> Function(String key, String value)? secureValueWriter,
  })  : _backupRepository = backupRepository,
        _store =
            store ??
            _SharedPreferencesCloudBackupStore(
              prefs,
              config,
              secureValueReader: secureValueReader ?? AppDatabase.readSecureValue,
              secureValueWriter:
                  secureValueWriter ?? AppDatabase.writeSecureValue,
            );

  final BackupRepository _backupRepository;
  final CloudBackupStore _store;

  Future<DateTime> syncNow({DateTime? now}) async {
    final syncedAt = now ?? DateTime.now().toUtc();
    final exportedBundle = await _backupRepository.exportJsonBundle();
    await _store.saveBackupBundle(exportedBundle, syncedAt);
    return syncedAt;
  }

  Future<DateTime?> restoreLatestBackup() async {
    final snapshot = await _store.loadBackupSnapshot();
    if (snapshot == null) return null;
    await _backupRepository.importJsonBundle(snapshot.jsonBundle);
    return snapshot.syncedAt;
  }

  Future<bool> hasStoredBackup() async {
    return await _store.loadBackupSnapshot() != null;
  }
}
