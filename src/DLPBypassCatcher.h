//
//  DLPBypassCatcher.h
//  DouyinLogProbe
//
//  绕过登录专用捕捉器（用户要求定制：bypass 还是失效，要抓病灶）。
//  只做观察，不干预任何逻辑。统一输出 domain=bypass 的诊断时间线，回答：
//   1. 开关到底开没开？（三个 key：DYDBypassLoginEnabled / DYYYBypassLoginEnabled / DYYYEnableLoginBypass）
//   2. 官方真相是什么？（AWEUserService.sharedService isLogin + userID，变化才记）
//   3. 登录弹窗出现了吗？dismiss 调了吗？生效了吗？（present/dismiss 追踪 + 3s 未 dismiss 告警）
//   4. DYYY 自动禁用管线触发了吗？（开关 ON→OFF 翻转告警：若非手动，疑似自动禁用）
//

#import <Foundation/Foundation.h>

@interface DLPBypassCatcher : NSObject

+ (void)install;   // 幂等
+ (void)uninstall;

@end
