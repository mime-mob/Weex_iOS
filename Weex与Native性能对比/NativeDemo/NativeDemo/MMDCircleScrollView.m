//
//  MMDCircleScrollView.m
//  MeMeDaiSteward
//
//  Created by Mime97 on 2017/1/16.
//  Copyright © 2017年 Mime. All rights reserved.
//

#import "MMDCircleScrollView.h"
#import "UIImageView+WebCache.h"

@interface MMDCircleScrollView () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableArray  *imageViewsArray;
@property (nonatomic, strong) NSTimer         *timer;
@property (nonatomic, assign) NSInteger       currentIndex;
@property (nonatomic, assign) BOOL            isAutoCycle;

@end

@implementation MMDCircleScrollView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        
        self.bounces = NO;
        self.showsHorizontalScrollIndicator = NO;
        self.showsVerticalScrollIndicator = NO;
        self.userInteractionEnabled = YES;
        self.pagingEnabled = YES;
        self.delegate = self;
        
        _isAutoCycle = NO;
        _currentIndex = 1;
    }
    return self;
}

- (void)clickImageViewAtIndex:(UITapGestureRecognizer *)sender {
    if (_isAutoCycle) {
        if (self.clickAtImageView) {
            UIImageView *bannerImageView = (UIImageView *)[sender view];
            self.clickAtImageView(bannerImageView.tag - 1);
        }
    }
}

- (void)autoScrollView {
    _currentIndex ++;
    [self setContentOffset:CGPointMake(CGRectGetWidth(self.frame) * _currentIndex, 0) animated:YES];
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (_isAutoCycle) {
        [self stopAutoScrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    
    CGFloat offSetX = scrollView.contentOffset.x;
    _currentIndex = offSetX / CGRectGetWidth(self.frame);
    
    if (_currentIndex == _imageViewsArray.count - 1) {
        _currentIndex = 1;
        [self setContentOffset:CGPointMake(CGRectGetWidth(self.frame) * _currentIndex, 0) animated:NO];
    }
    
    if (_currentIndex == 0) {
        _currentIndex = _imageViewsArray.count - 2;
        [self setContentOffset:CGPointMake(CGRectGetWidth(self.frame) * _currentIndex, 0) animated:NO];
    }
    
    //实现代理的位置
    //    NSLog(@"%ld",(long)_currentIndex - 1);
    if (self.endScrolling) {
        self.endScrolling(_currentIndex - 1);
    }
    
    if (_isAutoCycle) {
        [self startAutoScrollView];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if (_currentIndex == _imageViewsArray.count - 1) {
        _currentIndex = 1;
        [self setContentOffset:CGPointMake(CGRectGetWidth(self.frame), 0) animated:NO];
    }
    //实现代理的位置
    //    NSLog(@"%ld",(long)_currentIndex - 1);
    if (self.endScrolling) {
        self.endScrolling(_currentIndex - 1);
    }
}

- (void)initAutoCycleImageViewWithImageArray:(NSArray *)imageArray defaultImage:(NSString *)imageName isAuto:(BOOL)isAuto {
    if (_imageViewsArray != nil) {
        [_imageViewsArray removeAllObjects];
        _imageViewsArray = nil;
    }
    //为避免重复创建，先删除已经存在的
    for (UIView *view in self.subviews) {
        if ([view isKindOfClass:[UIImageView class]]) {
            [view removeFromSuperview];
        }
    }
    
    _isAutoCycle = isAuto;
    
    _imageViewsArray = [NSMutableArray arrayWithArray:imageArray];
    if (imageArray.count > 1) {
        [_imageViewsArray insertObject:imageArray[imageArray.count - 1] atIndex:0];
        [_imageViewsArray addObject:imageArray[0]];
    }
    
    for (int i = 0; i < _imageViewsArray.count; i++) {
        
        UIImageView *imageView = [[UIImageView alloc] init];
        imageView.frame = CGRectMake(self.frame.size.width * i, 0, self.frame.size.width, self.frame.size.height);
        //不管是不是本地操作，都要先给一张默认底图
        [imageView sd_setImageWithURL:[NSURL URLWithString:imageName] placeholderImage:[UIImage imageNamed:@""]];
        imageView.tag = i;
        [self addSubview:imageView];
        
        if (_isAutoCycle) {
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(clickImageViewAtIndex:)];
            imageView.userInteractionEnabled = YES;
            [imageView addGestureRecognizer:tap];
        }
        //图片淡入淡出的动画
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIView transitionWithView:imageView duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
//                imageView.image = [UIImage imageNamed:_imageViewsArray[i]];
                [imageView sd_setImageWithURL:_imageViewsArray[i] placeholderImage:[UIImage imageNamed:@""]];
            } completion:nil];
        });
//        [[MMDImageHandle instance] loadImageWithURL:_imageViewsArray[i] defaultImage:imageName block:^(NSData * _Nullable data) {
//            UIImage *bannerImage = [UIImage imageWithData:data];
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [UIView transitionWithView:imageView duration:0.5 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
//                    imageView.image = bannerImage;
//                } completion:nil];
//            });
//        }];
    }
    
    self.contentOffset = CGPointMake(CGRectGetWidth(self.frame), 0);
    self.contentSize = CGSizeMake(self.frame.size.width * _imageViewsArray.count, self.frame.size.height);
}

- (void)startAutoScrollView {
    if (self.timer == nil) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(autoScrollView) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopAutoScrollView {
    if (self.timer != nil) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_isAutoCycle) {
        NSLog(@"^^^^^^^^^^^^^^^AutoCycleScrollView touchesBegan^^^^^^^^^^^^^^>>>>>");
        if (self.viewTouchesBegan) {
            self.viewTouchesBegan();
        }
    }
}

@end
