//
//  HTContext.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import "HTParameters.h"

/**
 * e.g. HT_CONCAT(foo, __FILE__).
 */
#define HT_CONCAT2(A, B) A ## B
#define HT_CONCAT(A, B) HT_CONCAT2(A, B)

/*
 * Get unique string（__LINE__ && __COUNTER__）
 * e.g. ATH_UNIQUE_NAME(login)
 */
#define HT_UNIQUE_STRING(key) HT_CONCAT(key, HT_CONCAT(__LINE__, __COUNTER__))

/**
 * 用于Wrapper声明，指定是代理哪个SDK协议
 * If not using this macro:
 *  char *mUniqueString __attribute((used, section("__DATA,"HTWrapper" "))) = "ProtoImplClass#Proto#OnNeed#1"
 *  @param _protocol_ Interfaces
 *  @param classname  Implementation
 */
#define HT_WRAPPER(_protocol_, classname) \
char *HT_UNIQUE_STRING(classname) __attribute((used, section("__DATA,HTWrapper"))) = ""#classname"#"#_protocol_"";

#define HT_EXECUTOR(_protocol_) (id<_protocol_>)[HTContext executorFor:@protocol(_protocol_) allowDelay:NO]
#define HT_EXECUTOR_ASYNC(_protocol_) (id<_protocol_>)[HTContext executorFor:@protocol(_protocol_) allowDelay:YES]
#define HT_WAIT_FOR(_protocol_, _callback_) [HTContext waitForProtocol:@protocol(_protocol_) callback:_callback_];

NS_ASSUME_NONNULL_BEGIN

@interface HTContext : NSObject
/// 配置参数
@property (nonatomic, class, readonly) HTParameters *parameters;
/// 全局字典，用于传递参数
@property (nonatomic, class, readonly) NSDictionary *globalDictionary;
/// 启动参数
@property (nonatomic, class, readonly, nullable) NSDictionary *launchOptions;


- (instancetype)init NS_UNAVAILABLE;

/**
 * 设置全局参数
 */
+ (void)setGlobalValue:(id)value forKey:(NSString *)key;

/**
 * Call in [AppDelegate didFinishLaunchingWithOptions:]
 *
 * @param launchOptions from AppDelegate
 */
+ (void)initWithParameters:(HTParameters *)parameters launchOptions:(NSDictionary *)launchOptions;

/**
 * 获取协议的执行对象
 * @param protocol SDK提供的协议接口
 * @param allowDelay 是否允许延迟
 */
+ (id)executorFor:(Protocol *)protocol allowDelay:(BOOL)allowDelay;

/**
 * 获取协议的注册对象
 * @param protocol SDK提供的协议接口
 */
+ (id)declareFor:(Protocol *)protocol;

/**
 * 注册Wrapper负责协议接口的安全代理
 * @param wrapper Wrapper实例
 * @param protocol 协议接口
 */
+ (void)registerWrapper:(id)wrapper forProtocol:(Protocol *)protocol;

/**
 * 延迟SDK初始化
 * @param protocol SDK提供的协议接口
 * @param event 事件名称，需要保证唯一性
 */
+ (void)delayProtocol:(Protocol *)protocol withEvent:(NSString *)event;

/**
 * 批量延迟SDK初始化，具体参数解析见上面那个接口
 */
+ (void)delayProtocols:(NSArray<Protocol *> *)protocols withEvent:(NSString *)event;

/**
 * 分发事件，触发延迟初始化
 * @param event 事件名称
 */
+ (void)dispatchEvent:(NSString *)event;

/**
 * 注册SDK初始化完成后的回调
 * @param protocol 需要等待初始化的SDK
 * @param callback 需要执行的代码块
 */
+ (void)waitForProtocol:(Protocol *)protocol callback:(void(^)(void))callback;



@end

NS_ASSUME_NONNULL_END
