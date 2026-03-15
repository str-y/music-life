import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:music_life/main.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:music_life/services/ad_service.dart';
import 'package:music_life/screens/library_screen.dart';
import 'package:music_life/screens/main_screen.dart';
import 'package:music_life/screens/practice_log_screen.dart';
import 'package:music_life/router/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdService implements IAdService {
  @override
  String get bannerAdUnitId => 'test-banner';

  @override
  String get interstitialAdUnitId => 'test-interstitial';

  @override
  String get rewardedAdUnitId => 'test-rewarded';

  @override
  void loadInterstitialAd() {}

  @override
  void loadRewardedAd() {}

  @override
  void showInterstitialAd() {}

  @override
  Future<bool> showRewardedAd({
    required void Function(RewardItem reward) onUserEarnedReward,
  }) async {
    return false;
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  String? initialLocation,
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(_FakeAdService()),
      ],
      child: MusicLifeApp(initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('App router', () {
    testWidgets('default route opens main screen', (tester) async {
      await _pumpApp(tester);

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('deep link /recordings opens the recording view',
        (tester) async {
      await _pumpApp(
        tester,
        initialLocation: const RecordingsRoute().location,
      );

      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('deep link /practice-log opens the practice log view',
        (tester) async {
      await _pumpApp(
        tester,
        initialLocation: const PracticeLogRoute().location,
      );

      expect(find.byType(PracticeLogScreen), findsOneWidget);
    });

    testWidgets('practice log feature tile pushes the typed practice log route',
        (tester) async {
      await _pumpApp(
        tester,
        initialValues: const <String, Object>{'onboarding_completed_v2': true},
      );

      await tester.tap(find.text('Practice Log'));
      await tester.pumpAndSettle();

      expect(find.byType(PracticeLogScreen), findsOneWidget);
    });

    testWidgets('library logs CTA pushes the typed practice log route',
        (tester) async {
      await _pumpApp(
        tester,
        initialLocation: const LibraryLogsRoute().location,
      );

      await tester.tap(find.text('Record Practice'));
      await tester.pumpAndSettle();

      expect(find.byType(PracticeLogScreen), findsOneWidget);
    });
  });
}
