import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/app_constants.dart';
import 'package:music_life/native_pitch_bridge.dart';

void main() {
  group('AppConstants', () {
    group('audio engine', () {
      test('audioFrameSize is a positive power of two', () {
        expect(AppConstants.audioFrameSize, greaterThan(0));
        expect(
          AppConstants.audioFrameSize & (AppConstants.audioFrameSize - 1),
          0,
          reason: 'frame size should be a power of two',
        );
      });

      test('audioSampleRate is a standard rate', () {
        const standardRates = [8000, 16000, 22050, 44100, 48000];
        expect(standardRates, contains(AppConstants.audioSampleRate));
      });

      test('pitchDetectionThreshold is between 0 and 1', () {
        expect(AppConstants.pitchDetectionThreshold, greaterThan(0.0));
        expect(AppConstants.pitchDetectionThreshold, lessThan(1.0));
      });
    });

    group('idle timeout', () {
      test('listeningIdleTimeout is positive', () {
        expect(AppConstants.listeningIdleTimeout, greaterThan(Duration.zero));
      });
    });

    group('tuner UI thresholds', () {
      test('inTuneThreshold is less than warningThreshold', () {
        expect(
          AppConstants.tunerInTuneThresholdCents,
          lessThan(AppConstants.tunerWarningThresholdCents),
        );
      });

      test('thresholds are positive', () {
        expect(AppConstants.tunerInTuneThresholdCents, greaterThan(0.0));
        expect(AppConstants.tunerWarningThresholdCents, greaterThan(0.0));
      });
    });

    group('metronome BPM range', () {
      test('minBpm is less than maxBpm', () {
        expect(AppConstants.metronomeMinBpm,
            lessThan(AppConstants.metronomeMaxBpm));
      });

      test('minBpm and maxBpm are positive', () {
        expect(AppConstants.metronomeMinBpm, greaterThan(0));
        expect(AppConstants.metronomeMaxBpm, greaterThan(0));
      });
    });

    group('chord history', () {
      test('chordHistoryMaxEntries is positive', () {
        expect(AppConstants.chordHistoryMaxEntries, greaterThan(0));
      });
    });
  });

  group('NativePitchBridge default constants', () {
    test('defaultFrameSize matches AppConstants', () {
      expect(
          NativePitchBridge.defaultFrameSize, AppConstants.audioFrameSize);
    });

    test('defaultSampleRate matches AppConstants', () {
      expect(
          NativePitchBridge.defaultSampleRate, AppConstants.audioSampleRate);
    });

    test('defaultThreshold matches AppConstants', () {
      expect(NativePitchBridge.defaultThreshold,
          AppConstants.pitchDetectionThreshold);
    });
  });
}
