import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/metronome_sound_library.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/metronome_settings_provider.dart';
import 'package:music_life/providers/rhythm_provider.dart';
import 'package:music_life/repositories/metronome_settings_repository.dart';
import 'package:music_life/widgets/rhythm/metronome_preset_controls.dart';
import 'package:music_life/widgets/rhythm/metronome_section.dart';
import 'package:music_life/widgets/rhythm/sound_library_sheet.dart';

typedef UpdateMetronomeSettingsCallback =
    Future<void> Function({
      required int bpm,
      required int numerator,
      required int denominator,
    });

class MetronomeControls extends ConsumerWidget {
  const MetronomeControls({
    super.key,
    required this.timeSignatureNumerators,
    required this.timeSignatureDenominators,
    required this.beatPulseAnimation,
    required this.onPresetApplied,
    required this.onSavePreset,
    required this.onChangeBpm,
    required this.onUpdateMetronomeSettings,
  });

  final List<int> timeSignatureNumerators;
  final List<int> timeSignatureDenominators;
  final Animation<double> beatPulseAnimation;
  final ValueChanged<MetronomePreset> onPresetApplied;
  final VoidCallback onSavePreset;
  final ValueChanged<int> onChangeBpm;
  final UpdateMetronomeSettingsCallback onUpdateMetronomeSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final hasPremiumAccess = ref.watch(
      appSettingsProvider.select((settings) => settings.hasRewardedPremiumAccess),
    );
    final bpm = ref.watch(rhythmProvider.select<int>((s) => s.bpm));
    final isPlaying = ref.watch(rhythmProvider.select<bool>((s) => s.isPlaying));
    final numerator = ref.watch(rhythmProvider.select<int>((s) => s.timeSignatureNumerator));
    final denominator = ref.watch(rhythmProvider.select<int>((s) => s.timeSignatureDenominator));

    final settings = ref.watch(metronomeSettingsProvider);
    final presetOptions = _buildPresetOptions(l10n, settings);
    
    // Internal helper for preset matching
    MetronomePresetOption? findMatching() {
      for (final option in presetOptions) {
        if (option.preset.bpm == bpm &&
            option.preset.timeSignatureNumerator == numerator &&
            option.preset.timeSignatureDenominator == denominator) {
          return option;
        }
      }
      return null;
    }

    final selectedPreset = findMatching();
    final selectedPack = resolveSelectedMetronomeSoundPack(
      selectedId: settings.selectedSoundPackId,
      installedIds: settings.installedSoundPackIds,
      hasPremiumAccess: hasPremiumAccess,
    );
    final recommendedPack = recommendMetronomeSoundPack(bpm);

    return MetronomeSection(
      presetOptions: presetOptions,
      selectedPresetId: selectedPreset?.id,
      onPresetSelected: (value) {
        final option = _findPresetOption(presetOptions, value);
        if (option == null) {
          return;
        }
        onPresetApplied(option.preset);
      },
      onSavePreset: onSavePreset,
      timeSignatureNumerators: timeSignatureNumerators,
      timeSignatureDenominators: timeSignatureDenominators,
      selectedNumerator: numerator,
      selectedDenominator: denominator,
      onNumeratorChanged: (value) {
        if (value == null) {
          return;
        }
        unawaited(
          onUpdateMetronomeSettings(
            bpm: bpm,
            numerator: value,
            denominator: denominator,
          ),
        );
      },
      onDenominatorChanged: (value) {
        if (value == null) {
          return;
        }
        unawaited(
          onUpdateMetronomeSettings(
            bpm: bpm,
            numerator: numerator,
            denominator: value,
          ),
        );
      },
      bpm: bpm,
      isPlaying: isPlaying,
      beatPulseAnimation: beatPulseAnimation,
      onDecrease10: () => onChangeBpm(-10),
      onDecrease1: () => onChangeBpm(-1),
      onTogglePlayStop: ref.read(rhythmProvider.notifier).toggleMetronome,
      onIncrease1: () => onChangeBpm(1),
      onIncrease10: () => onChangeBpm(10),
      selectedPack: selectedPack,
      recommendedPack: recommendedPack,
      onManageSoundLibrary: () {
        unawaited(
          showSoundLibrarySheet(
            context: context,
            bpm: bpm,
          ),
        );
      },
    );
  }
}

List<MetronomePresetOption> _buildPresetOptions(
  AppLocalizations l10n,
  MetronomeSettings settings,
) {
  final builtInPresets = <MetronomePresetOption>[
    MetronomePresetOption(
      id: 'builtin-ballad',
      label: l10n.metronomePresetBallad,
      preset: const MetronomePreset(
        name: 'builtin-ballad',
        bpm: 72,
        timeSignatureNumerator: 4,
        timeSignatureDenominator: 4,
      ),
    ),
    MetronomePresetOption(
      id: 'builtin-up-tempo',
      label: l10n.metronomePresetUpTempo,
      preset: const MetronomePreset(
        name: 'builtin-up-tempo',
        bpm: 160,
        timeSignatureNumerator: 4,
        timeSignatureDenominator: 4,
      ),
    ),
    MetronomePresetOption(
      id: 'builtin-waltz',
      label: l10n.metronomePresetWaltz,
      preset: const MetronomePreset(
        name: 'builtin-waltz',
        bpm: 96,
        timeSignatureNumerator: 3,
        timeSignatureDenominator: 4,
      ),
    ),
    MetronomePresetOption(
      id: 'builtin-shuffle',
      label: l10n.metronomePresetShuffle,
      preset: const MetronomePreset(
        name: 'builtin-shuffle',
        bpm: 132,
        timeSignatureNumerator: 6,
        timeSignatureDenominator: 8,
      ),
    ),
  ];
  final customPresets = settings.presets
      .asMap()
      .entries
      .map(
        (entry) => MetronomePresetOption(
          id: 'custom-${entry.key}',
          label: entry.value.name,
          preset: entry.value,
        ),
      )
      .toList(growable: false);
  return [...builtInPresets, ...customPresets];
}


MetronomePresetOption? _findPresetOption(
  List<MetronomePresetOption> presetOptions,
  String? id,
) {
  if (id == null) {
    return null;
  }
  for (final option in presetOptions) {
    if (option.id == id) {
      return option;
    }
  }
  return null;
}
