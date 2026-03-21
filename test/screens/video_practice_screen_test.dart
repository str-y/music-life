import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/screens/video_practice_screen.dart';
import 'package:music_life/services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_test_utils.dart';

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
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [...overrides.whereType<dynamic>()],
    child: buildGoldenTestApp(
      locale: locale,
      themeMode: themeMode,
      home: child,
    ),
  );
}

Future<List<dynamic>> _settingsOverridesWithPrefs({
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
    for (final variant in screenGoldenVariants) {
      testWidgets('matches premium paywall golden (${variant.name})',
          (tester) async {
        await prepareGoldenSurface(tester);
        final overrides = await _settingsOverridesWithPrefs(
          initialValues: {
            AppConfig.defaultUseSystemThemeStorageKey: false,
            AppConfig.defaultDarkModeStorageKey:
                variant.themeMode == ThemeMode.dark,
            AppConfig.defaultLocaleStorageKey: variant.locale.languageCode,
          },
        );
        final adService = _MockAdService();

        await tester.pumpWidget(
          _wrap(
            const VideoPracticeScreen(),
            locale: variant.locale,
            themeMode: variant.themeMode,
            overrides: [
              ...overrides,
              adServiceProvider.overrideWithValue(adService),
            ],
          ),
        );
        await tester.pump();

        await expectScreenGolden(
          find.byType(VideoPracticeScreen),
          variant.goldenPath('video_practice_screen'),
        );
      });
    }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

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
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
    });
  });

  group('PremiumVideoExportPanel', () {
    testWidgets('shows consolidated settings cards and export action',
        (tester) async {
      final overrides = await _settingsOverridesWithPrefs();
      var exportCalls = 0;

      await tester.pumpWidget(
        _wrap(
          PremiumVideoExportPanel(
            recordingPath: '/tmp/sample.mp4',
            onExport: () async {
              exportCalls += 1;
            },
          ),
          overrides: overrides,
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;
      final previewCard = find.byKey(const Key('premium-export-preview-card'));

      expect(
        find.byKey(const Key('premium-export-settings-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('premium-export-appearance-card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('premium-export-output-card')), findsOneWidget);
      expect(previewCard, findsOneWidget);
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportSkinAurora),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportEffectGlow),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportQualityHigh),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('premium-export-confirm-button')));
      await tester.pump();

      expect(exportCalls, 1);
    });

    testWidgets('updates live preview when export settings change',
        (tester) async {
      final overrides = await _settingsOverridesWithPrefs();

      await tester.pumpWidget(
        _wrap(
          const PremiumVideoExportPanel(
            recordingPath: '/tmp/sample.mp4',
            onExport: _noopExport,
          ),
          overrides: overrides,
        ),
      );
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }

      final l10n = AppLocalizations.of(
        tester.element(find.byType(MaterialApp)),
      )!;
      final previewCard = find.byKey(const Key('premium-export-preview-card'));

      await tester.tap(find.text(l10n.videoPracticeExportSkinSunsetGold));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportSkinSunsetGold),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.videoPracticeExportEffectPrism));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportEffectPrism),
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.videoPracticeExportQualityUltra));
      await tester.tap(find.text(l10n.videoPracticeExportQualityUltra));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
      expect(
        find.descendant(of: previewCard, matching: find.text('2160×3840')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: previewCard, matching: find.text('30 Mbps')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text(l10n.videoPracticeExportLogo));
      await tester.tap(find.text(l10n.videoPracticeExportLogo));
      for (var i = 0; i < 50; i++) { await tester.pump(const Duration(milliseconds: 50)); }
      expect(
        find.descendant(
          of: previewCard,
          matching: find.text(l10n.videoPracticeExportLogoHidden),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: previewCard, matching: find.text('music-life')),
        findsNothing,
      );
    });
  });
}

Future<void> _noopExport() async {}
