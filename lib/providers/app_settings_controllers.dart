import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_provider.dart';
import 'dependency_providers.dart';
import 'metronome_settings_provider.dart';
import '../metronome_sound_library.dart';
import '../models/premium_video_export.dart';
import '../native_pitch_bridge.dart';
import '../repositories/metronome_settings_repository.dart';
import '../repositories/settings_repository.dart';

const double _maxCentsOffsetForThemeEnergy = 50.0;
final RegExp _noteNamePattern = RegExp(r'^[A-G](?:#|b)?');

class AppSettingsController {
  AppSettingsController(this._ref);

  final Ref _ref;

  AppSettingsNotifier get _notifier => _ref.read(appSettingsProvider.notifier);

  Future<void> update(
    AppSettings updated, {
    bool syncCloudBackup = true,
  }) async {
    await _notifier.save(updated);
    if (!syncCloudBackup) {
      return;
    }
    await _ref
        .read(cloudSyncControllerProvider)
        .syncBackupIfEligible(settings: updated);
  }
}

final appSettingsControllerProvider = Provider<AppSettingsController>((ref) {
  return AppSettingsController(ref);
});

class MetronomeSettingsController {
  MetronomeSettingsController(this._ref);

  final Ref _ref;

  MetronomeSettings get _settings => _ref.read(metronomeSettingsProvider);
  MetronomeSettingsNotifier get _notifier =>
      _ref.read(metronomeSettingsProvider.notifier);
  bool get _hasRewardedPremiumAccess =>
      _ref.read(appSettingsProvider).hasRewardedPremiumAccess;

  Future<void> updateMetronomeSettings({
    required int bpm,
    required int timeSignatureNumerator,
    required int timeSignatureDenominator,
  }) {
    return _notifier.save(
      _settings.copyWith(
        bpm: bpm,
        timeSignatureNumerator: timeSignatureNumerator,
        timeSignatureDenominator: timeSignatureDenominator,
      ),
    );
  }

  Future<void> savePreset(MetronomePreset preset) {
    final updatedPresets = [..._settings.presets];
    final existingIndex = updatedPresets.indexWhere(
      (candidate) => candidate.name == preset.name,
    );
    if (existingIndex >= 0) {
      updatedPresets[existingIndex] = preset;
    } else {
      updatedPresets.add(preset);
    }
    return _notifier.save(_settings.copyWith(presets: updatedPresets));
  }

  Future<void> installSoundPack(String packId) async {
    final pack = findMetronomeSoundPackById(packId);
    if (pack == null || (pack.premiumOnly && !_hasRewardedPremiumAccess)) {
      return;
    }
    await _notifier.save(
      _settings.copyWith(
        installedSoundPackIds: <String>[
          ..._settings.installedSoundPackIds,
          packId,
        ],
      ),
    );
  }

  Future<void> selectSoundPack(String packId) async {
    final pack = findMetronomeSoundPackById(packId);
    if (pack == null ||
        !_settings.installedSoundPackIds.contains(packId) ||
        (pack.premiumOnly && !_hasRewardedPremiumAccess)) {
      return;
    }
    await _notifier.save(_settings.copyWith(selectedSoundPackId: packId));
  }
}

final metronomeSettingsControllerProvider =
    Provider<MetronomeSettingsController>((ref) {
  return MetronomeSettingsController(ref);
});

class PremiumSettingsController {
  PremiumSettingsController(this._ref);

  final Ref _ref;

  AppSettings get _settings => _ref.read(appSettingsProvider);

  Future<void> unlockRewardedPremiumFor(
    Duration duration, {
    DateTime? now,
  }) async {
    final grantedAt = now ?? DateTime.now();
    await _ref.read(appSettingsControllerProvider).update(
          _settings.copyWith(
            rewardedPremiumExpiresAt: grantedAt.add(duration),
          ),
        );
  }

  Future<void> updateVideoExportSettings({
    PremiumVideoExportSkin? skin,
    int? waveformColorValue,
    PremiumVideoExportEffect? effect,
    bool? showLogo,
    PremiumVideoExportQuality? quality,
  }) async {
    await _ref.read(appSettingsControllerProvider).update(
          _settings.copyWith(
            premiumVideoExportSkin: skin,
            premiumVideoExportColor: waveformColorValue,
            premiumVideoExportEffect: effect,
            premiumVideoExportShowLogo: showLogo,
            premiumVideoExportQuality: quality,
          ),
          syncCloudBackup: false,
        );
  }
}

final premiumSettingsControllerProvider =
    Provider<PremiumSettingsController>((ref) {
  return PremiumSettingsController(ref);
});

class CloudSyncController {
  CloudSyncController(this._ref);

  final Ref _ref;

  AppSettingsNotifier get _notifier => _ref.read(appSettingsProvider.notifier);

  Future<DateTime?> syncBackupIfEligible({AppSettings? settings}) async {
    final currentSettings = settings ?? _ref.read(appSettingsProvider);
    if (!currentSettings.cloudSyncEnabled ||
        !currentSettings.hasRewardedPremiumAccess) {
      return null;
    }
    final syncedAt = await _ref.read(cloudSyncRepositoryProvider).syncNow();
    await _notifier.save(
      _ref.read(appSettingsProvider).copyWith(lastCloudSyncAt: syncedAt),
    );
    return syncedAt;
  }

  Future<DateTime?> setEnabled(bool enabled) async {
    final settings = _ref.read(appSettingsProvider);
    await _ref.read(appSettingsControllerProvider).update(
          enabled
              ? settings.copyWith(cloudSyncEnabled: true)
              : settings.copyWith(
                  cloudSyncEnabled: false,
                  clearLastCloudSyncAt: true,
                ),
          syncCloudBackup: enabled,
        );
    return _ref.read(appSettingsProvider).lastCloudSyncAt;
  }

  Future<bool> restoreLatestBackup() async {
    final syncedAt =
        await _ref.read(cloudSyncRepositoryProvider).restoreLatestBackup();
    if (syncedAt == null) {
      return false;
    }
    await _notifier.save(
      _ref.read(appSettingsProvider).copyWith(lastCloudSyncAt: syncedAt),
    );
    return true;
  }

  Future<DateTime> syncNow() async {
    final syncedAt = await _ref.read(cloudSyncRepositoryProvider).syncNow();
    await _notifier.save(
      _ref.read(appSettingsProvider).copyWith(lastCloudSyncAt: syncedAt),
    );
    return syncedAt;
  }
}

final cloudSyncControllerProvider = Provider<CloudSyncController>((ref) {
  return CloudSyncController(ref);
});

class DynamicThemeController {
  DynamicThemeController(this._ref);

  final Ref _ref;

  AppSettingsNotifier get _notifier => _ref.read(appSettingsProvider.notifier);

  void updateFromPitch(PitchResult pitch) {
    final centsEnergy =
        (pitch.centsOffset.abs() / _maxCentsOffsetForThemeEnergy)
            .clamp(0.0, 1.0)
            .toDouble();
    final energy = (centsEnergy * _frequencyRangeWeight(pitch.frequency))
        .clamp(0.0, 1.0)
        .toDouble();
    _notifier.setTransient(
      _ref.read(appSettingsProvider).copyWith(
            dynamicThemeNote: pitch.noteName,
            dynamicThemeEnergy: energy,
          ),
    );
  }

  void updateFromChord(String chordName) {
    final note = _noteNamePattern.firstMatch(chordName)?.group(0);
    if (note == null) {
      return;
    }
    _notifier.setTransient(
      _ref.read(appSettingsProvider).copyWith(
            dynamicThemeNote: note,
            dynamicThemeEnergy: _chordComplexityEnergy(chordName),
          ),
    );
  }

  double _frequencyRangeWeight(double frequency) {
    if (frequency < 196.0) return 0.85;
    if (frequency < 523.25) return 1.0;
    return 1.15;
  }

  double _chordComplexityEnergy(String chordName) {
    final suffix = chordName.replaceFirst(_noteNamePattern, '').toLowerCase();
    if (suffix.isEmpty) return 0.28;
    if (suffix.contains('dim') || suffix.contains('aug')) return 0.78;
    if (suffix.contains('maj7') ||
        suffix.contains('m7') ||
        suffix.contains('7') ||
        suffix.contains('sus') ||
        suffix.contains('add')) {
      return 0.64;
    }
    if (suffix.startsWith('m')) return 0.46;
    return 0.38;
  }
}

final dynamicThemeControllerProvider = Provider<DynamicThemeController>((ref) {
  return DynamicThemeController(ref);
});
