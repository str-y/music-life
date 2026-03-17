import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/metronome_settings_provider.dart';
import 'package:music_life/providers/rhythm_provider.dart';
import 'package:music_life/repositories/metronome_settings_repository.dart';
import 'package:music_life/widgets/rhythm/groove_analysis_section.dart';
import 'package:music_life/widgets/rhythm/metronome_controls.dart';

/// Rhythm & Metronome screen.
///
/// Features:
///  - Pro-grade metronome: large BPM display with +/− controls and a
///    play/stop button.
///  - Groove analysis: the lower half of the screen shows an animated
///    "target" (concentric rings).  When the user taps on the beat the ring
///    animates to show how far from the perfect grid the tap was.
class RhythmScreen extends ConsumerStatefulWidget {
  const RhythmScreen({super.key});

  @override
  ConsumerState<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends ConsumerState<RhythmScreen>
    with TickerProviderStateMixin {
  static const List<int> _timeSignatureNumerators = <int>[
    2,
    3,
    4,
    5,
    6,
    7,
    9,
    12,
  ];
  static const List<int> _timeSignatureDenominators = <int>[4, 8];

  /// Animation controller for the target ring pulse on each beat.
  late final AnimationController _beatPulseCtrl;
  late final CurvedAnimation _beatPulseCurve;
  late final Animation<double> _beatPulseAnim;

  /// Animation controller for the user-tap impact ring.
  late final AnimationController _tapRingCtrl;
  late final CurvedAnimation _tapRingCurve;
  late final Animation<double> _tapRingAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _beatPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _beatPulseCurve = CurvedAnimation(parent: _beatPulseCtrl, curve: Curves.easeOut);
    _beatPulseAnim = Tween<double>(begin: 0, end: 1).animate(_beatPulseCurve);

    _tapRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tapRingCurve = CurvedAnimation(parent: _tapRingCtrl, curve: Curves.easeOut);
    _tapRingAnim = Tween<double>(begin: 0, end: 1).animate(_tapRingCurve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(metronomeSettingsProvider);
      ref.read(rhythmProvider.notifier).applyMetronomeSettings(
            bpm: settings.bpm,
            timeSignatureNumerator: settings.timeSignatureNumerator,
            timeSignatureDenominator: settings.timeSignatureDenominator,
          );
    });
  }

  @override
  void dispose() {
    _beatPulseCtrl.dispose();
    _beatPulseCurve.dispose();
    _tapRingCtrl.dispose();
    _tapRingCurve.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.listen<RhythmState>(rhythmProvider, (previous, next) {
      if (previous?.beatIndex != next.beatIndex && next.isPlaying) {
        _beatPulseCtrl.forward(from: 0);
      }
      if (previous != null && previous.lastOffsetMs != next.lastOffsetMs) {
        _tapRingCtrl.forward(from: 0);
      }
    });

    final rhythmState = ref.watch(rhythmProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.rhythmTitle),
      ),
      body: Column(
        children: [
          // ── Top half: metronome controls ────────────────────────────────
          Expanded(
            child: RepaintBoundary(
              child: MetronomeControls(
                rhythmState: rhythmState,
                timeSignatureNumerators: _timeSignatureNumerators,
                timeSignatureDenominators: _timeSignatureDenominators,
                beatPulseAnimation: _beatPulseAnim,
                onPresetApplied: _applyPreset,
                onSavePreset: () => _showSavePresetDialog(rhythmState),
                onChangeBpm: (delta) => _changeBpm(rhythmState, delta),
                onUpdateMetronomeSettings: _updateMetronomeSettings,
              ),
            ),
          ),
          const Divider(height: 1),
          // ── Bottom half: groove analysis target ─────────────────────────
          Expanded(
            child: GrooveAnalysisSection(
              colorScheme: colorScheme,
              rhythmState: rhythmState,
              beatPulseAnimation: _beatPulseAnim,
              tapRingAnimation: _tapRingAnim,
              onTap: ref.read(rhythmProvider.notifier).onGrooveTap,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSavePresetDialog(RhythmState rhythmState) async {
    final l10n = AppLocalizations.of(context)!;
    final customPresetCount = ref.read(metronomeSettingsProvider).presets.length;
    final controller = TextEditingController(
      text: l10n.metronomePresetDefaultName(customPresetCount + 1),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.metronomeSavePreset),
          content: TextField(
            key: const ValueKey('metronome-preset-name-field'),
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.metronomePresetNameLabel,
            ),
            autofocus: true,
            onSubmitted: (_) => Navigator.of(dialogContext).pop(true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.save),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final trimmedName = controller.text.trim();
      final preset = MetronomePreset(
        name: trimmedName.isEmpty
            ? l10n.metronomePresetDefaultName(customPresetCount + 1)
            : trimmedName,
        bpm: rhythmState.bpm,
        timeSignatureNumerator: rhythmState.timeSignatureNumerator,
        timeSignatureDenominator: rhythmState.timeSignatureDenominator,
      );
      await ref.read(metronomeSettingsControllerProvider).savePreset(preset);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.metronomePresetSaved(preset.name))),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _applyPreset(MetronomePreset preset) {
    return _updateMetronomeSettings(
      bpm: preset.bpm,
      numerator: preset.timeSignatureNumerator,
      denominator: preset.timeSignatureDenominator,
    );
  }

  Future<void> _changeBpm(RhythmState rhythmState, int delta) {
    final nextBpm = (rhythmState.bpm + delta).clamp(30, 240).toInt();
    return _updateMetronomeSettings(
      bpm: nextBpm,
      numerator: rhythmState.timeSignatureNumerator,
      denominator: rhythmState.timeSignatureDenominator,
    );
  }

  Future<void> _updateMetronomeSettings({
    required int bpm,
    required int numerator,
    required int denominator,
  }) async {
    ref.read(rhythmProvider.notifier).applyMetronomeSettings(
          bpm: bpm,
          timeSignatureNumerator: numerator,
          timeSignatureDenominator: denominator,
        );
    await ref.read(metronomeSettingsControllerProvider).updateMetronomeSettings(
          bpm: bpm,
          timeSignatureNumerator: numerator,
          timeSignatureDenominator: denominator,
        );
  }
}
