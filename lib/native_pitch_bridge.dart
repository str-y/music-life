import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:record/record.dart';

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
    // The pitch-detection FFI symbols are exported from libpitch_detection.so.
    // Ensure the CMake target is built as a SHARED library for Android FFI.
    return DynamicLibrary.open('libpitch_detection.so');
  }
  if (Platform.isIOS) {
    // On iOS the symbols are statically linked into the main binary.
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

  /// Scientific note name, e.g. "A4" or "C#3".
  final String noteName;

  /// Detected fundamental frequency in Hz.
  final double frequency;

  /// Deviation from the nearest semitone in cents (−50 … +50).
  final double centsOffset;

  /// MIDI note number (0–127).
  final int midiNote;
}

// ── Bridge ────────────────────────────────────────────────────────────────────

/// Bridges the native C++ pitch-detection engine to a Dart [Stream].
///
/// Create one instance per active recording session.  Feed audio frames via
/// [processAudioFrame] (called by the platform audio-capture layer), and
/// listen to [chordStream] to receive detected note names in real time.
///
/// **Note:** This bridge performs monophonic pitch detection only.  The
/// [chordStream] emits scientific note names (e.g. "A4") for the dominant
/// fundamental frequency; no polyphonic chord analysis is performed.
///
/// Call [dispose] when done to release the native handle and close the stream.
class NativePitchBridge {
  /// Default frame size (samples) matching the native detector's default.
  static const int defaultFrameSize = 2048;

  /// Default sample rate matching the native detector's default.
  static const int defaultSampleRate = 44100;

  /// Default YIN probability threshold.
  ///
  /// Valid range is 0.0–1.0.  Lower values increase sensitivity (detect more
  /// pitched frames) but may produce false positives in noisy conditions.
  /// Higher values require stronger pitch evidence before firing.
  static const double defaultThreshold = 0.10;

  final Pointer<Void> _handle;
  final _MLProcessDart _nativeProcess;
  final _MLDestroyDart _nativeDestroy;

  /// Persistent native buffer reused across every [processAudioFrame] call.
  final Pointer<Float> _persistentBuffer;

  /// Number of Float elements that [_persistentBuffer] can hold.
  final int _frameSize;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Emits the detected note name (e.g. "A4") each time the native engine
  /// detects a pitched note.  This is a monophonic note label; no chord
  /// inference is performed.
  Stream<String> get chordStream => _controller.stream;

  final StreamController<PitchResult> _pitchController =
      StreamController<PitchResult>.broadcast();

  /// Emits a [PitchResult] each time the native engine detects a pitched note.
  Stream<PitchResult> get pitchStream => _pitchController.stream;

  // ── Audio capture ──────────────────────────────────────────────────────────

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  /// Partial-frame accumulator for PCM samples between [processAudioFrame] calls.
  final List<double> _sampleBuffer = [];

  NativePitchBridge._({
    required Pointer<Void> handle,
    required _MLProcessDart nativeProcess,
    required _MLDestroyDart nativeDestroy,
    required Pointer<Float> persistentBuffer,
    required int frameSize,
  })  : _handle = handle,
        _nativeProcess = nativeProcess,
        _nativeDestroy = nativeDestroy,
        _persistentBuffer = persistentBuffer,
        _frameSize = frameSize;

  /// Creates a [NativePitchBridge] backed by the platform's native library.
  factory NativePitchBridge({
    int sampleRate = defaultSampleRate,
    int frameSize = defaultFrameSize,
    double threshold = defaultThreshold,
  }) {
    final lib = _loadNativeLib();

    final create = lib.lookupFunction<_MLCreateNative, _MLCreateDart>(
        'ml_pitch_detector_create');
    final handle = create(sampleRate, frameSize, threshold);
    if (handle == nullptr) {
      throw StateError('ml_pitch_detector_create returned a null handle.');
    }

    return NativePitchBridge._(
      handle: handle,
      nativeProcess: lib.lookupFunction<_MLProcessNative, _MLProcessDart>(
          'ml_pitch_detector_process'),
      nativeDestroy: lib.lookupFunction<_MLDestroyNative, _MLDestroyDart>(
          'ml_pitch_detector_destroy'),
      persistentBuffer: malloc.allocate<Float>(frameSize * sizeOf<Float>()),
      frameSize: frameSize,
    );
  }

  /// Feed a frame of 32-bit float PCM samples to the native pitch detector.
  ///
  /// If the engine identifies a pitched note, the detected note name
  /// is emitted on [chordStream].
  void processAudioFrame(Float32List samples) {
    assert(
      !_controller.isClosed,
      'processAudioFrame called after dispose().',
    );
    assert(
      samples.length <= _frameSize,
      'samples.length (${samples.length}) exceeds frameSize ($_frameSize).',
    );
    _persistentBuffer.asTypedList(samples.length).setAll(0, samples);
    final result = _nativeProcess(_handle, _persistentBuffer, samples.length);
    if (result.pitched != 0) {
      // Decode null-terminated ASCII note name (e.g. "A4\0\0\0\0\0\0").
      final bytes = <int>[];
      for (int i = 0; i < 8; i++) {
        final b = result.noteName[i];
        if (b == 0) break;
        bytes.add(b);
      }
      final noteName = String.fromCharCodes(bytes);
      _controller.add(noteName);
      _pitchController.add(PitchResult(
        noteName: noteName,
        frequency: result.frequency,
        centsOffset: result.centsOffset,
        midiNote: result.midiNote,
      ));
    }
  }

  /// Requests microphone permission and starts streaming audio from the
  /// default input device into the native pitch detector.
  ///
  /// Returns `true` if capture started successfully, or `false` if microphone
  /// permission was denied.
  Future<bool> startCapture() async {
    if (!await _recorder.hasPermission()) return false;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: defaultSampleRate,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen(_onAudioChunk);
    return true;
  }

  /// Converts an incoming PCM-16 little-endian [chunk] to float samples,
  /// buffers them, and dispatches complete [_frameSize]-sample frames to
  /// [processAudioFrame].
  void _onAudioChunk(Uint8List chunk) {
    for (int i = 0; i + 1 < chunk.length; i += 2) {
      int s = chunk[i] | (chunk[i + 1] << 8);
      if (s >= 0x8000) s -= 0x10000; // sign-extend int16
      _sampleBuffer.add(s / 32768.0);
    }
    while (_sampleBuffer.length >= _frameSize) {
      processAudioFrame(
        Float32List.fromList(_sampleBuffer.sublist(0, _frameSize)),
      );
      _sampleBuffer.removeRange(0, _frameSize);
    }
  }

  /// Releases the native handle and closes [chordStream].
  void dispose() {
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop().ignore();
    _recorder.dispose();
    _sampleBuffer.clear();
    _nativeDestroy(_handle);
    malloc.free(_persistentBuffer);
    _controller.close();
    _pitchController.close();
  }

}
