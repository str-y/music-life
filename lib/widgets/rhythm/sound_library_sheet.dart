import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/metronome_settings_provider.dart';
import 'package:music_life/services/ad_service.dart';

const Duration _rewardedPremiumDuration = Duration(hours: 24);

Future<void> showSoundLibrarySheet({
  required BuildContext context,
  required int bpm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SoundLibrarySheet(bpm: bpm),
  );
}

class SoundLibrarySheet extends ConsumerWidget {
  const SoundLibrarySheet({
    super.key,
    required this.bpm,
  });

  final int bpm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasPremiumAccess = ref.watch(
      appSettingsProvider.select((settings) => settings.hasRewardedPremiumAccess),
    );
    final settings = ref.watch(metronomeSettingsProvider);
    final selectedPack = resolveSelectedMetronomeSoundPack(
      selectedId: settings.selectedSoundPackId,
      installedIds: settings.installedSoundPackIds,
      hasPremiumAccess: hasPremiumAccess,
    );
    final recommendedPack = recommendMetronomeSoundPack(bpm);
    final sheetHeight = MediaQuery.of(context).size.height * 0.72;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.metronomeSoundLibraryTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.metronomeSoundLibrarySubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.metronomeSoundLibrarySelected(
                        _soundPackName(l10n, selectedPack),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.metronomeSoundLibraryRecommendation(
                        _soundPackName(l10n, recommendedPack),
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latencyLabel(l10n, selectedPack),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: metronomeSoundPacks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pack = metronomeSoundPacks[index];
                    final isInstalled =
                        settings.installedSoundPackIds.contains(pack.id);
                    final isSelected = selectedPack.id == pack.id && isInstalled;
                    final isRecommended = recommendedPack.id == pack.id;
                    final isLocked = pack.premiumOnly && !hasPremiumAccess;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer,
                                  child: Icon(_iconForSoundPack(pack)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _soundPackName(l10n, pack),
                                        key: ValueKey(
                                          'metronome-sound-name-${pack.id}',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_soundPackDescription(l10n, pack)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _StatusChip(
                                  label: _soundPackTypeLabel(l10n, pack),
                                ),
                                _StatusChip(
                                  label: _latencyLabel(l10n, pack),
                                ),
                                if (isRecommended)
                                  _StatusChip(
                                    label:
                                        l10n.metronomeSoundLibraryRecommendedChip,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                  ),
                                if (pack.premiumOnly)
                                  _StatusChip(
                                    label: l10n.metronomeSoundLibraryPremiumChip,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .tertiaryContainer,
                                  ),
                                if (isInstalled)
                                  _StatusChip(
                                    label:
                                        l10n.metronomeSoundLibraryInstalledChip,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                key: ValueKey(
                                  'metronome-sound-action-${pack.id}',
                                ),
                                onPressed: () => _handleSoundPackAction(
                                  context: context,
                                  ref: ref,
                                  pack: pack,
                                  isInstalled: isInstalled,
                                  isSelected: isSelected,
                                  isLocked: isLocked,
                                ),
                                icon: Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : isLocked
                                          ? Icons.ondemand_video
                                          : isInstalled
                                              ? Icons.graphic_eq
                                              : Icons.download,
                                ),
                                label: Text(
                                  isSelected
                                      ? l10n.metronomeSoundLibraryInUse
                                      : isLocked
                                          ? l10n.watchAdAndUnlock
                                          : isInstalled
                                              ? l10n.metronomeSoundLibraryUse
                                              : l10n
                                                  .metronomeSoundLibraryDownload,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _handleSoundPackAction({
  required BuildContext context,
  required WidgetRef ref,
  required MetronomeSoundPack pack,
  required bool isInstalled,
  required bool isSelected,
  required bool isLocked,
}) async {
  final l10n = AppLocalizations.of(context)!;
  if (isSelected) {
    return;
  }
  if (isLocked) {
    final rewarded = await ref.read(adServiceProvider).showRewardedAd(
      onUserEarnedReward: (_) {},
    );
    if (!context.mounted) {
      return;
    }
    if (!rewarded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rewardedAdNotReady)),
      );
      return;
    }
    await ref
        .read(premiumSettingsControllerProvider)
        .unlockRewardedPremiumFor(_rewardedPremiumDuration);
    await ref.read(metronomeSettingsControllerProvider).installSoundPack(pack.id);
    await ref.read(metronomeSettingsControllerProvider).selectSoundPack(pack.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.metronomeSoundLibraryUnlocked(_soundPackName(l10n, pack))),
      ),
    );
    return;
  }
  if (!isInstalled) {
    await ref.read(metronomeSettingsControllerProvider).installSoundPack(pack.id);
  }
  await ref.read(metronomeSettingsControllerProvider).selectSoundPack(pack.id);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.metronomeSoundLibraryDownloaded(_soundPackName(l10n, pack)),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.backgroundColor,
  });

  final String label;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

IconData _iconForSoundPack(MetronomeSoundPack pack) {
  switch (pack.type) {
    case MetronomeSoundPackType.electronic:
      return Icons.radio_button_checked;
    case MetronomeSoundPackType.acousticDrums:
      return Icons.album;
    case MetronomeSoundPackType.percussion:
      return Icons.music_note;
    case MetronomeSoundPackType.voiceCount:
      return Icons.record_voice_over;
  }
}

String _soundPackName(AppLocalizations l10n, MetronomeSoundPack pack) {
  switch (pack.id) {
    case defaultMetronomeSoundPackId:
      return l10n.metronomeSoundPackElectronicName;
    case 'acoustic_kit':
      return l10n.metronomeSoundPackAcousticName;
    case 'percussion_clave':
      return l10n.metronomeSoundPackPercussionName;
    case 'signature_voice_count':
      return l10n.metronomeSoundPackVoiceName;
  }
  return pack.id;
}

String _soundPackDescription(AppLocalizations l10n, MetronomeSoundPack pack) {
  switch (pack.id) {
    case defaultMetronomeSoundPackId:
      return l10n.metronomeSoundPackElectronicDescription;
    case 'acoustic_kit':
      return l10n.metronomeSoundPackAcousticDescription;
    case 'percussion_clave':
      return l10n.metronomeSoundPackPercussionDescription;
    case 'signature_voice_count':
      return l10n.metronomeSoundPackVoiceDescription;
  }
  return pack.id;
}

String _soundPackTypeLabel(AppLocalizations l10n, MetronomeSoundPack pack) {
  switch (pack.type) {
    case MetronomeSoundPackType.electronic:
      return l10n.metronomeSoundTypeElectronic;
    case MetronomeSoundPackType.acousticDrums:
      return l10n.metronomeSoundTypeAcoustic;
    case MetronomeSoundPackType.percussion:
      return l10n.metronomeSoundTypePercussion;
    case MetronomeSoundPackType.voiceCount:
      return l10n.metronomeSoundTypeVoice;
  }
}

String _latencyLabel(AppLocalizations l10n, MetronomeSoundPack pack) {
  switch (pack.latencyProfile) {
    case MetronomeLatencyProfile.ultraLow:
      return l10n.metronomeSoundLatencyUltraLow;
    case MetronomeLatencyProfile.balanced:
      return l10n.metronomeSoundLatencyBalanced;
    case MetronomeLatencyProfile.preloaded:
      return l10n.metronomeSoundLatencyPreloaded;
  }
}
