import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';
import '../native_pitch_bridge.dart';
import '../repositories/settings_repository.dart';

const double _maxCentsOffsetForThemeEnergy = 50.0;

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return _repo.load();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> update(AppSettings updated) async {
    state = updated;
    await _repo.save(updated);
  }

  void updateDynamicThemeFromPitch(PitchResult pitch) {
    final energy = pitch.centsOffset.abs() / _maxCentsOffsetForThemeEnergy;
    state = state.copyWith(
      dynamicThemeNote: pitch.noteName,
      dynamicThemeEnergy: energy < 0 ? 0.0 : (energy > 1 ? 1.0 : energy),
    );
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
