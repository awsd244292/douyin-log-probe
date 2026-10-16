//
//  DLPDoctorBridge.h
//  DouyinLogProbe
//
//  直接从 douyin-doctor 的 DYDLogManager 环形缓冲拉日志，
//  不依赖 stderr 重定向（真机上 stderr 捕获不可靠）。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DLPDoctorBridge : NSObject

/// 医生是否在当前进程（DYDLogManager 类存在）
+ (BOOL)doctorPresent;

/// 拉取医生日志环形缓冲（DYDLogManager.allLogs），失败返回空数组
+ (NSArray<NSString *> *)pullDoctorLogs;

@end

NS_ASSUME_NONNULL_END
