import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/l10n/app_localizations.dart';
import 'package:music_life/services/permission_service.dart';
import 'package:music_life/widgets/mic_permission_gate.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakePermissionService extends PermissionService {
  _FakePermissionService(this._requestResults);

  final List<PermissionStatus> _requestResults;
  int requestCount = 0;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    final index = requestCount < _requestResults.length
        ? requestCount
        : _requestResults.length - 1;
    requestCount++;
    return _requestResults[index];
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('MicPermissionGate', () {
    testWidgets('shows loading while requesting permission', (tester) async {
      final completer = Completer<PermissionStatus>();
      final permissionService = _CompleterPermissionService(completer);

      await tester.pumpWidget(
        _wrap(
          MicPermissionGate(
            permissionService: permissionService,
            child: const Text('granted child'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(find.text('granted child'), findsOneWidget);
    });

    testWidgets('shows denied view when permission is denied', (tester) async {
      final permissionService = _FakePermissionService([PermissionStatus.denied]);
      await tester.pumpWidget(
        _wrap(
          MicPermissionGate(
            permissionService: permissionService,
            child: const Text('granted child'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Microphone permission is required.'), findsOneWidget);
    });

    testWidgets('retries permission request from denied state', (tester) async {
      final permissionService = _FakePermissionService([
        PermissionStatus.denied,
        PermissionStatus.granted,
      ]);
      await tester.pumpWidget(
        _wrap(
          MicPermissionGate(
            permissionService: permissionService,
            child: const Text('granted child'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Microphone permission is required.'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('granted child'), findsOneWidget);
      expect(permissionService.requestCount, 2);
    });
  });
}

class _CompleterPermissionService extends PermissionService {
  _CompleterPermissionService(this.completer);

  final Completer<PermissionStatus> completer;

  @override
  Future<PermissionStatus> requestMicrophonePermission() => completer.future;
}
