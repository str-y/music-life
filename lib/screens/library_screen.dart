import 'package:flutter/material.dart';

import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../repositories/recording_repository.dart';
import '../service_locator.dart';
import 'library/log_tab.dart';
import 'library/recordings_tab.dart';

// ---------------------------------------------------------------------------
// LibraryScreen
// ---------------------------------------------------------------------------

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final RecordingRepository _repository;

  List<RecordingEntry> _recordings = [];
  List<PracticeLogEntry> _logs = [];
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _repository = ServiceLocator.instance.recordingRepository;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final recordings = await _repository.loadRecordings();
      final logs = await _repository.loadPracticeLogs();
      if (!mounted) return;
      setState(() {
        _recordings = recordings;
        _logs = logs;
      });
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addRecording(RecordingEntry entry) async {
    final updated = [entry, ..._recordings];
    setState(() => _recordings = updated);
    await _repository.saveRecordings(updated);

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

  Future<void> _showAddDialog() async {
    final result = await showDialog<RecordingEntry>(
      context: context,
      builder: (_) => const _AddRecordingDialog(),
    );
    if (result != null) {
      await _addRecording(result);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                semanticsLabel: AppLocalizations.of(context)!.loadingLibrary,
              ),
            )
          : _hasError
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
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _hasError = false;
                          });
                          _loadData();
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context)!.retry),
                      ),
                    ],
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: [
                RecordingsTab(recordings: _recordings),
                LogTab(logs: _logs),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              tooltip: AppLocalizations.of(context)!.newRecording,
              child: const Icon(Icons.add),
            )
          : null,
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

