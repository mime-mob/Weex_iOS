//
//  ViewController.m
//  NativeDemo
//
//  Created by Mime97 on 2017/1/19.
//  Copyright © 2017年 Mime. All rights reserved.
//

#import "ViewController.h"
#import "MMDCircleScrollView.h"
#import "UIImageView+WebCache.h"

@interface ViewController ()

@property (nonatomic, strong) MMDCircleScrollView *circleScrollView;
@property (nonatomic, strong) UIImageView *imageView1;
@property (nonatomic, strong) UIImageView *imageView2;
@property (nonatomic, strong) UIImageView *imageView3;
@property (nonatomic, strong) NSArray *imagesArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self setUpCircleScrollView];
    [self.view addSubview:self.imageView1];
    [self.view addSubview:self.imageView2];
    [self.view addSubview:self.imageView3];
}

- (MMDCircleScrollView *)circleScrollView {
    if (!_circleScrollView) {
        _circleScrollView = [[MMDCircleScrollView alloc] initWithFrame:CGRectMake(0,10, self.view.frame.size.width/2, 150)];
        [_circleScrollView startAutoScrollView];
    }
    return _circleScrollView;
}

- (void)setUpCircleScrollView {
    self.imagesArray = @[@"http://t.cn/RGE3uo9",@"http://t.cn/RGE31hq",@"http://t.cn/RGE3AJt"];
    [self.view addSubview:self.circleScrollView];
    [self.circleScrollView initAutoCycleImageViewWithImageArray:self.imagesArray defaultImage:@"http://t.cn/RGE3uo9" isAuto:YES];
}

- (UIImageView *)imageView1 {
    if (!_imageView1) {
        _imageView1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 160, self.view.frame.size.width/2, 150)];
        [_imageView1 sd_setImageWithURL:[NSURL URLWithString:@"http://t.cn/RGE3uo9"] placeholderImage:[UIImage imageNamed:@""]];
    }
    return _imageView1;
}

- (UIImageView *)imageView2 {
    if (!_imageView2) {
        _imageView2 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 310, self.view.frame.size.width/2, 150)];
        [_imageView2 sd_setImageWithURL:[NSURL URLWithString:@"http://t.cn/RGE31hq"] placeholderImage:[UIImage imageNamed:@""]];
    }
    return _imageView2;
}

- (UIImageView *)imageView3 {
    if (!_imageView3) {
        _imageView3 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 460, self.view.frame.size.width/2, 150)];
        [_imageView3 sd_setImageWithURL:[NSURL URLWithString:@"http://t.cn/RGE3AJt"] placeholderImage:[UIImage imageNamed:@""]];
    }
    return _imageView3;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
