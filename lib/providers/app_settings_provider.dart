import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';
import '../repositories/settings_repository.dart';

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
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
