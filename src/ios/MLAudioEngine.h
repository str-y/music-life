#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MLAudioInputHandler)(const float* samples, AVAudioFrameCount frameCount);

@interface MLAudioEngine : NSObject

- (instancetype)initWithFrameSize:(AVAudioFrameCount)frameSize NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (BOOL)startWithHandler:(MLAudioInputHandler)handler error:(NSError* _Nullable * _Nullable)error;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
