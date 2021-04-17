//
//  VideoPlayerView.m
//  GoodHappiness
//
//  Created by chaolong on 16/9/5.
//  Copyright © 2016年 Charles. All rights reserved.
//

#import "VideoPlayerView.h"
#import <Photos/PHAsset.h>
#import "Masonry.h"
#import "UIButton+TouchAreaInsets.h"
#define vkScreenWidth    [[UIScreen mainScreen] bounds].size.width
#define vkScreenHeight   [[UIScreen mainScreen] bounds].size.height

static void *PlayViewCMTimeValue = &PlayViewCMTimeValue;
static void *PlayViewStatusObservationContext = &PlayViewStatusObservationContext;

@interface VideoPlayerView () {
    BOOL _isPlay;
}

@property (nonatomic, assign) CGPoint firstPoint;
@property (nonatomic, assign) CGPoint secondPoint;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
// 监听播放起状态的监听者
@property (nonatomic, strong) id playbackTimeObserver;
// 视频进度条的单击事件
@property (nonatomic, strong) UITapGestureRecognizer *tap;
@property (nonatomic, assign) CGPoint originalPoint;
@property (nonatomic, assign) BOOL isDragingSlider;// 是否点击了按钮的响应事件
// 显示播放时间的UILabel
@property (nonatomic, strong) UILabel *leftTimeLabel;
@property (nonatomic, strong) UILabel *rightTimeLabel;
// 亮度的进度条
@property (nonatomic, strong) UISlider *lightSlider;
@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) UISlider *systemSlider;
@property (nonatomic, strong) UITapGestureRecognizer *singleTap;
@property (nonatomic, strong) UIProgressView *loadingProgress;


@end

@implementation VideoPlayerView

- (void)dealloc {
    if (_AVPlayerLayer) {
        [self stopPlay];
    }
}

/**
 * 初始化方法(页面只有单个视频的时候使用)
 * @param filePath  网络路径str or 视频文件本地路径str
 * @param isRepeat 是否循环播放
 * @param frame 视频大小及位置
 */
- (instancetype)initWithFilePath:(id)filePath isRepeat:(BOOL)isRepeat frame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isRepeat = isRepeat;
        // 1.创建播放层
        // 在此方法调用创建 AVPlayer 播放视频的第二步
        // 2.通过AVPlayer 创建预览层(AVPlayerLayer)并添加到可视的图层上播放
        _player = [[AVPlayer alloc]init];
        _player.usesExternalPlaybackWhileExternalScreenIsActive = YES;
        _AVPlayerLayer = [[AVPlayerLayer alloc]init];
        _AVPlayerLayer.videoGravity = isRepeat ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResizeAspect;
        [self.layer addSublayer:_AVPlayerLayer];
        if (filePath) {
            [self setFilePath:filePath];
        }
    }
    return self;
}

- (void)setUI {
    self.seekTime = 0.00;
    self.backgroundColor = [UIColor blackColor];
    //小菊花
    // WhiteLarge 的尺寸是（37，37）,White 的尺寸是（22，22）
    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [self addSubview:self.loadingView];
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
    self.loadingView.color = UIColor.greenColor;
    self.loadingView.hidesWhenStopped = YES;
    [self.loadingView startAnimating];
    
    //topView
    self.topView = [[UIView alloc]init];
    self.topView.hidden = YES;
    self.topView.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.4];
    [self addSubview:self.topView];
    //autoLayout topView
    [self.topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.top.equalTo(self);
    }];
    
    _loadFailedLabel = [[UILabel alloc]init];
    _loadFailedLabel.textColor = [UIColor whiteColor];
    _loadFailedLabel.textAlignment = NSTextAlignmentCenter;
    _loadFailedLabel.text = @"视频加载失败";
    _loadFailedLabel.hidden = YES;
    [self addSubview:_loadFailedLabel];
    [_loadFailedLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
        make.width.equalTo(self);
        make.height.mas_equalTo(30);
    }];
    
    //bottomView
    self.bottomView = [[UIView alloc]init];
    self.bottomView.hidden = YES;
    self.bottomView.backgroundColor = [UIColor colorWithWhite:0.4 alpha:0.4];
    [self addSubview:self.bottomView];
    //autoLayout bottomView
    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.right.equalTo(self);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(self);
        
    }];
    
    [self setAutoresizesSubviews:NO];
    //_playOrPauseBtn
    self.playButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.playButton.showsTouchWhenHighlighted = YES;
    self.playButton.tag = 109200;
    [self.playButton addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.playButton setImage:[UIImage imageNamed:@"video_play"] forState:UIControlStateNormal];
    self.playButton.hidden = YES;
    [self addSubview:self.playButton];
    //autoLayout _playOrPauseBtn
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.centerY.equalTo(self);
        make.height.width.mas_equalTo(43);
    }];
    
    //创建亮度的进度条
    self.lightSlider = [[UISlider alloc]initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.lightSlider.hidden = YES;
    self.lightSlider.minimumValue = 0;
    self.lightSlider.maximumValue = 1;
    //进度条的值等于当前系统亮度的值,范围都是0~1
    self.lightSlider.value = [UIScreen mainScreen].brightness;
    //[self.lightSlider addTarget:self action:@selector(updateLightValue:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.lightSlider];
    
    MPVolumeView *volumeView = [[MPVolumeView alloc]init];
    [self addSubview:volumeView];
    volumeView.frame = CGRectMake(-1000, -100, 100, 100);
    [volumeView sizeToFit];
    
    self.systemSlider = [[UISlider alloc]init];
    self.systemSlider.backgroundColor = [UIColor clearColor];
    for (UIControl *view in volumeView.subviews) {
        if ([view.superclass isSubclassOfClass:[UISlider class]]) {
            self.systemSlider = (UISlider *)view;
        }
    }
    self.systemSlider.autoresizesSubviews = NO;
    self.systemSlider.autoresizingMask = UIViewAutoresizingNone;
    [self addSubview:self.systemSlider];
    // self.systemSlider.hidden = YES;
    
    self.volumeSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    self.volumeSlider.tag = 1000;
    self.volumeSlider.hidden = YES;
    self.volumeSlider.minimumValue = self.systemSlider.minimumValue;
    self.volumeSlider.maximumValue = self.systemSlider.maximumValue;
    self.volumeSlider.value = self.systemSlider.value;
    [self.volumeSlider addTarget:self action:@selector(updateSystemVolumeValue:) forControlEvents:UIControlEventValueChanged];
    [self addSubview:self.volumeSlider];
    
    //slider
    self.progressSlider = [[UISlider alloc]init];
    self.progressSlider.minimumValue = 0.0;
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"video_dot"]  forState:UIControlStateNormal];
    self.progressSlider.minimumTrackTintColor = [UIColor greenColor];
    self.progressSlider.maximumTrackTintColor = [UIColor clearColor];
    self.progressSlider.value = 0.0;//指定初始值
    //进度条的拖拽事件
    [self.progressSlider addTarget:self action:@selector(stratDragSlide:)  forControlEvents:UIControlEventValueChanged];
    //进度条的点击事件
    [self.progressSlider addTarget:self action:@selector(updateProgress:) forControlEvents:UIControlEventTouchUpInside];
    
    //给进度条添加单击手势
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    [self.progressSlider addGestureRecognizer:self.tap];
    [self.bottomView addSubview:self.progressSlider];
    self.progressSlider.backgroundColor = [UIColor clearColor];
    
    //autoLayout slider
    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.centerY.equalTo(self.bottomView).with.offset(-5);
        make.height.mas_equalTo(1.5);
    }];
    
    self.loadingProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.loadingProgress.progressTintColor = [UIColor clearColor];
    self.loadingProgress.trackTintColor = [UIColor lightGrayColor];
    [self.bottomView addSubview:self.loadingProgress];
    [self.loadingProgress setProgress:0.0 animated:NO];
    
    [self.loadingProgress mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.progressSlider);
        make.right.equalTo(self.progressSlider);
        make.center.equalTo(self.progressSlider);
        make.height.mas_equalTo(1.5);
    }];
    [self.bottomView sendSubviewToBack:self.loadingProgress];
    
    //_fullScreenBtn
    self.fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fullScreenBtn.showsTouchWhenHighlighted = YES;
    self.fullScreenBtn.tag = 109201;
    [self.fullScreenBtn addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.fullScreenBtn setImage:[UIImage imageNamed:@"video_smallscreen"] forState:UIControlStateNormal];
    [self.fullScreenBtn setImage:[UIImage imageNamed:@"video_smallscreen"] forState:UIControlStateSelected];
    [self.bottomView addSubview:self.fullScreenBtn];
    //autoLayout fullScreenBtn
    [self.fullScreenBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomView);
        make.height.mas_equalTo(40);
        make.bottom.equalTo(self.bottomView);
        make.width.mas_equalTo(40);
    }];
    
    //leftTimeLabel
    self.leftTimeLabel = [[UILabel alloc]init];
    self.leftTimeLabel.textAlignment = NSTextAlignmentLeft;
    self.leftTimeLabel.textColor = [UIColor whiteColor];
    self.leftTimeLabel.backgroundColor = [UIColor clearColor];
    self.leftTimeLabel.font = [UIFont systemFontOfSize:11];
    [self.bottomView addSubview:self.leftTimeLabel];
    //autoLayout timeLabel
    [self.leftTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.height.mas_equalTo(20);
        make.bottom.equalTo(self.bottomView);
    }];
    
    //rightTimeLabel
    self.rightTimeLabel = [[UILabel alloc]init];
    self.rightTimeLabel.textAlignment = NSTextAlignmentRight;
    self.rightTimeLabel.textColor = [UIColor whiteColor];
    self.rightTimeLabel.backgroundColor = [UIColor clearColor];
    self.rightTimeLabel.font = [UIFont systemFontOfSize:11];
    [self.bottomView addSubview:self.rightTimeLabel];
    //autoLayout timeLabel
    [self.rightTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bottomView).with.offset(45);
        make.right.equalTo(self.bottomView).with.offset(-45);
        make.height.mas_equalTo(20);
        make.bottom.equalTo(self.bottomView);
    }];
    
    //_closeBtn
    _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeBtn.showsTouchWhenHighlighted = YES;
    _closeBtn.tag = 109202;
    _closeBtn.touchAreaInsets = UIEdgeInsetsMake(20, 20, 20, 20);
    [_closeBtn setImage:[UIImage imageNamed:@"video_back"] forState:UIControlStateNormal];
    [_closeBtn addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:_closeBtn];
    //autoLayout
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topView).with.offset(5);
        make.height.mas_equalTo(30);
        make.top.equalTo(self.topView).with.offset(5);
        make.width.mas_equalTo(30);
    }];
    
    /*//titleLabel
    self.titleLabel = [[UILabel alloc]init];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.font = [UIFont systemFontOfSize:17.0];
    [self.topView addSubview:self.titleLabel];
    //autoLayout titleLabel
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topView).with.offset(45);
        make.right.equalTo(self.topView).with.offset(-45);
        make.center.equalTo(self.topView);
        make.top.equalTo(self.topView);
    }];*/
    
    [self bringSubviewToFront:self.loadingView];
    [self bringSubviewToFront:self.bottomView];
    
    // 单击的 Recognizer
    self.singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
    self.singleTap.numberOfTapsRequired = 1; // 单击
    self.singleTap.numberOfTouchesRequired = 1;
    [self addGestureRecognizer:self.singleTap];
    
    UIWindow *keyWindow = [UIApplication sharedApplication].windows.lastObject;
    keyWindow.windowLevel = 10000;
    [keyWindow addSubview:self];
    self.frame = CGRectMake(0, 0, keyWindow.bounds.size.width, keyWindow.bounds.size.height);
}


- (void)setFilePath:(id)filePath {
    if (filePath) {
        if (!_loadingView) {
            [self setUI];
        }
        [_loadingView startAnimating];
        _filePath = filePath;
        _isPlay = YES;
        AVPlayerItem *currentItem;
        if ([filePath isKindOfClass:[NSString class]]) {
            if ([_filePath rangeOfString:@"http"].length) {
                // 网络路径nsurl
                AVURLAsset *movieAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:_filePath] options:nil];
                /*此种方式获取到的size可能为0，有问题所以取视频缩略图来判断视频size
                NSArray *array = movieAsset.tracks;
                CGSize videoSize = CGSizeZero;
                for (AVAssetTrack *track in array) {
                    if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                        videoSize = track.naturalSize;
                    }
                }
                // 视频适应屏幕大小，注意此处除数不能为0
                if (videoSize.width) {
                    self.height = videoSize.height * self.width / videoSize.width;
                }*/
                // 获取视频关键帧
                AVAssetImageGenerator *assetImageGenerator =[[AVAssetImageGenerator alloc] initWithAsset:movieAsset];
                assetImageGenerator.appliesPreferredTrackTransform = YES;
                assetImageGenerator.maximumSize = self.frame.size;
                assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
                
                CGImageRef thumbnailImageRef = NULL;
                NSError *thumbnailImageGenerationError = nil;
                thumbnailImageRef = [assetImageGenerator copyCGImageAtTime:CMTimeMake(0.1, 60)actualTime:NULL error:&thumbnailImageGenerationError];
                
                if(!thumbnailImageRef) {
                    NSLog(@"thumbnailImageGenerationError %@",thumbnailImageGenerationError);
                }
                UIImage *thumbnailImage = thumbnailImageRef ? [[UIImage alloc]initWithCGImage: thumbnailImageRef] : [self imageWithColor:UIColor.whiteColor];
                CGSize videoSize = thumbnailImage.size;
                // 视频适应屏幕大小，注意此处除数不能为0
                if (videoSize.width) {
                    self.frame = CGRectMake(self.frame.origin.x, ([[UIScreen mainScreen] bounds].size.height - videoSize.height) / 2, self.frame.size.width, videoSize.height * self.frame.size.width / videoSize.width);
                }
                self.backgroundColor = [UIColor colorWithPatternImage:thumbnailImage];
                currentItem = [AVPlayerItem playerItemWithAsset:movieAsset];
            } else {
                // 视频文件本地路径urlStr
                currentItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:_filePath]];
            }
        } else if ([filePath isKindOfClass:[NSURL class]])  {
            currentItem = [AVPlayerItem playerItemWithURL:_filePath];
        } else if ([filePath isKindOfClass:[AVAsset class]]) {
            currentItem = [AVPlayerItem playerItemWithAsset:filePath];
        }
        [self setPlayerWithFilePath:currentItem];
    }
}

- (void)setState:(WMPlayerState)state {
    _state = state;
    if (state == WMPlayerStateBuffering) {
        // 缓冲中显示菊花
        [self.loadingView startAnimating];
    } else {
        // 其他状态隐藏菊花
        [self.loadingView stopAnimating];
    }
}

- (void)setPlayerWithFilePath:(AVPlayerItem *)currentItem {
    if (_currentItem == currentItem) {
        return;
    }
    if (_currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
        [_currentItem removeObserver:self forKeyPath:@"status"];
        [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
        
        _currentItem = nil;
    }
    _currentItem = currentItem;
    if (_currentItem) {
        [_currentItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        [_currentItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区空了，需要等待数据
        [_currentItem addObserver:self forKeyPath:@"playbackBufferEmpty" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 缓冲区有足够数据可以播放了
        [_currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options: NSKeyValueObservingOptionNew context:PlayViewStatusObservationContext];
        // 添加视频播放结束通知
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:_currentItem];
        _AVPlayerLayer.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
        [_player replaceCurrentItemWithPlayerItem:_currentItem];
        _AVPlayerLayer.player = _player;
        [_player play];
        self.state = WMPlayerStateBuffering;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
}

#pragma mark - 进入后台or前台
- (void)appDidEnterBackground:(NSNotification*)note {
    if (_isPlay) {
        // 如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        _AVPlayerLayer.player = nil;
        [self.player play];
        self.state = WMPlayerStatePlaying;
    } else {
        self.state = WMPlayerStateStopped;
    }
}

- (void)appWillEnterForeground:(NSNotification*)note {
    if (_isPlay) {
        //如果是播放中，则继续播放
        NSArray *tracks = [self.currentItem tracks];
        for (AVPlayerItemTrack *playerItemTrack in tracks) {
            if ([playerItemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicVisual]) {
                playerItemTrack.enabled = YES;
            }
        }
        _AVPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
        _AVPlayerLayer.frame = self.bounds;
        _AVPlayerLayer.videoGravity = AVLayerVideoGravityResize;
        [self.layer insertSublayer:_AVPlayerLayer atIndex:0];
        [self.player play];
        self.state = WMPlayerStatePlaying;
        
    }else{
        self.state = WMPlayerStateStopped;
    }
}
#pragma mark - 视频进度条相关方法
/// 拖拽进度条
- (void)stratDragSlide:(UISlider *)slider {
    self.isDragingSlider = YES;
    self.isDragingSlider = NO;
}

/// 播放进度
- (void)updateProgress:(UISlider *)slider {
    self.isDragingSlider = NO;
    [self.player seekToTime:CMTimeMakeWithSeconds(slider.value, _currentItem.currentTime.timescale)];
    
}
/// 视频进度条的点击事件
- (void)actionTapGesture:(UITapGestureRecognizer *)sender {
    CGPoint touchLocation = [sender locationInView:self.progressSlider];
    CGFloat value = (self.progressSlider.maximumValue - self.progressSlider.minimumValue) * (touchLocation.x/self.progressSlider.frame.size.width);
    [self.progressSlider setValue:value animated:YES];
    
    [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale)];
    if (self.player.rate != 1.f) {
        if ([self currentTime] == [self duration]) {
            [self setCurrentTime:0.f];
        }
        self.playButton.selected = NO;
        [self.player play];
    }
}

/// 声音进度设置
- (void)updateSystemVolumeValue:(UISlider *)slider {
    self.systemSlider.value = slider.value;
}

/// 获取视频长度
- (double)duration {
    AVPlayerItem *playerItem = self.player.currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return CMTimeGetSeconds([[playerItem asset] duration]);
    } else {
        return 0.f;
    }
}

/// 获取视频当前播放的时间
- (double)currentTime {
    if (self.player) {
        return CMTimeGetSeconds([self.player currentTime]);
    } else {
        return 0.0;
    }
}

- (void)setCurrentTime:(double)time {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.player seekToTime:CMTimeMakeWithSeconds(time, self.currentItem.currentTime.timescale)];
    });
}
#pragma mark - 单击手势方法
- (void)handleSingleTap:(UITapGestureRecognizer *)sender {
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
    [UIView animateWithDuration:0.5 animations:^{
        if (self.bottomView.alpha == 0.0) {
            self.bottomView.alpha = 1.0;
            self.closeBtn.alpha = 1.0;
            self.topView.alpha = 1.0;
        } else {
            self.bottomView.alpha = 0.0;
            self.closeBtn.alpha = 0.0;
            self.topView.alpha = 0.0;
        }
    } completion:^(BOOL finish){
        
    }];
}

#pragma mark - 双击手势方法
- (void)handleDoubleTap:(UITapGestureRecognizer *)doubleTap {
    self.playButton.selected = !self.playButton.selected;
    if (self.playButton.selected) {
        [self.player play];
        self.playButton.hidden = YES;
    } else {
        self.playButton.hidden = NO;
        [self.player pause];
    }
    /*if (self.player.rate != 1.f) {
        if ([self currentTime] == self.duration) {
            [self setCurrentTime:0.f];
        }
        [self.player play];
        self.playButton.selected = NO;
        self.playButton.hidden = YES;
    } else {
        [self.player pause];
        self.playButton.selected = YES;
        self.playButton.hidden = NO;
    }
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
        self.closeBtn.alpha = 1.0;
        
    } completion:^(BOOL finish){
        
    }];*/
}

#pragma mark - 按钮相关方法
-(void)buttonAction:(UIButton *)button {
    button.selected = !button.selected;
    switch (button.tag) {
        case 109200: {
            // 暂停or继续播放
            if (button.selected) {
                [self.player play];
                button.hidden = YES;
            } else {
                [self.player pause];
            }
        }
            break;
        case 109201: {
            // 全屏or小屏播放
            [self stopPlay];
        }
            break;
        case 109202: {
            // 关闭
            [self stopPlay];
        }
            break;
    }
}

// 停止播放视频
- (void)stopPlay {
    if (_currentItem) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_currentItem removeObserver:self forKeyPath:@"status"];    
        [_currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [_currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
        [_currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    }
    [_player pause];
    [_AVPlayerLayer removeFromSuperlayer];
    [_player replaceCurrentItemWithPlayerItem:nil];
    _player = nil;
    _currentItem = nil;
    _AVPlayerLayer = nil;
    _isPlay = NO;
    [self removeFromSuperview];
    UIWindow *keyWindow = [UIApplication sharedApplication].windows.lastObject;
    keyWindow.windowLevel = 10000;
}

// 播放完成通知
- (void)playbackFinished:(NSNotification *)notification {
    NSLog(@"视频播放完成.");
    self.state = WMPlayerStateFinished;
    // 播放完成后重复播放
    // 跳到最新的时间点开始播放
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];

    [self.player seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [self.progressSlider setValue:0.0 animated:YES];
        self.playButton.selected = YES;
    }];
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomView.alpha = 1.0;
        self.topView.alpha = 1.0;
    } completion:^(BOOL finish){
    }];
}

#pragma mark autoDismissBottomView
-(void)autoDismissBottomView:(NSTimer *)timer {
    if (self.player.rate==.0f&&self.currentTime != self.duration) {//暂停状态
        
    }else if(self.player.rate==1.0f){
        if (self.bottomView.alpha==1.0) {
            [UIView animateWithDuration:0.5 animations:^{
                self.bottomView.alpha = 0.0;
                self.closeBtn.alpha = 0.0;
                self.topView.alpha = 0.0;
                
            } completion:^(BOOL finish){
                
            }];
        }
    }
}
#pragma  mark - 定时器
-(void)initTimer {
    double interval = 0.1f;
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)) {
        return;
    }
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)) {
        CGFloat width = CGRectGetWidth([self.progressSlider bounds]);
        interval = 0.5f * duration / width;
    }
    __weak typeof(self) weakSelf = self;
    self.playbackTimeObserver =  [weakSelf.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(1.0, NSEC_PER_SEC)  queue:dispatch_get_main_queue() /* If you pass NULL, the main queue is used. */
                                                                          usingBlock:^(CMTime time){
                                                                              [weakSelf syncScrubber];
                                                                          }];
}

- (void)syncScrubber {
    CMTime playerDuration = [self playerItemDuration];
    if (CMTIME_IS_INVALID(playerDuration)){
        self.progressSlider.minimumValue = 0.0;
        return;
    }
    double duration = CMTimeGetSeconds(playerDuration);
    if (isfinite(duration)){
        float maxValue = [self.progressSlider maximumValue];
        double nowTime = CMTimeGetSeconds([self.player currentTime]);
        self.leftTimeLabel.text = [self convertTime:nowTime];
        self.rightTimeLabel.text = [self convertTime:duration];
        if (self.isDragingSlider) {
            //拖拽slider中，不更新slider的值
            
        } else {
            [UIView animateWithDuration:0.01f animations:^{
                [self.progressSlider setValue:maxValue * (nowTime / duration)];
            }];
        }
    }
}
/**
 *  跳到time处播放
 *  @param time 这个时刻，这个时间点
 */
- (void)seekToTimeToPlay:(double)time {
    if (self.player&&self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        if (time>[self duration]) {
            time = [self duration];
        }
        if (time <= 0) {
            time = 0.0;
        }
        //        int32_t timeScale = self.player.currentItem.asset.duration.timescale;
        //currentItem.asset.duration.timescale计算的时候严重堵塞主线程，慎用
        /* A timescale of 1 means you can only specify whole seconds to seek to. The timescale is the number of parts per second. Use 600 for video, as Apple recommends, since it is a product of the common video frame rates like 50, 60, 25 and 24 frames per second*/
        
        [self.player seekToTime:CMTimeMakeWithSeconds(time, _currentItem.currentTime.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            
        }];
    }
}

// 视频时长
- (CMTime)playerItemDuration {
    AVPlayerItem *playerItem = _currentItem;
    if (playerItem.status == AVPlayerItemStatusReadyToPlay){
        return([playerItem duration]);
    }
    return(kCMTimeInvalid);
}

- (NSString *)convertTime:(CGFloat)second {
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    if (second/3600 >= 1) {
        [[self dateFormatter] setDateFormat:@"HH:mm:ss"];
    } else {
        [[self dateFormatter] setDateFormat:@"mm:ss"];
    }
    NSString *newTime = [[self dateFormatter] stringFromDate:d];
    return newTime;
}

/// 计算缓冲进度
- (NSTimeInterval)availableDuration {
    NSArray *loadedTimeRanges = [_currentItem loadedTimeRanges];
    CMTimeRange timeRange     = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds        = CMTimeGetSeconds(timeRange.start);
    float durationSeconds     = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result     = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}

- (NSDateFormatter *)dateFormatter {
    if (!_dateFormatter) {
        _dateFormatter = [[NSDateFormatter alloc] init];
    }
    return _dateFormatter;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch =[touches anyObject];
    self.firstPoint = [touch locationInView:self];
    self.volumeSlider.value = self.systemSlider.value;
    // 记录下第一个点的位置,用于moved方法判断用户是调节音量还是调节视频
    self.originalPoint = self.firstPoint;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch *touch =[touches anyObject];
    self.secondPoint = [touch locationInView:self];
    //判断是左右滑动还是上下滑动
    CGFloat verValue = fabs(self.originalPoint.y - self.secondPoint.y);
    CGFloat horValue = fabs(self.originalPoint.x - self.secondPoint.x);
    //如果竖直方向的偏移量大于水平方向的偏移量,那么是调节音量或者亮度
    if (verValue >= horValue) {
        //上下滑动
        //判断是全屏模式还是正常模式
        if (self.isFullScreen) {
            //全屏下
            //判断刚开始点的是左边还是右边,左边控制音量
            if (self.originalPoint.x <= vkScreenWidth / 2) {
                //全屏下:point在view的左边(控制音量)
                /* 手指上下移动的计算方式,根据y值,刚开始进度条在0位置,当手指向上移动600个点后,当手指向上移动N个点的距离后,
                 当前的进度条的值就是N/600,600随开发者任意调整,数值越大,那么进度条到大1这个峰值需要移动的距离也变大,反之越小 */
                self.systemSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                self.volumeSlider.value = self.systemSlider.value;
            } else {
                //全屏下:point在view的右边(控制亮度)
                //右边调节屏幕亮度
                self.lightSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                [[UIScreen mainScreen] setBrightness:self.lightSlider.value];
                
            }
        } else {
            //非全屏
            //判断刚开始的点是左边还是右边,左边控制音量
            if (self.originalPoint.x <= vkScreenWidth / 2) {
                //非全屏下:point在view的左边(控制音量)
                /* 手指上下移动的计算方式,根据y值,刚开始进度条在0位置,当手指向上移动600个点后,当手指向上移动N个点的距离后,
                 当前的进度条的值就是N/600,600随开发者任意调整,数值越大,那么进度条到大1这个峰值需要移动的距离也变大,反之越小 */
                self.systemSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                self.volumeSlider.value = self.systemSlider.value;
            } else {
                //非全屏下:point在view的右边(控制亮度)
                //右边调节屏幕亮度
                self.lightSlider.value += (self.firstPoint.y - self.secondPoint.y)/600.0;
                [[UIScreen mainScreen] setBrightness:self.lightSlider.value];
            }
        }
    } else {
        //左右滑动,调节视频的播放进度
        //视频进度不需要除以600是因为self.progressSlider没设置最大值,它的最大值随着视频大小而变化
        //要注意的是,视频的一秒时长相当于progressSlider.value的1,视频有多少秒,progressSlider的最大值就是多少
        self.progressSlider.value -= (self.firstPoint.x - self.secondPoint.x);
        [self.player seekToTime:CMTimeMakeWithSeconds(self.progressSlider.value, self.currentItem.currentTime.timescale)];
        //滑动太快可能会停止播放,所以这里自动继续播放
        if (self.player.rate != 1.f) {
            if ([self currentTime] == [self duration])
                [self setCurrentTime:0.f];
            self.playButton.selected = NO;
            [self.player play];
        }
    }
    self.firstPoint = self.secondPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    self.firstPoint = self.secondPoint = CGPointZero;
}

//重置播放器
-(void )resetWMPlayer {
    self.currentItem = nil;
    self.seekTime = 0;
    // 移除通知
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // 关闭定时器
    [self.autoDismissTimer invalidate];
    self.autoDismissTimer = nil;
    // 暂停
    [self.player pause];
    // 移除原来的layer
    [self.AVPlayerLayer removeFromSuperlayer];
    // 替换PlayerItem为nil
    [self.player replaceCurrentItemWithPlayerItem:nil];
    // 把player置为nil
    self.player = nil;
}

#pragma mark - KVO
/**
 * 通过KVO监控播放器状态 *
 * @param keyPath 监控属性
 * @param object 监视器
 * @param change 状态改变
 * @param context 上下文
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    AVPlayerItem *playerItem = object;
    if (context == PlayViewStatusObservationContext) {
        if ([keyPath isEqualToString:@"status"]) {
            AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
            switch (status) {
                case AVPlayerStatusUnknown: {
                    [self.loadingProgress setProgress:0.0 animated:NO];
                    self.state = WMPlayerStateBuffering;
                }
                    break;
                case AVPlayerStatusReadyToPlay: {
                    self.state = WMPlayerStatusReadyToPlay;
                    AVPlayerStatus status = [[change objectForKey:@"new"] intValue];
                    if(status == AVPlayerStatusReadyToPlay) {
                        NSLog(@"正在播放...，视频总长度:%.2f",CMTimeGetSeconds(playerItem.duration));
                    }
                    // 双击的 Recognizer
                    UITapGestureRecognizer* doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
                    doubleTap.numberOfTapsRequired = 2; // 双击
                    [self.singleTap requireGestureRecognizerToFail:doubleTap];//如果双击成立，则取消单击手势（双击的时候不回走单击事件）
                    [self addGestureRecognizer:doubleTap];
                    /* Once the AVPlayerItem becomes ready to play, i.e.
                     [playerItem status] == AVPlayerItemStatusReadyToPlay,
                     its duration can be fetched from the item. */
                    if (CMTimeGetSeconds(_currentItem.duration)) {
                        double _x = CMTimeGetSeconds(_currentItem.duration);
                        if (!isnan(_x)) {
                            self.progressSlider.maximumValue = CMTimeGetSeconds(self.player.currentItem.duration);
                        }
                    }
                    //监听播放状态
                    [self initTimer];
                    //5s dismiss bottomView
                    if (self.autoDismissTimer == nil) {
                        self.autoDismissTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(autoDismissBottomView:) userInfo:nil repeats:YES];
                        [[NSRunLoop currentRunLoop] addTimer:self.autoDismissTimer forMode:NSDefaultRunLoopMode];
                    }
//                    if (self.delegate&&[self.delegate respondsToSelector:@selector(wmplayerReadyToPlay:WMPlayerStatus:)]) {
//                        [self.delegate wmplayerReadyToPlay:self WMPlayerStatus:WMPlayerStatusReadyToPlay];
//                    }
                    [self.loadingView stopAnimating];
                    // 跳到xx秒播放视频
                    if (self.seekTime) {
                        [self seekToTimeToPlay:self.seekTime];
                    }
                }
                    break;
                    
                case AVPlayerStatusFailed: {
                    self.state = WMPlayerStateFailed;
//                    if (self.delegate&&[self.delegate respondsToSelector:@selector(wmplayerFailedPlay:WMPlayerStatus:)]) {
//                        [self.delegate wmplayerFailedPlay:self WMPlayerStatus:WMPlayerStateFailed];
//                    }
                    NSError *error = [self.player.currentItem error];
                    if (error) {
                        self.loadFailedLabel.hidden = NO;
                        [self bringSubviewToFront:self.loadFailedLabel];
                        [self.loadingView stopAnimating];
                    }
                    NSLog(@"视频加载失败===%@",error.description);
                }
                    break;
            }
            
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            /*NSArray *array = playerItem.loadedTimeRanges;
            //本次缓冲时间范围
            CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];
            float startSeconds = CMTimeGetSeconds(timeRange.start);
            float durationSeconds = CMTimeGetSeconds(timeRange.duration);
            //缓冲总长度
            NSTimeInterval totalBuffer = startSeconds + durationSeconds;
            DLog(@"共缓冲：%.2f",totalBuffer);*/
            // 计算缓冲进度
            NSTimeInterval timeInterval = [self availableDuration];
            CMTime duration = self.currentItem.duration;
            CGFloat totalDuration = CMTimeGetSeconds(duration);
            //缓冲颜色
            self.loadingProgress.progressTintColor = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.7];
            [self.loadingProgress setProgress:timeInterval / totalDuration animated:NO];
        } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
            [self.loadingView startAnimating];
            // 当缓冲是空的时候
            if (self.currentItem.playbackBufferEmpty) {
                self.state = WMPlayerStateBuffering;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.player play];
                    [self.loadingView stopAnimating];
                });
            }
        } else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
            [self.loadingView stopAnimating];
            // 当缓冲好的时候
            if (self.currentItem.playbackLikelyToKeepUp && self.state == WMPlayerStateBuffering){
                self.state = WMPlayerStatePlaying;
            }
        }
    }
}

/// 获取视频时长
+ (NSString *)getVideoDurationWithAsset:(id)asset {
    NSInteger seconds = 0;
    if ([asset isKindOfClass:[PHAsset class]]) {
        seconds = ((PHAsset *)asset).duration * 1000;
    } else if ([asset isKindOfClass:[AVAsset class]]) {
        CMTime time = ((AVAsset *)asset).duration;
        seconds = time.value / time.timescale * 1000;
    } else if ([asset isKindOfClass:[NSString class]]) {
        // 网络路径nsurl
        AVURLAsset *movieAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:asset] options:nil];
        CMTime time = movieAsset.duration;
        seconds = time.value / time.timescale * 1000;
    }
    NSString *hour = [NSString stringWithFormat:@"%ld", seconds/1000/60/60];
    NSString *minute = [NSString stringWithFormat:@"%ld", seconds/1000/60%60];
    NSString *second = [NSString stringWithFormat:@"%ld", seconds/1000%60];
    CGFloat sss = seconds%1000/10;
    NSString *ss = [NSString stringWithFormat:@"%.lf", sss];
    NSString *duration = @"";
    if (hour.integerValue && hour.integerValue < 10) {
        hour = [NSString stringWithFormat:@"0%@", hour];
    }
    if (minute.integerValue < 10) {
        minute = [NSString stringWithFormat:@"0%@", minute];
    }
    if (second.integerValue < 10) {
        second = [NSString stringWithFormat:@"0%@", second];
    }
    if (ss.integerValue < 10) {
        ss = [NSString stringWithFormat:@"0%@", ss];
    }
    if (hour.integerValue) {
        duration = [NSString stringWithFormat:@"%@:%@:%@:%@", hour, minute, second, ss];
    } else if (minute.integerValue) {
        duration = [NSString stringWithFormat:@"%@:%@:%@", minute, second, ss];
    } else if (second.integerValue) {
        duration = [NSString stringWithFormat:@"%@:%@", minute, second];
    }
    return duration;
}

- (void)adjustWithImageView:(UIImageView *)imageView {
    if (imageView.image) {
        // 基本尺寸参数
        CGSize boundsSize = self.bounds.size;
        CGFloat boundsWidth = boundsSize.width;
        CGFloat boundsHeight = boundsSize.height;
        
        CGSize imageSize = imageView.image.size;
        CGFloat imageWidth = imageSize.width;
        CGFloat imageHeight = imageSize.height;
        
        
        // 设置伸缩比例
        CGFloat widthRatio = boundsWidth/imageWidth;
        CGFloat heightRatio = boundsHeight/imageHeight;
        CGFloat minScale = (widthRatio > heightRatio) ? heightRatio : widthRatio;
        
        if (minScale >= 1) {
            minScale = 0.8;
        }
        CGRect oldFrame = imageView.frame;
        CGRect newFrame = CGRectMake(0, 0, boundsWidth, imageHeight * boundsWidth / imageWidth);
        // 宽大
        if ( imageWidth <= imageHeight &&  imageHeight <  boundsHeight ) {
            newFrame.origin.x = floorf((boundsWidth - newFrame.size.width ) / 2.0) * minScale;
            newFrame.origin.y = floorf((boundsHeight - newFrame.size.height ) / 2.0) * minScale;
        }else{
            newFrame.origin.x = floorf((boundsWidth - newFrame.size.width ) / 2.0);
            newFrame.origin.y = floorf((boundsHeight - newFrame.size.height ) / 2.0);
        }

        UIWindow *keyWindow = [UIApplication sharedApplication].windows.lastObject;
        imageView.frame = [self convertRect:keyWindow.bounds toView:nil];
        [keyWindow addSubview:self];
        self.frame = oldFrame;
        [UIView animateWithDuration:0.3  animations:^{
            self.frame = oldFrame;
        } completion:^(BOOL finished) {
            // 设置底部的小图片
            self.frame = newFrame;
        }];
    }
}

/**
 *  @brief  根据颜色生成纯色图片
 *  @param color 颜色
 *  @return 纯色图片
 */
- (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
