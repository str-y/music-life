import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music_life/app_constants.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/models/premium_video_export.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/tuner_provider.dart';
import 'package:music_life/services/ad_service.dart';
import 'package:music_life/services/premium_video_export_service.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:music_life/utils/tuner_transposition.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';
import 'package:music_life/widgets/shared/waveform_view.dart';
import 'package:share_plus/share_plus.dart';
const Duration _rewardedPremiumDuration = Duration(hours: 24);
const List<double> _exportPreviewWaveform = <double>[
  0.18,
  0.22,
  0.34,
  0.56,
  0.72,
  0.64,
  0.48,
  0.28,
  0.2,
  0.3,
  0.46,
  0.7,
  0.62,
  0.44,
  0.26,
  0.18,
];
const List<int> _exportPresetColors = <int>[
  0xFF7C4DFF,
  0xFF00E5FF,
  0xFFFFB300,
  0xFFFF4081,
];
const double _previewChipBorderRadius = 999;

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
        .read(premiumSettingsControllerProvider)
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
  String? _lastRecordingPath;

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
        setState(() {
          _isRecording = false;
          _lastRecordingPath = file.path;
        });
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
      return const LoadingStateWidget();
    }

    if (_errorMessage != null) {
      return StatusMessageView(
        icon: Icons.videocam_off_outlined,
        iconColor: Theme.of(context).colorScheme.error,
        message: _errorMessage!,
        messageStyle: Theme.of(context).textTheme.bodyLarge,
        action: OutlinedButton.icon(
          onPressed: _initCamera,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const LoadingStateWidget();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        _PitchOverlay(isRecording: _isRecording),
        Positioned(
          top: 88,
          right: 16,
          child: _ExportButton(
            isEnabled: _lastRecordingPath != null && !_isRecording,
            onPressed: _isRecording ? null : _openExportSheet,
          ),
        ),
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

  Future<void> _openExportSheet() async {
    final recordingPath = _lastRecordingPath;
    final l10n = AppLocalizations.of(context)!;
    if (recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoPracticeSnsExportRecordFirst)),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.92,
        child: PremiumVideoExportPanel(
          recordingPath: recordingPath,
          onExport: _exportRecordingForSocial,
        ),
      ),
    );
  }

  Future<void> _exportRecordingForSocial() async {
    final recordingPath = _lastRecordingPath;
    if (recordingPath == null) return;
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(appSettingsProvider).premiumVideoExportSettings;
    final exportService = ref.read(premiumVideoExportServiceProvider);
    try {
      final plan = exportService.buildPlan(
        sourceVideoPath: recordingPath,
        settings: settings,
      );
      final exported = await exportService.createShareReadyCopy(plan);
      if (!mounted) return;
      await Share.shareXFiles(
        [
          XFile(
            exported.path,
            name: exported.uri.pathSegments.isEmpty
                ? null
                : exported.uri.pathSegments.last,
          ),
        ],
        text: l10n.videoPracticeSnsExportShareText(
          plan.resolutionLabel,
          plan.bitrateLabel,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.videoPracticeSnsExportReady(
              plan.resolutionLabel,
              plan.bitrateLabel,
            ),
          ),
        ),
      );
    } catch (e, st) {
      AppLogger.reportError(
        'VideoPracticeScreen: premium SNS export failed',
        error: e,
        stackTrace: st,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoPracticeSnsExportFailed)),
      );
    }
  }
}

// ── Pitch overlay ──────────────────────────────────────────────────────────────

class _PitchOverlay extends ConsumerWidget {
  const _PitchOverlay({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tunerProvider);
    final cs = Theme.of(context).colorScheme;
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
          color: cs.inverseSurface.withValues(alpha: 0.86),
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
              style: TextStyle(
                color: cs.onInverseSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (centsText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '$centsText¢',
                style: TextStyle(
                  color: inTune
                      ? (Color.lerp(cs.primary, cs.tertiary, 0.35) ??
                          cs.primary)
                      : (Color.lerp(cs.secondary, cs.error, 0.4) ??
                          cs.secondary),
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
    final errorColor = Theme.of(context).colorScheme.error;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Opacity(
        opacity: _ctrl.value,
        child: Icon(Icons.circle, color: errorColor, size: 12),
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
    final cs = Theme.of(context).colorScheme;
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
            color: cs.surface,
            border: Border.all(
              color: isRecording ? cs.error : cs.outlineVariant,
              width: 4,
            ),
          ),
          child: Center(
            child: Container(
              width: isRecording ? 28 : 56,
              height: isRecording ? 28 : 56,
              decoration: BoxDecoration(
                color: cs.error,
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

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.isEnabled,
    required this.onPressed,
  });

  final bool isEnabled;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton.icon(
      onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
      icon: const Icon(Icons.auto_awesome),
      label: Text(l10n.videoPracticeSnsExport),
      style: FilledButton.styleFrom(
        backgroundColor: isEnabled
            ? Theme.of(context).colorScheme.primary
            : Colors.black45,
      ),
    );
  }
}

class PremiumVideoExportPanel extends ConsumerWidget {
  const PremiumVideoExportPanel({
    required this.recordingPath,
    required this.onExport,
    super.key,
  });

  final String recordingPath;
  final Future<void> Function() onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider).premiumVideoExportSettings;
    final plan = ref.read(premiumVideoExportServiceProvider).buildPlan(
          sourceVideoPath: recordingPath,
          settings: settings,
        );
    final notifier = ref.read(premiumSettingsControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          key: const Key('premium-export-settings-panel'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.videoPracticeSnsExportTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.videoPracticeSnsExportDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _PremiumExportPreviewCard(
              settings: settings,
              plan: plan,
              l10n: l10n,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _SettingsGroupCard(
                      key: const Key('premium-export-appearance-card'),
                      icon: Icons.palette_outlined,
                      title: l10n.videoPracticeExportSkin,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(l10n.videoPracticeExportSkin),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PremiumVideoExportSkin.values
                                .map(
                                  (skin) => ChoiceChip(
                                    label: Text(_skinLabel(l10n, skin)),
                                    selected: settings.skin == skin,
                                    onSelected: (_) => unawaited(
                                      notifier.updateVideoExportSettings(
                                        skin: skin,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle(l10n.videoPracticeExportColor),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _exportPresetColors
                                .map(
                                  (colorValue) => GestureDetector(
                                    key: Key(
                                      'premium-export-color-${_colorKey(colorValue)}',
                                    ),
                                    onTap: () => unawaited(
                                        notifier.updateVideoExportSettings(
                                          waveformColorValue: colorValue,
                                        ),
                                    ),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Color(colorValue),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: settings.waveformColorValue ==
                                                  colorValue
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onSurface
                                              : Colors.white24,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          _SectionTitle(l10n.videoPracticeExportEffect),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PremiumVideoExportEffect.values
                                .map(
                                  (effect) => ChoiceChip(
                                    label: Text(_effectLabel(l10n, effect)),
                                    selected: settings.effect == effect,
                                    onSelected: (_) => unawaited(
                                      notifier.updateVideoExportSettings(
                                        effect: effect,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SettingsGroupCard(
                      key: const Key('premium-export-output-card'),
                      icon: Icons.high_quality,
                      title: l10n.videoPracticeExportQuality,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile.adaptive(
                            value: settings.showLogo,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.videoPracticeExportLogo),
                            subtitle: Text(
                              settings.showLogo
                                  ? l10n.videoPracticeExportLogoShown
                                  : l10n.videoPracticeExportLogoHidden,
                            ),
                            onChanged: (value) => unawaited(
                              notifier.updateVideoExportSettings(
                                showLogo: value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SectionTitle(l10n.videoPracticeExportQuality),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: PremiumVideoExportQuality.values
                                .map(
                                  (quality) => ChoiceChip(
                                    label: Text(_qualityLabel(l10n, quality)),
                                    selected: settings.quality == quality,
                                    onSelected: (_) => unawaited(
                                      notifier.updateVideoExportSettings(
                                        quality: quality,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.high_quality),
                            title: Text(plan.resolutionLabel),
                            subtitle: Text(
                              l10n.videoPracticeSnsExportReady(
                                plan.resolutionLabel,
                                plan.bitrateLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('premium-export-confirm-button'),
                onPressed: () => unawaited(onExport()),
                icon: const Icon(Icons.ios_share),
                label: Text(l10n.videoPracticeSnsExport),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumExportPreviewCard extends StatelessWidget {
  const _PremiumExportPreviewCard({
    required this.settings,
    required this.plan,
    required this.l10n,
  });

  final PremiumVideoExportSettings settings;
  final PremiumVideoExportPlan plan;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final effectColor = _effectAccentColor(settings);
    return Container(
      key: const Key('premium-export-preview-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: _previewGradient(settings.skin),
        boxShadow: _previewBoxShadow(effectColor, settings.effect),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 8),
              Text(
                plan.resolutionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (settings.showLogo)
                Text(
                  'music-life',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: effectColor.withValues(alpha: 0.55),
                  ),
                ),
                child: WaveformView(
                  data: _exportPreviewWaveform,
                  durationSeconds: 15,
                  isPlaying: false,
                  animate: true,
                  color: settings.waveformColor,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: _effectOverlayGradient(settings.effect),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewChip(label: _skinLabel(l10n, settings.skin)),
              _PreviewChip(label: _effectLabel(l10n, settings.effect)),
              _PreviewChip(label: _qualityLabel(l10n, settings.quality)),
              _PreviewChip(
                label: settings.showLogo
                    ? l10n.videoPracticeExportLogoShown
                    : l10n.videoPracticeExportLogoHidden,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plan.bitrateLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({
    required this.icon,
    required this.title,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(_previewChipBorderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

LinearGradient _previewGradient(PremiumVideoExportSkin skin) {
  return switch (skin) {
    PremiumVideoExportSkin.aurora => const LinearGradient(
        colors: [Color(0xFF1B1E5A), Color(0xFF5E35B1), Color(0xFF00B8D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    PremiumVideoExportSkin.neonPulse => const LinearGradient(
        colors: [Color(0xFF12001D), Color(0xFF6A00F4), Color(0xFFFF4081)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    PremiumVideoExportSkin.sunsetGold => const LinearGradient(
        colors: [Color(0xFF3E2723), Color(0xFFFF8F00), Color(0xFFFFD180)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
  };
}

List<BoxShadow> _previewBoxShadow(
  Color effectColor,
  PremiumVideoExportEffect effect,
) {
  final opacity = switch (effect) {
    PremiumVideoExportEffect.glow => 0.34,
    PremiumVideoExportEffect.prism => 0.28,
    PremiumVideoExportEffect.shimmer => 0.2,
  };

  return [
    BoxShadow(
      color: effectColor.withValues(alpha: opacity),
      blurRadius: 24,
      spreadRadius: 2,
      offset: const Offset(0, 10),
    ),
  ];
}

LinearGradient _effectOverlayGradient(PremiumVideoExportEffect effect) {
  return switch (effect) {
    PremiumVideoExportEffect.glow => const LinearGradient(
        colors: [Color(0x00000000), Color(0x2200E5FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    PremiumVideoExportEffect.prism => const LinearGradient(
        colors: [Color(0x26FF4081), Color(0x00000000), Color(0x2600E5FF)],
      ),
    PremiumVideoExportEffect.shimmer => const LinearGradient(
        colors: [Color(0x00FFFFFF), Color(0x22FFFFFF), Color(0x00FFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
  };
}

Color _effectAccentColor(PremiumVideoExportSettings settings) {
  return switch (settings.effect) {
    PremiumVideoExportEffect.glow => settings.waveformColor,
    PremiumVideoExportEffect.prism =>
      Color.alphaBlend(const Color(0x66FFFFFF), settings.waveformColor),
    PremiumVideoExportEffect.shimmer =>
      Color.alphaBlend(const Color(0x55FFF8E1), settings.waveformColor),
  };
}

String _colorKey(int colorValue) {
  return (colorValue & 0x00FFFFFF).toRadixString(16).padLeft(6, '0');
}

String _skinLabel(AppLocalizations l10n, PremiumVideoExportSkin skin) {
  return switch (skin) {
    PremiumVideoExportSkin.aurora => l10n.videoPracticeExportSkinAurora,
    PremiumVideoExportSkin.neonPulse => l10n.videoPracticeExportSkinNeonPulse,
    PremiumVideoExportSkin.sunsetGold => l10n.videoPracticeExportSkinSunsetGold,
  };
}

String _effectLabel(AppLocalizations l10n, PremiumVideoExportEffect effect) {
  return switch (effect) {
    PremiumVideoExportEffect.glow => l10n.videoPracticeExportEffectGlow,
    PremiumVideoExportEffect.prism => l10n.videoPracticeExportEffectPrism,
    PremiumVideoExportEffect.shimmer => l10n.videoPracticeExportEffectShimmer,
  };
}

String _qualityLabel(AppLocalizations l10n, PremiumVideoExportQuality quality) {
  return switch (quality) {
    PremiumVideoExportQuality.social => l10n.videoPracticeExportQualitySocial,
    PremiumVideoExportQuality.high => l10n.videoPracticeExportQualityHigh,
    PremiumVideoExportQuality.ultra => l10n.videoPracticeExportQualityUltra,
  };
}
