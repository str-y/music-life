part of 'native_pitch_bridge.dart';

/// Bridges the native C++ pitch-detection engine to a Dart [Stream].
///
/// Features:
/// - **Zero-Jank**: Offloads all native processing to a background Isolate.
/// - **Memory-Safe**: Uses [NativeFinalizer] and [Finalizable] to prevent leaks.
/// - **Robust**: Real-time error reporting via [FfiErrorHandler].
class NativePitchBridge implements Finalizable {

  factory NativePitchBridge({
    int sampleRate = defaultSampleRate,
    int frameSize = defaultFrameSize,
    double threshold = defaultThreshold,
    FfiErrorHandler? onError,
    PermissionService permissionService = defaultPermissionService,
  }) {
    return NativePitchBridge._(
      frameSize: frameSize,
      sampleRate: sampleRate,
      threshold: threshold,
      permissionService: permissionService,
      onError: onError,
    );
  }

  NativePitchBridge._({
    required int frameSize,
    required int sampleRate,
    required double threshold,
    required PermissionService permissionService,
    FfiErrorHandler? onError,
  })  : _frameSize = frameSize,
        _sampleRate = sampleRate,
        _threshold = threshold,
        _permissionService = permissionService,
        _onError = onError;
  static const int defaultFrameSize = AppConstants.audioFrameSize;
  static const int defaultSampleRate = AppConstants.audioSampleRate;
  static const double defaultThreshold = AppConstants.pitchDetectionThreshold;
  static bool _nativeLoggingConfigured = false;
  static const _NativePitchResourceFactory _nativePitchResourceFactory =
      _createNativeResources;
  static VoidCallback? _onNativeResourceInitializationAttemptForTesting;
  static final NativeCallable<_MLNativeLogCallbackNative> _nativeLogCallback =
      NativeCallable<_MLNativeLogCallbackNative>.listener(
    _onNativeLog,
  );
  static final NativeFinalizer _bufferFinalizer =
      NativeFinalizer(malloc.nativeFree);

  final int _sampleRate;
  final int _frameSize;
  final double _threshold;
  _NativePitchResources? _nativeResources;

  NativePitchIsolateManager? _isolateManager;
  final FfiErrorHandler? _onError;
  final PermissionService _permissionService;
  bool _disposed = false;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  Stream<String> get chordStream => _controller.stream;

  final StreamController<PitchResult> _pitchController =
      StreamController<PitchResult>.broadcast();
  Stream<PitchResult> get pitchStream => _pitchController.stream;

  final StreamController<TunerAnalysisFrame> _analysisController =
      StreamController<TunerAnalysisFrame>.broadcast();
  Stream<TunerAnalysisFrame> get tunerAnalysisStream =>
      _analysisController.stream;

  NativeIsolateMetrics _latestIsolateMetrics = const NativeIsolateMetrics();
  final StreamController<NativeIsolateMetrics> _metricsController =
      StreamController<NativeIsolateMetrics>.broadcast();
  Stream<NativeIsolateMetrics> get isolateMetricsStream =>
      _metricsController.stream;
  NativeIsolateMetrics get latestIsolateMetrics => _latestIsolateMetrics;

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
      ),
    );
  }

  @visibleForTesting
  static void configureNativeResourceInitializationCallbackForTesting(
    VoidCallback? callback,
  ) {
    _onNativeResourceInitializationAttemptForTesting = callback;
  }

  @visibleForTesting
  static void resetNativeResourceInitializationCallbackForTesting() {
    _onNativeResourceInitializationAttemptForTesting = null;
  }

  NativePitchResultMessage? _tryDecodePitchResultPayload(dynamic message) {
    return NativePitchResultMessage.tryDecode(message);
  }

  void processAudioFrame(Float32List samples) {
    if (_disposed) return;
    if (samples.length > _frameSize) {
      _onError?.call(
        StateError(
          'samples.length (${samples.length}) exceeds frameSize ($_frameSize).',
        ),
        StackTrace.current,
      );
      return;
    }
    _isolateManager?.send(TransferableFloatFrame(
      TransferableTypedData.fromList([samples]),
      samples.length,
    ));
  }

  Future<bool> startCapture() async {
    if (_disposed) return false;
    if (!await _permissionService.hasMicrophonePermission()) return false;
    if (_disposed) return false;
    try {
      final resources = _ensureNativeResourcesInitialized();
      final manager = NativePitchIsolateManager(
        handle: resources.handle,
        buffer: resources.persistentBuffer,
        frameSize: _frameSize,
        entryPoint: _audioProcessingIsolate,
        onMessage: (msg) {
          if (msg is TransferableTunerAnalysisFrame) {
            _onTunerAnalysisFrame(msg.materialize());
            return;
          }
          final pitch = _tryDecodePitchResultPayload(msg);
          if (pitch != null) {
            _onPitchResult(pitch);
          }
        },
        onMetrics: (metrics) {
          _latestIsolateMetrics = metrics;
          if (!_metricsController.isClosed) {
            _metricsController.add(metrics);
          }
        },
        onError: _onError,
      );
      _isolateManager = manager;
    } catch (e, stack) {
      if (_onError != null) {
        _onError.call(e, stack);
        return false;
      }
      rethrow;
    }
    final manager = _isolateManager!;

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

  _NativePitchResources _ensureNativeResourcesInitialized() {
    final existingResources = _nativeResources;
    if (existingResources != null) return existingResources;
    _onNativeResourceInitializationAttemptForTesting?.call();
    final resources = _nativePitchResourceFactory(
      sampleRate: _sampleRate,
      frameSize: _frameSize,
      threshold: _threshold,
    );
    resources.handleFinalizer.attach(
      this,
      resources.handle.cast(),
      detach: this,
    );
    _bufferFinalizer.attach(
      this,
      resources.persistentBuffer.cast(),
      detach: this,
    );
    _nativeResources = resources;
    return resources;
  }

  void _onAudioChunk(Uint8List chunk) {
    if (_disposed) return;
    _isolateManager?.send(
      TransferablePcmChunk(
        TransferableTypedData.fromList([chunk]),
      ),
    );
  }

  void _onPitchResult(NativePitchResultMessage pitch) {
    if (_controller.isClosed) return;
    _controller.add(pitch.noteName);
    _pitchController.add(PitchResult(
      noteName: pitch.noteName,
      frequency: pitch.frequency,
      centsOffset: pitch.centsOffset,
      midiNote: pitch.midiNote,
    ));
  }

  void _onTunerAnalysisFrame(TunerAnalysisFrame analysisFrame) {
    if (_analysisController.isClosed) return;
    _analysisController.add(analysisFrame);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final resources = _nativeResources;
    _nativeResources = null;
    if (resources != null) {
      resources.handleFinalizer.detach(this);
      _bufferFinalizer.detach(this);
    }
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
    _analysisController.close();
    _metricsController.close();
    final isolate = shutdownHandle?.isolate;
    final exitPort = shutdownHandle?.exitPort;

    if (resources == null) {
      return;
    }

    if (isolate == null || exitPort == null) {
      // No isolate was started; free native resources immediately.
      resources.nativeDestroy(resources.handle);
      malloc.free(resources.persistentBuffer);
      return;
    }

    // Defer native-resource teardown until the isolate confirms it has exited.
    // This prevents a use-after-free if the isolate is mid-frame when
    // dispose() is called: the isolate is single-threaded, so it finishes its
    // current message (including any in-flight native call) before processing
    // the null shutdown signal and exiting.
    var freed = false;
    StreamSubscription<dynamic>? exitSub;
    Timer? forceKillTimer;
    void freeNativeResources() {
      if (freed) return;
      freed = true;
      forceKillTimer?.cancel();
      exitSub?.cancel();
      exitPort.close();
      resources.nativeDestroy(resources.handle);
      malloc.free(resources.persistentBuffer);
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
