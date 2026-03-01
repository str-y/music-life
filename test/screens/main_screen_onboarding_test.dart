import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/main.dart';
import 'package:music_life/providers/dependency_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'golden_test_utils.dart';

const String _onboardingShownKey = 'onboarding_shown_v1';

Future<void> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> initialValues = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MusicLifeApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MainScreen onboarding', () {
    testWidgets('shows onboarding on first launch and stores flag',
        (tester) async {
      await _pumpApp(tester);

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
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
