import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/widgets/shared/async_value_state_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AsyncValueStateView', () {
    testWidgets('shows loading indicator for AsyncLoading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AsyncValueStateView<int>(
            value: AsyncLoading<int>(),
            loadingSemanticsLabel: 'Loading test data',
            errorMessage: 'Error',
            data: _emptyWidget,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading test data'), findsOneWidget);
    });

    testWidgets('shows retry action for AsyncError', (tester) async {
      var retried = false;

      await tester.pumpWidget(
        _wrap(
          AsyncValueStateView<int>(
            value: AsyncError<int>(Exception('boom'), StackTrace.empty),
            errorMessage: 'Could not load data',
            onRetry: () => retried = true,
            data: _emptyWidget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load data'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('renders data content for AsyncData', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AsyncValueStateView<int>(
            value: AsyncData<int>(42),
            errorMessage: 'Error',
            data: _valueText,
          ),
        ),
      );

      expect(find.text('42'), findsOneWidget);
    });
  });
}

Widget _valueText(int value) => Text('$value');

Widget _emptyWidget(int _) => const SizedBox.shrink();
