//
//  DLPConstants.h
//  DouyinLogProbe
//
//  开关 key 与常量。命名习惯照 DYD：key 即 NSUserDefaults 键名。
//

#import <Foundation/Foundation.h>

#define DLP_NAME    @"日志探针"
#define DLP_VERSION @"1.5.19-beta"

// 总开关（默认开；关则全部模块卸载，干净退出）
#define kDLPEnabled @"DLPEnabled"

// 各模块开关（默认开；细节日志默认关）
#define kDLPModuleClassProbe   @"DLPModuleClassProbe"
#define kDLPModuleEventTracer  @"DLPModuleEventTracer"
#define kDLPModulePerfProbe    @"DLPModulePerfProbe"
#define kDLPModuleCrashCatcher @"DLPModuleCrashCatcher"
#define kDLPModuleBypassCatcher @"DLPModuleBypassCatcher" // 绕过登录专用捕捉器（默认开）

// 长按面板入口（默认开）：视频长按菜单加「查看日志」按钮数据
#define kDLPModuleLongPressEntry @"DLPModuleLongPressEntry"

// 细节日志总闸（默认开：全量默认开；K 级关键日志常驻，D 级细节同步输出）
#define kDLPDetailEnabled @"DLPDetailEnabled"

// 落盘日志（默认开）与保留天数
#define kDLPLogToFile  @"DLPLogToFile"
#define kDLPLogKeepDays @"DLPLogKeepDays" // 默认 7

// 收其他插件日志（stderr 重定向，默认开；
// 若同时装了 CrashLogger，两家都重定向 stderr，后装的生效）
#define kDLPStderrCapture @"DLPStderrCapture"

// 取值宏
#define DLPGetBool(key) [[NSUserDefaults standardUserDefaults] boolForKey:key]
#define DLPGetInteger(key) [[NSUserDefaults standardUserDefaults] integerForKey:key]

/// 带默认值的 bool 读取（key 不存在时返回 def）
static inline BOOL DLPGetBoolDef(NSString *key, BOOL def) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:key] == nil) { return def; }
    return [ud boolForKey:key];
}
static inline NSInteger DLPGetIntDef(NSString *key, NSInteger def) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:key] == nil) { return def; }
    return [ud integerForKey:key];
}
