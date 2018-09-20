//
//  YMVideoPlayerView.h
//  CrazyBeeFitness
//
//  Created by 彦明 on 2017/7/19.
//  Copyright © 2017年 siunion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface YMVideoPlayerView : UIView
//@property (nonatomic, copy) NSString *videoUrlString;
//@property (nonatomic, copy) NSString *videoCoverUrlString;
/** 默认和建议的播放器比例为16:9 */
- (instancetype)initWithFrame:(CGRect)frame UrlString:(NSString *)urlString;
@end
