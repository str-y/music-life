import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
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

// ── Isolate support ───────────────────────────────────────────────────────────

/// Configuration passed to the background audio-processing isolate on spawn.
class _IsolateSetup {
  const _IsolateSetup({
    required this.resultPort,
    required this.sampleRate,
    required this.frameSize,
    required this.threshold,
  });

  /// Port on which the background isolate sends results (and its own
  /// [SendPort] as the very first message).
  final SendPort resultPort;
  final int sampleRate;
  final int frameSize;
  final double threshold;
}

/// Entry point for the background isolate that owns all FFI resources.
///
/// Protocol (background → main):
/// - First message: own [SendPort] (ready), or `null` (initialisation failed).
/// - Subsequent messages: `Map<String, Object>` with keys
///   `noteName`, `frequency`, `centsOffset`, `midiNote`.
///
/// Protocol (main → background, via the returned [SendPort]):
/// - [Uint8List]: raw PCM-16 LE audio chunk to convert and process.
/// - [Float32List]: pre-converted float frame to process directly.
/// - `null`: shutdown signal — free native resources and exit.
void _audioProcessingIsolate(_IsolateSetup setup) {
  final DynamicLibrary lib;
  try {
    lib = _loadNativeLib();
  } catch (_) {
    setup.resultPort.send(null);
    return;
  }

  final create = lib.lookupFunction<_MLCreateNative, _MLCreateDart>(
      'ml_pitch_detector_create');
  final process = lib.lookupFunction<_MLProcessNative, _MLProcessDart>(
      'ml_pitch_detector_process');
  final destroy = lib.lookupFunction<_MLDestroyNative, _MLDestroyDart>(
      'ml_pitch_detector_destroy');

  final handle = create(setup.sampleRate, setup.frameSize, setup.threshold);
  if (handle == nullptr) {
    setup.resultPort.send(null);
    return;
  }

  final buffer = malloc.allocate<Float>(setup.frameSize * sizeOf<Float>());

  /// Accumulator for partial PCM-16 frames between incoming chunks.
  final sampleBuf = <double>[];

  /// Runs the native detector on [frame] and forwards any pitch result.
  void processFrame(Float32List frame) {
    buffer.asTypedList(frame.length).setAll(0, frame);
    final result = process(handle, buffer, frame.length);
    if (result.pitched != 0) {
      // Decode null-terminated ASCII note name (e.g. "A4\0\0\0\0\0\0").
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
  }

  final port = ReceivePort();
  setup.resultPort.send(port.sendPort); // Signal: ready.

  port.listen((msg) {
    if (msg == null) {
      // Graceful shutdown: free native resources then let the isolate exit.
      destroy(handle);
      malloc.free(buffer);
      port.close();
      return;
    }

    if (msg is Uint8List) {
      // Convert PCM-16 little-endian to normalised floats and accumulate.
      for (int i = 0; i + 1 < msg.length; i += 2) {
        int s = msg[i] | (msg[i + 1] << 8);
        if (s >= 0x8000) s -= 0x10000; // sign-extend int16
        sampleBuf.add(s / 32768.0);
      }
      while (sampleBuf.length >= setup.frameSize) {
        processFrame(
            Float32List.fromList(sampleBuf.sublist(0, setup.frameSize)));
        sampleBuf.removeRange(0, setup.frameSize);
      }
    } else if (msg is Float32List) {
      // Pre-converted float frame from processAudioFrame().
      processFrame(msg);
    }
  });
}

// ── Bridge ────────────────────────────────────────────────────────────────────

/// Bridges the native C++ pitch-detection engine to a Dart [Stream].
///
/// Create one instance per active recording session.  Call [startCapture] to
/// begin microphone capture; audio processing runs entirely on a background
/// isolate so the UI thread is never blocked.  Listen to [chordStream] or
/// [pitchStream] to receive results in real time.
///
/// Call [dispose] when done to shut down the background isolate and close the
/// streams.
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

  final int _sampleRate;
  final int _frameSize;
  final double _threshold;

  Isolate? _processingIsolate;
  SendPort? _audioSendPort;
  ReceivePort? _resultPort;
  StreamSubscription<dynamic>? _resultSub;

  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// Emits a chord label each time the native engine detects a pitched note.
  Stream<String> get chordStream => _controller.stream;

  final StreamController<PitchResult> _pitchController =
      StreamController<PitchResult>.broadcast();

  /// Emits a [PitchResult] each time the native engine detects a pitched note.
  Stream<PitchResult> get pitchStream => _pitchController.stream;

  // ── Audio capture ──────────────────────────────────────────────────────────

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;

  NativePitchBridge({
    int sampleRate = defaultSampleRate,
    int frameSize = defaultFrameSize,
    double threshold = defaultThreshold,
  })  : _sampleRate = sampleRate,
        _frameSize = frameSize,
        _threshold = threshold;

  /// Feed a frame of 32-bit float PCM samples to the native pitch detector.
  ///
  /// The call returns immediately; all processing is performed on the
  /// background isolate.  If the engine identifies a pitched note, the
  /// corresponding chord label is emitted on [chordStream].
  void processAudioFrame(Float32List samples) {
    assert(
      !_controller.isClosed,
      'processAudioFrame called after dispose().',
    );
    assert(
      samples.length <= _frameSize,
      'samples.length (${samples.length}) exceeds frameSize ($_frameSize).',
    );
    _audioSendPort?.send(samples);
  }

  /// Requests microphone permission, spawns the background processing isolate,
  /// and starts streaming audio from the default input device.
  ///
  /// Returns `true` if capture started successfully, or `false` if microphone
  /// permission was denied or the native library could not be initialised.
  Future<bool> startCapture() async {
    if (!await _recorder.hasPermission()) return false;

    final resultPort = ReceivePort();
    _resultPort = resultPort;

    _processingIsolate = await Isolate.spawn(
      _audioProcessingIsolate,
      _IsolateSetup(
        resultPort: resultPort.sendPort,
        sampleRate: _sampleRate,
        frameSize: _frameSize,
        threshold: _threshold,
      ),
    );

    // Wait for the background isolate to confirm it is ready.  The first
    // message is its SendPort (success) or null (initialisation failure).
    final completer = Completer<bool>();
    _resultSub = resultPort.listen((msg) {
      if (!completer.isCompleted) {
        if (msg is SendPort) {
          _audioSendPort = msg;
          completer.complete(true);
        } else {
          completer.complete(false);
        }
        return;
      }
      // Subsequent messages are pitch results from the background isolate.
      if (msg is Map) _onPitchResult(msg);
    });

    final ready = await completer.future;
    if (!ready) {
      // The isolate has already exited cleanly (no active ports left after
      // sending the failure signal), so no kill() is needed.
      _processingIsolate = null;
      _resultSub?.cancel();
      _resultSub = null;
      resultPort.close();
      _resultPort = null;
      return false;
    }

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen(_onAudioChunk);
    return true;
  }

  /// Forwards a raw PCM-16 [chunk] to the background isolate for processing.
  void _onAudioChunk(Uint8List chunk) {
    _audioSendPort?.send(chunk);
  }

  /// Handles a pitch-result [Map] received from the background isolate.
  void _onPitchResult(Map<dynamic, dynamic> msg) {
    if (_controller.isClosed) return;
    final noteName = msg['noteName'];
    final frequency = msg['frequency'];
    final centsOffset = msg['centsOffset'];
    final midiNote = msg['midiNote'];
    if (noteName is! String ||
        frequency is! double ||
        centsOffset is! double ||
        midiNote is! int) {
      return;
    }
    _controller.add(_deriveChordLabel(midiNote));
    _pitchController.add(PitchResult(
      noteName: noteName,
      frequency: frequency,
      centsOffset: centsOffset,
      midiNote: midiNote,
    ));
  }

  /// Shuts down the background isolate and closes [chordStream].
  void dispose() {
    _audioSub?.cancel();
    _audioSub = null;
    _recorder.stop().ignore();
    _recorder.dispose();
    // Send the shutdown signal; the isolate will free native resources and exit.
    _audioSendPort?.send(null);
    _audioSendPort = null;
    _resultSub?.cancel();
    _resultSub = null;
    _resultPort?.close();
    _resultPort = null;
    _processingIsolate = null;
    _controller.close();
    _pitchController.close();
  }
}
