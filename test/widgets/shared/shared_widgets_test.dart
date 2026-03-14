import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/widgets/shared/chord_card.dart';
import 'package:music_life/widgets/shared/loading_state_widget.dart';
import 'package:music_life/widgets/shared/status_message_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('LoadingStateWidget forwards semantics label', (tester) async {
    await tester.pumpWidget(
      _wrap(const LoadingStateWidget(semanticsLabel: 'Loading library')),
    );

    final indicator =
        tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));
    expect(indicator.semanticsLabel, 'Loading library');
  });

  testWidgets('StatusMessageView shows icon, message, and action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        StatusMessageView(
          icon: Icons.error_outline,
          message: 'Something went wrong',
          action: ElevatedButton(
            onPressed: () => tapped = true,
            child: const Text('Retry'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('ChordCard uses highlighted theme tokens', (tester) async {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: ChordCard(
            highlighted: true,
            child: Text('Cmaj7'),
          ),
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ChordCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, theme.colorScheme.primaryContainer);
    expect(decoration.border, isNotNull);
  });
}
