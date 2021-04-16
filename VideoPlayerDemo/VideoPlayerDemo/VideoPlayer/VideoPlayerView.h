//
//  VideoPlayerView.h
//  GoodHappiness
//
//  Created by chaolong on 16/9/5.
//  Copyright © 2016年 Charles. All rights reserved.
//

#import <UIKit/UIKit.h>
@import MediaPlayer;
@import AVFoundation;

// 播放器的几种状态
typedef NS_ENUM(NSInteger, WMPlayerState) {
    WMPlayerStateFailed,        // 播放失败
    WMPlayerStateBuffering,     // 缓冲中
    WMPlayerStatusReadyToPlay,  // 将要播放
    WMPlayerStatePlaying,       // 播放中
    WMPlayerStateStopped,       // 暂停播放
    WMPlayerStateFinished       // 播放完毕
};

@interface VideoPlayerView : UIView

@property (nonatomic, strong) UIView *bottomView;// 底部操作工具栏
@property (nonatomic, strong) UILabel *titleLabel;// 显示播放视频的title
@property (nonatomic, strong) UIButton *closeBtn;// 左上角关闭按钮

@property (nonatomic, strong) UIView *topView;// 顶部操作工具栏
@property (nonatomic,retain ) UIButton *fullScreenBtn;// 控制全屏的按钮

@property (nonatomic, strong) UIButton *playButton;// 播放暂停按钮
@property (nonatomic, strong) UILabel *loadFailedLabel;// 显示加载失败的UILabel
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;// 菊花（加载框）

@property (nonatomic, assign) WMPlayerState state;// 播放器状态
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *AVPlayerLayer;
@property (nonatomic, strong) AVPlayerItem *currentItem;

@property (nonatomic, assign) double seekTime;// 跳到某个时间点处播放
@property (nonatomic, strong) NSTimer *autoDismissTimer;// 定时器
@property (nonatomic, assign) BOOL isRepeat;// 是否重复播放
@property (nonatomic, assign) BOOL isFullScreen;// 判断当前全屏的状态
@property (nonatomic, assign) BOOL isPlaying;// 播放状态
@property (nonatomic, copy) id filePath;// 文件路径urlStr

/**
 * 初始化方法(页面只有单个视频的时候使用)
 * @param filePath  网络路径str or 视频文件本地路径str
 * @param isRepeat 是否循环播放
 * @param frame 视频大小及位置
 */
- (instancetype)initWithFilePath:(id)filePath isRepeat:(BOOL)isRepeat frame:(CGRect)frame;
// 获取正在播放的时间点
- (double)currentTime;
// 停止播放视频
- (void)stopPlay;
// 播放视频
//- (void)startPlay;
// 重置播放器
- (void )resetWMPlayer;
/// 获取视频时长
+ (NSString *)getVideoDurationWithAsset:(id)asset;
/// 视频显示动画
- (void)adjustWithImageView:(UIImageView *)imageView;


/*示例
 _videoPlayer = [[VideoPlayerView alloc]initWithFilePath:model.videoUrl isRepeat:NO frame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
@weakify(self);
[_videoPlayer addTapActionWithBlock:^(UIGestureRecognizer *gestureRecoginzer) {
    @strongify(self);
    [self->_videoPlayer stopPlay];
    [self->_videoPlayerBg removeFromSuperview];
}];
[self.view addSubview:_videoPlayer];*/

@end
