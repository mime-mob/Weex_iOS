//
//  ViewController.m
//  WeexDemo
//
//  Created by Mime97 on 2016/12/23.
//  Copyright © 2016年 Mime. All rights reserved.
//

#import "ViewController.h"
#import <WeexSDK.h>

@interface ViewController ()

@property (nonatomic, strong) WXSDKInstance *wxInstance;
@property (nonatomic, strong) UIView *wxView;
@property (nonatomic, strong) NSURL *jsUrl;

@end

@implementation ViewController

- (instancetype)initWithJs:(NSString *)jsPath {
    if (self = [super init]) {
        //远程js文件
//        NSString *path=[NSString stringWithFormat:@"http://99.48.58.63:8081/weex_tmp/h5_render/weex_test_slider.js?wsport=8082"];
        //本地js文件
        NSString *path = [NSString stringWithFormat:@"file://%@/js/%@",[NSBundle mainBundle].bundlePath,jsPath];
        self.jsUrl = [NSURL URLWithString:path];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rander) name:@"RefreshInstance" object:nil];
    [self rander];
}

- (void)rander {
    self.wxInstance = [[WXSDKInstance alloc] init];
    self.wxInstance.viewController = self;
    self.wxInstance.frame = self.view.frame;
    __weak typeof(self) weakSelf = self;
    self.wxInstance.onCreate = ^(UIView *view) {
        [weakSelf.wxView removeFromSuperview];
        weakSelf.wxView = view;
        [weakSelf.view addSubview:weakSelf.wxView];
    };
    self.wxInstance.onFailed = ^(NSError *error) {
        NSLog(@"加载失败");
    };
    self.wxInstance.renderFinish = ^(UIView *view) {
        NSLog(@"加载成功");
    };
    if (!self.jsUrl) {
        return;
    }
    [self.wxInstance renderWithURL:self.jsUrl];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self.wxInstance destroyInstance];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
