import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/app_constants.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/tuner_provider.dart';
import 'package:music_life/utils/tuner_transposition.dart';
import 'package:music_life/widgets/listening_indicator.dart';
import 'package:music_life/widgets/mic_permission_denied_view.dart';
import 'package:music_life/widgets/mic_permission_gate.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
Color _tunerInTuneColor(ColorScheme colorScheme) => colorScheme.tertiary;
Color _tunerWarningColor(ColorScheme colorScheme) => colorScheme.secondary;

class TunerScreen extends StatelessWidget {
  const TunerScreen({
    super.key,
    this.useMicPermissionGate = true,
    this.showTranspositionControl = true,
  });

  final bool useMicPermissionGate;
  final bool showTranspositionControl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.tunerTitle)),
      body: useMicPermissionGate
          ? MicPermissionGate(
              child: _TunerBodyWrapper(
                showTranspositionControl: showTranspositionControl,
              ),
            )
          : _TunerBodyWrapper(showTranspositionControl: showTranspositionControl),
    );
  }
}

// ── Internal body wrapper (handles provider & animation) ─────────────────────

class _TunerBodyWrapper extends ConsumerStatefulWidget {
  const _TunerBodyWrapper({required this.showTranspositionControl});

  final bool showTranspositionControl;

  @override
  ConsumerState<_TunerBodyWrapper> createState() => _TunerBodyWrapperState();
}

class _TunerBodyWrapperState extends ConsumerState<_TunerBodyWrapper>
    with SingleTickerProviderStateMixin {
  /// Controller for the "listening" pulse animation shown before a note is
  /// detected, and for animating the cents needle.
  late final AnimationController _pulseCtrl;

  /// Timer used to stop [_pulseCtrl] after [AppConstants.listeningIdleTimeout] of no audio input.
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scheduleIdleStop();
  }

  /// Schedules [_pulseCtrl] to stop after [AppConstants.listeningIdleTimeout] of no audio activity.
  void _scheduleIdleStop() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConstants.listeningIdleTimeout, () {
      if (mounted) _pulseCtrl.stop();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TunerState>(tunerProvider, (prev, next) {
      if (next.latest != null && next.latest != prev?.latest) {
        ref
            .read(dynamicThemeControllerProvider)
            .updateFromPitch(next.latest!);
        if (!_pulseCtrl.isAnimating) {
          _pulseCtrl.repeat(reverse: true);
        }
        _scheduleIdleStop();
      }
    });

    final state = ref.watch(tunerProvider);
    final transposition = ref.watch(
      appSettingsProvider.select((settings) => settings.tunerTransposition),
    );
    final dynamicThemeEnergy = ref.watch(
      appSettingsProvider.select(
        (settings) => (settings.dynamicThemeEnergy *
                settings.dynamicThemeIntensity)
            .clamp(0.0, 1.0)
            ,
      ),
    );

    if (state.loading) return const LoadingStateWidget();

    if (!state.bridgeActive) {
      return MicPermissionDeniedView(
        onRetry: () => ref.read(tunerProvider.notifier).retry(),
      );
    }

    return RepaintBoundary(
      child: _TunerBody(
        latest: state.latest,
        spectrumBins: state.spectrumBins,
        pulseCtrl: _pulseCtrl,
        transposition: transposition,
        dynamicThemeEnergy: dynamicThemeEnergy,
        showTranspositionControl: widget.showTranspositionControl,
        onTranspositionChanged: (value) {
          final currentSettings = ref.read(appSettingsProvider);
          ref.read(appSettingsControllerProvider).update(
                currentSettings.copyWith(tunerTransposition: value),
              );
        },
      ),
    );
  }
}

// ── Tuner body ────────────────────────────────────────────────────────────────

class _TunerBody extends StatelessWidget {
  const _TunerBody({
    required this.latest,
    required this.spectrumBins,
    required this.pulseCtrl,
    required this.transposition,
    required this.dynamicThemeEnergy,
    required this.showTranspositionControl,
    required this.onTranspositionChanged,
  });

  final PitchResult? latest;
  final List<double> spectrumBins;
  final AnimationController pulseCtrl;
  final String transposition;
  final double dynamicThemeEnergy;
  final bool showTranspositionControl;
  final ValueChanged<String> onTranspositionChanged;

  /// Maps cents offset (−50 … +50) to a colour between red → green → red.
  Color _centColor(BuildContext context, double cents) {
    final cs = Theme.of(context).colorScheme;
    final abs = cents.abs();
    if (abs <= AppConstants.tunerInTuneThresholdCents) return _tunerInTuneColor(cs);
    if (abs <= AppConstants.tunerWarningThresholdCents) return _tunerWarningColor(cs);
    return cs.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final inTuneColor = _tunerInTuneColor(cs);

    final noteName = latest != null
        ? transposedNoteNameFromMidi(
            midiNote: latest!.midiNote,
            transposition: transposition,
          )
        : '---';
    final freqText = latest != null
        ? '${latest!.frequency.toStringAsFixed(1)} Hz'
        : '-- Hz';
    final cents = latest?.centsOffset ?? 0.0;
    final centsText = latest != null
        ? (cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1))
        : '---';
    final inTune = latest != null && cents.abs() <= AppConstants.tunerInTuneThresholdCents;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideLayout = constraints.maxWidth >= 900;
        final leftPaneChildren = <Widget>[
          if (showTranspositionControl) ...[
            DropdownButtonFormField<String>(
              initialValue: transposition,
              decoration:
                  InputDecoration(labelText: l10n.tunerTranspositionLabel),
              items: TunerTransposition.supported
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onTranspositionChanged(value);
              },
            ),
            const SizedBox(height: 24),
          ],
          Semantics(
            label: l10n.currentNoteSemanticLabel,
            value: latest != null ? '$noteName, $freqText' : null,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              scale: latest == null ? 1.0 : 1.0 + (dynamicThemeEnergy * 0.035),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Text(
                  noteName,
                  key: ValueKey(noteName),
                  style: tt.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: latest != null
                        ? (inTune ? inTuneColor : cs.primary)
                        : cs.onSurfaceVariant,
                    shadows: latest == null
                        ? null
                        : [
                            Shadow(
                              color: cs.primary.withValues(
                                alpha: 0.12 + (dynamicThemeEnergy * 0.18),
                              ),
                              blurRadius: 10 + (dynamicThemeEnergy * 10),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            scale: latest == null ? 1.0 : 1.0 + (dynamicThemeEnergy * 0.02),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                freqText,
                key: ValueKey(freqText),
                style: tt.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ];
        final rightPaneChildren = <Widget>[
          Semantics(
            label: l10n.centsMeterSemanticLabel,
            value: '$centsText cents',
            child: _CentsMeter(cents: cents, hasReading: latest != null),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: 10 + (dynamicThemeEnergy * 8),
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: latest == null
                  ? Colors.transparent
                  : cs.primaryContainer.withValues(
                      alpha: 0.04 + (dynamicThemeEnergy * 0.08),
                    ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Semantics(
              label: l10n.waveformSemanticLabel,
              child: AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, _) => _TunerWaveform(
                  hasReading: latest != null,
                  spectrumBins: spectrumBins,
                  cents: cents,
                  phase: pulseCtrl.value,
                  color: latest != null ? _centColor(context, cents) : cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              '$centsText cents',
              key: ValueKey(centsText),
              style: tt.bodyLarge?.copyWith(
                color:
                    latest != null ? _centColor(context, cents) : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ];
        final statusChildren = <Widget>[
          if (latest == null) ...[
            ListeningIndicator(
              controller: pulseCtrl,
              color: cs.primary,
              semanticLabel: l10n.dynamicThemeEnergySemanticLabel,
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.playSound,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else if (inTune) ...[
            Icon(Icons.check_circle, color: inTuneColor, size: 32),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.tuningOk,
              style: tt.bodyMedium?.copyWith(color: inTuneColor),
            ),
          ],
        ];

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWideLayout ? 1200 : 560),
              child: isWideLayout
                  ? Row(
                      key: const ValueKey('tuner-wide-layout'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ...leftPaneChildren,
                              ...statusChildren,
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: rightPaneChildren,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('tuner-compact-layout'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...leftPaneChildren,
                        ...rightPaneChildren,
                        const SizedBox(height: 32),
                        ...statusChildren,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _TunerWaveform extends StatelessWidget {
  const _TunerWaveform({
    required this.hasReading,
    required this.spectrumBins,
    required this.cents,
    required this.phase,
    required this.color,
  });

  final bool hasReading;
  final List<double> spectrumBins;
  final double cents;
  final double phase;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TunerWavePainter(
            hasReading: hasReading,
            spectrumBins: spectrumBins,
            cents: cents,
            phase: phase,
            color: color,
            trackColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _TunerWavePainter extends CustomPainter {

  const _TunerWavePainter({
    required this.hasReading,
    required this.spectrumBins,
    required this.cents,
    required this.phase,
    required this.color,
    required this.trackColor,
  });
  static const double _baseAmplitude = 2;
  static const double _maxCentsForScale = 50;
  static const double _amplitudeScale = 8;
  static const double _idleAmplitude = 2.5;
  static const double _waveCycles = 2.5;
  static const double _baseSpectrumScale = 0.65;
  static const double _spectrumScaleRange = 0.35;

  final bool hasReading;
  final List<double> spectrumBins;
  final double cents;
  final double phase;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = hasReading ? color : trackColor;
    final path = Path();
    if (spectrumBins.isNotEmpty) {
      final availableHeight = (size.height / 2) - 2;
      final amplitudeScale = _baseSpectrumScale +
          ((cents.abs().clamp(0.0, _maxCentsForScale) / _maxCentsForScale) *
              _spectrumScaleRange)
              ;
      final hasSingleBin = spectrumBins.length == 1;
      final step = hasSingleBin ? 0.0 : size.width / (spectrumBins.length - 1);
      for (var i = 0; i < spectrumBins.length; i++) {
        final x = hasSingleBin ? size.width / 2 : i * step;
        final magnitude = spectrumBins[i].clamp(0.0, 1.0);
        final y = centerY - (magnitude * availableHeight * amplitudeScale);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      final amp = hasReading
          ? (_baseAmplitude +
              (cents.abs().clamp(0.0, _maxCentsForScale) / _maxCentsForScale) *
                  _amplitudeScale)
          : _idleAmplitude;
      for (double x = 0; x <= size.width; x += 2) {
        final t = x / size.width;
        final y =
            centerY + math.sin((t * _waveCycles + phase) * 2 * math.pi) * amp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }
    canvas.drawPath(path, basePaint);
  }

  @override
  bool shouldRepaint(_TunerWavePainter oldDelegate) =>
      oldDelegate.hasReading != hasReading ||
      oldDelegate.spectrumBins != spectrumBins ||
      oldDelegate.cents != cents ||
      oldDelegate.phase != phase ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}

// ── Cents meter ───────────────────────────────────────────────────────────────

class _CentsMeter extends StatelessWidget {
  const _CentsMeter({required this.cents, required this.hasReading});

  final double cents;
  final bool hasReading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inTuneColor = _tunerInTuneColor(cs);
    final warningColor = _tunerWarningColor(cs);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _CentsMeterPainter(
            cents: hasReading ? cents : null,
            trackColor: cs.outlineVariant,
            needleColor: hasReading
                ? (cents.abs() <= AppConstants.tunerInTuneThresholdCents
                    ? inTuneColor
                    : cents.abs() <= AppConstants.tunerWarningThresholdCents
                        ? warningColor
                        : cs.error)
                : cs.outlineVariant,
            centerColor: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _CentsMeterPainter extends CustomPainter {
  const _CentsMeterPainter({
    required this.cents,
    required this.trackColor,
    required this.needleColor,
    required this.centerColor,
  });

  final double? cents;
  final Color trackColor;
  final Color needleColor;
  final Color centerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final radius = math.min(cx, cy) * 1.6;
    const sweepDeg = 100.0; // ±50 cents mapped to ±50°
    const startDeg = 180 + (180 - sweepDeg) / 2; // starts at bottom-left arc

    // Draw arc track
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(
      rect,
      _toRad(startDeg),
      _toRad(sweepDeg),
      false,
      trackPaint,
    );

    // Draw tick marks at −50, −25, 0, +25, +50
    for (final t in [-50.0, -25.0, 0.0, 25.0, 50.0]) {
      final angle = _toRad(startDeg + (t + 50) / 100 * sweepDeg);
      final isCenter = t == 0;
      final inner = radius - (isCenter ? 10 : 6);
      final outer = radius + 2.0;
      canvas.drawLine(
        Offset(cx + inner * math.cos(angle), cy + inner * math.sin(angle)),
        Offset(cx + outer * math.cos(angle), cy + outer * math.sin(angle)),
        Paint()
          ..color = isCenter ? centerColor : trackColor
          ..strokeWidth = isCenter ? 2.5 : 1.5,
      );
    }

    // Draw needle
    if (cents != null) {
      final clamped = cents!.clamp(-50.0, 50.0);
      final angle = _toRad(startDeg + (clamped + 50) / 100 * sweepDeg);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + (radius - 4) * math.cos(angle),
            cy + (radius - 4) * math.sin(angle)),
        Paint()
          ..color = needleColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      // Needle pivot dot
      canvas.drawCircle(
        Offset(cx, cy),
        5,
        Paint()..color = needleColor,
      );
    }
  }

  static double _toRad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(_CentsMeterPainter old) =>
      old.cents != cents ||
      old.needleColor != needleColor ||
      old.trackColor != trackColor ||
      old.centerColor != centerColor;
}
