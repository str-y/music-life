#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    BOOL pitched;
    float frequency;
    float probability;
    int midiNote;
    float centsOffset;
} MLPitchResult;

@interface MLPitchDetector : NSObject

- (nullable instancetype)initWithSampleRate:(int)sampleRate
                                   frameSize:(int)frameSize
                                   threshold:(float)threshold
                            referencePitchHz:(float)referencePitchHz NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)reset;
- (BOOL)setReferencePitch:(float)referencePitchHz;
- (MLPitchResult)processSamples:(const float*)samples count:(int)count;

@end

NS_ASSUME_NONNULL_END
