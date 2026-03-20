import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/metronome_settings_provider.dart';
import 'package:music_life/services/ad_service.dart';

class MetronomeSoundLibraryState {
  const MetronomeSoundLibraryState({
    this.installingPackId,
  });

  final String? installingPackId;

  MetronomeSoundLibraryState copyWith({
    String? installingPackId,
    bool clearInstalling = false,
  }) {
    return MetronomeSoundLibraryState(
      installingPackId: clearInstalling ? null : (installingPackId ?? this.installingPackId),
    );
  }
}

class MetronomeSoundLibraryNotifier extends Notifier<MetronomeSoundLibraryState> {
  @override
  MetronomeSoundLibraryState build() => const MetronomeSoundLibraryState();

  Future<bool> handleSoundPackAction({
    required MetronomeSoundPack pack,
    required bool isLocked,
    required Duration rewardedDuration,
  }) async {
    if (isLocked) {
      state = state.copyWith(installingPackId: pack.id);
      try {
        final rewarded = await ref.read(adServiceProvider).showRewardedAd(
          onUserEarnedReward: (_) {},
        );
        if (!rewarded) {
          state = state.copyWith(clearInstalling: true);
          return false;
        }

        await ref
            .read(premiumSettingsControllerProvider)
            .unlockRewardedPremiumFor(rewardedDuration);
      } catch (_) {
        state = state.copyWith(clearInstalling: true);
        return false;
      }
    }

    state = state.copyWith(installingPackId: pack.id);
    try {
      await ref.read(metronomeSettingsControllerProvider).installSoundPack(pack.id);
      await ref.read(metronomeSettingsControllerProvider).selectSoundPack(pack.id);
      return true;
    } finally {
      state = state.copyWith(clearInstalling: true);
    }
  }
}

final metronomeSoundLibraryControllerProvider =
    NotifierProvider<MetronomeSoundLibraryNotifier, MetronomeSoundLibraryState>(
  MetronomeSoundLibraryNotifier.new,
);
