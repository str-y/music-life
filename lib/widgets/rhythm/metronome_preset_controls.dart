import 'package:flutter/material.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/repositories/settings_repository.dart';

class MetronomePresetOption {
  const MetronomePresetOption({
    required this.id,
    required this.label,
    required this.preset,
  });

  final String id;
  final String label;
  final MetronomePreset preset;
}

class MetronomePresetControls extends StatelessWidget {
  const MetronomePresetControls({
    super.key,
    required this.presetOptions,
    required this.selectedPresetId,
    required this.onPresetSelected,
    required this.onSavePreset,
    required this.timeSignatureNumerators,
    required this.timeSignatureDenominators,
    required this.selectedNumerator,
    required this.selectedDenominator,
    required this.onNumeratorChanged,
    required this.onDenominatorChanged,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const ValueKey('metronome-preset-dropdown'),
                value: selectedPresetId,
                decoration: InputDecoration(labelText: l10n.metronomePresetLabel),
                hint: Text(l10n.metronomePresetHint),
                items: presetOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.id,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onPresetSelected,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('save-metronome-preset'),
              onPressed: onSavePreset,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l10n.metronomeSavePreset),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              l10n.metronomeTimeSignatureLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const ValueKey('time-signature-numerator-dropdown'),
                value: selectedNumerator,
                decoration: const InputDecoration(isDense: true),
                items: timeSignatureNumerators
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onNumeratorChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/'),
            ),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: const ValueKey('time-signature-denominator-dropdown'),
                value: selectedDenominator,
                decoration: const InputDecoration(isDense: true),
                items: timeSignatureDenominators
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text(value.toString()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onDenominatorChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
