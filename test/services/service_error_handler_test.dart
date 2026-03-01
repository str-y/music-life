import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/services/service_error_handler.dart';
import 'package:music_life/utils/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clearBufferedLogs();
  });

  tearDown(() {
    AppLogger.clearBufferedLogs();
  });

  test('report logs errors through AppLogger', () {
    ServiceErrorHandler.report(
      'test log message',
      error: StateError('boom'),
      stackTrace: StackTrace.current,
    );

    expect(AppLogger.bufferedLogs, isNotEmpty);
    expect(AppLogger.bufferedLogs.last, contains('test log message'));
    expect(AppLogger.bufferedLogs.last, contains('StateError'));
  });

  testWidgets('showErrorSnackBar displays message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ServiceErrorHandler.showErrorSnackBar(
                context: context,
                message: 'Something went wrong',
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
  });
}
