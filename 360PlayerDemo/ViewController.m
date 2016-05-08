//
//  ViewController.m
//  360PlayerDemo
//
//  Created by heyunpeng on 16/5/8.
//  Copyright © 2016年 heyunpeng. All rights reserved.
//

#import "ViewController.h"
#import "PlayerViewController.h"

static void *RateObservationContext = &RateObservationContext;
static void *StatusObservationContext = &StatusObservationContext;

@interface PlayerViewController () {
    VideoPlayerViewController *glViewController;
    AVPlayerItemVideoOutput* videoOutput;
    AVPlayer* player;
    AVPlayerItem* playerItem;
    dispatch_queue_t videoOutputQueue;
}

@property (strong, nonatomic) IBOutlet UIView *playerControlBackgroundView;
@property (strong, nonatomic) IBOutlet UIButton *playButton;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"demo" ofType:@"mp4"];
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    
    [self setupVideoPlaybackForURL:url];
    [self configureGLKView];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (void)viewWillAppear:(BOOL)animated {
    [self updatePlayButton];
}

- (CVPixelBufferRef)getPixelBuffer {
    CVPixelBufferRef pixelBuffer = [videoOutput copyPixelBufferForItemTime:[playerItem currentTime] itemTimeForDisplay:nil];
    
    return pixelBuffer;
}

- (void)setupVideoPlaybackForURL:(NSURL*)url {
    NSDictionary *pixelBuffAttributes = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
    videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixelBuffAttributes];
    videoOutputQueue = dispatch_queue_create("PlayerViewControllerQueue", DISPATCH_QUEUE_SERIAL);
    
    [videoOutput setDelegate:self queue:videoOutputQueue];
    
    player = [[AVPlayer alloc] init];
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    
    NSArray *requestedKeys = [NSArray arrayWithObjects:@"tracks", @"playable", nil];
    [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        dispatch_async( dispatch_get_main_queue(),
                       ^{
                           NSError* error = nil;
                           AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
                           if (status == AVKeyValueStatusLoaded) {
                               playerItem = [AVPlayerItem playerItemWithAsset:asset];
                               [playerItem addOutput:videoOutput];
                               [player replaceCurrentItemWithPlayerItem:playerItem];
                               [videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:0.03];
                               
                               
                               [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:StatusObservationContext];
                               
                               [player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:RateObservationContext];
                           }
                       });
    }];
}

- (void)configureGLKView {
    glViewController = [[VideoPlayerViewController alloc] init];
    glViewController.videoPlayerController = self;
    glViewController.view.frame = self.view.bounds;
    
    [self.view insertSubview:glViewController.view belowSubview:_playerControlBackgroundView];
    [self addChildViewController:glViewController];
    
    [glViewController didMoveToParentViewController:self];
}

- (IBAction)playButtonTouched:(id)sender {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    if ([self isPlaying]) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)updatePlayButton {
    [_playButton setImage:[UIImage imageNamed:[self isPlaying] ? @"playback_pause" : @"playback_play"] forState:UIControlStateNormal];
}

- (void)play {
    if ([self isPlaying])
        return;
    
    [self updatePlayButton];
    [player play];
}

- (void)pause {
    if (![self isPlaying])
        return;
    
    [self updatePlayButton];
    [player pause];
}

- (void)observeValueForKeyPath:(NSString*)path ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if (context == StatusObservationContext) {
        [self updatePlayButton];
        
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status) {
            case AVPlayerStatusUnknown: {
                self.playButton.enabled = NO;
                break;
            }
            case AVPlayerStatusReadyToPlay: {
                self.playButton.enabled = YES;
                break;
            }
            case AVPlayerStatusFailed: {
                break;
            }
        }
    } else if (context == RateObservationContext) {
        [self updatePlayButton];
    } else {
        [super observeValueForKeyPath:path ofObject:object change:change context:context];
    }
}

- (BOOL)isPlaying {
    return [player rate] != 0.f;
}

@end