import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/chord_analyser_provider.dart';
import 'package:music_life/repositories/chord_history_repository.dart';
import 'package:music_life/utils/chord_utils.dart';
import 'package:music_life/widgets/listening_indicator.dart';
import 'package:music_life/widgets/mic_permission_denied_view.dart';
import 'package:music_life/widgets/mic_permission_gate.dart';
import 'package:music_life/widgets/shared/chord_card.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';

class ChordAnalyserScreen extends StatelessWidget {
  const ChordAnalyserScreen({super.key, this.useMicPermissionGate = true});

  final bool useMicPermissionGate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.chordAnalyserTitle),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: useMicPermissionGate
          ? const MicPermissionGate(child: _ChordAnalyserBody())
          : const _ChordAnalyserBody(),
    );
  }
}

// ── Internal body (shown only after permission is granted) ────────────────────

class _ChordAnalyserBody extends ConsumerStatefulWidget {
  const _ChordAnalyserBody();

  @override
  ConsumerState<_ChordAnalyserBody> createState() => _ChordAnalyserBodyState();
}

/// Holds only the [AnimationController] that requires a [TickerProvider].
/// All other state and lifecycle logic lives in [ChordAnalyserNotifier].
class _ChordAnalyserBodyState extends ConsumerState<_ChordAnalyserBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _listeningCtrl;

  @override
  void initState() {
    super.initState();
    _listeningCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _listeningCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _listeningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dynamicThemeEnergy = ref.watch(
      appSettingsProvider.select(
        (settings) => (settings.dynamicThemeEnergy *
                settings.dynamicThemeIntensity)
            .clamp(0.0, 1.0),
      ),
    );
    final analyserState = ref.watch(chordAnalyserProvider);

    ref
      // Control the listening animation from provider state.
      ..listen<bool>(
        chordAnalyserProvider.select((s) => s.isListeningActive),
        (_, isActive) {
          if (isActive) {
            if (!_listeningCtrl.isAnimating) _listeningCtrl.repeat(reverse: true);
          } else {
            _listeningCtrl.stop();
          }
        },
      )
      // Surface bridge errors as a SnackBar, then clear the error state.
      ..listen<String?>(
        chordAnalyserProvider.select((s) => s.errorMessage),
        (_, errorMessage) {
          if (errorMessage != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.chordAnalyserError),
              ),
            );
            ref.read(chordAnalyserProvider.notifier).clearError();
          }
        },
      );

    if (analyserState.loading) return const LoadingStateWidget();

    // Bridge failed to start (e.g. permission revoked after the gate check).
    if (!analyserState.bridgeReady) {
      return MicPermissionDeniedView(
        onRetry: () => ref.read(chordAnalyserProvider.notifier).restartCapture(),
      );
    }

    final currentChord = analyserState.currentChord;

    return Column(
      children: [
        // ── Current chord ──────────────────────────────────────────
        Expanded(
          flex: 5,
          child: RepaintBoundary(
            child: Center(
              child: Semantics(
                liveRegion: true,
                label: AppLocalizations.of(context)!.currentNoteSemanticLabel,
                value: currentChord == '---' ? null : currentChord,
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
                    AnimatedScale(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      scale: 1.0 +
                          ((currentChord == '---' ? 0.0 : dynamicThemeEnergy) *
                              0.04),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        ),
                        child: Text(
                          currentChord,
                          key: ValueKey(currentChord),
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                                fontSize: 80,
                                shadows: currentChord == '---'
                                    ? null
                                    : [
                                        Shadow(
                                          color: colorScheme.primary.withValues(
                                            alpha:
                                                0.10 + (dynamicThemeEnergy * 0.22),
                                          ),
                                          blurRadius:
                                              10 + (dynamicThemeEnergy * 12),
                                        ),
                                      ],
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10 + (dynamicThemeEnergy * 10),
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.03 + (dynamicThemeEnergy * 0.08),
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListeningIndicator(
                        controller: _listeningCtrl,
                        color: Color.lerp(
                          colorScheme.primary,
                          colorScheme.tertiary,
                          dynamicThemeEnergy,
                        ),
                        semanticLabel: AppLocalizations.of(
                          context,
                        )!.dynamicThemeEnergySemanticLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // ── Chord history timeline ──────────────────────────────────
        Semantics(
          button: true,
          label: AppLocalizations.of(context)!.chordHistory,
          hint: AppLocalizations.of(context)!.filterByChordName,
          child: InkWell(
            onTap: _openFilterSheet,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
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
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Semantics(
            label: AppLocalizations.of(context)!.chordHistory,
            child: RepaintBoundary(
              child: analyserState.history.isEmpty
                  ? StatusMessageView(
                      illustration: StatusMessageIllustration(
                        primaryIcon: Icons.music_note_rounded,
                        accentIcon: Icons.history_rounded,
                        colorScheme: colorScheme,
                      ),
                      message: AppLocalizations.of(context)!.noChordHistory,
                      padding: EdgeInsets.zero,
                      messageStyle: Theme.of(context).textTheme.titleMedium,
                      details: AppLocalizations.of(context)!.chordHistoryEmptyHint,
                      detailsStyle:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                      action: OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(chordAnalyserProvider.notifier).restartCapture(),
                        icon: const Icon(Icons.hearing_rounded),
                        label: Text(
                          AppLocalizations.of(context)!.listenForFirstChord,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: analyserState.history.length,
                      itemBuilder: (context, index) {
                        final entry = analyserState.history[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _ChordHistoryTile(
                            entry: entry,
                            isLatest: index == 0,
                            colorScheme: colorScheme,
                            animation: kAlwaysCompleteAnimation,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openFilterSheet() async {
    final localizations = AppLocalizations.of(context)!;
    final notifier = ref.read(chordAnalyserProvider.notifier);
    final currentState = ref.read(chordAnalyserProvider);
    final chordFilterController =
        TextEditingController(text: currentState.chordNameFilter);
    var pendingDate = currentState.selectedFilterDate;

    try {
      final action = await showModalBottomSheet<_HistoryFilterAction>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final dateLabel =
                  pendingDate == null ? '-' : formatDateYMD(pendingDate!);
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: chordFilterController,
                      decoration: InputDecoration(
                        labelText: localizations.filterByChordName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('${localizations.practiceDate}: $dateLabel'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: pendingDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && context.mounted) {
                              setModalState(() => pendingDate = picked);
                            }
                          },
                          child: Text(localizations.practiceDate),
                        ),
                        TextButton(
                          onPressed: () =>
                              setModalState(() => pendingDate = null),
                          child: Text(localizations.clearDateFilter),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .pop(_HistoryFilterAction.clear),
                          child: Text(localizations.clearFilter),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(localizations.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context)
                              .pop(_HistoryFilterAction.apply),
                          child: Text(localizations.save),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      final appliedText = chordFilterController.text.trim();
      if (!mounted || action == null) return;

      if (action == _HistoryFilterAction.apply) {
        await notifier.applyFilter(date: pendingDate, chordName: appliedText);
        return;
      }

      await notifier.clearFilter();
    } finally {
      chordFilterController.dispose();
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

enum _HistoryFilterAction { apply, clear }

// ── Chord history tile ────────────────────────────────────────────────────────

class _ChordHistoryTile extends StatelessWidget {
  const _ChordHistoryTile({
    required this.entry,
    required this.isLatest,
    required this.colorScheme,
    required this.animation,
  });

  final ChordHistoryEntry entry;
  final bool isLatest;
  final ColorScheme colorScheme;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final timeLabel = formatTimeHMS(entry.time);

    return SizeTransition(
      sizeFactor: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
        child: Semantics(
          label: '${entry.chord}, $timeLabel',
          excludeSemantics: true,
          child: ChordCard(
            highlighted: isLatest,
            opacity: isLatest ? 1.0 : 0.65,
            duration: const Duration(milliseconds: 300),
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
