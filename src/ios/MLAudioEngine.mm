#import "MLAudioEngine.h"

@interface MLAudioEngine ()

@property(nonatomic, strong) AVAudioEngine* engine;
@property(nonatomic, assign) AVAudioFrameCount frameSize;

@end

@implementation MLAudioEngine

- (instancetype)initWithFrameSize:(AVAudioFrameCount)frameSize {
    self = [super init];
    if (!self) return nil;
    _engine = [[AVAudioEngine alloc] init];
    _frameSize = frameSize;
    return self;
}

- (BOOL)startWithHandler:(MLAudioInputHandler)handler error:(NSError* _Nullable * _Nullable)error {
    AVAudioInputNode* inputNode = self.engine.inputNode;
    AVAudioFormat* inputFormat = [inputNode outputFormatForBus:0];

    [inputNode removeTapOnBus:0];
    [inputNode installTapOnBus:0
                    bufferSize:self.frameSize
                        format:inputFormat
                         block:^(AVAudioPCMBuffer* buffer, AVAudioTime* when) {
        (void)when;
        if (!handler || !buffer.floatChannelData || buffer.format.channelCount == 0 || buffer.frameLength == 0) {
            return;
        }
        const float* channelData = buffer.floatChannelData[0];
        if (!channelData) {
            return;
        }
        handler(channelData, buffer.frameLength);
    }];

    [self.engine prepare];
    return [self.engine startAndReturnError:error];
}

- (void)stop {
    [self.engine.inputNode removeTapOnBus:0];
    [self.engine stop];
}

@end
