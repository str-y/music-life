part of 'native_pitch_bridge.dart';

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

typedef _NativePitchResourceFactory = _NativePitchResources Function({
  required int sampleRate,
  required int frameSize,
  required double threshold,
});

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

_NativePitchResources _createNativeResources({
  required int sampleRate,
  required int frameSize,
  required double threshold,
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

  return _NativePitchResources(
    handle: handle,
    nativeDestroy: lib.lookupFunction<_MLDestroyNative, _MLDestroyDart>(
        'ml_pitch_detector_destroy'),
    persistentBuffer: malloc.allocate<Float>(frameSize * sizeOf<Float>()),
    handleFinalizer: handleFinalizer,
  );
}

void _configureNativeLogging(DynamicLibrary lib) {
  if (NativePitchBridge._nativeLoggingConfigured) return;
  NativePitchBridge._nativeLoggingConfigured = true;
  try {
    lib
        .lookupFunction<_MLSetLogCallbackNative, _MLSetLogCallbackDart>(
          'ml_pitch_detector_set_log_callback',
        )
        .call(NativePitchBridge._nativeLogCallback.nativeFunction);
    lib
        .lookupFunction<_MLInstallCrashHandlersNative,
            _MLInstallCrashHandlersDart>(
          'ml_pitch_detector_install_crash_handlers',
        )
        .call();
  } catch (e, stack) {
    NativePitchBridge._nativeLoggingConfigured = false;
    AppLogger.reportError(
      'Failed to configure native logging bridge',
      error: e,
      stackTrace: stack,
    );
  }
}

void _onNativeLog(int level, Pointer<Utf8> messagePointer) {
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

final class _NativePitchResources {
  const _NativePitchResources({
    required this.handle,
    required this.nativeDestroy,
    required this.persistentBuffer,
    required this.handleFinalizer,
  });

  final Pointer<Void> handle;
  final _MLDestroyDart nativeDestroy;
  final Pointer<Float> persistentBuffer;
  final NativeFinalizer handleFinalizer;
}
