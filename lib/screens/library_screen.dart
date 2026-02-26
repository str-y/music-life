import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/library_provider.dart';
import '../repositories/recording_repository.dart';
import 'library/log_tab.dart';
import 'library/recordings_tab.dart';

// ---------------------------------------------------------------------------
// LibraryScreen
// ---------------------------------------------------------------------------

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showAddDialog() async {
    final result = await showDialog<RecordingEntry>(
      context: context,
      builder: (_) => const _AddRecordingDialog(),
    );
    if (result != null && mounted) {
      await ref.read(libraryProvider.notifier).addRecording(result);
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.recordingSavedSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.libraryTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.mic), text: AppLocalizations.of(context)!.recordingsTab),
            Tab(icon: const Icon(Icons.calendar_month), text: AppLocalizations.of(context)!.logsTab),
          ],
        ),
      ),
      body: state.loading
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
              ),
            )
          : state.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.loadDataError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(libraryProvider.notifier).reload(),
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: [
                RecordingsTab(recordings: state.recordings),
                LogTab(logs: state.logs),
              ],
            ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0 || state.loading || state.hasError) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () => _showAddDialog(),
            tooltip: AppLocalizations.of(context)!.newRecording,
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add recording dialog
// ---------------------------------------------------------------------------

class _AddRecordingDialog extends StatefulWidget {
  const _AddRecordingDialog();

  @override
  State<_AddRecordingDialog> createState() => _AddRecordingDialogState();
}

class _AddRecordingDialogState extends State<_AddRecordingDialog> {
  final _titleCtrl = TextEditingController();
  int _durationSeconds = 60;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  List<double> _generateWaveform() {
    final random = math.Random();
    return List.generate(40, (_) => 0.1 + random.nextDouble() * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.newRecording),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.recordingTitleLabel,
                hintText: l10n.recordingTitleHint,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.recordingDurationLabel(_durationSeconds),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Slider(
              min: 5,
              max: 300,
              divisions: 59,
              label: '${_durationSeconds}s',
              value: _durationSeconds.toDouble(),
              onChanged: (v) => setState(() => _durationSeconds = v.round()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleCtrl.text.trim().isEmpty
                ? l10n.newRecording
                : _titleCtrl.text.trim();
            Navigator.of(context).pop(
              RecordingEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                recordedAt: DateTime.now(),
                durationSeconds: _durationSeconds,
                waveformData: _generateWaveform(),
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
