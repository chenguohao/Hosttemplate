//
//  HTEventDispatcher.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTWrapperDeclare.h"

NS_ASSUME_NONNULL_BEGIN

@protocol HTEventAdaptor <NSObject>

/// 通知可以开始初始化了
- (void)startInit;

@end

@interface HTEventDispatcher : NSObject

+ (instancetype)shared;

/// 通知App启动，这个时候那些需要启动初始化的Wrapper就可以开始执行初始化了
- (void)appStart;

/// 延迟某个SDK直到事件发生
/// @param wrapper 需要执行初始化的SDK Wrapper
/// @param event 事件名称
- (void)wrapper:(id)wrapper delayFor:(NSString *)event;

/// 声明依赖谁初始化完成
/// @param wrapper 需要执行初始化的SDK Wrapper
/// @param other 需要等待发出初始化完成的SDK
- (void)wrapper:(id)wrapper waitFor:(Protocol *)other;

/// 由Wrapper初始化完成之后调用，通知自己初始化完成了
/// @param wrapper 初始化完成的SDK Wrapper
/// @param success 初始化结果是否成功，目前没有处理失败的情况，统一认为都是成功的
- (void)wrapper:(id)wrapper initDone:(BOOL)success;  // 大家要遵守，否则依赖者等不到消息 ！！！！！！！！！！

/// 发生事件event，需要处理监听
/// @param event 通过delayFor接口添加的延迟事件
- (void)dispatchEvent:(NSString *)event;

/// 注册wrapper初始化完成后的回调
/// @param wrapper 需要回调的wrapper
/// @param callback 回调的block
- (void)registerCallback:(void(^)(void))callback
              forWrapper:(id)wrapper;

@end

NS_ASSUME_NONNULL_END
