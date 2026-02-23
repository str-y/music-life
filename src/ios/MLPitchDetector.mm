#import "MLPitchDetector.h"

#include "../pitch_detection/pitch_detector.h"

#include <memory>

@interface MLPitchDetector () {
    std::unique_ptr<music_life::PitchDetector> _detector;
}
@end

@implementation MLPitchDetector

- (nullable instancetype)initWithSampleRate:(int)sampleRate
                                   frameSize:(int)frameSize
                                   threshold:(float)threshold
                            referencePitchHz:(float)referencePitchHz {
    self = [super init];
    if (!self) return nil;

    try {
        _detector = std::make_unique<music_life::PitchDetector>(
            sampleRate, frameSize, threshold, referencePitchHz
        );
    } catch (...) {
        return nil;
    }

    return self;
}

- (void)reset {
    if (_detector) {
        _detector->reset();
    }
}

- (BOOL)setReferencePitch:(float)referencePitchHz {
    if (!_detector) return NO;
    try {
        _detector->set_reference_pitch(referencePitchHz);
        return YES;
    } catch (...) {
        return NO;
    }
}

- (MLPitchResult)processSamples:(const float*)samples count:(int)count {
    MLPitchResult result = {NO, 0.0f, 0.0f, 0, 0.0f};
    if (!_detector || samples == nullptr || count <= 0) {
        return result;
    }

    const music_life::PitchDetector::Result nativeResult = _detector->process(samples, count);
    result.pitched = nativeResult.pitched ? YES : NO;
    result.frequency = nativeResult.frequency;
    result.probability = nativeResult.probability;
    result.midiNote = nativeResult.midi_note;
    result.centsOffset = nativeResult.cents_offset;
    return result;
}

@end
