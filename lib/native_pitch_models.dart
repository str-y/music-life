part of 'native_pitch_bridge.dart';

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

class TunerAnalysisFrame {
  const TunerAnalysisFrame({
    required this.bins,
  });

  final List<double> bins;
}

// ── Error handling ────────────────────────────────────────────────────────────

/// Callback invoked when an unhandled error occurs in the background processing.
typedef FfiErrorHandler = void Function(Object error, StackTrace stack);

// ── Isolate support ───────────────────────────────────────────────────────────

class NativeIsolateFailure implements Exception {
  const NativeIsolateFailure({
    required this.code,
    required this.phase,
    required this.message,
  });

  final String code;
  final String phase;
  final String message;

  @override
  String toString() => '[native-isolate:$code][$phase] $message';
}

class NativeIsolateMetrics {
  const NativeIsolateMetrics({
    this.lastHeartbeatLatency = Duration.zero,
    this.lastHeartbeatRoundTrip = Duration.zero,
    this.averageHeartbeatRoundTrip = Duration.zero,
    this.maxHeartbeatRoundTrip = Duration.zero,
    this.heartbeatSamples = 0,
    this.bufferedSamples = 0,
    this.peakBufferedSamples = 0,
    this.bufferUtilization = 0,
    this.peakBufferUtilization = 0,
    this.framesProcessed = 0,
    this.lastFrameProcessingTime = Duration.zero,
    this.averageFrameProcessingTime = Duration.zero,
    this.maxFrameProcessingTime = Duration.zero,
    this.lastChunkSampleCount = 0,
    this.bufferBacklogEvents = 0,
    this.lastUpdatedAtMicros = 0,
  });

  final Duration lastHeartbeatLatency;
  final Duration lastHeartbeatRoundTrip;
  final Duration averageHeartbeatRoundTrip;
  final Duration maxHeartbeatRoundTrip;
  final int heartbeatSamples;
  final int bufferedSamples;
  final int peakBufferedSamples;
  final double bufferUtilization;
  final double peakBufferUtilization;
  final int framesProcessed;
  final Duration lastFrameProcessingTime;
  final Duration averageFrameProcessingTime;
  final Duration maxFrameProcessingTime;
  final int lastChunkSampleCount;
  final int bufferBacklogEvents;
  final int lastUpdatedAtMicros;

  NativeIsolateMetrics copyWith({
    Duration? lastHeartbeatLatency,
    Duration? lastHeartbeatRoundTrip,
    Duration? averageHeartbeatRoundTrip,
    Duration? maxHeartbeatRoundTrip,
    int? heartbeatSamples,
    int? bufferedSamples,
    int? peakBufferedSamples,
    double? bufferUtilization,
    double? peakBufferUtilization,
    int? framesProcessed,
    Duration? lastFrameProcessingTime,
    Duration? averageFrameProcessingTime,
    Duration? maxFrameProcessingTime,
    int? lastChunkSampleCount,
    int? bufferBacklogEvents,
    int? lastUpdatedAtMicros,
  }) {
    return NativeIsolateMetrics(
      lastHeartbeatLatency:
          lastHeartbeatLatency ?? this.lastHeartbeatLatency,
      lastHeartbeatRoundTrip:
          lastHeartbeatRoundTrip ?? this.lastHeartbeatRoundTrip,
      averageHeartbeatRoundTrip:
          averageHeartbeatRoundTrip ?? this.averageHeartbeatRoundTrip,
      maxHeartbeatRoundTrip:
          maxHeartbeatRoundTrip ?? this.maxHeartbeatRoundTrip,
      heartbeatSamples: heartbeatSamples ?? this.heartbeatSamples,
      bufferedSamples: bufferedSamples ?? this.bufferedSamples,
      peakBufferedSamples: peakBufferedSamples ?? this.peakBufferedSamples,
      bufferUtilization: bufferUtilization ?? this.bufferUtilization,
      peakBufferUtilization:
          peakBufferUtilization ?? this.peakBufferUtilization,
      framesProcessed: framesProcessed ?? this.framesProcessed,
      lastFrameProcessingTime:
          lastFrameProcessingTime ?? this.lastFrameProcessingTime,
      averageFrameProcessingTime:
          averageFrameProcessingTime ?? this.averageFrameProcessingTime,
      maxFrameProcessingTime:
          maxFrameProcessingTime ?? this.maxFrameProcessingTime,
      lastChunkSampleCount: lastChunkSampleCount ?? this.lastChunkSampleCount,
      bufferBacklogEvents: bufferBacklogEvents ?? this.bufferBacklogEvents,
      lastUpdatedAtMicros: lastUpdatedAtMicros ?? this.lastUpdatedAtMicros,
    );
  }
}

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
    required this.code,
    required this.phase,
    required this.message,
    required this.stack,
  });
  final String code;
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
  const IsolateHeartbeatPing(this.token, this.sentAtMicros);
  final int token;
  final int sentAtMicros;
}

class IsolateHeartbeatPong {
  const IsolateHeartbeatPong({
    required this.token,
    required this.pingSentAtMicros,
    required this.receivedAtMicros,
    required this.sentAtMicros,
  });
  final int token;
  final int pingSentAtMicros;
  final int receivedAtMicros;
  final int sentAtMicros;
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

class TransferableTunerAnalysisFrame {
  const TransferableTunerAnalysisFrame(this.data, this.binCount);
  final TransferableTypedData data;
  final int binCount;

  TunerAnalysisFrame materialize() {
    final buffer = data.materialize();
    final maxBins = buffer.lengthInBytes ~/ Float32List.bytesPerElement;
    final boundedBinCount = math.min(binCount, maxBins);
    final bins = buffer
        .asFloat32List(0, boundedBinCount)
        .map((value) => value)
        .toList(growable: false);
    return TunerAnalysisFrame(bins: bins);
  }
}

class IsolateShutdownHandle {
  const IsolateShutdownHandle(this.isolate, this.exitPort);
  final Isolate? isolate;
  final ReceivePort? exitPort;
}
