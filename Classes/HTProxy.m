//
//  HTProxy.m
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/30.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTProxy.h"

static NSLock *s_proxy_lock;
static NSMutableArray<HTProxy *> *s_proxies;

@interface HTProxy()
@property (nonatomic, weak) HTWrapperDeclare *declare;
@property (nonatomic, strong) NSInvocation *invocation;
@property (nonatomic, assign) BOOL inMainQueue;
@end

NSArray<HTProxy *> *PopProxiesForProtocol(Protocol *proto) {
    NSMutableArray *result = [NSMutableArray array];
    [s_proxy_lock lock];
    for (HTProxy *proxy in s_proxies) {
        if (proxy.declare.proto != proto) {
            continue;
        }
        [result addObject:proxy];
    }
    [s_proxies removeObjectsInArray:result];
    [s_proxy_lock unlock];
    return result;
}

@implementation HTProxy

+ (void)initialize
{
    s_proxy_lock = [NSLock new];
    s_proxies = [NSMutableArray array];
}

- (instancetype)initWithDeclare:(HTWrapperDeclare *)declare
{
    if (self = [super init]) {
        _declare = declare;
    }
    return self;
}

- (void)execute
{
    id target = [self.declare.wrapper instanceForProtocol:self.declare.proto];
    if (self.inMainQueue) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.invocation invokeWithTarget:target];
        });
    } else {
        [self.invocation invokeWithTarget:target];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    Class clazz = [self.declare.wrapper classForProtocol:self.declare.proto];
    return [clazz instanceMethodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if (![anInvocation.target isKindOfClass:[HTProxy class]]) {
        [super forwardInvocation:anInvocation];
        return;
    }
    
    const char *returnType = [anInvocation.methodSignature methodReturnType];
    
    NSAssert(returnType[0] == 'v', @"Trying to proxy invoke method (%@),which contains non-void return value! This is not supported, please change it to callback.",NSStringFromSelector(anInvocation.selector));

    NSAssert(self.invocation == nil, @"Invocation already exists! This may happend when you try to assign HT_EXECUTOR(someWrapperProtocol) to a variable, and send message to it mulitiple times.\
             \
             id impl = HT_EXECUTOR(IWrapperProtocol);\
             [impl foo];\
             [impl bar];\
             Do not reference the return value of HT_EXECUTOR, instead, send message to it every time.\
             [HT_EXECUTOR(IWrapperProtocol) foo];\
             [HT_EXECUTOR(IWrapperProtocol) bar];\
             ");
    
    if (self.invocation != nil) {
        return;
    }
    [anInvocation retainArguments];
    self.invocation = anInvocation;
    self.inMainQueue = strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0;
    
    // Add to queue
    [s_proxy_lock lock];
    [s_proxies addObject:self];
    [s_proxy_lock unlock];
}

@end
