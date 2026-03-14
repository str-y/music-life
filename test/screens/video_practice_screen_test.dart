import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/app_settings_provider.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/screens/video_practice_screen.dart';
import 'package:music_life/services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockAdService extends Mock implements IAdService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

Future<List<Override>> _settingsOverridesWithPrefs({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return [sharedPreferencesProvider.overrideWithValue(prefs)];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('VideoPracticeScreen – premium paywall', () {
    testWidgets('shows paywall when premium is not active', (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      final adService = _MockAdService();

      await tester.pumpWidget(
        _wrap(
          const VideoPracticeScreen(),
          overrides: [
            ...overrides,
            adServiceProvider.overrideWithValue(adService),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;

      expect(find.text(l10n.videoPracticePremiumTitle), findsOneWidget);
      expect(
        find.text(l10n.videoPracticePremiumDescription(24)),
        findsOneWidget,
      );
      expect(find.text(l10n.watchAdAndUnlock), findsOneWidget);
    });

    testWidgets('watch-ad button calls ad service', (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      final adService = _MockAdService();

      when(
        () => adService.showRewardedAd(
          onUserEarnedReward: any(named: 'onUserEarnedReward'),
        ),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _wrap(
          const VideoPracticeScreen(),
          overrides: [
            ...overrides,
            adServiceProvider.overrideWithValue(adService),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;

      await tester.tap(find.text(l10n.watchAdAndUnlock));
      await tester.pumpAndSettle();

      verify(
        () => adService.showRewardedAd(
          onUserEarnedReward: any(named: 'onUserEarnedReward'),
        ),
      ).called(1);
    });

    testWidgets('snackbar shown when rewarded ad is not ready', (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      final adService = _MockAdService();

      when(
        () => adService.showRewardedAd(
          onUserEarnedReward: any(named: 'onUserEarnedReward'),
        ),
      ).thenAnswer((_) async => false);

      await tester.pumpWidget(
        _wrap(
          const VideoPracticeScreen(),
          overrides: [
            ...overrides,
            adServiceProvider.overrideWithValue(adService),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;

      await tester.tap(find.text(l10n.watchAdAndUnlock));
      await tester.pumpAndSettle();

      expect(find.text(l10n.rewardedAdNotReady), findsOneWidget);
    });

    testWidgets('screen title is correct', (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      final adService = _MockAdService();

      await tester.pumpWidget(
        _wrap(
          const VideoPracticeScreen(),
          overrides: [
            ...overrides,
            adServiceProvider.overrideWithValue(adService),
          ],
        ),
      );
      await tester.pump();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;

      expect(find.text(l10n.videoPracticeTitle), findsOneWidget);
    });
  });

  group('VideoPracticeScreen – localization', () {
    testWidgets('all video practice l10n strings are non-empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(l10n.videoPracticeTitle, isNotEmpty);
              expect(l10n.videoPracticeSubtitle, isNotEmpty);
              expect(l10n.videoPracticeStartRecording, isNotEmpty);
              expect(l10n.videoPracticeStopRecording, isNotEmpty);
              expect(l10n.videoPracticeRecordingSaved, isNotEmpty);
              expect(l10n.videoPracticeRecordingFailed, isNotEmpty);
              expect(l10n.videoPracticePremiumTitle, isNotEmpty);
              expect(l10n.videoPracticePremiumDescription(24), isNotEmpty);
              expect(l10n.videoPracticeCameraPermissionDenied, isNotEmpty);
              expect(l10n.videoPracticeSnsExport, isNotEmpty);
              expect(l10n.videoPracticeSnsExportTitle, isNotEmpty);
              expect(l10n.videoPracticeSnsExportDescription, isNotEmpty);
              expect(l10n.videoPracticeSnsExportRecordFirst, isNotEmpty);
              expect(
                l10n.videoPracticeSnsExportReady('1080×1920', '8 Mbps'),
                isNotEmpty,
              );
              expect(
                l10n.videoPracticeSnsExportShareText('1080×1920', '8 Mbps'),
                isNotEmpty,
              );
              expect(l10n.videoPracticeSnsExportFailed, isNotEmpty);
              expect(l10n.videoPracticeExportSkin, isNotEmpty);
              expect(l10n.videoPracticeExportColor, isNotEmpty);
              expect(l10n.videoPracticeExportEffect, isNotEmpty);
              expect(l10n.videoPracticeExportLogo, isNotEmpty);
              expect(l10n.videoPracticeExportLogoShown, isNotEmpty);
              expect(l10n.videoPracticeExportLogoHidden, isNotEmpty);
              expect(l10n.videoPracticeExportQuality, isNotEmpty);
              expect(l10n.videoPracticeExportSkinAurora, isNotEmpty);
              expect(l10n.videoPracticeExportSkinNeonPulse, isNotEmpty);
              expect(l10n.videoPracticeExportSkinSunsetGold, isNotEmpty);
              expect(l10n.videoPracticeExportEffectGlow, isNotEmpty);
              expect(l10n.videoPracticeExportEffectPrism, isNotEmpty);
              expect(l10n.videoPracticeExportEffectShimmer, isNotEmpty);
              expect(l10n.videoPracticeExportQualitySocial, isNotEmpty);
              expect(l10n.videoPracticeExportQualityHigh, isNotEmpty);
              expect(l10n.videoPracticeExportQualityUltra, isNotEmpty);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
