//
//  HTWrapperDeclare.m
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTWrapperDeclare.h"
#import "HTEventDispatcher.h"

@implementation HTWrapperDeclare

- (instancetype)initWithClass:(Class)clazz proto:(Protocol *)proto
{
    if (self = [super init]) {
        _clazz = clazz;
        _proto = proto;
    }
    return self;
}

- (instancetype)initWithWrapper:(id)wrapper proto:(Protocol *)proto
{
    if (self = [super init]) {
        _clazz = [wrapper class];
        _proto = proto;
        _wrapper = wrapper;
    }
    return self;
}

- (id<IHTWrapper>)wrapper
{
    if (_wrapper == nil) {
        _wrapper = [self.clazz new];
    }
    return _wrapper;
}

- (void)onInit
{   
    // 添加默认的注册方法
    [HTEventDispatcher.shared wrapper:self.wrapper waitFor:nil];
    // 添加依赖关系
    for (Protocol *proto in [self.wrapper waitForProtocols]) {
        [HTEventDispatcher.shared wrapper:self.wrapper waitFor:proto];
    }
}

@end
