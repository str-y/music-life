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
    // ── Audio session setup ────────────────────────────────────────────────
    // Request recording focus from the OS before touching any audio hardware.
    // Using AVAudioSessionCategoryRecord ensures exclusive microphone access
    // and causes the system to silence any competing audio sessions (e.g.
    // music apps), while AVAudioSessionModeMeasurement minimises built-in
    // signal processing so raw pitch data is preserved.
    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* sessionError = nil;
    if (![session setCategory:AVAudioSessionCategoryRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionAllowBluetooth
                        error:&sessionError]) {
        if (error) *error = sessionError;
        return NO;
    }
    if (![session setActive:YES error:&sessionError]) {
        if (error) *error = sessionError;
        return NO;
    }

    // ── Interruption notifications ─────────────────────────────────────────
    // Remove any prior observer before adding a new one to prevent duplicate
    // registrations if startWithHandler:error: is called more than once.
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:AVAudioSessionInterruptionNotification
                object:session];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_handleAudioSessionInterruption:)
               name:AVAudioSessionInterruptionNotification
             object:session];

    // ── AVAudioEngine tap ──────────────────────────────────────────────────
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
    // ── Tear down notifications ────────────────────────────────────────────
    [[NSNotificationCenter defaultCenter]
        removeObserver:self
                  name:AVAudioSessionInterruptionNotification
                object:[AVAudioSession sharedInstance]];

    [self _stopEngine];

    // ── Release audio focus ────────────────────────────────────────────────
    // Notify other audio sessions that we are done so they can resume.
    [[AVAudioSession sharedInstance]
        setActive:NO
      withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
            error:nil];
}

// ── Private helpers ────────────────────────────────────────────────────────────

/// Removes the input tap and stops the AVAudioEngine.
/// Shared by -stop and -_handleAudioSessionInterruption:.
- (void)_stopEngine {
    [self.engine.inputNode removeTapOnBus:0];
    [self.engine stop];
}

// ── Interruption handler ───────────────────────────────────────────────────────

- (void)_handleAudioSessionInterruption:(NSNotification*)notification {
    NSDictionary* info = notification.userInfo;
    if (!info) return;

    AVAudioSessionInterruptionType type =
        (AVAudioSessionInterruptionType)[info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];

    if (type == AVAudioSessionInterruptionTypeBegan) {
        // An interruption (e.g. phone call) has started.  Stop capturing
        // immediately so we don't hold the microphone while inactive.
        [self _stopEngine];
        if (self.interruptionHandler) {
            self.interruptionHandler(YES);
        }
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        // The interruption is over; inform the caller so it can decide
        // whether to restart capture.
        if (self.interruptionHandler) {
            self.interruptionHandler(NO);
        }
    }
}

@end
