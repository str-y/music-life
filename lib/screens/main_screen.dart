import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../providers/dependency_providers.dart';
import '../providers/library_provider.dart';
import '../repositories/settings_repository.dart';
import '../router/routes.dart';
import '../services/ad_service.dart';
import '../services/permission_service.dart';
import '../services/review_service.dart';
import '../services/service_error_handler.dart';
import '../utils/app_logger.dart';
import '../theme/dynamic_theme_mode.dart';
import '../widgets/banner_ad_widget.dart';

const String _privacyPolicyUrl =
    'https://str-y.github.io/music-life/privacy-policy';
const String _onboardingShownKey = 'onboarding_completed_v2';
const Duration _rewardedPremiumDuration = Duration(hours: 24);
const int _dailyGoalMinutes = 30;
const int _onboardingStepCount = 3;
const List<String> _supportedLanguageCodes = <String>['en', 'ja'];
const List<String> _themeColorNoteOptions = <String>[
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

String _dynamicThemeModeLabel(
  AppLocalizations l10n,
  DynamicThemeMode mode,
) {
  return switch (mode) {
    DynamicThemeMode.chill => l10n.dynamicThemeModeChill,
    DynamicThemeMode.intense => l10n.dynamicThemeModeIntense,
    DynamicThemeMode.classical => l10n.dynamicThemeModeClassical,
  };
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final CurvedAnimation _entranceCurve;
  late final CurvedAnimation _entranceFadeCurve;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _entranceCurve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _entranceFadeCurve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pre-load interstitial ad
      ref.read(adServiceProvider).loadInterstitialAd();
      ref.read(adServiceProvider).loadRewardedAd();
      _showOnboardingIfNeeded();
    });
  }

  @override
  void dispose() {
    _entranceCurve.dispose();
    _entranceFadeCurve.dispose();
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _showAdAndPush(String route) {
    // Show interstitial with some probability or frequency logic
    // For now, let's try to show it, the service handles loading state
    ref.read(adServiceProvider).showInterstitialAd();
    context.push(route);
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs.getBool(_onboardingShownKey) == true || !mounted) return;
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _OnboardingDialog(
        permissionService: ref.read(permissionServiceProvider),
      ),
    );
    if (completed == true) {
      await prefs.setBool(_onboardingShownKey, true);
    }
  }

  void _openSettings(BuildContext context, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SettingsModal(
        settings: settings,
        isRewardedPremiumUnlocked: settings.hasRewardedPremiumAccess,
        onChanged: (updated) {
          ref.read(appSettingsProvider.notifier).update(updated);
        },
        onUnlockPremiumWithRewardedAd: () => _unlockPremiumWithRewardedAd(context),
        onExportBackup: () => _exportBackupData(context),
        onImportBackup: () => _importBackupData(context),
        onSetCloudSyncEnabled: (enabled) => _setCloudSyncEnabled(context, enabled),
        onSyncCloudBackupNow: () => _syncCloudBackupNow(context),
        onRestoreCloudBackup: () => _restoreCloudBackup(context),
        onRequestReview: () => _requestStoreReview(context),
      ),
    );
  }

  Future<void> _unlockPremiumWithRewardedAd(BuildContext context) async {
    final rewarded = await ref.read(adServiceProvider).showRewardedAd(
      onUserEarnedReward: (_) {},
    );
    if (!mounted) return;
    if (!rewarded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.rewardedAdNotReady)),
      );
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .unlockRewardedPremiumFor(_rewardedPremiumDuration);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!
              .premiumUnlockSuccess(_rewardedPremiumDuration.inHours),
        ),
      ),
    );
  }

  Future<void> _exportBackupData(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await ref.read(backupRepositoryProvider).exportWithFilePicker();
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupExported(path))),
      );
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to export backup',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to export backup',
        userMessage: l10n.backupExportFailed,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _importBackupData(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await ref.read(backupRepositoryProvider).importWithFilePicker();
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupImported(path))),
      );
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to import backup',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to import backup',
        userMessage: l10n.backupImportFailed,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<DateTime?> _setCloudSyncEnabled(BuildContext context, bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final syncedAt = await ref
          .read(appSettingsProvider.notifier)
          .setCloudSyncEnabled(enabled);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled ? l10n.cloudSyncEnabledMessage : l10n.cloudSyncDisabledMessage,
          ),
        ),
      );
      return syncedAt;
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to update cloud sync preference',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to update cloud sync preference',
        userMessage: l10n.cloudSyncFailed,
        error: e,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  Future<DateTime?> _syncCloudBackupNow(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final syncedAt =
          await ref.read(appSettingsProvider.notifier).syncCloudBackupNow();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cloudSyncCompleted)),
      );
      return syncedAt;
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to sync cloud backup',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to sync cloud backup',
        userMessage: l10n.cloudSyncFailed,
        error: e,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  Future<void> _restoreCloudBackup(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final restored =
          await ref.read(appSettingsProvider.notifier).restoreLatestCloudBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored ? l10n.cloudBackupRestored : l10n.cloudBackupNotFound,
          ),
        ),
      );
      if (restored) {
        ref.invalidate(libraryProvider);
      }
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to restore cloud backup',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to restore cloud backup',
        userMessage: l10n.cloudSyncFailed,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _requestStoreReview(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final shown = await ref
          .read(reviewServiceProvider)
          .requestReviewIfAvailable();
      if (!context.mounted || shown) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewDialogUnavailable)));
    } catch (e, stackTrace) {
      if (!context.mounted) {
        ServiceErrorHandler.report(
          'Failed to request store review',
          error: e,
          stackTrace: stackTrace,
        );
        return;
      }
      ServiceErrorHandler.reportAndNotify(
        context: context,
        message: 'Failed to request store review',
        userMessage: l10n.reviewDialogUnavailable,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final libraryState = ref.watch(libraryProvider);
    final practiceSummary =
        computePracticeSummary(libraryState.valueOrNull?.logs ?? const []);
    final hasDailyGoalAchievement =
        practiceSummary.todayMinutes >= _dailyGoalMinutes;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settingsTooltip,
            onPressed: () => _openSettings(context, settings),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _entranceFadeCurve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(_entranceCurve),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.welcomeTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeSubtitle,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.practiceSummaryTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (hasDailyGoalAchievement)
                            _GoalAchievementBadge(
                              label: l10n.durationMinutes(_dailyGoalMinutes),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _CountUpSummaryMetric(
                            icon: Icons.today,
                            value: practiceSummary.todayMinutes,
                            formatter: l10n.durationMinutes,
                            label: l10n.todayPracticeTime,
                          ),
                          _StreakSummaryMetric(
                            streakDays: practiceSummary.streakDays,
                            formatter: l10n.practiceDayCount,
                            label: l10n.streakDays,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _FeatureTile(
                    icon: Icons.tune,
                    title: l10n.tunerTitle,
                    subtitle: l10n.tunerSubtitle,
                    delay: 0.0,
                    animation: _entranceCurve,
                    onTap: () => _showAdAndPush(const TunerRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.graphic_eq,
                    title: l10n.practiceLogTitle,
                    subtitle: l10n.practiceLogSubtitle,
                    delay: 0.08,
                    animation: _entranceCurve,
                    onTap: () =>
                        _showAdAndPush(const PracticeLogRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.library_music,
                    title: l10n.libraryTitle,
                    subtitle: l10n.librarySubtitle,
                    delay: 0.16,
                    animation: _entranceCurve,
                    onTap: () => _showAdAndPush(const LibraryRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.av_timer,
                    title: l10n.rhythmTitle,
                    subtitle: l10n.rhythmSubtitle,
                    delay: 0.24,
                    animation: _entranceCurve,
                    onTap: () => _showAdAndPush(const RhythmRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.piano,
                    title: l10n.chordAnalyserTitle,
                    subtitle: l10n.chordAnalyserSubtitle,
                    delay: 0.32,
                    animation: _entranceCurve,
                    onTap: () =>
                        _showAdAndPush(const ChordAnalyserRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.piano_outlined,
                    title: l10n.compositionHelperTitle,
                    subtitle: l10n.compositionHelperSubtitle,
                    delay: 0.4,
                    animation: _entranceCurve,
                    onTap: () =>
                        _showAdAndPush(const CompositionHelperRoute().location),
                  ),
                  _FeatureTile(
                    icon: Icons.videocam_outlined,
                    title: l10n.videoPracticeTitle,
                    subtitle: l10n.videoPracticeSubtitle,
                    isPremium: !settings.hasRewardedPremiumAccess,
                    delay: 0.48,
                    animation: _entranceCurve,
                    onTap: () =>
                        _showAdAndPush(const VideoPracticeRoute().location),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog({required this.permissionService});

  final PermissionService permissionService;

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  int _stepIndex = 0;
  bool _isRequestingPermission = false;
  PermissionStatus? _permissionStatus;

  bool get _isPermissionStep => _stepIndex == 1;
  bool get _isLastStep => _stepIndex == _onboardingStepCount - 1;

  void _goToNextStep() {
    if (_stepIndex >= _onboardingStepCount - 1) return;
    setState(() => _stepIndex += 1);
  }

  void _goToPreviousStep() {
    if (_stepIndex == 0) return;
    setState(() => _stepIndex -= 1);
  }

  Future<void> _requestMicrophonePermission() async {
    setState(() => _isRequestingPermission = true);
    final status = await widget.permissionService.requestMicrophonePermission();
    if (!mounted) return;
    setState(() {
      _isRequestingPermission = false;
      _permissionStatus = status;
    });
  }

  String? _buildPermissionStatusMessage(AppLocalizations l10n) {
    final status = _permissionStatus;
    if (status == null) return null;
    if (status.isGranted) {
      return l10n.onboardingMicrophoneGranted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return l10n.micPermissionDenied;
    }
    return l10n.onboardingMicrophoneDeferred;
  }

  String _dialogTitle(AppLocalizations l10n) {
    return switch (_stepIndex) {
      0 => l10n.welcomeTitle,
      1 => l10n.onboardingMicrophoneTitle,
      _ => l10n.onboardingHowToUseTitle,
    };
  }

  Widget _buildStepContent(BuildContext context, AppLocalizations l10n) {
    return switch (_stepIndex) {
      0 => _OnboardingWelcomeStep(l10n: l10n),
      1 => _OnboardingPermissionStep(
        l10n: l10n,
        isRequestingPermission: _isRequestingPermission,
        permissionStatusMessage: _buildPermissionStatusMessage(l10n),
        permissionStatus: _permissionStatus,
      ),
      _ => _OnboardingHowToUseStep(l10n: l10n),
    };
  }

  List<Widget> _buildActions(BuildContext context, AppLocalizations l10n) {
    final actions = <Widget>[
      if (_stepIndex > 0)
        TextButton(
          key: const ValueKey('onboarding-back'),
          onPressed: _goToPreviousStep,
          child: Text(l10n.onboardingBack),
        ),
    ];
    if (_isPermissionStep) {
      actions.add(
        TextButton(
          key: const ValueKey('onboarding-skip-permission'),
          onPressed: _goToNextStep,
          child: Text(l10n.onboardingSkipPermission),
        ),
      );
      if (_permissionStatus?.isPermanentlyDenied == true) {
        actions.add(
          FilledButton.tonal(
            key: const ValueKey('onboarding-open-settings'),
            onPressed: openAppSettings,
            child: Text(l10n.openSettings),
          ),
        );
      } else {
        actions.add(
          FilledButton(
            key: const ValueKey('onboarding-request-permission'),
            onPressed: _isRequestingPermission
                ? null
                : (_permissionStatus?.isGranted == true
                    ? _goToNextStep
                    : _requestMicrophonePermission),
            child: _isRequestingPermission
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _permissionStatus?.isGranted == true
                        ? l10n.onboardingContinue
                        : l10n.onboardingAllowMicrophone,
                  ),
          ),
        );
      }
      return actions;
    }
    if (_isLastStep) {
      actions.add(
        FilledButton(
          key: const ValueKey('onboarding-finish'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.onboardingFinish),
        ),
      );
      return actions;
    }
    actions.add(
      FilledButton(
        key: const ValueKey('onboarding-next'),
        onPressed: _goToNextStep,
        child: Text(l10n.onboardingGetStarted),
      ),
    );
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(_dialogTitle(l10n)),
        content: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            key: ValueKey<int>(_stepIndex),
            width: 360,
            child: SingleChildScrollView(
              child: _buildStepContent(context, l10n),
            ),
          ),
        ),
        actions: _buildActions(context, l10n),
      ),
    );
  }
}

class _OnboardingWelcomeStep extends StatelessWidget {
  const _OnboardingWelcomeStep({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.welcomeSubtitle),
        const SizedBox(height: 12),
        Text(l10n.onboardingWelcomeDescription),
        const SizedBox(height: 16),
        _OnboardingInfoCard(
          icon: Icons.tune,
          title: l10n.tunerTitle,
          subtitle: l10n.tunerSubtitle,
        ),
        const SizedBox(height: 8),
        _OnboardingInfoCard(
          icon: Icons.piano,
          title: l10n.chordAnalyserTitle,
          subtitle: l10n.chordAnalyserSubtitle,
        ),
        const SizedBox(height: 8),
        _OnboardingInfoCard(
          icon: Icons.graphic_eq,
          title: l10n.practiceLogTitle,
          subtitle: l10n.practiceLogSubtitle,
        ),
      ],
    );
  }
}

class _OnboardingPermissionStep extends StatelessWidget {
  const _OnboardingPermissionStep({
    required this.l10n,
    required this.isRequestingPermission,
    required this.permissionStatusMessage,
    required this.permissionStatus,
  });

  final AppLocalizations l10n;
  final bool isRequestingPermission;
  final String? permissionStatusMessage;
  final PermissionStatus? permissionStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.onboardingMicrophoneReason),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(l10n.tunerTitle),
            ),
            Chip(
              avatar: const Icon(Icons.piano, size: 18),
              label: Text(l10n.chordAnalyserTitle),
            ),
            Chip(
              avatar: const Icon(Icons.mic, size: 18),
              label: Text(l10n.libraryTitle),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          permissionStatusMessage ?? l10n.onboardingMicrophonePrompt,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (isRequestingPermission) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (permissionStatus?.isPermanentlyDenied == true) ...[
          const SizedBox(height: 12),
          Text(
            l10n.onboardingMicrophoneSettingsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _OnboardingHowToUseStep extends StatelessWidget {
  const _OnboardingHowToUseStep({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.onboardingHowToUseBody),
        const SizedBox(height: 12),
        Text('• ${l10n.practiceLogTitle}: ${l10n.practiceLogSubtitle}'),
        Text('• ${l10n.libraryTitle}: ${l10n.librarySubtitle}'),
        Text('• ${l10n.rhythmTitle}: ${l10n.rhythmSubtitle}'),
        const SizedBox(height: 12),
        Text(
          l10n.onboardingSettingsHint,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _OnboardingInfoCard extends StatelessWidget {
  const _OnboardingInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatefulWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.animation,
    required this.delay,
    this.isPremium = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Animation<double> animation;
  final double delay;
  final bool isPremium;

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
}

class _CountUpSummaryMetric extends StatelessWidget {
  const _CountUpSummaryMetric({
    required this.icon,
    required this.value,
    required this.formatter,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String Function(int) formatter;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cs.primary),
        const SizedBox(height: 4),
        _CountUpMetricText(
          key: ValueKey<String>('summary-metric-$label'),
          value: value,
          formatter: formatter,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StreakSummaryMetric extends StatelessWidget {
  const _StreakSummaryMetric({
    required this.streakDays,
    required this.formatter,
    required this.label,
  });

  final int streakDays;
  final String Function(int) formatter;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final celebrationGlowColor =
        Color.lerp(cs.tertiary, cs.primary, 0.3) ?? cs.tertiary;
    final celebrationSparkColor =
        Color.lerp(cs.tertiary, cs.secondary, 0.4) ?? cs.secondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: streakDays == 0 ? 0 : 1),
          duration: const Duration(milliseconds: 850),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final glowSize = 24 + value * 12;
            final sparkOpacity = 0.18 + (1 - value) * 0.35;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (streakDays > 0)
                  Container(
                    width: glowSize,
                    height: glowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          celebrationGlowColor.withValues(
                            alpha: 0.2 + value * 0.18,
                          ),
                          celebrationGlowColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                if (streakDays > 0)
                  _CelebrationDot(
                    offset: Offset(-10 - value * 8, -8 - value * 10),
                    color: celebrationSparkColor,
                    opacity: sparkOpacity,
                    size: 5,
                  ),
                if (streakDays > 0)
                  _CelebrationDot(
                    offset: Offset(10 + value * 6, -10 - value * 12),
                    color: cs.secondary,
                    opacity: sparkOpacity * 0.85,
                    size: 4,
                  ),
                Transform.scale(
                  scale: 1 + value * 0.08,
                  child: Icon(
                    Icons.local_fire_department,
                    key: const ValueKey<String>('summary-streak-flame'),
                    color: streakDays > 0
                        ? Color.lerp(cs.primary, cs.tertiary, 0.45)
                        : cs.outline,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        _CountUpMetricText(
          key: const ValueKey<String>('summary-streak-value'),
          value: streakDays,
          formatter: formatter,
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CountUpMetricText extends StatelessWidget {
  const _CountUpMetricText({
    super.key,
    required this.value,
    required this.formatter,
  });

  final int value;
  final String Function(int) formatter;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          formatter(animatedValue.round()),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        );
      },
    );
  }
}

class _GoalAchievementBadge extends StatelessWidget {
  const _GoalAchievementBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final celebrationAccent =
        Color.lerp(cs.tertiary, cs.secondary, 0.35) ?? cs.tertiary;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      child: Chip(
        key: const ValueKey<String>('daily-goal-badge'),
        visualDensity: VisualDensity.compact,
        avatar: Icon(
          Icons.workspace_premium,
          size: 18,
          color: cs.onPrimaryContainer,
        ),
        backgroundColor: cs.primaryContainer,
        side: BorderSide(color: cs.primary.withOpacity(0.12)),
        label: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onPrimaryContainer,
              ),
        ),
      ),
      builder: (context, value, child) {
        final confettiOpacity = 0.12 + (1 - value) * 0.45;
        return SizedBox(
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerRight,
            children: [
              _CelebrationDot(
                offset: Offset(-14 - value * 16, -14 - value * 6),
                color: cs.secondary,
                opacity: confettiOpacity,
                size: 6,
              ),
              _CelebrationDot(
                offset: Offset(-2 - value * 12, -22 - value * 8),
                color: cs.tertiary,
                opacity: confettiOpacity * 0.9,
                size: 5,
              ),
              _CelebrationDot(
                offset: Offset(12 + value * 10, -12 - value * 10),
                color: celebrationAccent,
                opacity: confettiOpacity * 0.8,
                size: 4,
              ),
              Transform.scale(
                scale: 0.92 + value * 0.08,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CelebrationDot extends StatelessWidget {
  const _CelebrationDot({
    required this.offset,
    required this.color,
    required this.opacity,
    required this.size,
  });

  final Offset offset;
  final Color color;
  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size / 2),
          ),
        ),
      ),
    );
  }
}

class _FeatureTileState extends State<_FeatureTile> {
  static const double _maxAnimationDelayFraction = 0.9;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = widget.delay.clamp(0.0, _maxAnimationDelayFraction);
    final interval = CurvedAnimation(
      parent: widget.animation,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: interval,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(interval),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Card(
            elevation: _hovered ? 3 : 1,
            child: Semantics(
              button: true,
              label: widget.title,
              hint: widget.subtitle,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(widget.icon, color: cs.primary),
                          if (widget.isPremium) ...[
                            const Spacer(),
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsModal extends StatefulWidget {
  final AppSettings settings;
  final bool isRewardedPremiumUnlocked;
  final ValueChanged<AppSettings> onChanged;
  final Future<void> Function() onUnlockPremiumWithRewardedAd;
  final Future<void> Function() onExportBackup;
  final Future<void> Function() onImportBackup;
  final Future<DateTime?> Function(bool enabled) onSetCloudSyncEnabled;
  final Future<DateTime?> Function() onSyncCloudBackupNow;
  final Future<void> Function() onRestoreCloudBackup;
  final Future<void> Function() onRequestReview;

  const _SettingsModal({
    required this.settings,
    required this.isRewardedPremiumUnlocked,
    required this.onChanged,
    required this.onUnlockPremiumWithRewardedAd,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onSetCloudSyncEnabled,
    required this.onSyncCloudBackupNow,
    required this.onRestoreCloudBackup,
    required this.onRequestReview,
  });

  @override
  State<_SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<_SettingsModal> {
  late AppSettings _local;

  @override
  void initState() {
    super.initState();
    _local = widget.settings;
  }

  void _emit(AppSettings updated) {
    setState(() => _local = updated);
    widget.onChanged(updated);
  }

  Future<void> _showRecentLogs(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final recentLogs = AppLogger.recentBufferedLogs(limit: 50);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.recentLogs),
        content: SizedBox(
          width: double.maxFinite,
          child: recentLogs.isEmpty
              ? Text(l10n.noRecentLogs)
              : SingleChildScrollView(
                  child: SelectableText(recentLogs.join('\n\n')),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(l10n.settingsTitle, style: textTheme.titleLarge),
            const SizedBox(height: 24),
            Text(l10n.languageSection, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('settings-language-selector'),
              value: _local.localeCode ?? '',
              decoration: InputDecoration(
                labelText: l10n.languageLabel,
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(l10n.systemDefaultLanguage),
                ),
                ..._supportedLanguageCodes.map(
                  (languageCode) => DropdownMenuItem<String>(
                    value: languageCode,
                    child: Text(
                      switch (languageCode) {
                        'ja' => l10n.languageJapanese,
                        _ => l10n.languageEnglish,
                      },
                    ),
                  ),
                ),
              ],
              onChanged: (value) => _emit(
                value == null || value.isEmpty
                    ? _local.copyWith(clearLocaleCode: true)
                    : _local.copyWith(localeCode: value),
              ),
            ),
            const Divider(height: 32),
            Text(l10n.themeSection, style: textTheme.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.followSystemTheme),
              value: _local.useSystemTheme,
              onChanged: (v) => _emit(_local.copyWith(useSystemTheme: v)),
            ),
            if (!_local.useSystemTheme)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.darkMode),
                value: _local.darkMode,
                onChanged: (v) => _emit(_local.copyWith(darkMode: v)),
              ),
            DropdownButtonFormField<DynamicThemeMode>(
              key: const ValueKey('settings-dynamic-theme-mode-selector'),
              value: _local.dynamicThemeMode,
              decoration: InputDecoration(
                labelText: l10n.dynamicThemeModeLabel,
              ),
              items: DynamicThemeMode.values
                  .map(
                    (mode) => DropdownMenuItem<DynamicThemeMode>(
                      value: mode,
                      child: Text(_dynamicThemeModeLabel(l10n, mode)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  _emit(_local.copyWith(dynamicThemeMode: value));
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.dynamicThemeIntensityLabel),
                const SizedBox(width: 8),
                Text(
                  '${(_local.dynamicThemeIntensity * 100).round()}%',
                  style:
                      textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              key: const ValueKey('settings-dynamic-theme-intensity-slider'),
              min: 0,
              max: 1,
              divisions: 10,
              label: '${(_local.dynamicThemeIntensity * 100).round()}%',
              value: _local.dynamicThemeIntensity,
              onChanged: (v) => _emit(_local.copyWith(dynamicThemeIntensity: v)),
            ),
            const SizedBox(height: 4),
            if (widget.isRewardedPremiumUnlocked)
              DropdownButtonFormField<String>(
                value: _local.themeColorNote ?? '',
                decoration: InputDecoration(
                  labelText: l10n.themeColorLabel,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: '',
                    child: Text(l10n.themeColorAuto),
                  ),
                  ..._themeColorNoteOptions.map(
                    (note) => DropdownMenuItem<String>(
                      value: note,
                      child: Text(note),
                    ),
                  ),
                ],
                onChanged: (value) => _emit(
                  value == null || value.isEmpty
                      ? _local.copyWith(clearThemeColorNote: true)
                      : _local.copyWith(themeColorNote: value),
                ),
              )
            else ...[
              Text(
                l10n.premiumCustomizationTitle,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.premiumCustomizationDescription(
                  _rewardedPremiumDuration.inHours,
                ),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: widget.onUnlockPremiumWithRewardedAd,
                icon: const Icon(Icons.ondemand_video),
                label: Text(l10n.watchAdAndUnlock),
              ),
            ],
            const Divider(height: 32),
            Text(l10n.calibration, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.referencePitchLabel),
                const SizedBox(width: 8),
                Text(
                  '${_local.referencePitch.round()} Hz',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              min: 430,
              max: 450,
              divisions: 20,
              label: '${_local.referencePitch.round()} Hz',
              value: _local.referencePitch,
              onChanged: (v) => _emit(_local.copyWith(referencePitch: v)),
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            Text(l10n.backupAndRestore, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            if (widget.isRewardedPremiumUnlocked) ...[
              SwitchListTile(
                key: const ValueKey('settings-cloud-sync-toggle'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.cloudSyncTitle),
                subtitle: Text(
                  _local.lastCloudSyncAt == null
                      ? l10n.cloudSyncNeverSynced
                      : l10n.cloudSyncLastSynced(
                          MaterialLocalizations.of(context).formatMediumDate(
                            _local.lastCloudSyncAt!.toLocal(),
                          ),
                        ),
                ),
                value: _local.cloudSyncEnabled,
                onChanged: (value) async {
                  setState(() {
                    _local = value
                        ? _local.copyWith(cloudSyncEnabled: true)
                        : _local.copyWith(
                            cloudSyncEnabled: false,
                            clearLastCloudSyncAt: true,
                          );
                  });
                  final syncedAt = await widget.onSetCloudSyncEnabled(value);
                  if (!mounted) return;
                  setState(() {
                    _local = value
                        ? _local.copyWith(lastCloudSyncAt: syncedAt)
                        : _local.copyWith(clearLastCloudSyncAt: true);
                  });
                },
              ),
              ListTile(
                key: const ValueKey('settings-cloud-sync-now'),
                contentPadding: EdgeInsets.zero,
                enabled: _local.cloudSyncEnabled,
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(l10n.cloudSyncNow),
                subtitle: Text(l10n.cloudSyncDescription),
                onTap: _local.cloudSyncEnabled
                    ? () async {
                        final syncedAt = await widget.onSyncCloudBackupNow();
                        if (syncedAt == null || !mounted) return;
                        setState(() {
                          _local = _local.copyWith(
                            lastCloudSyncAt: syncedAt,
                          );
                        });
                      }
                    : null,
              ),
              ListTile(
                key: const ValueKey('settings-cloud-restore'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(l10n.cloudRestoreLatest),
                subtitle: Text(l10n.cloudRestoreDescription),
                onTap: widget.onRestoreCloudBackup,
              ),
            ] else ...[
              Text(l10n.cloudSyncPremiumTitle, style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                l10n.cloudSyncPremiumDescription(_rewardedPremiumDuration.inHours),
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const ValueKey('settings-cloud-sync-premium-unlock'),
                onPressed: widget.onUnlockPremiumWithRewardedAd,
                icon: const Icon(Icons.cloud_sync_outlined),
                label: Text(l10n.watchAdAndUnlock),
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.exportBackup),
              onTap: widget.onExportBackup,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l10n.importBackup),
              onTap: widget.onImportBackup,
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            Text(l10n.developerSettings, style: textTheme.titleSmall),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.recentLogs),
              onTap: () => _showRecentLogs(context),
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              trailing: const Icon(Icons.open_in_new),
              onTap: () async {
                final uri = Uri.parse(_privacyPolicyUrl);
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.privacyPolicyOpenError)),
                    );
                  }
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_rate_outlined),
              title: Text(l10n.rateThisApp),
              onTap: widget.onRequestReview,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
