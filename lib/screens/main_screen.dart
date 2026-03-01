import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_settings_provider.dart';
import '../repositories/backup_repository.dart';
import '../repositories/settings_repository.dart';
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
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
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
              Text(
                l10n.welcomeTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.welcomeSubtitle,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(l10n.tunerTitle),
                  subtitle: Text(l10n.tunerSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/tuner'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(l10n.practiceLogTitle),
                  subtitle: Text(l10n.practiceLogSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/practice-log'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.library_music),
                  title: Text(l10n.libraryTitle),
                  subtitle: Text(l10n.librarySubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/library'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.av_timer),
                  title: Text(l10n.rhythmTitle),
                  subtitle: Text(l10n.rhythmSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/rhythm'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.piano),
                  title: Text(l10n.chordAnalyserTitle),
                  subtitle: Text(l10n.chordAnalyserSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/chord-analyser'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.piano_outlined),
                  title: Text(l10n.compositionHelperTitle),
                  subtitle: Text(l10n.compositionHelperSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/composition-helper'),
                ),
              ),
            ],
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

  const _SettingsModal({
    required this.settings,
    required this.onChanged,
    required this.onExportBackup,
    required this.onImportBackup,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
