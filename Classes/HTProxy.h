//
//  HTProxy.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/30.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTWrapperDeclare.h"

NS_ASSUME_NONNULL_BEGIN

@class HTProxy;
#if __cplusplus
extern "C" {
#endif
    NSArray<HTProxy *> *PopProxiesForProtocol(Protocol *proto);
#if __cplusplus
}
#endif

/// 方法调用代理
@interface HTProxy : NSObject

- (instancetype)initWithDeclare:(HTWrapperDeclare *)declare;

/// 执行缓存的方法
- (void)execute;

@end

NS_ASSUME_NONNULL_END
