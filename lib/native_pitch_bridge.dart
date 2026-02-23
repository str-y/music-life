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

// ── Chord inference ───────────────────────────────────────────────────────────

const _kNoteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

// Pitch classes (relative to C) that belong to the C-major diatonic scale.
const _kMajorScale = {0, 2, 4, 5, 7, 9, 11};

// Diatonic degrees that carry a minor quality (D, E, A).
const _kMinorDegrees = {2, 4, 9};

// Pitch class of B, which receives a half-diminished (m7♭5) label.
const _kHalfDiminishedDegree = 11;

/// Derives a chord label from a single detected MIDI note.
///
/// This is a simplified heuristic mapping suitable for monophonic pitch
/// detection.  Diatonic-scale notes map to maj7 or m7 chords; chromatic
/// notes map to dominant-7 chords.  Replace with a polyphonic
/// chord-detection algorithm when multi-note analysis is available.
String _deriveChordLabel(int midiNote) {
  final noteClass = midiNote % 12;
  final root = _kNoteNames[noteClass];

  if (noteClass == _kHalfDiminishedDegree) return '${root}m7♭5'; // B → half-diminished
  if (_kMajorScale.contains(noteClass)) {
    return _kMinorDegrees.contains(noteClass) ? '${root}m7' : '${root}maj7';
  }
  return '${root}7'; // chromatic → dominant 7
}

// ── Bridge ────────────────────────────────────────────────────────────────────

/// Bridges the native C++ pitch-detection engine to a Dart [Stream].
///
/// Create one instance per active recording session.  Feed audio frames via
/// [processAudioFrame] (called by the platform audio-capture layer), and
/// listen to [chordStream] to receive chord labels in real time.
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

  /// Emits a chord label each time the native engine detects a pitched note.
  Stream<String> get chordStream => _controller.stream;

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
  /// If the engine identifies a pitched note, the corresponding chord label
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
      _controller.add(_deriveChordLabel(result.midiNote));
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
  }
}
