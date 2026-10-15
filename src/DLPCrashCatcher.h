//
//  DLPCrashCatcher.h
//  DouyinLogProbe
//
//  崩溃抓捕（K 级，照抄 DCLCrashReporter 实证行为）：
//   - N 个崩溃信号（kDLPSignalCount，真机 12） sigaction（SA_ONSTACK|SA_SIGINFO）+ 备用信号栈
//   - NSSetUncaughtExceptionHandler 接管 ObjC 未捕获异常
//   - 自愈定时器：60s 检查 handler 是否被覆盖，被冲掉则恢复
//   - 卸载：全部 sigaction 逐个还原 + 未捕获异常 handler 还原 + 取消自愈定时器
//

#import <Foundation/Foundation.h>

@interface DLPCrashCatcher : NSObject

+ (void)install;   // 幂等
+ (void)uninstall;

@end
