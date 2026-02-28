import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../app_constants.dart';
import '../native_pitch_bridge.dart';
import '../service_locator.dart';
import '../utils/chord_utils.dart';
import '../widgets/listening_indicator.dart';
import '../widgets/mic_permission_gate.dart';


class ChordAnalyserScreen extends StatelessWidget {
  const ChordAnalyserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chordAnalyserTitle),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: const MicPermissionGate(child: _ChordAnalyserBody()),
    );
  }
}

// ── Internal body (shown only after permission is granted) ────────────────────

class _ChordAnalyserBody extends StatefulWidget {
  const _ChordAnalyserBody();

  @override
  State<_ChordAnalyserBody> createState() => _ChordAnalyserBodyState();
}

class _ChordAnalyserBodyState extends State<_ChordAnalyserBody>
    with SingleTickerProviderStateMixin {
  NativePitchBridge? _bridge;
  StreamSubscription<String>? _subscription;
  bool _loading = true;

  /// The chord currently being detected.
  String _currentChord = '---';

  /// Ordered list of recently detected chords (newest first).
  final List<_ChordEntry> _history = [];

  /// Key for the animated history list.
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  /// Controller for the pulsing "listening" indicator.
  late final AnimationController _listeningCtrl;

  /// Timer used to stop [_listeningCtrl] after [AppConstants.listeningIdleTimeout] of no audio input.
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _listeningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startCapture();
    _scheduleIdleStop();
  }

  Future<void> _startCapture() async {
    setState(() => _loading = true);

    final bridge = ServiceLocator.instance.pitchBridgeFactory();
    final started = await bridge.startCapture();
    if (!mounted) {
      bridge.dispose();
      return;
    }
    if (!started) {
      // Permission may have been revoked after MicPermissionGate confirmed it.
      bridge.dispose();
      setState(() => _loading = false); // _bridge stays null → shows denied UI
      return;
    }

    _bridge = bridge;
    _subscription = bridge.chordStream.listen((chord) {
      if (!mounted) return;
      if (!_listeningCtrl.isAnimating) {
        _listeningCtrl.repeat(reverse: true);
      }
      _scheduleIdleStop();
      setState(() => _currentChord = chord);
      _history.insert(0, _ChordEntry(chord: chord, time: DateTime.now()));
      _listKey.currentState?.insertItem(
        0,
        duration: const Duration(milliseconds: 300),
      );
      if (_history.length > AppConstants.chordHistoryMaxEntries) {
        final removed = _history.removeLast();
        _listKey.currentState?.removeItem(
          AppConstants.chordHistoryMaxEntries,
          (context, animation) => _ChordHistoryTile(
            entry: removed,
            isLatest: false,
            colorScheme: Theme.of(context).colorScheme,
            animation: animation,
          ),
          duration: Duration.zero,
        );
      }
    });
    setState(() => _loading = false);
  }

  /// Schedules [_listeningCtrl] to stop after [AppConstants.listeningIdleTimeout] of no audio activity.
  void _scheduleIdleStop() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConstants.listeningIdleTimeout, () {
      if (mounted) _listeningCtrl.stop();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _subscription?.cancel();
    _bridge?.dispose();
    _listeningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    // Bridge failed to start (e.g. permission revoked after the gate check).
    if (_bridge == null) {
      return MicPermissionDeniedView(
        onRetry: () => _startCapture(),
      );
    }

    return Column(
      children: [
        // ── Current chord ──────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.currentChord,
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
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          fontSize: 80,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                ListeningIndicator(controller: _listeningCtrl),
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
                AppLocalizations.of(context)!.chordHistory,
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
                    AppLocalizations.of(context)!.noChordHistory,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : AnimatedList(
                  key: _listKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  initialItemCount: _history.length,
                  itemBuilder: (context, index, animation) {
                    final entry = _history[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ChordHistoryTile(
                        entry: entry,
                        isLatest: index == 0,
                        colorScheme: colorScheme,
                        animation: animation,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// ── Data model ────────────────────────────────────────────────────────────────

class _ChordEntry {
  const _ChordEntry({
    required this.chord,
    required this.time,
  });

  final String chord;
  final DateTime time;
}

// ── Chord history tile ────────────────────────────────────────────────────────

class _ChordHistoryTile extends StatelessWidget {
  const _ChordHistoryTile({
    required this.entry,
    required this.isLatest,
    required this.colorScheme,
    required this.animation,
  });

  final _ChordEntry entry;
  final bool isLatest;
  final ColorScheme colorScheme;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final timeLabel = formatTimeHMS(entry.time);

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: AnimatedOpacity(
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
        ),
      ),
    );
  }
}
