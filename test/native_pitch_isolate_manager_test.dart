import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/native_pitch_bridge.dart';
import 'package:music_life/pigeon/native_pitch_messages.dart';

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
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      setup.resultPort.send(IsolateHeartbeatPong(
        token: msg.token,
        pingSentAtMicros: msg.sentAtMicros,
        receivedAtMicros: nowMicros,
        sentAtMicros: nowMicros,
      ));
    } else if (msg == 'emit-data') {
      setup.resultPort.send(NativePitchResultMessage(
        noteName: 'A4',
        frequency: 440.0,
        centsOffset: 0.0,
        midiNote: 69,
      ).encode());
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
      final nowMicros = DateTime.now().microsecondsSinceEpoch;
      setup.resultPort.send(IsolateHeartbeatPong(
        token: msg.token,
        pingSentAtMicros: msg.sentAtMicros,
        receivedAtMicros: nowMicros,
        sentAtMicros: nowMicros,
      ));
    }
  });
}

void _startupErrorIsolate(IsolateSetup setup) {
  setup.resultPort.send(const IsolateManagerError(
    code: 'startup-failure',
    phase: 'test-startup',
    message: 'simulated startup failure',
    stack: 'test-stack',
  ));
}

void _metricsReportingIsolate(IsolateSetup setup) {
  final port = ReceivePort();
  setup.resultPort.send(IsolateReady(port.sendPort));
  port.listen((msg) {
    if (msg == null) {
      port.close();
      return;
    }
    if (msg is IsolateHandshakeRequest) {
      setup.resultPort.send(IsolateHandshakeAck(msg.protocolVersion));
      setup.resultPort.send(const NativeIsolateMetrics(
        bufferedSamples: 32,
        peakBufferedSamples: 64,
        bufferUtilization: 0.5,
        peakBufferUtilization: 1.0,
        framesProcessed: 3,
        lastFrameProcessingTime: Duration(milliseconds: 2),
        averageFrameProcessingTime: Duration(milliseconds: 1),
        maxFrameProcessingTime: Duration(milliseconds: 2),
        lastChunkSampleCount: 128,
        bufferBacklogEvents: 1,
        lastUpdatedAtMicros: 1,
      ));
    } else if (msg is IsolateHeartbeatPing) {
      setup.resultPort.send(IsolateHeartbeatPong(
        token: msg.token,
        pingSentAtMicros: msg.sentAtMicros,
        receivedAtMicros: msg.sentAtMicros + 500,
        sentAtMicros: msg.sentAtMicros + 700,
      ));
    }
  });
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
      final payload = NativePitchResultMessage.decode(messages.single);
      expect(payload.noteName, 'A4');
      expect(payload.frequency, 440.0);

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
      expect(reportedError, isA<NativeIsolateFailure>());
      final failure = reportedError as NativeIsolateFailure;
      expect(failure.code, 'handshake-timeout');
      expect(failure.phase, 'handshake');
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
      expect(reportedError, isA<NativeIsolateFailure>());
      final failure = reportedError as NativeIsolateFailure;
      expect(failure.code, 'startup-failure');
      expect(failure.phase, 'test-startup');
      expect(failure.message, 'simulated startup failure');
      manager.disposeImmediately();
    });

    test('publishes heartbeat and processing metrics to the main isolate',
        () async {
      NativeIsolateMetrics? latestMetrics;
      final metricsReady = Completer<void>();
      final manager = NativePitchIsolateManager(
        handle: nullptr,
        buffer: Pointer<Float>.fromAddress(0),
        frameSize: 64,
        entryPoint: _metricsReportingIsolate,
        heartbeatInterval: const Duration(milliseconds: 10),
        heartbeatTimeout: const Duration(milliseconds: 100),
        onMessage: (_) {},
        onMetrics: (metrics) {
          latestMetrics = metrics;
          if (!metricsReady.isCompleted &&
              metrics.heartbeatSamples > 0 &&
              metrics.framesProcessed == 3) {
            metricsReady.complete();
          }
        },
        onError: (error, _) => fail('unexpected error: $error'),
      );

      final started = await manager.start();
      expect(started, isTrue);

      await metricsReady.future.timeout(const Duration(seconds: 1));
      expect(latestMetrics, isNotNull);
      expect(latestMetrics!.bufferedSamples, 32);
      expect(latestMetrics!.peakBufferedSamples, 64);
      expect(latestMetrics!.bufferUtilization, 0.5);
      expect(latestMetrics!.peakBufferUtilization, 1.0);
      expect(latestMetrics!.framesProcessed, 3);
      expect(
        latestMetrics!.lastFrameProcessingTime,
        const Duration(milliseconds: 2),
      );
      expect(
        latestMetrics!.averageFrameProcessingTime,
        const Duration(milliseconds: 1),
      );
      expect(
        latestMetrics!.maxFrameProcessingTime,
        const Duration(milliseconds: 2),
      );
      expect(latestMetrics!.lastChunkSampleCount, 128);
      expect(latestMetrics!.bufferBacklogEvents, 1);
      expect(latestMetrics!.heartbeatSamples, greaterThanOrEqualTo(1));
      expect(
        latestMetrics!.lastHeartbeatLatency,
        const Duration(microseconds: 500),
      );
      expect(
        latestMetrics!.lastHeartbeatRoundTrip,
        greaterThan(Duration.zero),
      );
      manager.disposeImmediately();
    });
  });
}
