//
//  HTContext.m
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTContext.h"
#import "HTWrapperDeclare.h"
#import "HTEventDispatcher.h"
#import "HTProxy.h"

#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <mach-o/ldsyms.h>

#pragma mark __MANAGER

static NSLock *s_wrap_lock;
static NSMutableDictionary *s_wrapperDeclares;

NSArray<HTWrapperDeclare *> *AllWrapperDeclares() {
    [s_wrap_lock lock];
    NSArray *candidates = s_wrapperDeclares.allValues;
    [s_wrap_lock unlock];
    return candidates;
}

HTWrapperDeclare *HTWrapperDeclareForProtocol(Protocol *proto) {
    NSString *key = NSStringFromProtocol(proto);
    id result = nil;
    [s_wrap_lock lock];
    result = [s_wrapperDeclares objectForKey:key];
    [s_wrap_lock unlock];
    return result;
}

#pragma mark __DATA Reader

static char* kWrapperSectionName = "HTWrapper";

NSArray<NSString *>* SFReadSectionData(char *sectionName,const struct mach_header *mhp)
{
    NSMutableArray *configs = [NSMutableArray array];
    unsigned long size = 0;
#ifndef __LP64__
    uintptr_t *memory = (uintptr_t*)getsectiondata(mhp, SEG_DATA, sectionName, &size);
#else
    const struct mach_header_64 *mhp64 = (const struct mach_header_64 *)mhp;
    uintptr_t *memory = (uintptr_t*)getsectiondata(mhp64, SEG_DATA, sectionName, &size);
#endif
    
    unsigned long counter = size/sizeof(void*);
    for(int idx = 0; idx < counter; ++idx){
        char *string = (char*)memory[idx];
        NSString *str = [NSString stringWithUTF8String:string];
        if(!str)continue;
        if(str) [configs addObject:str];
    }
    
    return configs;
}


static void SFBreakupSectionData(char *secName, const struct mach_header *mhp, void(^iterationBlock)(NSArray *parts))
{
    NSArray <NSString *> *strings = SFReadSectionData(secName, mhp);
    if (strings.count > 0) {
        for (NSString *str in strings) {
            NSArray *parts = [str componentsSeparatedByString:@"#"];
            iterationBlock(parts);
        }
    }
}

static void sf_onloaded(const struct mach_header *mhp, intptr_t vmaddr_slide)
{
    if (s_wrap_lock == nil) {
        s_wrap_lock = [NSLock new];
        s_wrapperDeclares = [NSMutableDictionary dictionary];
    }
    
    SFBreakupSectionData(kWrapperSectionName, mhp, ^(NSArray *parts) {
        Class clazz = NSClassFromString(parts[0]);
        if (clazz == nil) {
            return;
        }
        Protocol *proto = NSProtocolFromString(parts[1]);
        if (proto == nil) {
            return;
        }
        HTWrapperDeclare *declare = [[HTWrapperDeclare alloc] initWithClass:clazz proto:proto];
        NSString *protoName = NSStringFromProtocol(proto);
        [s_wrapperDeclares setObject:declare forKey:protoName];
    });
}

__attribute__((constructor))
void initProphet()
{
    _dyld_register_func_for_add_image(sf_onloaded);
}

#pragma mark - SFContext

static void *const GlobalConntextQueueIdentityKey = (void *)&GlobalConntextQueueIdentityKey;
static dispatch_queue_t contextQueue;

static inline void SYNC_EXECUTE_IN_QUEUE(dispatch_block_t block) {
    if (dispatch_get_specific(GlobalConntextQueueIdentityKey)) {
        block();
    } else {
        dispatch_sync(contextQueue, block);
    }
}
static inline void ASYNC_EXECUTE_IN_QUEUE(dispatch_block_t block) {
    dispatch_async(contextQueue, block);
}

@implementation HTContext
{
    NSMutableDictionary *_globalDictionary;
    NSDictionary *_launchOptions;
    HTParameters *_parameters;
}

#pragma mark Class Functions

+ (void)initialize
{
    contextQueue = dispatch_queue_create("smartframework.context", NULL);
    void *nonNullValue = GlobalConntextQueueIdentityKey;
    dispatch_queue_set_specific(contextQueue, GlobalConntextQueueIdentityKey, nonNullValue, NULL);
}

+ (instancetype)shared
{
    static HTContext *s_context = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_context = [HTContext new];
    });
    return s_context;
}

+ (void)initWithParameters:(HTParameters *)parameters launchOptions:(NSDictionary *)launchOptions
{
    HTContext *context = [self shared];
    context->_parameters = parameters;
    context->_launchOptions = launchOptions;
    [context onInit];
}

+ (void)setGlobalValue:(id)value forKey:(NSString *)key
{
    HTContext *context = [self shared];
    SYNC_EXECUTE_IN_QUEUE(^{
        if (!context->_globalDictionary) {
            context->_globalDictionary = [NSMutableDictionary new];
        }
        [context->_globalDictionary setObject:value forKey:key];
    });
}

+ (NSDictionary *)globalDictionary
{
    __block NSDictionary *result = nil;
    SYNC_EXECUTE_IN_QUEUE(^{
        result = [((HTContext *)(self.shared))->_globalDictionary copy];
    });
    return result;
}

+ (NSDictionary *)launchOptions
{
    return ((HTContext *)[self shared])->_launchOptions;
}

+ (HTParameters *)parameters
{
    return ((HTContext *)[self shared])->_parameters;
}

+ (id)executorFor:(Protocol *)protocol allowDelay:(BOOL)allowDelay
{
    HTWrapperDeclare *declare = HTWrapperDeclareForProtocol(protocol);
    if (declare == nil) {
#if DEBUG
         NSAssert(NO, @"No known bingding for [%@]", protocol);
#else
        return nil;
#endif
    }
    id ins = [declare.wrapper instanceForProtocol:protocol];
    if (ins == nil) {
        if (!allowDelay) {
#if !DEBUG
            @throw [NSException exceptionWithName:@"HTProtocolNotReady" reason:@"This method is not ready for calling, please re-check your code" userInfo:nil];
#else
            // 这里还需要更加明确的日志提示，以便发现问题
            NSLog(@"[Fursion][Error] Implementation for %@ is not ready", NSStringFromProtocol(protocol));
            if (![NSThread isMainThread]) {
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                int delay = 3;
                while (ins == nil
                       && CFAbsoluteTimeGetCurrent() - currentTime < delay) {
                    ins = [declare.wrapper instanceForProtocol:protocol];
                    // 子线程没有Runloop，需要使用sleep接口
                    sleep(.01);
                    NSLog(@"[Fursion]checking %@", NSStringFromProtocol(protocol));
                }
                if (ins == nil) {
                    NSLog(@"[Fursion][Error] Implementation for %@ is not ready after %i seconds, calling will be ignore", NSStringFromProtocol(protocol), delay);
                }
            } else {
                NSLog(@"[Fursion][Error] Calling of %@ will be ignore in main thread!", NSStringFromProtocol(protocol));
            }
#endif
        } else {
            // 允许延迟调用
            return [[HTProxy alloc] initWithDeclare:declare];
        }
    }
    return ins;
}

+ (id)declareFor:(Protocol *)protocol
{
    return HTWrapperDeclareForProtocol(protocol).wrapper;
}

+ (void)registerWrapper:(id)wrapper forProtocol:(Protocol *)protocol
{
    HTWrapperDeclare *declare = [[HTWrapperDeclare alloc] initWithWrapper:wrapper proto:protocol];
    NSString *protoName = NSStringFromProtocol(protocol);
    [s_wrapperDeclares setObject:declare forKey:protoName];
}

+ (void)delayProtocols:(NSArray<Protocol *> *)protocols withEvent:(NSString *)event
{
    for (Protocol *proto in protocols) {
        [self delayProtocol:proto withEvent:event];
    }
}

+ (void)delayProtocol:(Protocol *)protocol withEvent:(NSString *)event
{
    if (event == nil) {
        return;
    }
    id wrapper = HTWrapperDeclareForProtocol(protocol).wrapper;
    if (wrapper == nil) {
        NSLog(@"[Fursion]No wrapper found for protocol: %@", NSStringFromProtocol(protocol));
    }
    
    SYNC_EXECUTE_IN_QUEUE(^{
        [HTEventDispatcher.shared wrapper:wrapper delayFor:event];
    });
}

+ (void)dispatchEvent:(NSString *)event
{
    [HTEventDispatcher.shared dispatchEvent:event];
}

+ (void)waitForProtocol:(Protocol *)protocol callback:(void (^)(void))callback
{
    id wrapper = HTWrapperDeclareForProtocol(protocol).wrapper;
    if (wrapper){
        [HTEventDispatcher.shared registerCallback:callback
                                        forWrapper:wrapper];
    }
    
}

#pragma mark Instance Functions

- (void)onInit
{
    NSArray<HTWrapperDeclare *> *declares = AllWrapperDeclares();
    
    // 在onInit事件完成依赖关系的添加
    [declares makeObjectsPerformSelector:@selector(onInit)];
    
    // 通知开始初始化
    [HTEventDispatcher.shared appStart];
}

@end
