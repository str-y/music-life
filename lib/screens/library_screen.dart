import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'library/log_tab.dart';
import 'library/models.dart';
import 'library/recordings_tab.dart';
import 'library/repository.dart';

export 'library/models.dart';
export 'library/repository.dart';

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
  final _repository = RecordingRepository();

  List<RecordingEntry> _recordings = [];
  List<PracticeLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading recordings and practice logs',
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                RecordingsTab(recordings: _recordings),
                LogTab(logs: _logs),
              ],
            ),
    );
  }
}
