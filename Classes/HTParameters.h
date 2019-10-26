//
//  HTParameters.h
//  HostTemplate
//
//  Created by Li Hejun on 2019/9/29.
//  Copyright © 2019 Li Hejun. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MTPSignalConfig, HYMPushAccount, MTPDynamicConfigSetupInfo, MTPDynamicConfigUser;
@protocol IHYMTPLogApi, IHYMTPMonitorApi, MTPFeedbackCommandDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface HTParameters : NSObject
@property (nonatomic, assign) BOOL isDebug;
@property (nonatomic, assign) BOOL isOversea;
@property (nonatomic, strong) NSString *deviceId;

@property (nonatomic, strong) NSString *crashAppId;
@property (nonatomic, assign) BOOL enableANRReport;
@property (nonatomic, copy) void(^crashCallback)(NSString* crashId, NSString* crashDumpFile);

@property (nonatomic, strong) NSString *loggerDirectory;
@property (nonatomic, assign) NSUInteger logFileSize; // in bytes

@property (nonatomic, strong) MTPSignalConfig *signalConfig;

@property (nonatomic, weak) id<IHYMTPLogApi> logApi;
@property (nonatomic, weak) id<IHYMTPMonitorApi> monitorApi;

@property (nonatomic, strong) NSString *pushAppId;
@property (nonatomic, strong) NSString *pushUA;
@property (nonatomic, assign) NSInteger pushChannel;
@property (nonatomic, copy) HYMPushAccount*(^pushGetAccount)(void);

@property (nonatomic, strong) MTPDynamicConfigSetupInfo *dynamicConfigInfo;
@property (nonatomic, copy) MTPDynamicConfigUser*(^dynamicConfigGetUser)(void);

@property (nonatomic, strong) NSString *feedbackAppId;
@property (nonatomic, strong) NSString *feedbackLogFolderPath;
@property (nonatomic, weak) id<MTPFeedbackCommandDelegate> feedbackCommandDelegate;
@property (nonatomic, copy) int64_t(^feedbackGetUid)(void);

@end

NS_ASSUME_NONNULL_END
