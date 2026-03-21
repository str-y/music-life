import 'package:flutter/material.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/metronome_sound_library.dart';

import 'package:music_life/widgets/rhythm/metronome_bpm_controls.dart';
import 'package:music_life/widgets/rhythm/metronome_preset_controls.dart';

class MetronomeSection extends StatelessWidget {
  const MetronomeSection({
    required this.presetOptions, required this.selectedPresetId, required this.onPresetSelected, required this.onSavePreset, required this.timeSignatureNumerators, required this.timeSignatureDenominators, required this.selectedNumerator, required this.selectedDenominator, required this.onNumeratorChanged, required this.onDenominatorChanged, required this.bpm, required this.isPlaying, required this.beatPulseAnimation, required this.onDecrease10, required this.onDecrease1, required this.onTogglePlayStop, required this.onIncrease1, required this.onIncrease10, required this.selectedPack, required this.recommendedPack, required this.onManageSoundLibrary, super.key,
  });

  final List<MetronomePresetOption> presetOptions;
  final String? selectedPresetId;
  final ValueChanged<String?> onPresetSelected;
  final VoidCallback onSavePreset;
  final List<int> timeSignatureNumerators;
  final List<int> timeSignatureDenominators;
  final int selectedNumerator;
  final int selectedDenominator;
  final ValueChanged<int?> onNumeratorChanged;
  final ValueChanged<int?> onDenominatorChanged;
  final int bpm;
  final bool isPlaying;
  final Animation<double> beatPulseAnimation;
  final VoidCallback onDecrease10;
  final VoidCallback onDecrease1;
  final VoidCallback onTogglePlayStop;
  final VoidCallback onIncrease1;
  final VoidCallback onIncrease10;
  final MetronomeSoundPack selectedPack;
  final MetronomeSoundPack recommendedPack;
  final VoidCallback onManageSoundLibrary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MetronomePresetControls(
              presetOptions: presetOptions,
              selectedPresetId: selectedPresetId,
              onPresetSelected: onPresetSelected,
              onSavePreset: onSavePreset,
              timeSignatureNumerators: timeSignatureNumerators,
              timeSignatureDenominators: timeSignatureDenominators,
              selectedNumerator: selectedNumerator,
              selectedDenominator: selectedDenominator,
              onNumeratorChanged: onNumeratorChanged,
              onDenominatorChanged: onDenominatorChanged,
            ),
            const SizedBox(height: 16),
            MetronomeBpmControls(
              bpm: bpm,
              isPlaying: isPlaying,
              beatPulseAnimation: beatPulseAnimation,
              onDecrease10: onDecrease10,
              onDecrease1: onDecrease1,
              onTogglePlayStop: onTogglePlayStop,
              onIncrease1: onIncrease1,
              onIncrease10: onIncrease10,
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(_iconForSoundPack(selectedPack)),
                title: Text(l10n.metronomeSoundLibraryTitle),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.metronomeSoundLibrarySelected(
                        _soundPackName(l10n, selectedPack),
                      ),
                    ),
                    Text(
                      l10n.metronomeSoundLibraryRecommendation(
                        _soundPackName(l10n, recommendedPack),
                      ),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                trailing: IconButton(
                  key: const ValueKey('metronome-sound-library-button'),
                  tooltip: l10n.metronomeSoundLibraryManage,
                  onPressed: onManageSoundLibrary,
                  icon: const Icon(Icons.library_music),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
