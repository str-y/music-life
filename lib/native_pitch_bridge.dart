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

class _IsolateSetup {
  const _IsolateSetup({
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

class _IsolateError {
  const _IsolateError(this.message, this.stack);
  final String message;
  final String stack;
}

class _TransferablePcmChunk {
  const _TransferablePcmChunk(this.data);
  final TransferableTypedData data;
}

class _TransferableFloatFrame {
  const _TransferableFloatFrame(this.data, this.sampleCount);
  final TransferableTypedData data;
  final int sampleCount;
}

/// Entry point for the background isolate.
void _audioProcessingIsolate(_IsolateSetup setup) {
  final DynamicLibrary lib;
  try {
    lib = _loadNativeLib();
  } catch (e, stack) {
    setup.resultPort.send(_IsolateError(e.toString(), stack.toString()));
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
      setup.resultPort.send(_IsolateError(e.toString(), stack.toString()));
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
  setup.resultPort.send(port.sendPort);

  port.listen((msg) {
    if (msg == null) {
      port.close();
      return;
    }
    if (msg is _TransferablePcmChunk) {
      processPcmChunk(msg.data.materialize().asUint8List());
    } else if (msg is Uint8List) {
      processPcmChunk(msg);
    } else if (msg is _TransferableFloatFrame) {
      final buffer = msg.data.materialize();
      final maxSamples = buffer.lengthInBytes ~/ Float32List.bytesPerElement;
      if (msg.sampleCount < 0 || msg.sampleCount > maxSamples) {
        setup.resultPort.send(_IsolateError(
          'Invalid transferable frame length: '
          '${msg.sampleCount} samples requested from $maxSamples available.',
          StackTrace.current.toString(),
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

  final NativeFinalizer _handleFinalizer;
  static final NativeFinalizer _bufferFinalizer =
      NativeFinalizer(malloc.nativeFree);

  final Pointer<Void> _handle;
  final Pointer<Float> _persistentBuffer;
  final _MLDestroyDart _nativeDestroy;

  final int _sampleRate;
  final int _frameSize;

  SendPort? _audioSendPort;
  ReceivePort? _resultPort;
  ReceivePort? _exitPort;
  StreamSubscription<dynamic>? _resultSub;
  Isolate? _isolate;
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

  void processAudioFrame(Float32List samples) {
    if (_disposed) return;
    assert(
      samples.length <= _frameSize,
      'samples.length (${samples.length}) exceeds frameSize ($_frameSize).',
    );
    _audioSendPort?.send(_TransferableFloatFrame(
      TransferableTypedData.fromList([samples]),
      samples.length,
    ));
  }

  Future<bool> startCapture() async {
    if (!await _recorder.hasPermission()) return false;

    final resultPort = ReceivePort();
    _resultPort = resultPort;
    final exitPort = ReceivePort();
    _exitPort = exitPort;

    try {
      _isolate = await Isolate.spawn(
        _audioProcessingIsolate,
        _IsolateSetup(
          resultPort: resultPort.sendPort,
          handle: _handle,
          buffer: _persistentBuffer,
          frameSize: _frameSize,
        ),
        onError: resultPort.sendPort,
        onExit: exitPort.sendPort,
      );
    } catch (e, stack) {
      _onError?.call(e, stack);
      exitPort.close();
      _exitPort = null;
      return false;
    }

    final completer = Completer<bool>();

    // Helper: parse and forward a fatal error list sent by the Dart runtime
    // via onError: resultPort.sendPort  →  [errorDescription, stackTraceString].
    void forwardFatalError(List<dynamic> msg) {
      final error = msg.isNotEmpty ? msg[0] : 'Unknown isolate error';
      final stackStr = msg.length > 1 ? (msg[1] as String?) ?? '' : '';
      _onError?.call(error, StackTrace.fromString(stackStr));
    }

    // If the isolate exits before it ever sends its SendPort (e.g. fatal
    // crash before the port.listen line), complete the completer so the
    // caller is never left hanging.
    late StreamSubscription<dynamic> exitSub;
    exitSub = exitPort.listen((_) {
      exitPort.close();
      _exitPort = null;
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    _resultSub = resultPort.listen((msg) {
      if (!completer.isCompleted) {
        if (msg is SendPort) {
          _audioSendPort = msg;
          // Cancel the exit watcher now that startup succeeded; crashes after
          // this point are reported via onError: resultPort.sendPort.
          exitSub.cancel();
          completer.complete(true);
        } else if (msg is _IsolateError) {
          _onError?.call(msg.message, StackTrace.fromString(msg.stack));
          completer.complete(false);
        } else if (msg is List) {
          // Fatal uncaught isolate error forwarded via onError: resultPort.sendPort.
          // The Dart runtime sends it as [errorDescription, stackTraceString].
          forwardFatalError(msg);
          completer.complete(false);
        } else {
          completer.complete(false);
        }
        return;
      }
      if (msg is Map) {
        _onPitchResult(msg);
      } else if (msg is _IsolateError) {
        _onError?.call(msg.message, StackTrace.fromString(msg.stack));
      } else if (msg is List) {
        // Fatal uncaught isolate error after startup.
        forwardFatalError(msg);
      }
    });

    final ready = await completer.future;
    if (!ready) {
      _resultSub?.cancel();
      _resultSub = null;
      resultPort.close();
      _resultPort = null;
      return false;
    }

    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );
      _audioSub = stream.listen(_onAudioChunk, onError: _onError);
      return true;
    } catch (e, stack) {
      _onError?.call(e, stack);
      return false;
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    if (_disposed) return;
    _audioSendPort?.send(
      _TransferablePcmChunk(
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
    _audioSendPort?.send(null);
    _audioSendPort = null;
    _resultSub?.cancel();
    _resultSub = null;
    _resultPort?.close();
    _resultPort = null;
    _controller.close();
    _pitchController.close();

    final isolate = _isolate;
    _isolate = null;
    final exitPort = _exitPort;
    _exitPort = null;

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
