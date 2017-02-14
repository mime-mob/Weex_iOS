//
//  WXEventModule.m
//  WeexDemo
//
//  Created by Mime97 on 2017/2/13.
//  Copyright © 2017年 Mime. All rights reserved.
//

#import "WXEventModule.h"
#import "ViewController.h"

@implementation WXEventModule

@synthesize weexInstance;

WX_EXPORT_METHOD(@selector(openURL:callback:))

- (void)openURL:(NSString *)url callback:(WXModuleCallback)callback {
    callback(@{@"result":@"===========succeed!=========="});
}

@end
