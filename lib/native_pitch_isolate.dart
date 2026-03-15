part of 'native_pitch_bridge.dart';

class NativePitchIsolateManager {
  // Cap heartbeat tokens at max signed 32-bit so IDs stay positive and bounded.
  static const int _maxHeartbeatToken = 0x7fffffff;

  NativePitchIsolateManager({
    required this.handle,
    required this.buffer,
    required this.frameSize,
    required this.entryPoint,
    required this.onMessage,
    required this.onError,
    this.onMetrics,
    this.protocolVersion = 1,
    this.handshakeTimeout = const Duration(seconds: 3),
    this.heartbeatInterval = const Duration(seconds: 2),
    this.heartbeatTimeout = const Duration(seconds: 6),
  });

  final Pointer<Void> handle;
  final Pointer<Float> buffer;
  final int frameSize;
  final void Function(IsolateSetup setup) entryPoint;
  final void Function(dynamic message) onMessage;
  final FfiErrorHandler? onError;
  final void Function(NativeIsolateMetrics metrics)? onMetrics;
  final int protocolVersion;
  final Duration handshakeTimeout;
  final Duration heartbeatInterval;
  final Duration heartbeatTimeout;

  SendPort? _audioSendPort;
  ReceivePort? _resultPort;
  ReceivePort? _exitPort;
  StreamSubscription<dynamic>? _resultSub;
  Isolate? _isolate;
  Timer? _handshakeTimer;
  Timer? _heartbeatTimer;
  int? _pendingHeartbeatToken;
  Stopwatch? _pendingHeartbeatClock;
  int _nextHeartbeatToken = 0;
  NativeIsolateMetrics _metrics = const NativeIsolateMetrics();

  bool _isFatalErrorEnvelope(dynamic message) {
    // VM isolate errors arrive via `onError` as `[error, stackTraceString]`.
    return message is List &&
        message.length == 2 &&
        message[0] != null &&
        message[1] is String;
  }

  Future<bool> start() async {
    final resultPort = ReceivePort();
    _resultPort = resultPort;
    final exitPort = ReceivePort();
    _exitPort = exitPort;
    final setup = IsolateSetup(
      resultPort: resultPort.sendPort,
      handle: handle,
      buffer: buffer,
      frameSize: frameSize,
    );

    try {
      _isolate = await Isolate.spawn(
        entryPoint,
        setup,
        onError: resultPort.sendPort,
        onExit: exitPort.sendPort,
      );
    } catch (e, stack) {
      onError?.call(e, stack);
      _closePorts();
      return false;
    }

    final completer = Completer<bool>();

    void failStart(Object error, StackTrace stackTrace) {
      _handshakeTimer?.cancel();
      _handshakeTimer = null;
      onError?.call(error, stackTrace);
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    }

    late StreamSubscription<dynamic> exitSub;
    exitSub = exitPort.listen((_) {
      if (!completer.isCompleted) {
        failStart(
          const NativeIsolateFailure(
            code: 'startup-exit',
            phase: 'startup',
            message: 'Isolate exited unexpectedly during startup.',
          ),
          StackTrace.current,
        );
      }
    });

    _handshakeTimer = Timer(handshakeTimeout, () {
      failStart(
        const NativeIsolateFailure(
          code: 'handshake-timeout',
          phase: 'handshake',
          message: 'Timed out waiting for isolate handshake.',
        ),
        StackTrace.current,
      );
    });

    _resultSub = resultPort.listen((msg) {
      if (!completer.isCompleted) {
        if (msg is IsolateReady) {
          _audioSendPort = msg.sendPort;
          _audioSendPort?.send(IsolateHandshakeRequest(protocolVersion));
        } else if (msg is IsolateHandshakeAck) {
          if (msg.protocolVersion != protocolVersion) {
            failStart(
              NativeIsolateFailure(
                code: 'protocol-mismatch',
                phase: 'handshake',
                message: 'Isolate protocol mismatch. '
                    'Expected $protocolVersion, got ${msg.protocolVersion}.',
              ),
              StackTrace.current,
            );
            return;
          }
          _handshakeTimer?.cancel();
          _handshakeTimer = null;
          _startHeartbeat();
          completer.complete(true);
        } else if (msg is IsolateManagerError) {
          _reportIsolateError(msg);
          completer.complete(false);
        } else if (_isFatalErrorEnvelope(msg)) {
          _forwardFatalError(msg);
          completer.complete(false);
        }
        return;
      }

      if (msg is IsolateManagerError) {
        _reportIsolateError(msg);
      } else if (_isFatalErrorEnvelope(msg)) {
        _forwardFatalError(msg);
      } else if (msg is NativeIsolateMetrics) {
        _mergeProcessingMetrics(msg);
      } else if (msg is IsolateHeartbeatPong) {
        if (msg.token == _pendingHeartbeatToken) {
          _pendingHeartbeatToken = null;
          _pendingHeartbeatClock?.stop();
          _pendingHeartbeatClock = null;
          final heartbeatLatencyMicros =
              msg.receivedAtMicros - msg.pingSentAtMicros;
          final nowMicros = _nowMicros();
          final roundTripMicros = nowMicros - msg.pingSentAtMicros;
          final nextSamples = _metrics.heartbeatSamples + 1;
          final previousAverageRoundTripMicros =
              _metrics.averageHeartbeatRoundTrip.inMicroseconds;
          final averageRoundTripMicros =
              previousAverageRoundTripMicros +
                  ((roundTripMicros - previousAverageRoundTripMicros) ~/
                      nextSamples);
          _publishMetrics(
            _metrics.copyWith(
              lastHeartbeatLatency:
                  _clampDurationToZero(heartbeatLatencyMicros),
              lastHeartbeatRoundTrip:
                  _clampDurationToZero(roundTripMicros),
              averageHeartbeatRoundTrip:
                  _clampDurationToZero(averageRoundTripMicros),
              maxHeartbeatRoundTrip: roundTripMicros >
                      _metrics.maxHeartbeatRoundTrip.inMicroseconds
                  ? Duration(microseconds: roundTripMicros)
                  : _metrics.maxHeartbeatRoundTrip,
              heartbeatSamples: nextSamples,
              lastUpdatedAtMicros: nowMicros,
            ),
          );
        }
      } else {
        onMessage(msg);
      }
    });

    final ready = await completer.future;
    await exitSub.cancel();
    if (!ready) {
      _handshakeTimer?.cancel();
      _handshakeTimer = null;
      _resultSub?.cancel();
      _resultSub = null;
      _closeResultPort();
    }
    return ready;
  }

  void send(dynamic message) {
    _audioSendPort?.send(message);
  }

  IsolateShutdownHandle prepareForDisposal() {
    _stopHeartbeat();
    _audioSendPort?.send(null);
    _audioSendPort = null;
    _resultSub?.cancel();
    _resultSub = null;
    _closeResultPort();
    final isolate = _isolate;
    _isolate = null;
    final exitPort = _exitPort;
    _exitPort = null;
    return IsolateShutdownHandle(isolate, exitPort);
  }

  void disposeImmediately() {
    _stopHeartbeat();
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _resultSub?.cancel();
    _resultSub = null;
    _closeResultPort();
    _closeExitPort();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _audioSendPort = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_audioSendPort == null) return;
      final clock = _pendingHeartbeatClock;
      if (_pendingHeartbeatToken != null && clock != null) {
        if (clock.elapsed > heartbeatTimeout) {
          onError?.call(
            const NativeIsolateFailure(
              code: 'heartbeat-timeout',
              phase: 'heartbeat',
              message: 'Isolate heartbeat timed out.',
            ),
            StackTrace.current,
          );
          _isolate?.kill(priority: Isolate.immediate);
          _stopHeartbeat();
          return;
        }
        return;
      }

      // Keep tokens in a positive bounded range for stable round-trip matching.
      _nextHeartbeatToken = (_nextHeartbeatToken % _maxHeartbeatToken) + 1;
      final token = _nextHeartbeatToken;
      _pendingHeartbeatToken = token;
      _pendingHeartbeatClock = Stopwatch()..start();
      _audioSendPort?.send(
        IsolateHeartbeatPing(token, _nowMicros()),
      );
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _pendingHeartbeatToken = null;
    _pendingHeartbeatClock?.stop();
    _pendingHeartbeatClock = null;
  }

  void _reportIsolateError(IsolateManagerError msg) {
    onError?.call(
      NativeIsolateFailure(
        code: msg.code,
        phase: msg.phase,
        message: msg.message,
      ),
      StackTrace.fromString(msg.stack),
    );
  }

  void _forwardFatalError(List<dynamic> msg) {
    final error = msg.isNotEmpty ? msg[0] : 'Unknown isolate error';
    final stackStr = msg.length > 1 ? (msg[1] as String?) ?? '' : '';
    onError?.call(
      NativeIsolateFailure(
        code: 'fatal-error',
        phase: 'runtime',
        message: error.toString(),
      ),
      StackTrace.fromString(stackStr),
    );
  }

  void _mergeProcessingMetrics(NativeIsolateMetrics processingMetrics) {
    _publishMetrics(
      processingMetrics.copyWith(
        lastHeartbeatLatency: _metrics.lastHeartbeatLatency,
        lastHeartbeatRoundTrip: _metrics.lastHeartbeatRoundTrip,
        averageHeartbeatRoundTrip: _metrics.averageHeartbeatRoundTrip,
        maxHeartbeatRoundTrip: _metrics.maxHeartbeatRoundTrip,
        heartbeatSamples: _metrics.heartbeatSamples,
      ),
    );
  }

  void _publishMetrics(NativeIsolateMetrics metrics) {
    _metrics = metrics;
    onMetrics?.call(metrics);
  }

  int _nowMicros() {
    return DateTime.now().microsecondsSinceEpoch;
  }

  void _closePorts() {
    _closeResultPort();
    _closeExitPort();
  }

  void _closeResultPort() {
    _resultPort?.close();
    _resultPort = null;
  }

  void _closeExitPort() {
    _exitPort?.close();
    _exitPort = null;
  }
}

/// Entry point for the background isolate.
void _audioProcessingIsolate(IsolateSetup setup) {
  final DynamicLibrary lib;
  try {
    lib = _loadNativeLib();
  } catch (e, stack) {
    setup.resultPort.send(IsolateManagerError(
      code: 'load-native-lib',
      phase: 'load-native-lib',
      message: e.toString(),
      stack: stack.toString(),
    ));
    return;
  }

  final process = lib.lookupFunction<_MLProcessNative, _MLProcessDart>(
      'ml_pitch_detector_process');

  final sampleBuf = RingBuffer();
  int peakBufferedSamples = 0;
  int framesProcessed = 0;
  int totalFrameProcessingMicros = 0;
  int lastFrameProcessingMicros = 0;
  int maxFrameProcessingMicros = 0;
  int lastChunkSampleCount = 0;
  int bufferBacklogEvents = 0;
  final analysisBufferCount = AppConstants.tunerSpectrumBinCount;
  final spectrumBuffers = [
    Float32List(analysisBufferCount),
    Float32List(analysisBufferCount),
  ];
  final fftSize = _largestPowerOfTwo(setup.frameSize);
  final fftReal = Float32List(fftSize);
  final fftImag = Float32List(fftSize);
  final fftWindow = _buildHannWindow(fftSize);
  int nextSpectrumBufferIndex = 0;
  // Two queued frames allows for normal buffering while still flagging when
  // processing begins to fall behind real-time capture.
  const int bufferBacklogThresholdMultiplier = 2;

  void publishMetrics() {
    final bufferedSamples = sampleBuf.length;
    final frameSize = setup.frameSize;
    final hasValidFrameSize = frameSize > 0;
    final bufferUtilization =
        hasValidFrameSize ? bufferedSamples / frameSize : 0.0;
    final peakBufferUtilization =
        hasValidFrameSize ? peakBufferedSamples / frameSize : 0.0;
    final averageFrameProcessingTime = framesProcessed == 0
        ? Duration.zero
        : Duration(microseconds: totalFrameProcessingMicros ~/ framesProcessed);
    setup.resultPort.send(
      NativeIsolateMetrics(
        bufferedSamples: bufferedSamples,
        peakBufferedSamples: peakBufferedSamples,
        bufferUtilization: bufferUtilization,
        peakBufferUtilization: peakBufferUtilization,
        framesProcessed: framesProcessed,
        lastFrameProcessingTime:
            Duration(microseconds: lastFrameProcessingMicros),
        averageFrameProcessingTime: averageFrameProcessingTime,
        maxFrameProcessingTime: Duration(microseconds: maxFrameProcessingMicros),
        lastChunkSampleCount: lastChunkSampleCount,
        bufferBacklogEvents: bufferBacklogEvents,
        lastUpdatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  void processFrame(Float32List frame) {
    final stopwatch = Stopwatch()..start();
    try {
      setup.buffer.asTypedList(frame.length).setAll(0, frame);
      final result = process(setup.handle, setup.buffer, frame.length);
      if (analysisBufferCount > 0 && fftSize > 0) {
        final spectrumBuffer = spectrumBuffers[nextSpectrumBufferIndex];
        _fillSpectrumBins(
          source: frame,
          target: spectrumBuffer,
          real: fftReal,
          imag: fftImag,
          window: fftWindow,
        );
        nextSpectrumBufferIndex =
            (nextSpectrumBufferIndex + 1) % spectrumBuffers.length;
        setup.resultPort.send(
          TransferableTunerAnalysisFrame(
            TransferableTypedData.fromList([spectrumBuffer]),
            spectrumBuffer.length,
          ),
        );
      }
      stopwatch.stop();
      framesProcessed++;
      lastFrameProcessingMicros = stopwatch.elapsedMicroseconds;
      totalFrameProcessingMicros += lastFrameProcessingMicros;
      if (lastFrameProcessingMicros > maxFrameProcessingMicros) {
        maxFrameProcessingMicros = lastFrameProcessingMicros;
      }
      if (result.pitched != 0) {
        final bytes = <int>[];
        for (int i = 0; i < 8; i++) {
          final b = result.noteName[i];
          if (b == 0) break;
          bytes.add(b);
        }
        setup.resultPort.send(
          NativePitchResultMessage(
            noteName: String.fromCharCodes(bytes),
            frequency: result.frequency,
            centsOffset: result.centsOffset,
            midiNote: result.midiNote,
          ).encode(),
        );
      }
    } catch (e, stack) {
      stopwatch.stop();
      setup.resultPort.send(IsolateManagerError(
        code: 'process-frame',
        phase: 'process-frame',
        message: e.toString(),
        stack: stack.toString(),
      ));
    } finally {
      publishMetrics();
    }
  }

  void processPcmChunk(Uint8List chunk) {
    lastChunkSampleCount = chunk.length ~/ Int16List.bytesPerElement;
    for (int i = 0; i + 1 < chunk.length; i += 2) {
      int s = chunk[i] | (chunk[i + 1] << 8);
      if (s >= 0x8000) s -= 0x10000;
      sampleBuf.add(s / 32768.0);
    }
    if (sampleBuf.length > peakBufferedSamples) {
      peakBufferedSamples = sampleBuf.length;
    }
    if (setup.frameSize > 0 &&
        sampleBuf.length >
            setup.frameSize * bufferBacklogThresholdMultiplier) {
      bufferBacklogEvents++;
    }
    while (sampleBuf.length >= setup.frameSize) {
      final frame = Float32List(setup.frameSize);
      if (!sampleBuf.readInto(frame)) break;
      processFrame(frame);
    }
    publishMetrics();
  }

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
    } else if (msg is TransferablePcmChunk) {
      processPcmChunk(msg.data.materialize().asUint8List());
    } else if (msg is Uint8List) {
      processPcmChunk(msg);
    } else if (msg is TransferableFloatFrame) {
      final buffer = msg.data.materialize();
      final maxSamples = buffer.lengthInBytes ~/ Float32List.bytesPerElement;
      if (msg.sampleCount < 0 || msg.sampleCount > maxSamples) {
        setup.resultPort.send(IsolateManagerError(
          code: 'invalid-frame',
          phase: 'validate-frame',
          message: 'Invalid transferable frame length: '
              '${msg.sampleCount} samples requested from $maxSamples available.',
          stack: StackTrace.current.toString(),
        ));
        return;
      }
      processFrame(buffer.asFloat32List(0, msg.sampleCount));
    } else if (msg is Float32List) {
      if (msg.length > setup.frameSize) {
        setup.resultPort.send(IsolateManagerError(
          code: 'invalid-frame',
          phase: 'validate-raw-frame',
          message: 'Raw frame length (${msg.length}) exceeds frameSize (${setup.frameSize}).',
          stack: StackTrace.current.toString(),
        ));
        return;
      }
      processFrame(msg);
    }
  });
}

Duration _clampDurationToZero(int microseconds) {
  return Duration(microseconds: microseconds < 0 ? 0 : microseconds);
}

int _largestPowerOfTwo(int value) {
  if (value < 2) return 0;
  var result = 1;
  while ((result << 1) <= value) {
    result <<= 1;
  }
  return result;
}

Float32List _buildHannWindow(int size) {
  if (size <= 0) return Float32List(0);
  if (size == 1) return Float32List.fromList(const [1.0]);
  final window = Float32List(size);
  for (var i = 0; i < size; i++) {
    window[i] = 0.5 * (1 - math.cos((2 * math.pi * i) / (size - 1)));
  }
  return window;
}

void _fillSpectrumBins({
  required Float32List source,
  required Float32List target,
  required Float32List real,
  required Float32List imag,
  required Float32List window,
}) {
  if (target.isEmpty) return;
  target.fillRange(0, target.length, 0);
  if (real.isEmpty || imag.length != real.length || window.length != real.length) {
    return;
  }

  final fftSize = real.length;
  final copyLength = math.min(source.length, fftSize);
  for (var i = 0; i < copyLength; i++) {
    real[i] = source[i] * window[i];
    imag[i] = 0;
  }
  for (var i = copyLength; i < fftSize; i++) {
    real[i] = 0;
    imag[i] = 0;
  }

  _fftInPlace(real, imag);

  // The tuner visualiser emphasizes the low-frequency region where instrument
  // fundamentals and the strongest early harmonics typically appear.
  final usableFrequencies = math.max(1, fftSize ~/ 4);
  final frequenciesPerBin = usableFrequencies / target.length;
  var peak = 0.0;
  for (var i = 0; i < target.length; i++) {
    final start = math.min((i * frequenciesPerBin).floor(), usableFrequencies - 1);
    final rawEnd = ((i + 1) * frequenciesPerBin).ceil();
    // Tiny buckets can round down to the same index; keep at least one FFT bin
    // in every visual bucket so the preview remains stable.
    final end = rawEnd <= start
        ? start + 1
        : math.min(rawEnd, usableFrequencies);
    var sum = 0.0;
    for (var j = start; j < end; j++) {
      final magnitude = math.sqrt(
        (real[j] * real[j]) + (imag[j] * imag[j]),
      );
      sum += magnitude;
    }
    final average = sum / (end - start);
    target[i] = average.toDouble();
    if (average > peak) {
      peak = average;
    }
  }

  if (peak <= 0) {
    return;
  }
  final safePeak = peak;
  for (var i = 0; i < target.length; i++) {
    target[i] = math.sqrt(target[i] / safePeak).clamp(0.0, 1.0).toDouble();
  }
}

void _fftInPlace(Float32List real, Float32List imag) {
  final n = real.length;
  if (n <= 1) return;

  var j = 0;
  for (var i = 1; i < n; i++) {
    var bit = n >> 1;
    while ((j & bit) != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final realValue = real[i];
      real[i] = real[j];
      real[j] = realValue;
      final imagValue = imag[i];
      imag[i] = imag[j];
      imag[j] = imagValue;
    }
  }

  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    final wLenCos = math.cos(angle);
    final wLenSin = math.sin(angle);
    for (var i = 0; i < n; i += len) {
      var wReal = 1.0;
      var wImag = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final evenIndex = i + k;
        final oddIndex = evenIndex + (len ~/ 2);
        final uReal = real[evenIndex];
        final uImag = imag[evenIndex];
        final vReal =
            (real[oddIndex] * wReal) - (imag[oddIndex] * wImag);
        final vImag =
            (real[oddIndex] * wImag) + (imag[oddIndex] * wReal);
        real[evenIndex] = (uReal + vReal).toDouble();
        imag[evenIndex] = (uImag + vImag).toDouble();
        real[oddIndex] = (uReal - vReal).toDouble();
        imag[oddIndex] = (uImag - vImag).toDouble();
        final nextWReal = (wReal * wLenCos) - (wImag * wLenSin);
        wImag = (wReal * wLenSin) + (wImag * wLenCos);
        wReal = nextWReal;
      }
    }
  }
}
