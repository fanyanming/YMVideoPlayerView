//
//  YMVideoPlayerView.m
//  CrazyBeeFitness
//
//  Created by 彦明 on 2017/7/19.
//  Copyright © 2017年 siunion. All rights reserved.
//

typedef enum : NSUInteger {
    YMVideoPlayerSizeStatusNormal,
    YMVideoPlayerSizeStatusFull,
    YMVideoPlayerSizeStatusSwitching,
} YMVideoPlayerSizeStatus;


#import "YMVideoPlayerView.h"
#import <AVFoundation/AVFoundation.h> 
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#import "Masonry/Masonry.h"

@interface YMVideoPlayerView()

@property (nonatomic, strong) AVPlayer *videoPlayer;
@property (nonatomic, strong) AVURLAsset *videoAsset;
@property (nonatomic, strong) AVPlayerItem *videoItem;
@property (nonatomic, weak) AVPlayerLayer *playerLayer;
@property (nonatomic, weak) UIView *playerControlView;
@property (nonatomic, assign) CGRect framNormal;
@property (nonatomic, assign) YMVideoPlayerSizeStatus sizeStatus;
@property (nonatomic, weak) UIView *movieViewParentView;
@property (nonatomic, weak) UIButton *playButton;
@property (nonatomic, weak) UIButton *playAndPause;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, weak) UILabel *timeInfoLabel;
@property (nonatomic, weak) UISlider *positionSlider;
@property (nonatomic, weak) UIProgressView *timeProgress;
@property (nonatomic, assign) BOOL isVideoPaused;
@property (strong, nonatomic) id timerObserver;
@property (nonatomic, assign) NSInteger orientationBefore;
@property (nonatomic, weak) UIView *bottomBar;
@end
@implementation YMVideoPlayerView
- (instancetype)initWithFrame:(CGRect)frame UrlString:(NSString *)urlString {
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    if (CGRectEqualToRect(frame, CGRectZero)) {
        frame = CGRectMake(0, 0, screenBounds.size.width, screenBounds.size.height * 0.562);
    }
    
    if (self = [super initWithFrame:frame]) {
        [self setupWithUrlString:urlString];
        // 默认屏幕方向
        self.orientationBefore = UIDeviceOrientationPortrait;
        // 获取用户旋转手机的动作
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
        
    }
    
    return self;
}
//- (instancetype)initWithFrame:(CGRect)frame {
//    if (self = [super initWithFrame:frame]) {
//        [self setup];
//        // 默认屏幕方向
//        self.orientationBefore = UIDeviceOrientationPortrait;
//        // 获取用户旋转手机的动作
//        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
//        
//    }
//    
//    return self;
//}

- (void)orientationChanged:(NSNotification *)note {
    UIDeviceOrientation  orient = [UIDevice currentDevice].orientation;
    switch (orient) {
        case UIDeviceOrientationPortrait:
            CFLog(@"竖直");
            [self exitFullscreen];
            break;
        case UIDeviceOrientationLandscapeLeft:
            CFLog(@"向左");
            [self toFullScreenWithOrietation:(UIDeviceOrientationLandscapeLeft)];
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            CFLog(@"颠倒");
            break;
        case UIDeviceOrientationLandscapeRight:
            CFLog(@"向右");
            [self toFullScreenWithOrietation:(UIDeviceOrientationLandscapeRight)];
            break;
        default:
            break;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"status"]) {
        NSInteger status = [change[NSKeyValueChangeNewKey] integerValue];
        if (status == AVPlayerItemStatusReadyToPlay) {
            CFLog(@"准备就绪");
            [self setupTimeBar];
        
        }
        return;
    }
    
    else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {  //监听播放器的下载进度
        // 计算缓冲进度
        NSArray *loadedTimeRanges = [_videoItem loadedTimeRanges];
        CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
        float startSeconds = CMTimeGetSeconds(timeRange.start);
        float durationSeconds = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
        CMTime duration = _videoItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        [self.timeProgress setProgress:timeInterval / totalDuration animated:NO];
    }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        if (_videoItem.playbackLikelyToKeepUp == NO) {
            CFLog(@"要卡了， 我的哥");
            [self.videoPlayer pause];
        }else {
            CFLog(@"顺畅了， 我的哥");
            [self.videoPlayer play];
        }
    }else if([keyPath isEqualToString:@"rate"]) {
        if (self.videoPlayer.rate != 0) {
            self.playButton.hidden = YES;
            self.playAndPause.selected = YES;
        }
    }
}

- (void)setupWithUrlString:(NSString *)urlString {
    self.backgroundColor = [UIColor clearColor];
    
    // https://static1.keepcdn.com/video/032bd6d46a0eff6e7fc7ce72a467fc2bac868765.mp4
    // http://video.jiecao.fm/8/17/%E6%8A%AB%E8%90%A8.mp4
    // 创建视频播放内容
    self.videoAsset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:urlString] options:nil];
    self.videoItem = [AVPlayerItem playerItemWithAsset:self.videoAsset];
    [_videoItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:(NSKeyValueObservingOptionNew) context:nil];
    [_videoItem addObserver:self forKeyPath:@"status" options:(NSKeyValueObservingOptionNew) context:nil];
    [_videoItem addObserver:self forKeyPath:@"loadedTimeRanges" options:(NSKeyValueObservingOptionNew) context:nil];
    self.videoPlayer = [[AVPlayer alloc]initWithPlayerItem:self.videoItem];
    
    [self.videoPlayer addObserver:self forKeyPath:@"rate" options:(NSKeyValueObservingOptionNew) context:nil];
    //创建视频显示的图层
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];
    self.playerLayer.frame = self.bounds;
    [self.layer addSublayer:self.playerLayer];
    
    // 创建视频控制的view
    UIView *playerControlView = [[UIView alloc] initWithFrame:self.bounds];
    playerControlView.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
    [self addSubview:playerControlView];
    _playerControlView = playerControlView;
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(screenTapped:)];
    [_playerControlView addGestureRecognizer:tapGesture];
    
    // 播放按钮
    UIButton *playButton = [[UIButton alloc] init];
    [playButton setImage:[UIImage imageNamed:@"play_150"] forState:(UIControlStateNormal)];
    [playerControlView addSubview:playButton];
    _playButton = playButton;
    [playButton makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(playerControlView);
        make.height.width.equalTo(60);
    }];
    [playButton addTarget:self action:@selector(play:) forControlEvents:(UIControlEventTouchUpInside)];
    
    UIView *bottomBar = [[UIView alloc] init];
    
    bottomBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0];
    [playerControlView addSubview:bottomBar];
    _bottomBar = bottomBar;
    [bottomBar makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.equalTo(playerControlView);
        make.height.equalTo(barH);
    }];

    
    UIButton *playAndPause = [UIButton buttonWithType:(UIButtonTypeCustom)];
    [playAndPause setImageEdgeInsets:UIEdgeInsetsMake(0, -13, 0, 0)];
    playAndPause.imageView.contentMode = UIViewContentModeLeft;
    [playAndPause setImage:[UIImage imageNamed:@"play_white"] forState:(UIControlStateNormal)];
    [playAndPause setImage:[UIImage imageNamed:@"pause_white"] forState:(UIControlStateSelected)];
    [bottomBar addSubview:playAndPause];
    [playAndPause addTarget:self action:@selector(playAndPauseClicked:) forControlEvents:(UIControlEventTouchUpInside)];
    _playAndPause = playAndPause;
    [playAndPause makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(bottomBar).offset(margin);
        make.centerY.top.equalTo(bottomBar);
        make.width.equalTo(30);
    }];
    
    
    // 进度
    UILabel *timeInfoLabel = [[UILabel alloc] init];
    timeInfoLabel.textColor = CFWhiteColor;
    timeInfoLabel.text = @"00:00:00/00:00:00";
    timeInfoLabel.font = [UIFont systemFontOfSize:10];
    [bottomBar addSubview:timeInfoLabel];
    _timeInfoLabel = timeInfoLabel;
    [timeInfoLabel makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(bottomBar);
        make.left.equalTo(playAndPause.right);
    }];
    
    
    // 全屏按钮
    UIButton *switchSizeButton = [[UIButton alloc] init];
    [switchSizeButton setImageEdgeInsets:UIEdgeInsetsMake(0, 0, 0, -20)];
    switchSizeButton.imageView.contentMode = UIViewContentModeLeft;

    [switchSizeButton setImage:[UIImage imageNamed:@"fullSize"] forState:(UIControlStateNormal)];
    [switchSizeButton setImage:[UIImage imageNamed:@"normalSize"] forState:(UIControlStateSelected)];
    [bottomBar addSubview:switchSizeButton];
    [switchSizeButton makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.top.equalTo(bottomBar);
        make.right.equalTo(bottomBar).offset(-margin);
        make.width.equalTo(switchSizeButton.height);
    }];
    
    [switchSizeButton addTarget:self action:@selector(switchSizeButtonClicked:) forControlEvents:(UIControlEventTouchUpInside)];
    
    UIProgressView *timeProgress = [[UIProgressView alloc] init];
    timeProgress.trackTintColor = [UIColor colorWithWhite:0 alpha:0.4];
    timeProgress.progressTintColor = [UIColor lightGrayColor];
    [bottomBar addSubview:timeProgress];
    _timeProgress = timeProgress;

    UISlider *positionSlider = [[UISlider alloc] init];
    positionSlider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0];
    positionSlider.minimumValue = 0;
    [positionSlider setThumbImage:[UIImage imageNamed:@"sliderThumb"] forState:(UIControlStateNormal)];
    [positionSlider setMinimumTrackTintColor:CFThemeYellow];
    [bottomBar addSubview:positionSlider];
    _positionSlider = positionSlider;
    [_positionSlider addTarget:self action:@selector(sliderDidSlide:) forControlEvents:(UIControlEventValueChanged)];
    [_positionSlider addTarget:self action:@selector(sliderDidEndSlider) forControlEvents:(UIControlEventTouchCancel)];
    [positionSlider makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(playAndPause.right).offset(100);
        make.height.equalTo(30);
        make.right.equalTo(switchSizeButton.left);
        make.centerY.equalTo(bottomBar);
    }];
    
    [timeProgress makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(playAndPause.right).offset(100);
        make.height.equalTo(2.0);
        make.right.equalTo(switchSizeButton.left);
        make.centerY.equalTo(bottomBar).offset(0.5);
    }];

    
//    [self setupTimeBar];
    
}

#pragma mark - action controls
- (void)sliderDidSlide:(UISlider *)sender {
    CFLog(@"value: %f", sender.value);
    [_videoPlayer pause];
    [_videoItem seekToTime:CMTimeMakeWithSeconds(sender.value, 1) completionHandler:^(BOOL finished) {
//        [_videoPlayer play];
    }];
}

- (void)sliderDidEndSlider {
    CFLog(@"滑动结束");
    if (_isVideoPaused == NO) {
        [_videoPlayer play];
    }
}
- (void)playAndPauseClicked:(UIButton *)sender {
    sender.selected = !sender.selected;
    _isVideoPaused = sender.selected;
    if (sender.selected == YES) {
        [self.videoPlayer play];
        _playButton.hidden = YES;
    }else {
        [self.videoPlayer pause];
        _playButton.hidden = NO;
    }
}


- (void)screenTapped:(UITapGestureRecognizer *)gesture {
    
    
    if (CGRectContainsPoint(self.bottomBar.frame, [gesture locationInView:self.playerControlView])) {
        return;
    }
    
    [self.videoPlayer pause];
    _playButton.hidden = NO;
    _playAndPause.selected = _playButton.hidden;
}

- (void)switchSizeButtonClicked:(UIButton *)sender {
    sender.selected = !sender.selected;
    switch (_sizeStatus) {
        case YMVideoPlayerSizeStatusNormal:
            [self toFullScreenWithOrietation:(UIDeviceOrientationLandscapeLeft)];
            break;
        case YMVideoPlayerSizeStatusFull:
            [self exitFullscreen];
            break;
        default:
            break;
    }
}

- (void)play:(UIButton *)sender {
    [self.videoPlayer play];
    sender.hidden = YES;
    _playAndPause.selected = sender.hidden;
}


- (void)toFullScreenWithOrietation:(UIDeviceOrientation)orientation {
    
//    CFLog(@"1%@", NSStringFromCGRect(self.frame));
//    if (self.sizeStatus) {
//        return;
//    }
    
    
    self.sizeStatus = YMVideoPlayerSizeStatusSwitching;
    
    /*
     * 记录进入全屏前的parentView和frame
     */
    if (self.orientationBefore == UIDeviceOrientationPortrait) {
        self.movieViewParentView = self.superview;
        self.framNormal = self.frame;
        // 记录本次屏幕方向
        self.orientationBefore = orientation;

    }
    
    
    /*
     * movieView移到window上
     */
    CGRect rectInWindow = [self convertRect:self.bounds toView:[UIApplication sharedApplication].keyWindow];
    [self removeFromSuperview];
    self.frame = rectInWindow;
    
    [[UIApplication sharedApplication].keyWindow addSubview:self];
    [[UIApplication sharedApplication].keyWindow setWindowLevel:(UIWindowLevelStatusBar + 1)];
    /*
     * 执行动画
     */
    [UIView animateWithDuration:0.5 animations:^{
        self.transform = CGAffineTransformMakeRotation(orientation == UIDeviceOrientationLandscapeLeft ? M_PI_2 : -M_PI_2);
        self.bounds = CGRectMake(0, 0, CGRectGetHeight(self.superview.bounds), CGRectGetWidth(self.superview.bounds));
        self.center = CGPointMake(CGRectGetMidX(self.superview.bounds), CGRectGetMidY(self.superview.bounds));
        CFLog(@"2%@", NSStringFromCGRect(self.frame));
        self.playerControlView.frame = self.bounds;
        self.playerLayer.frame = self.bounds;
        
    } completion:^(BOOL finished) {
        self.sizeStatus = YMVideoPlayerSizeStatusFull;
        
    }];
    
}

- (void)exitFullscreen {
    
    if (!self.sizeStatus) {
        return;
    }
    
    self.sizeStatus = YMVideoPlayerSizeStatusSwitching;
    
    CGRect frame = [self.movieViewParentView convertRect:self.framNormal toView:[UIApplication sharedApplication].keyWindow];
    [[UIApplication sharedApplication].keyWindow setWindowLevel:(UIWindowLevelNormal)];

    [UIView animateWithDuration:0.5 animations:^{
        self.transform = CGAffineTransformIdentity;
        self.frame = frame;
        self.playerControlView.frame = self.bounds;
        self.playerLayer.frame = self.bounds;

    } completion:^(BOOL finished) {
        /*
         * movieView回到小屏位置
         */
        [self removeFromSuperview];
        self.frame = self.framNormal;
        [self.movieViewParentView addSubview:self];
        
        self.sizeStatus = YMVideoPlayerSizeStatusNormal;
    }];
}

- (void)setupTimeBar {
    __weak __typeof(self) weakSelf = self;
    // 视频的总长度
    NSTimeInterval total = CMTimeGetSeconds(weakSelf.videoPlayer.currentItem.duration);
//    CFLog(@"out: %lld--%d",_videoPlayer.currentItem.duration.value, _videoPlayer.currentItem.duration.timescale);
    // 设置slider的最大值
    _positionSlider.maximumValue = total;
    
    
    _timerObserver = [self.videoPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 30) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
//        CFLog(@"in: %lld--%d",time.value, time.timescale);
        //当前播放的时间
        NSTimeInterval current = CMTimeGetSeconds(time);
//        CFLog(@"current: %f", current);
        //视频的总时间
//        NSTimeInterval total = CMTimeGetSeconds(weakSelf.videoPlayer.currentItem.duration);
//        total = total ? total : 1;
        weakSelf.positionSlider.value = current;
        //设置时间
        weakSelf.timeInfoLabel.text = [NSString stringWithFormat:@"%@/%@", [weakSelf formatPlayTime:current], [weakSelf formatPlayTime:total]];
//        CFLog(@"网速： %lld", [YMVideoPlayerView getInterfaceBytes]);
            }];
    
    
}

- (NSTimeInterval)availableDurationRanges {
    NSArray *loadedTimeRanges = [_videoItem loadedTimeRanges]; // 获取item的缓冲数组
    // discussion Returns an NSArray of NSValues containing CMTimeRanges
    
    // CMTimeRange 结构体 start duration 表示起始位置 和 持续时间
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue]; // 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds; // 计算总缓冲时间 = start + duration
    return result;
}


//将时间转换成00:00:00格式
- (NSString *)formatPlayTime:(NSTimeInterval)duration
{
    int minute = 0, hour = 0, secend = duration;
    minute = (secend % 3600)/60;
    hour = secend / 3600;
    secend = secend % 60;
    return [NSString stringWithFormat:@"%02d:%02d:%02d", hour, minute, secend];
}

//// 计算缓冲进度
//- (NSTimeInterval)availableDuration {
//    NSArray *loadedTimeRanges = [[self.videoPlayer currentItem] loadedTimeRanges];
//    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
//    float startSeconds = CMTimeGetSeconds(timeRange.start);
//    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
//    
//    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
//    
//    return result;
//}
//
//
- (void)dealloc {
    [_videoItem removeObserver:self forKeyPath:@"status"];
    [_videoItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [_videoItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];// rate
    [self.videoPlayer removeObserver:self forKeyPath:@"rate"];
    [self.videoPlayer removeTimeObserver:_timerObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

+ (long long) getInterfaceBytes
{
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1)
    {
        return 0;
    }
    
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        
        if (ifa->ifa_data == 0)
            continue;
        
        /* Not a loopback device. */
        if (strncmp(ifa->ifa_name, "lo", 2))
        {
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
        }
    }
    freeifaddrs(ifa_list);
    
    NSLog(@"\n[getInterfaceBytes-Total]%d,%d",iBytes,oBytes);
    return iBytes + oBytes;
}


//
@end
