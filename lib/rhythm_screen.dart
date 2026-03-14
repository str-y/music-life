import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'metronome_sound_library.dart';
import 'providers/app_settings_provider.dart';
import 'providers/rhythm_provider.dart';
import 'services/ad_service.dart';

const Duration _rewardedPremiumDuration = Duration(hours: 24);

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
  /// Animation controller for the target ring pulse on each beat.
  late final AnimationController _beatPulseCtrl;
  late final Animation<double> _beatPulseAnim;

  /// Animation controller for the user-tap impact ring.
  late final AnimationController _tapRingCtrl;
  late final Animation<double> _tapRingAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _beatPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _beatPulseAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _beatPulseCtrl, curve: Curves.easeOut),
    );

    _tapRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tapRingAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tapRingCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _beatPulseCtrl.dispose();
    _tapRingCtrl.dispose();
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
            child: _buildMetronomeSection(colorScheme, rhythmState),
          ),
          const Divider(height: 1),
          // ── Bottom half: groove analysis target ─────────────────────────
          Expanded(
            child: _buildGrooveSection(colorScheme, rhythmState),
          ),
        ],
      ),
    );
  }

  Widget _buildMetronomeSection(ColorScheme cs, RhythmState rhythmState) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final selectedPack = resolveSelectedMetronomeSoundPack(
      selectedId: settings.selectedMetronomeSoundPackId,
      installedIds: settings.installedMetronomeSoundPackIds,
      hasPremiumAccess: settings.hasRewardedPremiumAccess,
    );
    final recommendedPack = recommendMetronomeSoundPack(rhythmState.bpm);
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // BPM display
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
            child: Text(
              '${rhythmState.bpm}',
              key: ValueKey(rhythmState.bpm),
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.bold,
                color: cs.primary,
                letterSpacing: -4,
              ),
            ),
          ),
          Text(
            l10n.bpmLabel,
            style: const TextStyle(fontSize: 18, letterSpacing: 4),
          ),
          const SizedBox(height: 16),
          // BPM controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BpmButton(
                label: '−10',
                semanticLabel: l10n.bpmDecrease10SemanticLabel,
                onPressed: () =>
                    ref.read(rhythmProvider.notifier).changeBpm(-10),
              ),
              const SizedBox(width: 8),
              _BpmButton(
                label: '−1',
                semanticLabel: l10n.bpmDecrease1SemanticLabel,
                onPressed: () =>
                    ref.read(rhythmProvider.notifier).changeBpm(-1),
              ),
              const SizedBox(width: 24),
              // Play / Stop button
              AnimatedBuilder(
                animation: _beatPulseAnim,
                builder: (context, child) {
                  final scale = rhythmState.isPlaying
                      ? 1.0 + _beatPulseAnim.value * 0.08
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: FloatingActionButton(
                  heroTag: 'playStop',
                  onPressed: ref.read(rhythmProvider.notifier).toggleMetronome,
                  tooltip: rhythmState.isPlaying
                      ? l10n.metronomeStopTooltip
                      : l10n.metronomePlayTooltip,
                  backgroundColor: rhythmState.isPlaying
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  child: Icon(
                    rhythmState.isPlaying ? Icons.stop : Icons.play_arrow,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _BpmButton(
                label: '+1',
                semanticLabel: l10n.bpmIncrease1SemanticLabel,
                onPressed: () =>
                    ref.read(rhythmProvider.notifier).changeBpm(1),
              ),
              const SizedBox(width: 8),
              _BpmButton(
                label: '+10',
                semanticLabel: l10n.bpmIncrease10SemanticLabel,
                onPressed: () =>
                    ref.read(rhythmProvider.notifier).changeBpm(10),
              ),
            ],
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
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                trailing: IconButton(
                  key: const ValueKey('metronome-sound-library-button'),
                  tooltip: l10n.metronomeSoundLibraryManage,
                  onPressed: () => _showSoundLibrarySheet(rhythmState),
                  icon: const Icon(Icons.library_music),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSoundLibrarySheet(RhythmState rhythmState) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final settings = ref.watch(appSettingsProvider);
            final selectedPack = resolveSelectedMetronomeSoundPack(
              selectedId: settings.selectedMetronomeSoundPackId,
              installedIds: settings.installedMetronomeSoundPackIds,
              hasPremiumAccess: settings.hasRewardedPremiumAccess,
            );
            final recommendedPack = recommendMetronomeSoundPack(rhythmState.bpm);
            final sheetHeight = MediaQuery.of(context).size.height * 0.72;
            final bottomPadding = MediaQuery.of(context).padding.bottom;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 20),
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
                          final isInstalled = settings.installedMetronomeSoundPackIds
                              .contains(pack.id);
                          final isSelected =
                              selectedPack.id == pack.id && isInstalled;
                          final isRecommended = recommendedPack.id == pack.id;
                          final isLocked =
                              pack.premiumOnly && !settings.hasRewardedPremiumAccess;

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
                                          label: l10n
                                              .metronomeSoundLibraryRecommendedChip,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                        ),
                                      if (pack.premiumOnly)
                                        _StatusChip(
                                          label: l10n
                                              .metronomeSoundLibraryPremiumChip,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .tertiaryContainer,
                                        ),
                                      if (isInstalled)
                                        _StatusChip(
                                          label: l10n
                                              .metronomeSoundLibraryInstalledChip,
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
                                                    ? l10n
                                                        .metronomeSoundLibraryUse
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
          },
        );
      },
    );
  }

  Future<void> _handleSoundPackAction({
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
      if (!mounted) {
        return;
      }
      if (!rewarded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.rewardedAdNotReady)),
        );
        return;
      }
      await ref
          .read(appSettingsProvider.notifier)
          .unlockRewardedPremiumFor(_rewardedPremiumDuration);
      await ref.read(appSettingsProvider.notifier).installMetronomeSoundPack(
            pack.id,
          );
      await ref.read(appSettingsProvider.notifier).selectMetronomeSoundPack(
            pack.id,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.metronomeSoundLibraryUnlocked(_soundPackName(l10n, pack)),
          ),
        ),
      );
      return;
    }
    if (!isInstalled) {
      await ref.read(appSettingsProvider.notifier).installMetronomeSoundPack(
            pack.id,
          );
    }
    await ref.read(appSettingsProvider.notifier).selectMetronomeSoundPack(
          pack.id,
        );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.metronomeSoundLibraryDownloaded(_soundPackName(l10n, pack)),
        ),
      ),
    );
  }

  Widget _buildGrooveSection(ColorScheme cs, RhythmState rhythmState) {
    final l10n = AppLocalizations.of(context)!;
    final scoreRatio = rhythmState.timingScore / 100.0;
    final offsetLabel = rhythmState.isPlaying
        ? (rhythmState.lastOffsetMs >= 0
            ? '+${rhythmState.lastOffsetMs.toStringAsFixed(0)} ms'
            : '${rhythmState.lastOffsetMs.toStringAsFixed(0)} ms')
        : '---';
    final scoreColor = Color.lerp(cs.error, cs.primary, scoreRatio)!;

    return Semantics(
      label: l10n.grooveTargetSemanticLabel,
      onTapHint: l10n.grooveTargetTapHint,
      child: GestureDetector(
        onTap: ref.read(rhythmProvider.notifier).onGrooveTap,
        child: Container(
          color: cs.surfaceContainerHighest,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.grooveAnalysis,
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 2,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              // Animated target
              Expanded(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_beatPulseAnim, _tapRingAnim]),
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _GrooveTargetPainter(
                          beatPhase: _beatPulseAnim.value,
                          tapPhase: _tapRingAnim.value,
                          offsetMs: rhythmState.lastOffsetMs,
                          beatDurationMs:
                              rhythmState.beatDuration.inMilliseconds.toDouble(),
                          isPlaying: rhythmState.isPlaying,
                          primaryColor: cs.primary,
                          errorColor: cs.error,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),
              // Score readout
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          l10n.timing,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          offsetLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          l10n.score,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          rhythmState.timingScore.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    if (rhythmState.isPlaying)
                      Text(
                        l10n.tapRhythmHint,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── BPM helper button ────────────────────────────────────────────────────────

class _BpmButton extends StatelessWidget {
  const _BpmButton({
    required this.label,
    required this.onPressed,
    required this.semanticLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(50, 36),
        ),
        child: ExcludeSemantics(child: Text(label)),
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

// ── Groove target painter ────────────────────────────────────────────────────

class _GrooveTargetPainter extends CustomPainter {
  const _GrooveTargetPainter({
    required this.beatPhase,
    required this.tapPhase,
    required this.offsetMs,
    required this.beatDurationMs,
    required this.isPlaying,
    required this.primaryColor,
    required this.errorColor,
  });

  final double beatPhase;
  final double tapPhase;
  final double offsetMs;
  final double beatDurationMs;
  final bool isPlaying;
  final Color primaryColor;
  final Color errorColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 8;

    // Draw concentric static rings.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = primaryColor.withValues(alpha: 60 / 255);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 3, ringPaint);
    }

    // Beat pulse: expanding ring that grows from center to edge and fades out.
    if (isPlaying && beatPhase > 0) {
      final pulseRadius = maxRadius * (0.1 + 0.9 * beatPhase);
      final pulsePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = primaryColor.withValues(alpha: (1 - beatPhase) * 220 / 255);
      canvas.drawCircle(center, pulseRadius, pulsePaint);
      // Inner flash fill at the very start of each beat.
      if (beatPhase < 0.25) {
        final flashOpacity = (1 - beatPhase / 0.25) * 40 / 255;
        canvas.drawCircle(
          center,
          maxRadius * 0.3 * (beatPhase / 0.25),
          Paint()
            ..style = PaintingStyle.fill
            ..color = primaryColor.withValues(alpha: flashOpacity),
        );
      }
    }

    // Center dot.
    canvas.drawCircle(
      center,
      8,
      Paint()..color = primaryColor,
    );

    // Tap impact ring: radius encodes timing accuracy.
    if (tapPhase > 0) {
      final maxOffset = beatDurationMs / 2;
      final accuracy = 1 - (offsetMs.abs() / maxOffset).clamp(0.0, 1.0);
      final tapRadius = maxRadius * (1 - accuracy * 0.7);
      final tapColor = Color.lerp(errorColor, primaryColor, accuracy)!;

      final tapPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - tapPhase)
        ..color = tapColor.withValues(alpha: (1 - tapPhase) * 230 / 255);
      canvas.drawCircle(center, tapRadius, tapPaint);
    }
  }

  @override
  bool shouldRepaint(_GrooveTargetPainter old) =>
      old.beatPhase != beatPhase ||
      old.tapPhase != tapPhase ||
      old.offsetMs != offsetMs ||
      old.isPlaying != isPlaying;
}
