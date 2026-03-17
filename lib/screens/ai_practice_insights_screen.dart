import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/app_settings_controllers.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/providers/library_provider.dart';
import 'package:music_life/services/ai_practice_insights_service.dart';
import 'package:music_life/services/ad_service.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';
const Duration _rewardedPremiumDuration = Duration(hours: 24);

class AiPracticeInsightsScreen extends ConsumerStatefulWidget {
  const AiPracticeInsightsScreen({super.key});

  @override
  ConsumerState<AiPracticeInsightsScreen> createState() =>
      _AiPracticeInsightsScreenState();
}

class _AiPracticeInsightsScreenState
    extends ConsumerState<AiPracticeInsightsScreen> {
  Future<AiPracticeInsight>? _analysisFuture;
  String? _analysisSignature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final libraryAsync = ref.watch(libraryProvider);
    final libraryData = libraryAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiPracticeInsightsTitle),
        actions: [
          if (settings.hasRewardedPremiumAccess &&
              !libraryAsync.isLoading &&
              !libraryAsync.hasError &&
              (libraryData?.logs.isNotEmpty == true ||
                  libraryData?.recordings.isNotEmpty == true))
            IconButton(
              tooltip: l10n.retry,
              onPressed: () => setState(() {
                _analysisSignature = null;
                _analysisFuture = null;
              }),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: settings.hasRewardedPremiumAccess
          ? _buildPremiumBody(context, libraryAsync)
          : _PremiumRequiredView(
              onUnlock: () => _unlockWithRewardedAd(context),
            ),
    );
  }

  Widget _buildPremiumBody(
      BuildContext context, AsyncValue<LibraryState> libraryAsync) {
    final l10n = AppLocalizations.of(context)!;

    if (libraryAsync.isLoading) {
      return LoadingStateWidget(semanticsLabel: l10n.loadingLibrary);
    }
    if (libraryAsync.hasError) {
      return StatusMessageView(
        icon: Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        message: l10n.loadDataError,
        action: OutlinedButton.icon(
          onPressed: () => ref.read(libraryProvider.notifier).reload(),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.retry),
        ),
      );
    }
    final libraryState = libraryAsync.asData?.value;
    if (libraryState == null ||
        (libraryState.logs.isEmpty && libraryState.recordings.isEmpty)) {
      return StatusMessageView(
        icon: Icons.insights_outlined,
        message: l10n.aiPracticeInsightsEmpty,
        action: OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.edit_note),
          label: Text(l10n.recordPractice),
        ),
      );
    }

    final signature = _buildSignature(libraryState);
    if (_analysisSignature != signature || _analysisFuture == null) {
      _analysisSignature = signature;
      _analysisFuture = ref.read(aiPracticeInsightsServiceProvider).analyze(
            logs: libraryState.logs,
            recordings: libraryState.recordings,
            localeCode: Localizations.localeOf(context).languageCode,
          );
    }

    return FutureBuilder<AiPracticeInsight>(
      future: _analysisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return LoadingStateWidget(
            semanticsLabel: l10n.aiPracticeInsightsGenerating,
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return StatusMessageView(
            icon: Icons.auto_awesome_outlined,
            message: l10n.loadDataError,
            action: OutlinedButton.icon(
              onPressed: () => setState(() {
                _analysisSignature = null;
                _analysisFuture = null;
              }),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          );
        }
        final insight = snapshot.data!;
        return _InsightListView(insight: insight);
      },
    );
  }

  Future<void> _unlockWithRewardedAd(BuildContext context) async {
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

  String _buildSignature(LibraryState state) {
    final latestLog = state.logs.isEmpty ? '' : state.logs.first.date.toIso8601String();
    final latestRecording = state.recordings.isEmpty
        ? ''
        : state.recordings.first.recordedAt.toIso8601String();
    return '${state.logs.length}|${state.recordings.length}|$latestLog|$latestRecording';
  }
}

class _PremiumRequiredView extends StatelessWidget {
  const _PremiumRequiredView({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 72, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              l10n.aiPracticeInsightsPremiumTitle,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.aiPracticeInsightsPremiumDescription(
                _rewardedPremiumDuration.inHours,
              ),
              style: Theme.of(context).textTheme.bodyLarge,
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

class _InsightListView extends StatelessWidget {
  const _InsightListView({required this.insight});

  final AiPracticeInsight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.providerLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight.headline,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ScoreTimelineCard(
          title: l10n.aiPracticeInsightsPitchStability,
          icon: Icons.graphic_eq,
          points: insight.pitchStabilitySeries,
        ),
        const SizedBox(height: 16),
        _ScoreTimelineCard(
          title: l10n.aiPracticeInsightsRhythmAccuracy,
          icon: Icons.timer_outlined,
          points: insight.rhythmAccuracySeries,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aiPracticeInsightsWeeklyMenu,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...insight.weeklyMenu.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              child: Text('${entry.key + 1}'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(l10n.aiPracticeInsightsNotification),
            subtitle: Text(insight.coachingNotification),
          ),
        ),
      ],
    );
  }
}

class _ScoreTimelineCard extends StatelessWidget {
  const _ScoreTimelineCard({
    required this.title,
    required this.icon,
    required this.points,
  });

  final String title;
  final IconData icon;
  final List<AiPracticeScorePoint> points;

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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: points.map((point) {
                  return Expanded(
                    child: Semantics(
                      label: '${point.label}, ${point.score}%',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: 14,
                                  height: 18 + point.score.toDouble(),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              point.label,
                              style: Theme.of(context).textTheme.labelSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
