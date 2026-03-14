import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'backup_repository.dart';

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
  const _SharedPreferencesCloudBackupStore(this._prefs, this._config);

  final SharedPreferences _prefs;
  final AppConfig _config;

  @override
  Future<void> saveBackupBundle(String jsonBundle, DateTime syncedAt) async {
    await _prefs.setString(_config.cloudBackupBundleStorageKey, jsonBundle);
    await _prefs.setString(
      _config.lastCloudSyncAtStorageKey,
      syncedAt.toIso8601String(),
    );
  }

  @override
  Future<CloudBackupSnapshot?> loadBackupSnapshot() async {
    final jsonBundle = _prefs.getString(_config.cloudBackupBundleStorageKey);
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
  })  : _backupRepository = backupRepository,
        _store = store ?? _SharedPreferencesCloudBackupStore(prefs, config);

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
