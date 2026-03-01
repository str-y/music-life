import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:record/record.dart';

import 'app_constants.dart';
import 'utils/app_logger.dart';
import 'utils/ring_buffer.dart';

// ── FFI struct matching MLPitchResult in src/app_bridge/pitch_detector_ffi.h ──

/// Mirrors the C struct `MLPitchResult` from `pitch_detector_ffi.h`.
final class MLPitchResult extends Struct {
  @Int32()
  external int pitched;

  @Float()
  external double frequency;

  @Float()
  external double probability;

  @Int32()
  external int midiNote;

  @Float()
  external double centsOffset;

  /// `char note_name[8]` in the C struct.
  @Array(8)
  external Array<Uint8> noteName;
}

// ── FFI function typedefs ─────────────────────────────────────────────────────

typedef _MLCreateNative = Pointer<Void> Function(
    Int32 sampleRate, Int32 frameSize, Float threshold);
typedef _MLCreateDart = Pointer<Void> Function(
    int sampleRate, int frameSize, double threshold);

typedef _MLDestroyNative = Void Function(Pointer<Void> handle);
typedef _MLDestroyDart = void Function(Pointer<Void> handle);

typedef _MLProcessNative = MLPitchResult Function(
    Pointer<Void> handle, Pointer<Float> samples, Int32 numSamples);
typedef _MLProcessDart = MLPitchResult Function(
    Pointer<Void> handle, Pointer<Float> samples, int numSamples);

typedef _MLNativeLogCallbackNative = Void Function(
    Int32 level, Pointer<Utf8> message);
typedef _MLNativeLogCallbackDart = void Function(
    int level, Pointer<Utf8> message);

typedef _MLSetLogCallbackNative = Void Function(
    Pointer<NativeFunction<_MLNativeLogCallbackNative>> callback);
typedef _MLSetLogCallbackDart = void Function(
    Pointer<NativeFunction<_MLNativeLogCallbackNative>> callback);

typedef _MLInstallCrashHandlersNative = Void Function();
typedef _MLInstallCrashHandlersDart = void Function();

const int _mlLogLevelTrace = 0;
const int _mlLogLevelDebug = 1;
const int _mlLogLevelInfo = 2;
const int _mlLogLevelError = 3;

// ── Native library loading ────────────────────────────────────────────────────

DynamicLibrary _loadNativeLib() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libpitch_detection.so');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  throw UnsupportedError(
    'NativePitchBridge is not supported on ${Platform.operatingSystem}.',
  );
}

// ── Pitch result ─────────────────────────────────────────────────────────────

/// Decoded pitch information emitted by [NativePitchBridge.pitchStream].
class PitchResult {
  const PitchResult({
    required this.noteName,
    required this.frequency,
    required this.centsOffset,
    required this.midiNote,
  });

  final String noteName;
  final double frequency;
  final double centsOffset;
  final int midiNote;
}

// ── Error handling ────────────────────────────────────────────────────────────

/// Callback invoked when an unhandled error occurs in the background processing.
typedef FfiErrorHandler = void Function(Object error, StackTrace stack);

// ── Isolate support ───────────────────────────────────────────────────────────

class IsolateSetup {
  const IsolateSetup({
    required this.resultPort,
    required this.handle,
    required this.buffer,
    required this.frameSize,
  });

  final SendPort resultPort;
  final Pointer<Void> handle;
  final Pointer<Float> buffer;
  final int frameSize;
}

class IsolateManagerError {
  const IsolateManagerError({
    required this.phase,
    required this.message,
    required this.stack,
  });
  final String phase;
  final String message;
  final String stack;
}

class IsolateReady {
  const IsolateReady(this.sendPort);
  final SendPort sendPort;
}

class IsolateHandshakeRequest {
  const IsolateHandshakeRequest(this.protocolVersion);
  final int protocolVersion;
}

class IsolateHandshakeAck {
  const IsolateHandshakeAck(this.protocolVersion);
  final int protocolVersion;
}

class IsolateHeartbeatPing {
  const IsolateHeartbeatPing(this.token);
  final int token;
}

class IsolateHeartbeatPong {
  const IsolateHeartbeatPong(this.token);
  final int token;
}

class TransferablePcmChunk {
  const TransferablePcmChunk(this.data);
  final TransferableTypedData data;
}

class TransferableFloatFrame {
  const TransferableFloatFrame(this.data, this.sampleCount);
  final TransferableTypedData data;
  final int sampleCount;
}

class IsolateShutdownHandle {
  const IsolateShutdownHandle(this.isolate, this.exitPort);
  final Isolate? isolate;
  final ReceivePort? exitPort;
}

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
          StateError('Isolate exited unexpectedly during startup.'),
          StackTrace.current,
        );
      }
    });

    _handshakeTimer = Timer(handshakeTimeout, () {
      failStart(
        TimeoutException(
          'Timed out waiting for isolate handshake.',
          handshakeTimeout,
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
              StateError(
                'Isolate protocol mismatch. '
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
        } else if (msg is List) {
          _forwardFatalError(msg);
          completer.complete(false);
        }
        return;
      }

      if (msg is IsolateManagerError) {
        _reportIsolateError(msg);
      } else if (msg is List) {
        _forwardFatalError(msg);
      } else if (msg is IsolateHeartbeatPong) {
        if (msg.token == _pendingHeartbeatToken) {
          _pendingHeartbeatToken = null;
          _pendingHeartbeatClock?.stop();
          _pendingHeartbeatClock = null;
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
            TimeoutException(
              'Isolate heartbeat timed out.',
              heartbeatTimeout,
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
      _audioSendPort?.send(IsolateHeartbeatPing(token));
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
      StateError('[${msg.phase}] ${msg.message}'),
      StackTrace.fromString(msg.stack),
    );
  }

  void _forwardFatalError(List<dynamic> msg) {
    final error = msg.isNotEmpty ? msg[0] : 'Unknown isolate error';
    final stackStr = msg.length > 1 ? (msg[1] as String?) ?? '' : '';
    onError?.call(error, StackTrace.fromString(stackStr));
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
      phase: 'load-native-lib',
      message: e.toString(),
      stack: stack.toString(),
    ));
    return;
  }

  final process = lib.lookupFunction<_MLProcessNative, _MLProcessDart>(
      'ml_pitch_detector_process');

  final sampleBuf = RingBuffer();

  void processFrame(Float32List frame) {
    try {
      setup.buffer.asTypedList(frame.length).setAll(0, frame);
      final result = process(setup.handle, setup.buffer, frame.length);
      if (result.pitched != 0) {
        final bytes = <int>[];
        for (int i = 0; i < 8; i++) {
          final b = result.noteName[i];
          if (b == 0) break;
          bytes.add(b);
        }
        setup.resultPort.send(<String, Object>{
          'noteName': String.fromCharCodes(bytes),
          'frequency': result.frequency,
          'centsOffset': result.centsOffset,
          'midiNote': result.midiNote,
        });
      }
    } catch (e, stack) {
      setup.resultPort.send(IsolateManagerError(
        phase: 'process-frame',
        message: e.toString(),
        stack: stack.toString(),
      ));
    }
  }

  void processPcmChunk(Uint8List chunk) {
    for (int i = 0; i + 1 < chunk.length; i += 2) {
      int s = chunk[i] | (chunk[i + 1] << 8);
      if (s >= 0x8000) s -= 0x10000;
      sampleBuf.add(s / 32768.0);
    }
    while (sampleBuf.length >= setup.frameSize) {
      final frame = Float32List(setup.frameSize);
      if (!sampleBuf.readInto(frame)) break;
      processFrame(frame);
    }
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
      setup.resultPort.send(IsolateHeartbeatPong(msg.token));
    } else if (msg is TransferablePcmChunk) {
      processPcmChunk(msg.data.materialize().asUint8List());
    } else if (msg is Uint8List) {
      processPcmChunk(msg);
    } else if (msg is TransferableFloatFrame) {
      final buffer = msg.data.materialize();
      final maxSamples = buffer.lengthInBytes ~/ Float32List.bytesPerElement;
      if (msg.sampleCount < 0 || msg.sampleCount > maxSamples) {
        setup.resultPort.send(IsolateManagerError(
          phase: 'validate-frame',
          message: 'Invalid transferable frame length: '
              '${msg.sampleCount} samples requested from $maxSamples available.',
          stack: StackTrace.current.toString(),
        ));
        return;
      }
      processFrame(buffer.asFloat32List(0, msg.sampleCount));
    } else if (msg is Float32List) {
      processFrame(msg);
    }
  });
}

// ── Bridge ────────────────────────────────────────────────────────────────────

/// Bridges the native C++ pitch-detection engine to a Dart [Stream].
///
/// Features:
/// - **Zero-Jank**: Offloads all native processing to a background Isolate.
/// - **Memory-Safe**: Uses [NativeFinalizer] and [Finalizable] to prevent leaks.
/// - **Robust**: Real-time error reporting via [FfiErrorHandler].
class NativePitchBridge implements Finalizable {
  static const int defaultFrameSize = AppConstants.audioFrameSize;
  static const int defaultSampleRate = AppConstants.audioSampleRate;
  static const double defaultThreshold = AppConstants.pitchDetectionThreshold;
  static bool _nativeLoggingConfigured = false;
  static final NativeCallable<_MLNativeLogCallbackNative> _nativeLogCallback =
      NativeCallable<_MLNativeLogCallbackNative>.listener(
    _onNativeLog,
  );

  final NativeFinalizer _handleFinalizer;
  static final NativeFinalizer _bufferFinalizer =
      NativeFinalizer(malloc.nativeFree);

  final Pointer<Void> _handle;
  final Pointer<Float> _persistentBuffer;
  final _MLDestroyDart _nativeDestroy;

  final int _sampleRate;
  final int _frameSize;

  NativePitchIsolateManager? _isolateManager;
  final FfiErrorHandler? _onError;
  bool _disposed = false;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  Stream<String> get chordStream => _controller.stream;

  final StreamController<PitchResult> _pitchController =
      StreamController<PitchResult>.broadcast();
  Stream<PitchResult> get pitchStream => _pitchController.stream;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  static RecordConfig captureRecordConfig({
    required int sampleRate,
    required int frameSize,
  }) {
    return RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      streamBufferSize: frameSize * Int16List.bytesPerElement,
      androidConfig: const AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceRecognition,
        audioManagerMode: AudioManagerMode.modeInCommunication,
        useLegacy: false,
      ),
    );
  }

  NativePitchBridge._({
    required Pointer<Void> handle,
    required _MLDestroyDart nativeDestroy,
    required Pointer<Float> persistentBuffer,
    required int frameSize,
    required int sampleRate,
    required NativeFinalizer handleFinalizer,
    FfiErrorHandler? onError,
  })  : _handle = handle,
        _nativeDestroy = nativeDestroy,
        _persistentBuffer = persistentBuffer,
        _frameSize = frameSize,
        _sampleRate = sampleRate,
        _handleFinalizer = handleFinalizer,
        _onError = onError {
    _handleFinalizer.attach(this, handle.cast(), detach: this);
    _bufferFinalizer.attach(this, persistentBuffer.cast(), detach: this);
  }

  factory NativePitchBridge({
    int sampleRate = defaultSampleRate,
    int frameSize = defaultFrameSize,
    double threshold = defaultThreshold,
    FfiErrorHandler? onError,
  }) {
    final lib = _loadNativeLib();
    _configureNativeLogging(lib);
    final handleFinalizer = NativeFinalizer(
      lib.lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'ml_pitch_detector_destroy'),
    );

    final create = lib.lookupFunction<_MLCreateNative, _MLCreateDart>(
        'ml_pitch_detector_create');
    final handle = create(sampleRate, frameSize, threshold);
    if (handle == nullptr) {
      throw StateError('ml_pitch_detector_create returned a null handle.');
    }

    return NativePitchBridge._(
      handle: handle,
      nativeDestroy: lib.lookupFunction<_MLDestroyNative, _MLDestroyDart>(
          'ml_pitch_detector_destroy'),
      persistentBuffer: malloc.allocate<Float>(frameSize * sizeOf<Float>()),
      frameSize: frameSize,
      sampleRate: sampleRate,
      handleFinalizer: handleFinalizer,
      onError: onError,
    );
  }

  static void _configureNativeLogging(DynamicLibrary lib) {
    if (_nativeLoggingConfigured) return;
    _nativeLoggingConfigured = true;
    try {
      lib
          .lookupFunction<_MLSetLogCallbackNative, _MLSetLogCallbackDart>(
            'ml_pitch_detector_set_log_callback',
          )
          .call(_nativeLogCallback.nativeFunction);
      lib
          .lookupFunction<_MLInstallCrashHandlersNative,
              _MLInstallCrashHandlersDart>(
            'ml_pitch_detector_install_crash_handlers',
          )
          .call();
    } catch (e, stack) {
      _nativeLoggingConfigured = false;
      AppLogger.reportError(
        'Failed to configure native logging bridge',
        error: e,
        stackTrace: stack,
      );
    }
  }

  static void _onNativeLog(int level, Pointer<Utf8> messagePointer) {
    final message = messagePointer == nullptr
        ? 'Native log callback received null message'
        : messagePointer.toDartString();
    switch (level) {
      case _mlLogLevelTrace:
        AppLogger.trace('[native] $message');
        break;
      case _mlLogLevelDebug:
        AppLogger.debug('[native] $message');
        break;
      case _mlLogLevelInfo:
        AppLogger.info('[native] $message');
        break;
      case _mlLogLevelError:
        AppLogger.reportError(
          '[native] $message',
          error: StateError('Native C++ error'),
          stackTrace: StackTrace.current,
        );
        break;
      default:
        AppLogger.info('[native][unknown:$level] $message');
    }
  }

  void processAudioFrame(Float32List samples) {
    if (_disposed) return;
    assert(
      samples.length <= _frameSize,
      'samples.length (${samples.length}) exceeds frameSize ($_frameSize).',
    );
    _isolateManager?.send(TransferableFloatFrame(
      TransferableTypedData.fromList([samples]),
      samples.length,
    ));
  }

  Future<bool> startCapture() async {
    if (!await _recorder.hasPermission()) return false;
    final manager = NativePitchIsolateManager(
      handle: _handle,
      buffer: _persistentBuffer,
      frameSize: _frameSize,
      entryPoint: _audioProcessingIsolate,
      onMessage: (msg) {
        if (msg is Map) {
          _onPitchResult(msg);
        }
      },
      onError: _onError,
    );
    _isolateManager = manager;

    final ready = await manager.start();
    if (!ready) {
      manager.disposeImmediately();
      _isolateManager = null;
      return false;
    }

    try {
      final stream = await _recorder.startStream(
        captureRecordConfig(
          sampleRate: _sampleRate,
          frameSize: _frameSize,
        ),
      );
      _audioSub = stream.listen(_onAudioChunk, onError: _onError);
      return true;
    } catch (e, stack) {
      _onError?.call(e, stack);
      _isolateManager?.disposeImmediately();
      _isolateManager = null;
      return false;
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    if (_disposed) return;
    _isolateManager?.send(
      TransferablePcmChunk(
        TransferableTypedData.fromList([chunk]),
      ),
    );
  }

  void _onPitchResult(Map<dynamic, dynamic> msg) {
    if (_controller.isClosed) return;
    final noteName = msg['noteName'];
    if (noteName is! String) return;
    _controller.add(noteName);
    _pitchController.add(PitchResult(
      noteName: noteName,
      frequency: msg['frequency'],
      centsOffset: msg['centsOffset'],
      midiNote: msg['midiNote'],
    ));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _handleFinalizer.detach(this);
    _bufferFinalizer.detach(this);
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop().then<void>(
      (_) {},
      onError: (Object e, StackTrace st) => AppLogger.reportError(
        'Failed to stop recorder during dispose',
        error: e,
        stackTrace: st,
      ),
    );
    _recorder.dispose();
    // Signal the isolate to stop processing and close its receive port.
    final shutdownHandle = _isolateManager?.prepareForDisposal();
    _isolateManager = null;
    _controller.close();
    _pitchController.close();
    final isolate = shutdownHandle?.isolate;
    final exitPort = shutdownHandle?.exitPort;

    if (isolate == null || exitPort == null) {
      // No isolate was started; free native resources immediately.
      _nativeDestroy(_handle);
      malloc.free(_persistentBuffer);
      return;
    }

    // Defer native-resource teardown until the isolate confirms it has exited.
    // This prevents a use-after-free if the isolate is mid-frame when
    // dispose() is called: the isolate is single-threaded, so it finishes its
    // current message (including any in-flight native call) before processing
    // the null shutdown signal and exiting.
    bool freed = false;
    StreamSubscription<dynamic>? exitSub;
    Timer? forceKillTimer;
    void freeNativeResources() {
      if (freed) return;
      freed = true;
      forceKillTimer?.cancel();
      exitSub?.cancel();
      exitPort.close();
      _nativeDestroy(_handle);
      malloc.free(_persistentBuffer);
    }

    exitSub = exitPort.listen((_) => freeNativeResources());

    // Safety net: if the isolate does not exit gracefully within 5 seconds,
    // force-kill it. The Dart VM sends the exit-port notification after the
    // kill completes, so freeNativeResources() will still be called exactly
    // once even in this path.
    forceKillTimer = Timer(const Duration(seconds: 5), () {
      isolate.kill(priority: Isolate.immediate);
    });
  }
}
