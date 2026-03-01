import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../repositories/backup_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/ad_service.dart';
import '../services/review_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../utils/app_logger.dart';

const String _privacyPolicyUrl =
    'https://str-y.github.io/music-life/privacy-policy';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  final BackupRepository _backupRepository = const BackupRepository();

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    // Pre-load interstitial ad
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adServiceProvider).loadInterstitialAd();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  void _showAdAndPush(String route) {
    // Show interstitial with some probability or frequency logic
    // For now, let's try to show it, the service handles loading state
    ref.read(adServiceProvider).showInterstitialAd();
    context.push(route);
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
        onChanged: (updated) {
          ref.read(appSettingsProvider.notifier).update(updated);
        },
        onExportBackup: () => _exportBackupData(context),
        onImportBackup: () => _importBackupData(context),
        onRequestReview: () => _requestStoreReview(context),
      ),
    );
  }

  Future<void> _exportBackupData(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await _backupRepository.exportWithFilePicker();
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupExported(path))),
      );
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to export backup',
        error: e,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupExportFailed)),
      );
    }
  }

  Future<void> _importBackupData(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await _backupRepository.importWithFilePicker();
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupImported(path))),
      );
    } catch (e, stackTrace) {
      AppLogger.reportError(
        'Failed to import backup',
        error: e,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupImportFailed)),
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
      AppLogger.reportError(
        'Failed to request store review',
        error: e,
        stackTrace: stackTrace,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.reviewDialogUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final entranceCurve = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
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
        opacity: CurvedAnimation(
          parent: _entranceCtrl,
          curve: Curves.easeOut,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(entranceCurve),
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
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/tuner'),
                  ),
                  _FeatureTile(
                    icon: Icons.graphic_eq,
                    title: l10n.practiceLogTitle,
                    subtitle: l10n.practiceLogSubtitle,
                    delay: 0.08,
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/practice-log'),
                  ),
                  _FeatureTile(
                    icon: Icons.library_music,
                    title: l10n.libraryTitle,
                    subtitle: l10n.librarySubtitle,
                    delay: 0.16,
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/library'),
                  ),
                  _FeatureTile(
                    icon: Icons.av_timer,
                    title: l10n.rhythmTitle,
                    subtitle: l10n.rhythmSubtitle,
                    delay: 0.24,
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/rhythm'),
                  ),
                  _FeatureTile(
                    icon: Icons.piano,
                    title: l10n.chordAnalyserTitle,
                    subtitle: l10n.chordAnalyserSubtitle,
                    delay: 0.32,
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/chord-analyser'),
                  ),
                  _FeatureTile(
                    icon: Icons.piano_outlined,
                    title: l10n.compositionHelperTitle,
                    subtitle: l10n.compositionHelperSubtitle,
                    delay: 0.4,
                    animation: entranceCurve,
                    onTap: () => _showAdAndPush('/composition-helper'),
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

class _FeatureTile extends StatefulWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.animation,
    required this.delay,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Animation<double> animation;
  final double delay;

  @override
  State<_FeatureTile> createState() => _FeatureTileState();
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
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(widget.icon, color: cs.primary),
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
    );
  }
}

class _SettingsModal extends StatefulWidget {
  final AppSettings settings;
  final ValueChanged<AppSettings> onChanged;
  final Future<void> Function() onExportBackup;
  final Future<void> Function() onImportBackup;
  final Future<void> Function() onRequestReview;

  const _SettingsModal({
    required this.settings,
    required this.onChanged,
    required this.onExportBackup,
    required this.onImportBackup,
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
          Text(l10n.themeSection, style: textTheme.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.darkMode),
            value: _local.darkMode,
            onChanged: (v) => _emit(_local.copyWith(darkMode: v)),
          ),
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
    );
  }
}
