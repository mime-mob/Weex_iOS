//
//  MMDCircleScrollView.h
//  MeMeDaiSteward
//
//  Created by Mime97 on 2017/1/16.
//  Copyright © 2017年 Mime. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 自动轮播结束或者手动滑动结束
 
 @param currentIndex 当前显示图片的索引，用于更新pageControl
 */
typedef void(^AutoScrollViewDidEndScrolling)(NSInteger currentIndex);


/**
 点击图片
 
 @param imageViewIndex 点击图片的索引
 */
typedef void(^AutoScrollViewDidClickAtImageView)(NSInteger imageViewIndex);

typedef void(^AutoScrollViewDidTouchesBegan)(void);

@interface MMDCircleScrollView : UIScrollView

@property (nonatomic, copy) AutoScrollViewDidEndScrolling       endScrolling;
@property (nonatomic, copy) AutoScrollViewDidClickAtImageView   clickAtImageView;
@property (nonatomic, copy) AutoScrollViewDidTouchesBegan       viewTouchesBegan;

/**
 初始化自动轮播
 
 @param imageArray 图片或者图片地址
 @param imageName  默认图片
 @param isAuto     是否需要自动轮播
 */
- (void)initAutoCycleImageViewWithImageArray:(NSArray *)imageArray defaultImage:(NSString *)imageName isAuto:(BOOL)isAuto;

/**
 开启自动轮播
 */
- (void)startAutoScrollView;

/**
 停止自动轮播
 */
- (void)stopAutoScrollView;

@end
