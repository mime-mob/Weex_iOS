//
//  WXDebugger.m
//  PonyDebugger
//
//  Created by Mike Lewis on 11/5/11.
//
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.
//

#import <UIKit/UIKit.h>
#import "SRWebSocket.h"
#import "WXDebugger.h"
#import "WXDynamicDebuggerDomain.h"
#import "WXNetworkDomain.h"
#import "WXPrettyStringPrinter.h"
#import "WXDomainController.h"

#import "WXNetworkDomainController.h"
#import "WXRuntimeDomainController.h"
#import "WXPageDomainController.h"
#import "WXIndexedDBDomainController.h"
#import "WXDOMDomainController.h"
#import "WXInspectorDomainController.h"
#import "WXConsoleDomainController.h"
#import "WXSourceDebuggerDomainController.h"
#import "WXTimelineDomainController.h"
#import "WXCSSDomainController.h"
#import "WXDebugDomainController.h"
#import "WXDevToolType.h"

#import "WXDeviceInfo.h"
#import <WeexSDK/WeexSDK.h>

#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/utsname.h>

static NSString *const WXBonjourServiceType = @"_ponyd._tcp";
static BOOL WXIsVDom = NO;


void _WXLogObjectsImpl(NSString *severity, NSArray *arguments)
{
    [[WXConsoleDomainController defaultInstance] logWithArguments:arguments severity:severity];
}


@interface WXDebugger () <SRWebSocketDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>

- (void)_resolveService:(NSNetService*)service;
- (void)_addController:(WXDomainController *)controller;
- (NSString *)_domainNameForController:(WXDomainController *)controller;
- (BOOL)_isTrackingDomainController:(WXDomainController *)controller;

@end


@implementation WXDebugger {
    NSString *_bonjourServiceName;
    NSNetServiceBrowser *_bonjourBrowser;
    NSMutableArray *_bonjourServices;
    NSNetService *_currentService;
    NSMutableDictionary *_domains;
    NSMutableDictionary *_controllers;
    __strong SRWebSocket *_socket;
    NSMutableArray  *_msgAry;
    NSMutableArray  *_debugAry;
    BOOL _isConnect;
    WXJSCallNative  _nativeCallBlock;
    WXJSCallAddElement _callAddElementBlock;
    NSThread    *_bridgeThread;
    NSThread    *_inspectThread;
    NSString    *_registerData;
}

+ (WXDebugger *)defaultInstance;
{
    static dispatch_once_t onceToken;
    static WXDebugger *defaultInstance = nil;
    dispatch_once(&onceToken, ^{
        defaultInstance = [[super allocWithZone:NULL] init];
    });
    
    return defaultInstance;
}

+ (id) allocWithZone:(struct _NSZone *)zone {
    return [self defaultInstance];
}

- (id)init;
{
    self = [super init];
    if (!self) {
        return nil;
    }
    _isConnect = NO;
    _domains = [[NSMutableDictionary alloc] init];
    _controllers = [[NSMutableDictionary alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationIsDebug:) name:@"WXDevtoolDebug" object:nil];
    
    return self;
}

- (void) coutLogWithLevel:(NSString *)level arguments:(NSArray *)arguments {
    
    [[WXConsoleDomainController defaultInstance] logWithArguments:arguments severity:level];
}

#pragma mark - SRWebSocketDelegate

- (void)webSocketDidOpen:(SRWebSocket *)webSocket;
{
    _isConnect = YES;
    NSString *deviceID = [WXDeviceInfo getDeviceID];
    NSString *machine = [self _deviceName] ? : @"";
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        deviceID, @"deviceId",
        @"iOS", @"platform",
        machine, @"model",
        [WXSDKEngine SDKEngineVersion],@"weexVersion",
        [WXDevTool WXDevtoolVersion],@"devtoolVersion",
        appName, @"name",
        [WXLog logLevelString] ?: @"error",@"logLevel",
        [NSNumber numberWithBool:[WXDevToolType isDebug]],@"remoteDebug",
        nil];
    [self _registerDeviceWithParams:parameters];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(NSString *)message;
{
    if ([WXDevToolType isDebug]) {
        [self _changeToDebugLogicMessage:message];
    }
    
    NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:[message dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];

    NSString *fullMethodName = [obj objectForKey:@"method"];
    NSInteger dotPosition = [fullMethodName rangeOfString:@"."].location;
    NSString *domainName = [fullMethodName substringToIndex:dotPosition];
    NSString *methodName = [fullMethodName substringFromIndex:dotPosition + 1];
    NSString *objectID = [obj objectForKey:@"id"];

    WXResponseCallback responseCallback = ^(NSDictionary *result, id error) {
        NSMutableDictionary *response = [[NSMutableDictionary alloc] initWithCapacity:2];
        [response setValue:objectID forKey:@"id"];

        if (result) {
            NSMutableDictionary *newResult = [[NSMutableDictionary alloc] initWithCapacity:result.count];
            [result enumerateKeysAndObjectsUsingBlock:^(id key, id val, BOOL *stop) {
                [newResult setObject:[val WX_JSONObjectCopy] forKey:key];
            }];
            [response setObject:newResult forKey:@"result"];
        }else {
            NSMutableDictionary *newResult = [[NSMutableDictionary alloc] init];
            [response setObject:newResult forKey:@"result"];
        }

        NSData *data = [NSJSONSerialization dataWithJSONObject:response options:0 error:nil];
        NSString *encodedData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self _executeBridgeThead:^() {
            [webSocket send:encodedData];
        }];
    };

    WXDynamicDebuggerDomain *domain = [self domainForName:domainName];

    if (domain) {
        [domain handleMethodWithName:methodName parameters:[obj objectForKey:@"params"] responseCallback:[responseCallback copy]];
    } else {
        responseCallback(nil, [NSString stringWithFormat:@"unknown domain %@", domainName]);
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;
{
    NSLog(@"Debugger closed");
    _socket.delegate = nil;
    _socket = nil;
    _isConnect = NO;
    [self _addOvertimeMonitor];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error;
{
    NSLog(@"Debugger failed with web socket error: %@", [error localizedDescription]);
    _socket.delegate = nil;
    _socket = nil;
}

#pragma mark - timer
- (void)_addOvertimeMonitor
{
    NSTimer *timer = [NSTimer timerWithTimeInterval:5 target:self selector:@selector(_webSocketOvertime) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}
- (void)_webSocketOvertime
{
    if ([WXDevToolType isDebug]) {
        [WXDevToolType setDebug:NO];
        [WXSDKEngine restart];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"RefreshInstance" object:nil];
    }
}

#pragma mark - NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing;
{
    const NSStringCompareOptions compareOptions = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    if (_bonjourServiceName != nil && [_bonjourServiceName compare:service.name options:compareOptions] != NSOrderedSame) {
        return;
    }
    
    NSLog(@"Found ponyd bonjour service: %@", service);
    [_bonjourServices addObject:service];
    
    if (!_currentService) {
        [self _resolveService:service];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didRemoveService:(NSNetService*)service moreComing:(BOOL)moreComing;
{
    if ([service isEqual:_currentService]) {
        [_currentService stop];
        _currentService.delegate = nil;
        _currentService = nil;
    }
    
    NSUInteger serviceIndex = [_bonjourServices indexOfObject:service];
    if (NSNotFound != serviceIndex) {
        [_bonjourServices removeObjectAtIndex:serviceIndex];
        NSLog(@"Removed ponyd bonjour service: %@", service);
        
        // Try next one
        if (!_currentService && _bonjourServices.count){
            NSNetService* nextService = [_bonjourServices objectAtIndex:(serviceIndex % _bonjourServices.count)];
            [self _resolveService:nextService];
        }
    }
}

#pragma mark - NSNetServiceDelegate

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict;
{
    NSAssert([service isEqual:_currentService], @"Did not resolve incorrect service!");
    _currentService.delegate = nil;
    _currentService = nil;
    
    // Try next one, we may retry the same one if there's only 1 service in _bonjourServices
    NSUInteger serviceIndex = [_bonjourServices indexOfObject:service];
    if (NSNotFound != serviceIndex) {
        if (_bonjourServices.count){
            NSNetService* nextService = [_bonjourServices objectAtIndex:((serviceIndex + 1) % _bonjourServices.count)];
            [self _resolveService:nextService];
        }
    }
}


- (void)netServiceDidResolveAddress:(NSNetService *)service;
{
    NSAssert([service isEqual:_currentService], @"Resolved incorrect service!");

    [self connectToURL:[NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:%ld/device", [service hostName], (long)[service port]]]];
}

#pragma mark - Public Methods

- (id)domainForName:(NSString *)name;
{
    return [_domains valueForKey:name];
}

- (void)sendEventWithName:(NSString *)methodName parameters:(id)params;
{
    NSDictionary *obj = [[NSDictionary alloc] initWithObjectsAndKeys:methodName, @"method", [params WX_JSONObject], @"params",nil];

    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    NSString *encodedData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [_msgAry addObject:encodedData];
        [weakSelf _executionMsgAry];
    });
}

#pragma mark Connect / Disconnect

/**
 * Connect to any ponyd service found via Bonjour.
 */
- (void)autoConnect;
{
    [self autoConnectToBonjourServiceNamed:nil];
}

/**
 * Only connect to the specified Bonjour service name, this makes things easier in a teamwork
 * environment where multiple instances of ponyd may run on the same network.
 */
- (void)autoConnectToBonjourServiceNamed:(NSString*)serviceName;
{
    if (_bonjourBrowser) {
        return;
    }
    
    _bonjourServiceName = serviceName;
    _bonjourServices = [NSMutableArray array];
    _bonjourBrowser = [[NSNetServiceBrowser alloc] init];
    [_bonjourBrowser setDelegate:self];
    
    if (_bonjourServiceName) {
        NSLog(@"Waiting for ponyd bonjour service '%@'...", _bonjourServiceName);
    } else {
        NSLog(@"Waiting for ponyd bonjour service...");
    }
    [_bonjourBrowser searchForServicesOfType:WXBonjourServiceType inDomain:@""];
}

- (void)connectToURL:(NSURL *)url;
{
    NSLog(@"Connecting to %@", url);
    if (_socket && _isConnect) {
        return;
    }
    _msgAry = nil;
    _msgAry = [NSMutableArray array];
    _debugAry = nil;
    _debugAry = [NSMutableArray array];
    if (![WXDevToolType isDebug]) {
        _bridgeThread = nil;
    }
    _registerData = nil;
    _isConnect = NO;
    
    [_socket close];
    _socket.delegate = nil;
    
    _socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:url]];
    _socket.delegate = self;
    [_socket open];
}

- (BOOL)isConnected;
{
    return _socket && _socket.readyState == SR_OPEN;
}

- (void)disconnect;
{
    _nativeCallBlock = nil;
    _callAddElementBlock = nil;
    _msgAry = nil;
    _debugAry = nil;
    [_bonjourBrowser stop];
    _bonjourBrowser.delegate = nil;
    _bonjourBrowser = nil;
    _bonjourServiceName = nil;
    _bonjourServices = nil;
    [_currentService stop];
    _currentService.delegate = nil;
    _currentService = nil;
    
    [_socket close];
    _socket.delegate = nil;
    _socket = nil;
}

#pragma mark - set get method
+ (void)setVDom:(BOOL)isVDom {
    WXIsVDom = isVDom;
}

+ (BOOL)isVDom {
    return WXIsVDom;
}

#pragma mark - Public Interface

#pragma mark Network Debugging

- (void)enableNetworkTrafficDebugging;
{
    [self _addController:[WXNetworkDomainController defaultInstance]];
}

- (void)disEnableNetworkTrafficDebugging
{
    [self _removeController:[WXNetworkDomainController defaultInstance]];
}

- (void)forwardAllNetworkTraffic;
{
    [WXNetworkDomainController registerPrettyStringPrinter:[[WXJSONPrettyStringPrinter alloc] init]];
    [WXNetworkDomainController injectIntoAllNSURLConnectionDelegateClasses];
    [WXNetworkDomainController swizzleNSURLSessionClasses];
}

- (void)cancleAllNetworkTraffic
{
    
}

- (void)forwardNetworkTrafficFromDelegateClass:(Class)cls;
{
    [WXNetworkDomainController injectIntoDelegateClass:cls];
}

+ (void)registerPrettyStringPrinter:(id<WXPrettyStringPrinting>)prettyStringPrinter;
{
    [WXNetworkDomainController registerPrettyStringPrinter:prettyStringPrinter];
}

+ (void)unregisterPrettyStringPrinter:(id<WXPrettyStringPrinting>)prettyStringPrinter;
{
    [WXNetworkDomainController unregisterPrettyStringPrinter:prettyStringPrinter];
}

#pragma mark Core Data Debugging

- (void)enableCoreDataDebugging;
{
    [self _addController:[WXRuntimeDomainController defaultInstance]];
    [self _addController:[WXPageDomainController defaultInstance]];
    [self _addController:[WXIndexedDBDomainController defaultInstance]];
}

- (void)addManagedObjectContext:(NSManagedObjectContext *)context;
{
    [[WXIndexedDBDomainController defaultInstance] addManagedObjectContext:context];
}

- (void)addManagedObjectContext:(NSManagedObjectContext *)context withName:(NSString *)name;
{
    [[WXIndexedDBDomainController defaultInstance] addManagedObjectContext:context withName:name];
}

- (void)removeManagedObjectContext:(NSManagedObjectContext *)context;
{
    [[WXIndexedDBDomainController defaultInstance] removeManagedObjectContext:context];
}

#pragma mark View Hierarchy Debugging

- (void)enableViewHierarchyDebugging;
{
    [self _addController:[WXDOMDomainController defaultInstance]];
    [self _addController:[WXInspectorDomainController defaultInstance]];
    
    // Choosing frame, alpha, and hidden as the default key paths to display
    [[WXDOMDomainController defaultInstance] setViewKeyPathsToDisplay:@[@"frame", @"alpha", @"hidden"]];
    
    [WXDOMDomainController startMonitoringWeexComponentChanges];
}

- (void)setDisplayedViewAttributeKeyPaths:(NSArray *)keyPaths;
{
    [[WXDOMDomainController defaultInstance] setViewKeyPathsToDisplay:keyPaths];
}

#pragma mark Remote Logging

- (void)enableRemoteLogging;
{
    [self _addController:[WXConsoleDomainController defaultInstance]];
}

- (void)clearConsole;
{
    [[WXConsoleDomainController defaultInstance] clear];
}

#pragma mark Remote Debugging
- (void)enableRemoteDebugger {
    [self _addController:[WXRuntimeDomainController defaultInstance]];
    [self _addController:[WXPageDomainController defaultInstance]];
    [self _addController:[WXSourceDebuggerDomainController defaultInstance]];
}

- (void)remoteDebuggertest {
    [[WXSourceDebuggerDomainController defaultInstance] remoteDebuggerControllerTest];
}

#pragma mark - Timeline
- (void)enableTimeline {
    [self _addController:[WXTimelineDomainController defaultInstance]];
}

#pragma mark CSSStyle
- (void)enableCSSStyle {
    [self _addController:[WXCSSDomainController defaultInstance]];
}

#pragma mark - DevToolDebug
- (void)enableDevToolDebug {
    [self _addController:[WXDebugDomainController defaultInstance]];
}

#pragma mark - WXBridgeProtocol
- (void)executeJSFramework:(NSString *)frameworkScript {
    NSDictionary *WXEnvironment = @{@"WXEnvironment":[WXUtility getEnvironment]};
    NSDictionary *args = @{@"source":frameworkScript, @"env":WXEnvironment};
    [self callJSMethod:@"WxDebug.initJSRuntime" params:args];
}

- (void)callJSMethod:(NSString *)method params:(NSDictionary*)params {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:method forKey:@"method"];
    [dict setObject:params forKey:@"params"];
    [_debugAry addObject:[WXUtility JSONString:dict]];
    [self _executionDebugAry];
}

- (JSValue *)callJSMethod:(NSString *)method args:(NSArray *)args {
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    NSString *nonullMethod = method ? : @"";
    NSArray *nonullArgs = args ? : [NSArray array];
    [params setObject:nonullMethod forKey:@"method"];
    [params setObject:nonullArgs forKey:@"args"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@"WxDebug.callJS" forKey:@"method"];
    [dict setObject:params forKey:@"params"];
    
    [_debugAry addObject:[WXUtility JSONString:dict]];
    [self _executionDebugAry];
    return nil;
}

- (void)registerCallNative:(WXJSCallNative)callNative
{
    [self _initBridgeThread];
    _nativeCallBlock = callNative;
}

- (void)registerCallAddElement:(WXJSCallAddElement)callAddElement
{
    _callAddElementBlock = callAddElement;
}

- (JSValue*) exception
{
    return nil;
}

- (void)resetEnvironment
{
    [self _initEnvironment];
}

#pragma mark - notification 
- (void)notificationIsDebug:(NSNotification *)notification {
    if ([notification.object boolValue]) {
        _bridgeThread = nil;
    }
}

#pragma mark - Private Methods
- (void)_changeToDebugLogicMessage:(NSString *)message {
    __weak typeof(self) weakSelf = self;
    [self _executeBridgeThead:^() {
        [weakSelf _evaluateNative:message];
    }];
}

- (void)_initBridgeThread {
    _bridgeThread = [NSThread currentThread];
}

- (void)_executeBridgeThead:(dispatch_block_t)block
{
    if ([WXDevToolType isDebug]) {
        if([NSThread currentThread] == _bridgeThread) {
            block();
        } else if (_bridgeThread){
            [self performSelector:@selector(_executeBridgeThead:)
                         onThread:_bridgeThread
                       withObject:[block copy]
                    waitUntilDone:NO];
        }
    } else {
        if([NSThread currentThread] == [NSThread mainThread]) {
            block();
        } else {
            [self performSelector:@selector(_executeBridgeThead:)
                         onThread:[NSThread mainThread]
                       withObject:[block copy]
                    waitUntilDone:NO];
        }
    }
    
    /*
    if([NSThread currentThread] == _bridgeThread){
        block();
    } else {
        [self performSelector:@selector(_executeBridgeThead:)
                     onThread:_curThread
                   withObject:[block copy]
                waitUntilDone:NO];
    }
     */
}

-(void)_evaluateNative:(NSString *)data
{
    NSDictionary *dict = [WXUtility objectFromJSON:data];
    
    NSString *fullMethodName = [dict objectForKey:@"method"];
    NSInteger dotPosition = [fullMethodName rangeOfString:@"."].location;
    NSString *method = [fullMethodName substringFromIndex:dotPosition + 1];
    
    NSDictionary *args = [dict objectForKey:@"params"];
    
    if ([method isEqualToString:@"callNative"]) {
        // call native
        NSString *instanceId = args[@"instance"];
        NSArray *methods = args[@"tasks"];
        NSString *callbackId = args[@"callback"];
        
        // params parse
        if(!methods || methods.count <= 0){
            return;
        }
        //call native
        WXLogInfo(@"Calling native... instancdId:%@, methods:%@, callbackId:%@", instanceId, [WXUtility JSONString:methods], callbackId);
        _nativeCallBlock(instanceId, methods, callbackId);
    }
    
    if ([method isEqualToString:@"callAddElement"]) {
        NSString *instanceId = args[@"instance"] ? : @"";
        NSDictionary *componentData = args[@"dom"] ? : [NSDictionary dictionary];
        NSString *parentRef = args[@"ref"] ? : @"";
        NSNumber *index = args[@"index"] ? : [NSNumber numberWithInteger:0];
        NSInteger insertIndex = index.integerValue;
        
        WXLogDebug(@"callAddElement...%@, %@, %@, %ld", instanceId, parentRef, componentData, (long)insertIndex);
        _callAddElementBlock(instanceId, parentRef, componentData, insertIndex);
        
    }
}

- (void)_executionDebugAry {
    if (!_isConnect) return;
    
    NSArray *templateContainers = [NSArray arrayWithArray:_debugAry];
    for (NSString *msg in templateContainers) {
        [_socket send:msg];
    }
    [_debugAry removeAllObjects];
}

- (void)_executionMsgAry {
    if (!_isConnect) return;
    
    NSArray *templateContainers = [NSArray arrayWithArray:_msgAry];
    for (NSString *msg in templateContainers) {
        [_socket send:msg];
    }
    [_msgAry removeAllObjects];
}


- (NSString *)_deviceName
{
    /*
    UIDevice *device = [UIDevice currentDevice];
#if TARGET_IPHONE_SIMULATOR
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *userName = [environment objectForKey:@"USER"];
    if (!userName) {
        NSString *simulatorHostHome = [environment objectForKey:@"SIMULATOR_HOST_HOME"];
        if ([simulatorHostHome hasPrefix:@"/Users/"]) {
            userName = [simulatorHostHome substringFromIndex:7];
        }
    }
    NSString *deviceName = userName ? [NSString stringWithFormat:@"%@'s Simulator", userName] : @"iOS Simulator";
#else
    NSString *deviceName = device.name;
#endif
  */

//    struct utsname systemInfo;
//    uname(&systemInfo);
//    NSString *machine = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *machine = [[UIDevice currentDevice] model];
    NSString *systemVer = [[UIDevice currentDevice] systemVersion] ? : @"";
    NSString *model = [NSString stringWithFormat:@"%@:%@",machine,systemVer];
    return model;
}


- (void)_registerDeviceWithParams:(id)params {
    NSDictionary *obj = [[NSDictionary alloc] initWithObjectsAndKeys:
                         @"WxDebug.registerDevice", @"method",
                         [params WX_JSONObject], @"params",
                         [NSNumber numberWithInt:0],@"id",
                         nil];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    NSString *encodedData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    _registerData = encodedData;
    
    if (_bridgeThread) {
        [self _executeBridgeThead:^{
            [_debugAry insertObject:encodedData atIndex:0];
            [self _executionDebugAry];
        }];
    }else {
        [_socket send:encodedData];
    }
    
    /*
    if (_bridgeThread) {
        [self _executeBridgeThead:^{
            [_debugAry insertObject:encodedData atIndex:0];
            [self _executionDebugAry];
        }];
    }else if(![WXDevToolType isDebug]) {
        [self _executeBridgeThead:^{
            [_msgAry insertObject:encodedData atIndex:0];
            [self _executionMsgAry];
        }];
    }
     */
}

- (void)_resolveService:(NSNetService*)service;
{
    NSLog(@"Resolving %@", service);
    _currentService = service;
    _currentService.delegate = self;
    [_currentService resolveWithTimeout:10.f];
}

- (void)_initEnvironment
{
    [self callJSMethod:@"setEnvironment" args:@[[WXUtility getEnvironment]]];
}

- (NSString *)_domainNameForController:(WXDomainController *)controller;
{
    Class cls = [[controller class] domainClass];
    return [cls domainName];
}

- (void)_addController:(WXDomainController *)controller;
{
    NSString *domainName = [self _domainNameForController:controller];
    if ([_domains objectForKey:domainName]) {
        return;
    }
    
    Class cls = [[controller class] domainClass];
    WXDynamicDebuggerDomain *domain = [(WXDynamicDebuggerDomain *)[cls alloc] initWithDebuggingServer:self];
    [_domains setObject:domain forKey:domainName];
    
    controller.domain = domain;
    domain.delegate = controller;
}

- (void)_removeController:(WXDomainController *)controller
{
    NSString *domainName = [self _domainNameForController:controller];
    if ([_domains objectForKey:domainName]) {
        [_domains removeObjectForKey:domainName];
    }
}

- (BOOL)_isTrackingDomainController:(WXDomainController *)controller;
{
    NSString *domainName = [self _domainNameForController:controller];
    if ([_domains objectForKey:domainName]) {
        return YES;
    }
    
    return NO;
}

/*
#pragma mark - server
- (void)serverStartWithHost:(NSString *)host port:(NSUInteger)port {
    if (!_server) {
        _server = [PSWebSocketServer serverWithHost:host port:port];
        _server.delegate = self;
        [_server start];
    }
}

#pragma mark - PSWebSocketServerDelegate

- (void)serverDidStart:(PSWebSocketServer *)server {
    NSLog(@"Server did start…");
}
- (void)serverDidStop:(PSWebSocketServer *)server {
    NSLog(@"Server did stop…");
}
- (BOOL)server:(PSWebSocketServer *)server acceptWebSocketWithRequest:(NSURLRequest *)request {
    NSLog(@"Server should accept request: %@", request);
    return YES;
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"Server websocket did receive message: %@", message);
}
- (void)server:(PSWebSocketServer *)server webSocketDidOpen:(PSWebSocket *)webSocket {
    NSLog(@"Server websocket did open");
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"Server websocket did close with code: %@, reason: %@, wasClean: %@", @(code), reason, @(wasClean));
}
- (void)server:(PSWebSocketServer *)server webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"Server websocket did fail with error: %@", error);
}
*/

@end
