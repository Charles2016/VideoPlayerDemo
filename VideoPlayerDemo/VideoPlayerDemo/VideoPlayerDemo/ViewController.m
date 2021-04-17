//
//  ViewController.m
//  VideoPlayerDemo
//
//  Created by MT_iOS08 on 2021/4/16.
//  Copyright © 2021 charles. All rights reserved.
//

#import "ViewController.h"
#import "VideoPlayerView.h"
#import <AVKit/AVPlayerViewController.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    VideoPlayerView *videoPlayer = [[VideoPlayerView alloc]initWithFilePath:@"http://14.21.76.43/cdnsrc.v.cctv.com/flash/mp4video6/TMS/2011/01/05/cf752b1c12ce452b3040cab2f90bc265_h264818000nero_aac32-1.mp4" isRepeat:NO frame:self.view.bounds];
//    @weakify(self);
//    [videoPlayer addTapActionWithBlock:^(UIGestureRecognizer *gestureRecoginzer) {
//        @strongify(self);
//        [self->_videoPlayer stopPlay];
//        [self->_videoPlayerBg removeFromSuperview];
//    }];
    [self.view addSubview:videoPlayer];
    
    /*AVPlayerViewController *moviePlayer = [[AVPlayerViewController alloc]init];
    moviePlayer.view.frame = self.view.bounds;
    moviePlayer.showsPlaybackControls = YES;
    moviePlayer.player = [[AVPlayer alloc] initWithURL:[NSURL URLWithString:@"http://14.21.76.43/cdnsrc.v.cctv.com/flash/mp4video6/TMS/2011/01/05/cf752b1c12ce452b3040cab2f90bc265_h264818000nero_aac32-1.mp4"]];
    [self addChildViewController:moviePlayer];
    [self.view addSubview:moviePlayer.view];
    [moviePlayer.player play];*/
}


@end
