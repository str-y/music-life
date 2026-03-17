import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/repositories/metronome_settings_repository.dart';
import 'package:music_life/providers/dependency_providers.dart';

class MetronomeSettingsNotifier extends Notifier<MetronomeSettings> {
  @override
  MetronomeSettings build() {
    return _repo.load();
  }

  MetronomeSettingsRepository get _repo =>
      ref.read(metronomeSettingsRepositoryProvider);

  Future<void> save(MetronomeSettings updated) async {
    state = updated;
    await _repo.save(updated);
  }
}

final metronomeSettingsProvider =
    NotifierProvider<MetronomeSettingsNotifier, MetronomeSettings>(
      MetronomeSettingsNotifier.new,
    );
