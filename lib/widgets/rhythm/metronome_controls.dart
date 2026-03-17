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
    required this.rhythmState,
    required this.timeSignatureNumerators,
    required this.timeSignatureDenominators,
    required this.beatPulseAnimation,
    required this.onPresetApplied,
    required this.onSavePreset,
    required this.onChangeBpm,
    required this.onUpdateMetronomeSettings,
  });

  final RhythmState rhythmState;
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
    final settings = ref.watch(metronomeSettingsProvider);
    final presetOptions = _buildPresetOptions(l10n, settings);
    final selectedPreset = _findMatchingPreset(presetOptions, rhythmState);
    final selectedPack = resolveSelectedMetronomeSoundPack(
      selectedId: settings.selectedSoundPackId,
      installedIds: settings.installedSoundPackIds,
      hasPremiumAccess: hasPremiumAccess,
    );
    final recommendedPack = recommendMetronomeSoundPack(rhythmState.bpm);

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
      selectedNumerator: rhythmState.timeSignatureNumerator,
      selectedDenominator: rhythmState.timeSignatureDenominator,
      onNumeratorChanged: (value) {
        if (value == null) {
          return;
        }
        unawaited(
          onUpdateMetronomeSettings(
            bpm: rhythmState.bpm,
            numerator: value,
            denominator: rhythmState.timeSignatureDenominator,
          ),
        );
      },
      onDenominatorChanged: (value) {
        if (value == null) {
          return;
        }
        unawaited(
          onUpdateMetronomeSettings(
            bpm: rhythmState.bpm,
            numerator: rhythmState.timeSignatureNumerator,
            denominator: value,
          ),
        );
      },
      bpm: rhythmState.bpm,
      isPlaying: rhythmState.isPlaying,
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
            bpm: rhythmState.bpm,
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

MetronomePresetOption? _findMatchingPreset(
  List<MetronomePresetOption> presetOptions,
  RhythmState rhythmState,
) {
  for (final option in presetOptions) {
    if (option.preset.bpm == rhythmState.bpm &&
        option.preset.timeSignatureNumerator ==
            rhythmState.timeSignatureNumerator &&
        option.preset.timeSignatureDenominator ==
            rhythmState.timeSignatureDenominator) {
      return option;
    }
  }
  return null;
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
