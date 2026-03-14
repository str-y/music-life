import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../native_pitch_bridge.dart';
import '../repositories/backup_repository.dart';
import '../repositories/chord_history_repository.dart';
import '../repositories/cloud_sync_repository.dart';
import '../repositories/composition_repository.dart';
import '../repositories/recording_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/ai_practice_insights_service.dart';
import '../services/permission_service.dart';
import '../services/premium_video_export_service.dart';
import '../services/recording_storage_service.dart';

typedef PitchBridgeFactory = NativePitchBridge Function(
    {FfiErrorHandler? onError});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final pitchBridgeFactoryProvider = Provider<PitchBridgeFactory>((ref) {
  return ({FfiErrorHandler? onError}) => NativePitchBridge(onError: onError);
});

final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final config = ref.read(appConfigProvider);
  return RecordingRepository(prefs, config: config);
});

final compositionRepositoryProvider = Provider<CompositionRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final config = ref.read(appConfigProvider);
  return CompositionRepository(prefs, config: config);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final config = ref.read(appConfigProvider);
  return SettingsRepository(prefs, config: config);
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return const BackupRepository();
});

final cloudSyncRepositoryProvider = Provider<CloudSyncRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final config = ref.read(appConfigProvider);
  final backupRepository = ref.read(backupRepositoryProvider);
  return CloudSyncRepository(
    backupRepository: backupRepository,
    prefs: prefs,
    config: config,
  );
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return defaultPermissionService;
});

final recordingStorageServiceProvider = Provider<RecordingStorageService>((ref) {
  return defaultRecordingStorageService;
});

final aiPracticeInsightsServiceProvider =
    Provider<AiPracticeInsightsService>((ref) {
  return HybridAiPracticeInsightsService();
});

final premiumVideoExportServiceProvider =
    Provider<PremiumVideoExportService>((ref) {
  return PremiumVideoExportService();
});

final chordHistoryRepositoryProvider = Provider<ChordHistoryRepository>((ref) {
  return const SqliteChordHistoryRepository();
});
