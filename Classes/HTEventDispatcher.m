//
//  HTEventDispatcher.m
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTEventDispatcher.h"
#import "HTProxy.h"

@implementation HTEventDispatcher
{
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> * wrapperDependancyDict;
    NSMutableDictionary<NSString *, id<IHTWrapper, HTEventAdaptor>> *wrappers;
    NSMutableDictionary<NSString *, NSMutableArray<void(^)(void)> *> * wrapperCallbackDict;
    
    BOOL initing;
    NSMutableArray<NSString *> *cachingEvts;
}

+ (instancetype)shared
{
    static HTEventDispatcher *s_dispatcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_dispatcher = [HTEventDispatcher new];
    });
    
    return s_dispatcher;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        wrapperDependancyDict = [NSMutableDictionary dictionary];
        wrapperCallbackDict   = [NSMutableDictionary dictionary];
        wrappers = [NSMutableDictionary dictionary];
        cachingEvts = [NSMutableArray array];
    }
    return self;
}

#define KEY NSString *key = NSStringFromClass([wrapper class]);

- (void)wrapper:(id)wrapper delayFor:(NSString *)event
{
    NSParameterAssert(wrapper);
    NSParameterAssert(event);
    KEY
    // 这个接口由内部调用，不会有多线程问题
    NSMutableArray<NSString *> *values = [wrapperDependancyDict objectForKey:key];
    if ([values containsObject:event]) {
        @throw [NSException exceptionWithName:@"HTEventDispatcher" reason:[NSString stringWithFormat:@"Adding duplicated event: %@!", event] userInfo:nil];
    } else if (values == nil) {
        values = [NSMutableArray array];
        [wrapperDependancyDict setObject:values forKey:key];
    }
    [values addObject:event];
}


- (void)wrapper:(id)wrapper waitFor:(nonnull Protocol *)other
{
    NSParameterAssert(wrapper);
    KEY
    
    if (other == nil) {
        // 默认注册，只在没有任何事件依赖的时候生效
        if ([wrapperDependancyDict objectForKey:key] == nil) {
            [wrapperDependancyDict setObject:@[].mutableCopy forKey:key];
            [wrappers setObject:wrapper forKey:key];
        }
        return;
    }
    
    NSString *val = NSStringFromProtocol(other);
    
    // 实现方式决定了不会出现多线程访问的问题
    NSMutableArray<NSString *> *values = [wrapperDependancyDict objectForKey:key];
    if (values == nil) {
        values = [NSMutableArray array];
        [wrapperDependancyDict setObject:values forKey:key];
    }
    [values addObject:val];
    [wrappers setObject:wrapper forKey:key];
}

- (void)wrapper:(id)wrapper initDone:(BOOL)success
{
    if ([NSThread isMainThread]) {
        NSLog(@"[Fursion][Main][%@] done init", NSStringFromClass([wrapper class]));
    } else {
        NSLog(@"[Fursion][Sub][%@] done init", NSStringFromClass([wrapper class]));
    }
    if (!success) {
        // 其中一个SDK初始化失败应该怎么处理？
        NSLog(@"[Fursion]%@ Init failed", NSStringFromClass([wrapper class]));
    }
    
    // 先把缓存的调用都完成先
    NSArray<Protocol *> *protos = [wrapper committedProtocols];
    [protos enumerateObjectsUsingBlock:^(Protocol * _Nonnull p, NSUInteger idx, BOOL * _Nonnull stop) {
        NSArray<HTProxy *> *proxies = PopProxiesForProtocol(p);
        [proxies makeObjectsPerformSelector:@selector(execute)];
        
        // 通知其他Wrapper
        NSString *val = NSStringFromProtocol(p);
        
        // callback @ initDone
        [self excuteCallbacksAtInitDone:val];
        
        // 这个调用应该是同步执行
        [self executeWhileRemove:val];
    }];
}

- (void)dispatchEvent:(NSString *)event
{
    if ([NSThread isMainThread]) {
        [self executeWhileRemove:event];
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self executeWhileRemove:event];
        });
    }
}

- (void)executeWhileRemove:(NSString *)evt // remove after excute 一次性消息
{
    if (initing) {
        // 需要把事件缓存起来，等待上一次执行完再统一处理
        @synchronized (cachingEvts) {
            [cachingEvts addObject:evt];
        }
        return;
    }
    
    // 移除事件, 这个接口遍历效率比较高，用于移除依赖事件，将正处于等待的SDK解放出来
    [wrapperDependancyDict.allValues makeObjectsPerformSelector:@selector(removeObject:) withObject:evt];
    // 执行初始化, 该方法会执行此刻依赖为空的SDK初始化
    [self checkAndExecuteInit];
}

- (void)appStart  // 这个接口只会被调用一次
{
    [self checkAndExecuteInit];
}

- (void)checkAndExecuteInit
{
    // 开始初始化
    initing = YES;
    // 如果进入执行初始化，说明所有的Wrapper都应该注册完成，所以不需要考虑线程安全
    NSMutableArray *candidates = [NSMutableArray arrayWithCapacity:wrapperDependancyDict.count];
    // 提取满足条件的SDK Wrapper，这个接口在不耗时操作时候效率最高
    [wrapperDependancyDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSMutableArray<NSString *> * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj.count == 0) {
            [candidates addObject:key];
        }
    }];
    
    // 执行那些需要在主线程初始化的SDK
    for (int i = 0; i < candidates.count; i++) {
        NSString *key = candidates[i];
        // 从记录中移除
        [wrapperDependancyDict removeObjectForKey:key];
        // 执行初始化
        id<IHTWrapper, HTEventAdaptor> wrapper = [wrappers objectForKey:key];
        if (wrapper.requireMainQueue) {
            NSLog(@"[Fursion][Serial][%@] start init", NSStringFromClass([wrapper class]));
            [wrapper startInit];
            // 已经初始化从候选中移除
            [candidates removeObject:key];
            i--;
        }
    }
    
    // 执行那些可以并行在后台线程初始化的SDK
    // 这个接口在执行耗时操作效率最高
    [candidates enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id w = [wrappers objectForKey:obj];
        NSLog(@"[Fursion][Concurrent][%@] start init", NSStringFromClass([w class]));
        [w startInit];
    }];
    
    // 结束初始化
    initing = NO;
    
    // 检查是否有缓存事件，这里一定是线程安全的
    NSString *cachingEvt = [cachingEvts firstObject];
    if (cachingEvt != nil) {
        [cachingEvts removeObject:cachingEvt];
        [self executeWhileRemove:cachingEvt];
    }
}

#pragma mark - register callback @ initDone

/// 问题：1. 如果已经完成初始化的SDK应该直接执行callback即可(可以通过wrapperDependancyDict判断_需要处理多线程)
- (void)registerCallback:(void(^)(void))callback
              forWrapper:(id)wrapper
{
    KEY
    // 倘若注册回调之时，此SDK已经被初始化完成，则回调将被直接完成
    if(![wrapperDependancyDict.allKeys containsObject:key]){
        callback();
        return;
    }
    @synchronized (wrapperCallbackDict) {
        NSMutableArray* callbackArray = wrapperCallbackDict[key];
        if (callbackArray.count == 0){
            callbackArray = [NSMutableArray new];
        }
        [callbackArray addObject:callback];
        [wrapperCallbackDict setObject:callbackArray forKey:key];
    }
    
}

- (void)excuteCallbacksAtInitDone:(NSString*)key
{
    @synchronized (wrapperCallbackDict) {
         NSMutableArray* callbackArray = wrapperCallbackDict[key];
         for ( void (^callback)(void) in callbackArray) {
             callback();
         }
        [wrapperCallbackDict removeObjectForKey:key];
    }
    
}

@end
