import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/config/app_config.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/main.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/utils/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'golden_test_utils.dart';

const String _onboardingShownKey = 'onboarding_completed_v2';
Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> initialValues = const <String, Object>{},
  PermissionService testPermissionService = defaultPermissionService,
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        permissionServiceProvider.overrideWithValue(testPermissionService),
      ],
      child: const MusicLifeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MainScreen onboarding', () {
    testWidgets('shows onboarding on first launch and stores flag after finish',
        (tester) async {
      await _pumpApp(tester);

      expect(find.text('Welcome'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_onboardingShownKey), isNull);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      expect(find.text('Enable microphone access'), findsOneWidget);
      expect(prefs.getBool(_onboardingShownKey), isNull);

      await tester.tap(find.byKey(const ValueKey('onboarding-skip-permission')));
      await tester.pumpAndSettle();

      expect(find.text('How to use Music Life'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('onboarding-finish')));
      await tester.pumpAndSettle();

      expect(prefs.getBool(_onboardingShownKey), isTrue);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('does not show onboarding when already shown', (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('permission step requests microphone access and shows success',
        (tester) async {
      final permissionService = _FakePermissionService([PermissionStatus.granted]);
      await _pumpApp(tester, testPermissionService: permissionService);

      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding-request-permission')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Microphone access enabled. You're ready to use tuner and recording features.",
        ),
        findsOneWidget,
      );
      expect(permissionService.requestCount, 1);
    });

    testWidgets('feature tile semantics expose button label and hint',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      final localizations =
          AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
      final semanticsHandle = tester.ensureSemantics();
      addTearDown(semanticsHandle.dispose);

      final featureTile =
          find.widgetWithText(InkWell, localizations.practiceLogTitle);
      expect(featureTile, findsOneWidget);
      expect(
        tester.getSemantics(featureTile),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: localizations.practiceLogTitle,
          hint: localizations.practiceLogSubtitle,
        ),
      );
    });

    testWidgets('language selector updates app locale and persists choice',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-language-selector')),
        findsOneWidget,
      );

      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日本語').last);
      await tester.pumpAndSettle();

      expect(find.text('設定'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.defaultLocaleStorageKey), 'ja');
    });

    testWidgets('settings exposes recent buffered logs', (tester) async {
      addTearDown(AppLogger.clearBufferedLogs);
      AppLogger.clearBufferedLogs();
      AppLogger.info('Settings log entry');

      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Developer Settings'), findsOneWidget);
      expect(find.text('Recent logs'), findsOneWidget);

      await tester.tap(find.text('Recent logs'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Settings log entry'), findsOneWidget);
    });

    testWidgets('dynamic theme controls persist mode and intensity',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-dynamic-theme-mode-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-dynamic-theme-intensity-slider')),
        findsOneWidget,
      );

      await tester.tap(find.text('Chill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intense').last);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('settings-dynamic-theme-intensity-slider')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AppConfig.defaultDynamicThemeModeStorageKey),
        'intense',
      );
      expect(
        prefs.getDouble(AppConfig.defaultDynamicThemeIntensityStorageKey),
        greaterThan(0.7),
      );
    });

    testWidgets('settings shows premium cloud sync upsell when premium is inactive',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Premium cloud sync'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings-cloud-sync-premium-unlock')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('settings-cloud-sync-toggle')), findsNothing);
    });

    testWidgets('settings shows cloud sync controls when premium is active',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: <String, Object>{
          _onboardingShownKey: true,
          AppConfig.defaultRewardedPremiumExpiresAtStorageKey:
              DateTime.utc(2026, 1, 2).toIso8601String(),
        },
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Cloud sync & backup'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-cloud-sync-toggle')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-cloud-sync-now')), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-cloud-restore')), findsOneWidget);
    });

    testWidgets('matches main screen golden baseline', (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{_onboardingShownKey: true},
      );
      await tester.pump(const Duration(milliseconds: 600));

      await expectScreenGolden(
        find.byType(Scaffold).first,
        'goldens/main_screen.png',
      );
    });
  });
}

class _FakePermissionService extends PermissionService {
  _FakePermissionService(this._results);

  final List<PermissionStatus> _results;
  int requestCount = 0;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    final index = requestCount < _results.length
        ? requestCount
        : _results.length - 1;
    requestCount += 1;
    return _results[index];
  }
}
