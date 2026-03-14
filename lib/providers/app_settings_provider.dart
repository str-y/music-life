import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependency_providers.dart';
import '../metronome_sound_library.dart';
import '../models/premium_video_export.dart';
import '../native_pitch_bridge.dart';
import '../repositories/settings_repository.dart';

const double _maxCentsOffsetForThemeEnergy = 50.0;
final RegExp _noteNamePattern = RegExp(r'^[A-G](?:#|b)?');

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    return _repo.load();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> update(AppSettings updated, {bool syncCloudBackup = true}) async {
    state = updated;
    await _repo.save(updated);
    if (!syncCloudBackup ||
        !updated.cloudSyncEnabled ||
        !updated.hasRewardedPremiumAccess) {
      return;
    }
    final syncedAt = await ref.read(cloudSyncRepositoryProvider).syncNow();
    state = updated.copyWith(lastCloudSyncAt: syncedAt);
    await _repo.save(state);
  }

  Future<void> unlockRewardedPremiumFor(
    Duration duration, {
    DateTime? now,
  }) async {
    final grantedAt = now ?? DateTime.now();
    await update(
      state.copyWith(
        rewardedPremiumExpiresAt: grantedAt.add(duration),
      ),
    );
  }

  Future<void> installMetronomeSoundPack(String packId) async {
    final pack = findMetronomeSoundPackById(packId);
    if (pack == null || (pack.premiumOnly && !state.hasRewardedPremiumAccess)) {
      return;
    }
    await update(
      state.copyWith(
        installedMetronomeSoundPackIds: <String>[
          ...state.installedMetronomeSoundPackIds,
          packId,
        ],
      ),
      syncCloudBackup: false,
    );
  }

  Future<void> selectMetronomeSoundPack(String packId) async {
    final pack = findMetronomeSoundPackById(packId);
    if (pack == null ||
        !state.installedMetronomeSoundPackIds.contains(packId) ||
        (pack.premiumOnly && !state.hasRewardedPremiumAccess)) {
      return;
    }
    await update(
      state.copyWith(selectedMetronomeSoundPackId: packId),
      syncCloudBackup: false,
    );
  }

  Future<DateTime?> setCloudSyncEnabled(bool enabled) async {
    await update(
      enabled
          ? state.copyWith(cloudSyncEnabled: true)
          : state.copyWith(
              cloudSyncEnabled: false,
              clearLastCloudSyncAt: true,
            ),
      syncCloudBackup: enabled,
    );
    return state.lastCloudSyncAt;
  }

  Future<bool> restoreLatestCloudBackup() async {
    final syncedAt = await ref
        .read(cloudSyncRepositoryProvider)
        .restoreLatestBackup();
    if (syncedAt == null) return false;
    await update(
      state.copyWith(lastCloudSyncAt: syncedAt),
      syncCloudBackup: false,
    );
    return true;
  }

  Future<DateTime> syncCloudBackupNow() async {
    final syncedAt = await ref.read(cloudSyncRepositoryProvider).syncNow();
    await update(
      state.copyWith(lastCloudSyncAt: syncedAt),
      syncCloudBackup: false,
    );
    return syncedAt;
  }

  Future<void> updatePremiumVideoExportSettings({
    PremiumVideoExportSkin? skin,
    int? waveformColorValue,
    PremiumVideoExportEffect? effect,
    bool? showLogo,
    PremiumVideoExportQuality? quality,
  }) async {
    await update(
      state.copyWith(
        premiumVideoExportSkin: skin,
        premiumVideoExportColor: waveformColorValue,
        premiumVideoExportEffect: effect,
        premiumVideoExportShowLogo: showLogo,
        premiumVideoExportQuality: quality,
      ),
      syncCloudBackup: false,
    );
  }

  void updateDynamicThemeFromPitch(PitchResult pitch) {
    final centsEnergy = (pitch.centsOffset.abs() / _maxCentsOffsetForThemeEnergy)
        .clamp(0.0, 1.0)
        .toDouble();
    final energy = (centsEnergy * _frequencyRangeWeight(pitch.frequency))
        .clamp(0.0, 1.0)
        .toDouble();
    state = state.copyWith(
      dynamicThemeNote: pitch.noteName,
      dynamicThemeEnergy: energy,
    );
  }

  void updateDynamicThemeFromChord(String chordName) {
    final note = _noteNamePattern.firstMatch(chordName)?.group(0);
    if (note == null) return;
    state = state.copyWith(
      dynamicThemeNote: note,
      dynamicThemeEnergy: _chordComplexityEnergy(chordName),
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

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
