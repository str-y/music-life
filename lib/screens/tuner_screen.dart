import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../app_constants.dart';
import '../native_pitch_bridge.dart';
import '../providers/tuner_provider.dart';
import '../widgets/listening_indicator.dart';
import '../widgets/mic_permission_gate.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.tunerTitle)),
      body: const MicPermissionGate(child: _TunerBodyWrapper()),
    );
  }
}

// ── Internal body wrapper (handles provider & animation) ─────────────────────

class _TunerBodyWrapper extends ConsumerStatefulWidget {
  const _TunerBodyWrapper();

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
        if (!_pulseCtrl.isAnimating) {
          _pulseCtrl.repeat(reverse: true);
        }
        _scheduleIdleStop();
      }
    });

    final state = ref.watch(tunerProvider);

    if (state.loading) return const Center(child: CircularProgressIndicator());

    if (!state.bridgeActive) {
      return MicPermissionDeniedView(
        onRetry: () => ref.read(tunerProvider.notifier).retry(),
      );
    }

    return RepaintBoundary(
      child: _TunerBody(
        latest: state.latest,
        pulseCtrl: _pulseCtrl,
      ),
    );
  }
}

// ── Tuner body ────────────────────────────────────────────────────────────────

class _TunerBody extends StatelessWidget {
  const _TunerBody({required this.latest, required this.pulseCtrl});

  final PitchResult? latest;
  final AnimationController pulseCtrl;

  /// Maps cents offset (−50 … +50) to a colour between red → green → red.
  Color _centColor(BuildContext context, double cents) {
    final abs = cents.abs();
    if (abs <= AppConstants.tunerInTuneThresholdCents) return Colors.green;
    if (abs <= AppConstants.tunerWarningThresholdCents) return Colors.orange;
    return Theme.of(context).colorScheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final noteName = latest?.noteName ?? '---';
    final freqText = latest != null
        ? '${latest!.frequency.toStringAsFixed(1)} Hz'
        : '-- Hz';
    final cents = latest?.centsOffset ?? 0.0;
    final centsText = latest != null
        ? (cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1))
        : '---';
    final inTune = latest != null && cents.abs() <= AppConstants.tunerInTuneThresholdCents;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Note name ──────────────────────────────────────────────
          Semantics(
            label: l10n.currentNoteSemanticLabel,
            value: latest != null ? '$noteName, $freqText' : null,
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
                      ? (inTune ? Colors.green : cs.primary)
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Frequency ─────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              freqText,
              key: ValueKey(freqText),
              style: tt.titleLarge,
            ),
          ),
          const SizedBox(height: 32),

          // ── Cents meter ───────────────────────────────────────────
          Semantics(
            label: l10n.centsMeterSemanticLabel,
            value: '$centsText cents',
            child: _CentsMeter(cents: cents, hasReading: latest != null),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: l10n.waveformSemanticLabel,
            child: AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, __) => _TunerWaveform(
                hasReading: latest != null,
                cents: cents,
                phase: pulseCtrl.value,
                color: latest != null ? _centColor(context, cents) : cs.primary,
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
                color: latest != null ? _centColor(context, cents) : cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ── Listening indicator ───────────────────────────────────
          if (latest == null) ...[
            ListeningIndicator(controller: pulseCtrl, color: cs.primary),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.playSound,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ] else if (inTune) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.tuningOk,
              style: tt.bodyMedium?.copyWith(color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }
}

class _TunerWaveform extends StatelessWidget {
  const _TunerWaveform({
    required this.hasReading,
    required this.cents,
    required this.phase,
    required this.color,
  });

  final bool hasReading;
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
  static const double _baseAmplitude = 2.0;
  static const double _maxCentsForScale = 50.0;
  static const double _amplitudeScale = 8.0;
  static const double _idleAmplitude = 2.5;
  static const double _waveCycles = 2.5;

  const _TunerWavePainter({
    required this.hasReading,
    required this.cents,
    required this.phase,
    required this.color,
    required this.trackColor,
  });

  final bool hasReading;
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
    final amp = hasReading
        ? (_baseAmplitude +
            (cents.abs().clamp(0.0, _maxCentsForScale) / _maxCentsForScale) *
                _amplitudeScale)
        : _idleAmplitude;
    for (double x = 0; x <= size.width; x += 2) {
      final t = x / size.width;
      final y = centerY + math.sin((t * _waveCycles + phase) * 2 * math.pi) * amp;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, basePaint);
  }

  @override
  bool shouldRepaint(_TunerWavePainter oldDelegate) =>
      oldDelegate.hasReading != hasReading ||
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
                    ? Colors.green
                    : cents.abs() <= AppConstants.tunerWarningThresholdCents
                        ? Colors.orange
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
