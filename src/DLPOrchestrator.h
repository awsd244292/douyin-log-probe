//
//  DLPOrchestrator.h
//  DouyinLogProbe
//
//  总控（照抄 DCLOrchestrator 骨架）：startupAll / shutdownAll / applyCurrentProfile。
//  applyCurrentProfile 为唯一入口：读总开关 + 各模块开关，按需启停。
//

#import <Foundation/Foundation.h>

@interface DLPOrchestrator : NSObject

/// 根据当前开关配置应用（安装或卸载各模块）。幂等，线程安全。
+ (void)applyCurrentProfile;

@end
