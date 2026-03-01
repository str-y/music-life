import 'package:flutter_test/flutter_test.dart';

const bool runScreenGoldens = bool.fromEnvironment('RUN_SCREEN_GOLDENS');

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
