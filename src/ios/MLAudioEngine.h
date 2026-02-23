#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MLAudioInputHandler)(const float* samples, AVAudioFrameCount frameCount);

/// Called when an audio session interruption begins or ends.
///
/// @param began  YES when the interruption started (recording has stopped),
///               NO when the interruption ended (the caller may restart).
typedef void (^MLAudioInterruptionHandler)(BOOL began);

@interface MLAudioEngine : NSObject

- (instancetype)initWithFrameSize:(AVAudioFrameCount)frameSize NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/// Optional block invoked on audio session interruptions.
/// Set before calling -startWithHandler:error: to receive interruption events.
@property(nonatomic, copy, nullable) MLAudioInterruptionHandler interruptionHandler;

- (BOOL)startWithHandler:(MLAudioInputHandler)handler error:(NSError* _Nullable * _Nullable)error;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
