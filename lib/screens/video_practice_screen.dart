import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/tuner_provider.dart';
import '../services/ad_service.dart';
import '../utils/app_logger.dart';
import '../utils/tuner_transposition.dart';

const Duration _rewardedPremiumDuration = Duration(hours: 24);

/// Screen that lets premium users record a video of their performance while
/// real-time pitch detection is overlaid on the camera preview.
///
/// Users who have not yet unlocked premium via a rewarded ad are shown a
/// paywall prompting them to watch an ad.
class VideoPracticeScreen extends ConsumerWidget {
  const VideoPracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.videoPracticeTitle)),
      body: settings.hasRewardedPremiumAccess
          ? const _CameraView()
          : _PremiumRequiredView(
              onUnlock: () => _unlockWithRewardedAd(context, ref),
            ),
    );
  }

  Future<void> _unlockWithRewardedAd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final rewarded = await ref.read(adServiceProvider).showRewardedAd(
      onUserEarnedReward: (_) {},
    );
    if (!context.mounted) return;
    if (!rewarded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.rewardedAdNotReady)),
      );
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .unlockRewardedPremiumFor(_rewardedPremiumDuration);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.premiumUnlockSuccess(_rewardedPremiumDuration.inHours),
        ),
      ),
    );
  }
}

// ── Premium paywall ────────────────────────────────────────────────────────────

class _PremiumRequiredView extends StatelessWidget {
  const _PremiumRequiredView({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_outlined, size: 72, color: cs.primary),
            const SizedBox(height: 24),
            Text(
              l10n.videoPracticePremiumTitle,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.videoPracticePremiumDescription(
                _rewardedPremiumDuration.inHours,
              ),
              style: tt.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.ondemand_video),
              label: Text(l10n.watchAdAndUnlock),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Camera view ────────────────────────────────────────────────────────────────

class _CameraView extends ConsumerStatefulWidget {
  const _CameraView();

  @override
  ConsumerState<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<_CameraView> {
  CameraController? _controller;
  bool _isInitializing = true;
  String? _errorMessage;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = AppLocalizations.of(context)!
              .videoPracticeCameraPermissionDenied;
        });
        return;
      }
      controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e, st) {
      unawaited(controller?.dispose());
      AppLogger.reportError(
        'VideoPracticeScreen: failed to initialize camera',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage =
            AppLocalizations.of(context)!.videoPracticeCameraPermissionDenied;
      });
    }
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (_isRecording) {
        final file = await controller.stopVideoRecording();
        if (!mounted) return;
        setState(() => _isRecording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.videoPracticeRecordingSaved}: ${file.name}',
            ),
          ),
        );
      } else {
        await controller.startVideoRecording();
        if (!mounted) return;
        setState(() => _isRecording = true);
      }
    } catch (e, st) {
      AppLogger.reportError(
        'VideoPracticeScreen: video recording toggle failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.videoPracticeRecordingFailed,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        _PitchOverlay(isRecording: _isRecording),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: _RecordButton(
              isRecording: _isRecording,
              onPressed: _toggleRecording,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pitch overlay ──────────────────────────────────────────────────────────────

class _PitchOverlay extends ConsumerWidget {
  const _PitchOverlay({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final transposition = ref.watch(
      appSettingsProvider.select((s) => s.tunerTransposition),
    );

    final latest = state.latest;
    final noteName = latest != null
        ? transposedNoteNameFromMidi(
            midiNote: latest.midiNote,
            transposition: transposition,
          )
        : '---';
    final cents = latest?.centsOffset ?? 0.0;
    final centsText = latest != null
        ? (cents >= 0 ? '+${cents.toStringAsFixed(1)}' : cents.toStringAsFixed(1))
        : '';
    final inTune = latest != null &&
        cents.abs() <= AppConstants.tunerInTuneThresholdCents;

    return Positioned(
      top: 24,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRecording) ...[
              const _RecordingDot(),
              const SizedBox(width: 8),
            ],
            Text(
              noteName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (centsText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '$centsText¢',
                style: TextStyle(
                  color: inTune ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Recording dot indicator ────────────────────────────────────────────────────

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: _ctrl.value,
        child: const Icon(Icons.circle, color: Colors.red, size: 12),
      ),
    );
  }
}

// ── Record / stop button ───────────────────────────────────────────────────────

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.isRecording,
    required this.onPressed,
  });

  final bool isRecording;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: isRecording
          ? l10n.videoPracticeStopRecording
          : l10n.videoPracticeStartRecording,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: isRecording ? Colors.red : Colors.white54,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              width: isRecording ? 28 : 56,
              height: isRecording ? 28 : 56,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: isRecording
                    ? BorderRadius.circular(6)
                    : BorderRadius.circular(28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
