import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/widgets/mic_permission_denied_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('MicPermissionDeniedView', () {
    testWidgets('shows mic_off icon', (tester) async {
      await tester.pumpWidget(_wrap(
        MicPermissionDeniedView(onRetry: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('shows permission-required message', (tester) async {
      await tester.pumpWidget(_wrap(
        MicPermissionDeniedView(onRetry: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Microphone permission is required.'), findsOneWidget);
    });

    testWidgets('shows Open Settings button', (tester) async {
      await tester.pumpWidget(_wrap(
        MicPermissionDeniedView(onRetry: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('shows Retry button', (tester) async {
      await tester.pumpWidget(_wrap(
        MicPermissionDeniedView(onRetry: () {}),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onRetry when Retry button is tapped', (tester) async {
      var onRetryCalled = false;
      await tester.pumpWidget(_wrap(
        MicPermissionDeniedView(onRetry: () => onRetryCalled = true),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      expect(onRetryCalled, isTrue);
    });
  });
}
