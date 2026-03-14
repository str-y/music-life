import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/repositories/backup_repository.dart';
import 'package:music_life/repositories/cloud_sync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('syncNow stores the exported backup bundle', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = CloudSyncRepository(
      backupRepository: _FakeBackupRepository(),
      prefs: prefs,
    );

    final syncedAt = await repository.syncNow(
      now: DateTime.utc(2026, 1, 1, 12),
    );

    expect(syncedAt, DateTime.utc(2026, 1, 1, 12));
    expect(
      prefs.getString(AppConfig.defaultCloudBackupBundleStorageKey),
      '{"version":1}',
    );
  });

  test('restoreLatestBackup imports the stored backup bundle', () async {
    SharedPreferences.setMockInitialValues({
      AppConfig.defaultCloudBackupBundleStorageKey: '{"version":1}',
      AppConfig.defaultLastCloudSyncAtStorageKey: '2026-01-01T12:00:00.000Z',
    });
    final prefs = await SharedPreferences.getInstance();
    final backupRepository = _FakeBackupRepository();
    final repository = CloudSyncRepository(
      backupRepository: backupRepository,
      prefs: prefs,
    );

    final restoredAt = await repository.restoreLatestBackup();

    expect(restoredAt, DateTime.parse('2026-01-01T12:00:00.000Z'));
    expect(backupRepository.importedBundles, ['{"version":1}']);
  });

  test('restoreLatestBackup returns false when no backup exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = CloudSyncRepository(
      backupRepository: _FakeBackupRepository(),
      prefs: prefs,
    );

    expect(await repository.restoreLatestBackup(), isNull);
  });
}

class _FakeBackupRepository extends BackupRepository {
  _FakeBackupRepository() : super();

  final List<String> importedBundles = <String>[];

  @override
  Future<String> exportJsonBundle() async {
    return '{"version":1}';
  }

  @override
  Future<void> importJsonBundle(String jsonContent) async {
    importedBundles.add(jsonContent);
  }
}
