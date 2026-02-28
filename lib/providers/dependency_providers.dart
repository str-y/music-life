import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native_pitch_bridge.dart';
import '../repositories/composition_repository.dart';
import '../repositories/recording_repository.dart';
import '../repositories/settings_repository.dart';

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
  return RecordingRepository(prefs);
});

final compositionRepositoryProvider = Provider<CompositionRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return CompositionRepository(prefs);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});
