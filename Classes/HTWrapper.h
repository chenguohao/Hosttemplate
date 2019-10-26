//
//  HTWrapper.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#ifndef HTWrapper_h
#define HTWrapper_h

#import <Foundation/Foundation.h>

@protocol IHTWrapper <NSObject>
/// 要求在主线程初始化SDK
@property (nonatomic, readonly) BOOL requireMainQueue;
/// SDK是否准备好了
@property (nonatomic, readonly) BOOL isReady;

/// SDK的具体实例，用于调用方法
/// 如果没有接口方法，直接返回nil即可
- (id)instanceForProtocol:(Protocol *)proto;

/// Wrapper代理的所有协议，也就是SDK对外提供的协议接口
- (NSArray<Protocol *> *)committedProtocols;

/// SDK的实现类，用于识别协议接口调用
/// 用于延迟调用，如果不需要实现该功能，直接返回nil即可
- (Class)classForProtocol:(Protocol *)proto;

/// 依赖哪些SDK先初始化完成，如果返回空的话就是启动初始化
- (NSArray<Protocol *> *)waitForProtocols;

@end

#endif /* HTWrapper_h */
