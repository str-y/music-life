import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/app_localizations.dart';
import '../native_pitch_bridge.dart';
import '../widgets/listening_indicator.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

// ── State ─────────────────────────────────────────────────────────────────────

enum _TunerStatus { loading, permissionDenied, running }

class _TunerScreenState extends State<TunerScreen>
    with SingleTickerProviderStateMixin {
  NativePitchBridge? _bridge;
  StreamSubscription<PitchResult>? _sub;

  _TunerStatus _status = _TunerStatus.loading;
  PitchResult? _latest;

  /// Controller for the "listening" pulse animation shown before a note is
  /// detected, and for animating the cents needle.
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startCapture();
  }

  Future<void> _startCapture() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => _status = _TunerStatus.permissionDenied);
      return;
    }

    final bridge = NativePitchBridge();
    final started = await bridge.startCapture();
    if (!mounted) {
      bridge.dispose();
      return;
    }
    if (!started) {
      bridge.dispose();
      setState(() => _status = _TunerStatus.permissionDenied);
      return;
    }

    _bridge = bridge;
    _sub = bridge.pitchStream.listen((result) {
      if (!mounted) return;
      setState(() => _latest = result);
    });
    setState(() => _status = _TunerStatus.running);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bridge?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.tunerTitle)),
      body: switch (_status) {
        _TunerStatus.loading => const Center(child: CircularProgressIndicator()),
        _TunerStatus.permissionDenied => _PermissionDeniedView(
            onRetry: () async {
              setState(() => _status = _TunerStatus.loading);
              await _startCapture();
            },
          ),
        _TunerStatus.running => _TunerBody(
            latest: _latest,
            pulseCtrl: _pulseCtrl,
          ),
      },
    );
  }
}

// ── Permission denied ─────────────────────────────────────────────────────────

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.micPermissionRequired,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.settings),
              label: Text(l10n.openSettings),
              onPressed: openAppSettings,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
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
    if (abs <= 5) return Colors.green;
    if (abs <= 15) return Colors.orange;
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
    final inTune = latest != null && cents.abs() <= 5;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Note name ──────────────────────────────────────────────
          AnimatedSwitcher(
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
          const SizedBox(height: 8),

          // ── Frequency ─────────────────────────────────────────────
          Text(freqText, style: tt.titleLarge),
          const SizedBox(height: 32),

          // ── Cents meter ───────────────────────────────────────────
          _CentsMeter(cents: cents, hasReading: latest != null),
          const SizedBox(height: 8),
          Text(
            '$centsText cents',
            style: tt.bodyLarge?.copyWith(
              color: latest != null ? _centColor(context, cents) : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
      child: CustomPaint(
        painter: _CentsMeterPainter(
          cents: hasReading ? cents : null,
          trackColor: cs.outlineVariant,
          needleColor: hasReading
              ? (cents.abs() <= 5
                  ? Colors.green
                  : cents.abs() <= 15
                      ? Colors.orange
                      : cs.error)
              : cs.outlineVariant,
          centerColor: cs.primary,
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
      old.cents != cents || old.needleColor != needleColor;
}
