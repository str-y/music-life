import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';

const bool runScreenGoldens = bool.fromEnvironment('RUN_SCREEN_GOLDENS');
const Size screenGoldenSurfaceSize = Size(800, 600);

@immutable
class ScreenGoldenVariant {
  const ScreenGoldenVariant({
    required this.name,
    required this.locale,
    required this.themeMode,
  });

  final String name;
  final Locale locale;
  final ThemeMode themeMode;

  String goldenPath(String baseName) => 'goldens/${baseName}_$name.png';
}

const List<ScreenGoldenVariant> screenGoldenVariants = [
  ScreenGoldenVariant(
    name: 'light_en',
    locale: Locale('en'),
    themeMode: ThemeMode.light,
  ),
  ScreenGoldenVariant(
    name: 'dark_en',
    locale: Locale('en'),
    themeMode: ThemeMode.dark,
  ),
  ScreenGoldenVariant(
    name: 'light_ja',
    locale: Locale('ja'),
    themeMode: ThemeMode.light,
  ),
  ScreenGoldenVariant(
    name: 'dark_ja',
    locale: Locale('ja'),
    themeMode: ThemeMode.dark,
  ),
];

ThemeData buildGoldenTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: brightness,
      contrastLevel: 0.5,
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    useMaterial3: true,
  );
}

Widget buildGoldenTestApp({
  required Widget home,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildGoldenTheme(Brightness.light),
    darkTheme: buildGoldenTheme(Brightness.dark),
    themeMode: themeMode,
    home: home,
  );
}

Future<void> prepareGoldenSurface(
  WidgetTester tester, {
  Size size = screenGoldenSurfaceSize,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> expectScreenGolden(
  Finder finder,
  String goldenPath,
) async {
  if (runScreenGoldens) {
    await expectLater(finder, matchesGoldenFile(goldenPath));
    return;
  }
  expect(finder, findsOneWidget);
}
