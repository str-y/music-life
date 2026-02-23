import 'dart:async';

import 'package:flutter/material.dart';

/// Demo chord sequence used to simulate real-time chord detection.
/// In production this would be driven by the native pitch-detection engine
/// via FFI / platform channels.
const List<String> _demoChords = [
  'Cmaj7',
  'Am7',
  'Fmaj7',
  'G7',
  'Em7',
  'A7',
  'Dm7',
  'G7',
  'Cmaj7',
  'E7',
  'Am7',
  'D7',
];

/// Maximum number of historical chord entries shown in the timeline.
const int _maxHistory = 12;

/// How often (in seconds) the demo advances to the next chord.
const int _demoIntervalSeconds = 2;

class ChordAnalyserScreen extends StatefulWidget {
  const ChordAnalyserScreen({super.key});

  @override
  State<ChordAnalyserScreen> createState() => _ChordAnalyserScreenState();
}

class _ChordAnalyserScreenState extends State<ChordAnalyserScreen> {
  /// The chord currently being "heard".
  String _currentChord = _demoChords.first;

  /// Ordered list of recently detected chords (newest first).
  final List<_ChordEntry> _history = [];

  Timer? _timer;
  int _demoIndex = 0;

  @override
  void initState() {
    super.initState();
    _history.add(_ChordEntry(chord: _currentChord, time: DateTime.now()));
    _startDemoTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startDemoTimer() {
    _timer = Timer.periodic(
      const Duration(seconds: _demoIntervalSeconds),
      (_) {
        _demoIndex = (_demoIndex + 1) % _demoChords.length;
        final next = _demoChords[_demoIndex];
        setState(() {
          _currentChord = next;
          _history.insert(0, _ChordEntry(chord: next, time: DateTime.now()));
          if (_history.length > _maxHistory) {
            _history.removeLast();
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('コード解析'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // ── Current chord ──────────────────────────────────────────
          Expanded(
            flex: 5,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '現在のコード',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      _currentChord,
                      key: ValueKey(_currentChord),
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            fontSize: 80,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'リアルタイム解析中…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Chord history timeline ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: colorScheme.secondary),
                const SizedBox(width: 6),
                Text(
                  'コード進行の履歴',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.secondary,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _history.isEmpty
                ? Center(
                    child: Text(
                      'まだ履歴がありません',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = _history[index];
                      final isLatest = index == 0;
                      return _ChordHistoryTile(
                        entry: entry,
                        isLatest: isLatest,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';

// ── Data model ────────────────────────────────────────────────────────────────

class _ChordEntry {
  const _ChordEntry({required this.chord, required this.time});

  final String chord;
  final DateTime time;
}

// ── Chord history tile ────────────────────────────────────────────────────────

class _ChordHistoryTile extends StatelessWidget {
  const _ChordHistoryTile({
    required this.entry,
    required this.isLatest,
    required this.colorScheme,
  });

  final _ChordEntry entry;
  final bool isLatest;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(entry.time);

    return AnimatedOpacity(
      opacity: isLatest ? 1.0 : 0.65,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isLatest
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isLatest
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.chord,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight:
                          isLatest ? FontWeight.bold : FontWeight.normal,
                      color: isLatest
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
              ),
            ),
            Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isLatest
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
