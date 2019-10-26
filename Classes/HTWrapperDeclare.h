//
//  HTWrapperDeclare.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTWrapper.h"

NS_ASSUME_NONNULL_BEGIN

/// 用于记录Wrapper的声明关系
@interface HTWrapperDeclare : NSObject
@property (nonatomic, strong) Class clazz;
@property (nonatomic, strong) Protocol *proto;
@property (nonatomic, strong) id<IHTWrapper> wrapper;

- (instancetype)initWithClass:(Class)clazz proto:(Protocol *)proto;
- (instancetype)initWithWrapper:(id)wrapper proto:(Protocol *)proto;

/// 由 HTContext 在初始化的时候调用，这个接口内部完成Wrapperc的创建
- (void)onInit;

@end

NS_ASSUME_NONNULL_END
