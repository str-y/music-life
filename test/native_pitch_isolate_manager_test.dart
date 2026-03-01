import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/native_pitch_bridge.dart';

void _successfulIsolate(IsolateSetup setup) {
  final port = ReceivePort();
  setup.resultPort.send(IsolateReady(port.sendPort));
  port.listen((msg) {
    if (msg == null) {
      port.close();
      return;
    }
    if (msg is IsolateHandshakeRequest) {
      setup.resultPort.send(IsolateHandshakeAck(msg.protocolVersion));
    } else if (msg is IsolateHeartbeatPing) {
      setup.resultPort.send(IsolateHeartbeatPong(msg.token));
    } else if (msg == 'emit-data') {
      setup.resultPort.send({
        'noteName': 'A4',
        'frequency': 440.0,
        'centsOffset': 0.0,
        'midiNote': 69,
      });
    }
  });
}

void _missingHandshakeAckIsolate(IsolateSetup setup) {
  final port = ReceivePort();
  setup.resultPort.send(IsolateReady(port.sendPort));
  port.listen((msg) {
    if (msg == null) {
      port.close();
      return;
    }
    if (msg is IsolateHeartbeatPing) {
      setup.resultPort.send(IsolateHeartbeatPong(msg.token));
    }
  });
}

void _startupErrorIsolate(IsolateSetup setup) {
  setup.resultPort.send(const IsolateManagerError(
    phase: 'test-startup',
    message: 'simulated startup failure',
    stack: 'test-stack',
  ));
}

void main() {
  group('NativePitchIsolateManager', () {
    test('completes handshake and forwards messages', () async {
      final messages = <dynamic>[];
      final firstMessage = Completer<void>();
      final manager = NativePitchIsolateManager(
        handle: nullptr,
        buffer: Pointer<Float>.fromAddress(0),
        frameSize: 0,
        entryPoint: _successfulIsolate,
        onMessage: (message) {
          messages.add(message);
          if (!firstMessage.isCompleted) {
            firstMessage.complete();
          }
        },
        onError: (error, _) => fail('unexpected error: $error'),
      );

      final started = await manager.start();
      expect(started, isTrue);

      manager.send('emit-data');
      await firstMessage.future.timeout(const Duration(seconds: 1));
      expect(messages, hasLength(1));
      expect(messages.single, isA<Map<dynamic, dynamic>>());

      final shutdown = manager.prepareForDisposal();
      shutdown.isolate?.kill(priority: Isolate.immediate);
      shutdown.exitPort?.close();
    });

    test('fails start when handshake ack does not arrive', () async {
      Object? reportedError;
      final manager = NativePitchIsolateManager(
        handle: nullptr,
        buffer: Pointer<Float>.fromAddress(0),
        frameSize: 0,
        entryPoint: _missingHandshakeAckIsolate,
        handshakeTimeout: const Duration(milliseconds: 80),
        onMessage: (_) {},
        onError: (error, _) => reportedError = error,
      );

      final started = await manager.start();
      expect(started, isFalse);
      expect(reportedError, isA<TimeoutException>());
      manager.disposeImmediately();
    });

    test('propagates isolate startup errors with phase context', () async {
      Object? reportedError;
      final manager = NativePitchIsolateManager(
        handle: nullptr,
        buffer: Pointer<Float>.fromAddress(0),
        frameSize: 0,
        entryPoint: _startupErrorIsolate,
        onMessage: (_) {},
        onError: (error, _) => reportedError = error,
      );

      final started = await manager.start();
      expect(started, isFalse);
      expect(reportedError, isA<StateError>());
      expect(
        (reportedError as StateError).message,
        contains('[test-startup] simulated startup failure'),
      );
      manager.disposeImmediately();
    });
  });
}
