//
//  AppDelegate.m
//  WeexDemo
//
//  Created by Mime97 on 2016/12/23.
//  Copyright © 2016年 Mime. All rights reserved.
//

#import "AppDelegate.h"
#import <WeexSDK.h>
#import "ViewController.h"
#import "WXDevTool.h"
#import "WXImageLoaderImpl.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)initWeex {
    //相关配置
    [WXAppConfiguration setAppGroup:@"MemeApp"];
    [WXAppConfiguration setAppName:@"WeexDemo"];
    [WXAppConfiguration setAppVersion:@"1.0.0"];
    //启动weex环境
    [WXSDKEngine initSDKEnviroment];
    //注册图片加载协议
    [WXSDKEngine registerHandler:[WXImageLoaderImpl new] withProtocol:@protocol(WXImgLoaderProtocol)];
#ifdef DEBUG
//    [WXDevTool setDebug:YES];
//    [WXDevTool launchDevToolDebugWithUrl:@"ws://99.48.58.63:8088/debugProxy/native"];
    
#else
    [WXDevTool setDebug:NO];
    
#endif
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self initWeex];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[ViewController alloc] initWithJs:@"weex_test_slider.js"];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}



@end
