import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/repositories/settings_repository.dart';
class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return _repo.load();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> save(AppSettings updated) async {
    await _repo.save(updated);
    state = updated;
  }

  void setTransient(AppSettings updated) {
    state = updated;
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
