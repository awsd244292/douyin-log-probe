//
//  DLPOrchestrator.m
//  DouyinLogProbe
//

#import "DLPOrchestrator.h"
#import "DLPConstants.h"
#import "DLPLogHub.h"
#import "DLPClassProbe.h"
#import "DLPEventTracer.h"
#import "DLPPerfProbe.h"
#import "DLPCrashCatcher.h"
#import "DLPBypassCatcher.h"
#import "DLPLongPressEntry.h"
#import "DLPSettings.h"
#import <fcntl.h>
#import <unistd.h>

/// stderr 重定向：收其他插件日志（[DYYY]/[DCL]/[SJJ]/[DouyinDoctor]/[PDP] 前缀归因）
static int sStderrPipe[2] = {-1, -1};
static BOOL sStderrOn = NO;

static void DLPInstallStderrCapture(void) {
    if (sStderrOn) { return; }
    @try {
        if (pipe(sStderrPipe) != 0) { return; }
        // 读端设为非阻塞，写端 dup 到 stderr
        int flags = fcntl(sStderrPipe[0], F_GETFL, 0);
        fcntl(sStderrPipe[0], F_SETFL, flags | O_NONBLOCK);
        dup2(sStderrPipe[1], STDERR_FILENO);
        sStderrOn = YES;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            char buf[4096];
            NSMutableString *pending = [NSMutableString string];
            while (sStderrOn) {
                ssize_t n = read(sStderrPipe[0], buf, sizeof(buf) - 1);
                if (n > 0) {
                    buf[n] = '\0';
                    [pending appendFormat:@"%s", buf];
                    // 按行切分
                    NSRange r;
                    while ((r = [pending rangeOfString:@"\n"]).location != NSNotFound) {
                        NSString *line = [pending substringToIndex:r.location];
                        [pending deleteCharactersInRange:NSMakeRange(0, r.location + 1)];
                        NSString *trimmed = [line stringByTrimmingCharactersInSet:
                                             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (trimmed.length == 0) { continue; }
                        // 只收其他插件的日志行（前缀归因），避免把系统噪音全吞进来
                        NSString *low = trimmed.lowercaseString;
                        BOOL isPlugin = [low containsString:@"[dcl]"] || [low containsString:@"[dyyy]"] ||
                                        [low containsString:@"[sjj"] || [low containsString:@"[douyindoctor]"] ||
                                        [low containsString:@"[pdp]"] || [low containsString:@"[dyd"];
                        if (isPlugin) {
                            if (trimmed.length > 220) { trimmed = [trimmed substringToIndex:220]; }
                            DLPLog(@"plugin", NO, @"stderr", @"capture", @"%@", trimmed);
                        }
                    }
                    if (pending.length > 8192) { [pending deleteCharactersInRange:NSMakeRange(0, pending.length - 8192)]; }
                } else {
                    usleep(100 * 1000);
                }
            }
        });
    } @catch (NSException *e) { }
}

static void DLPRemoveStderrCapture(void) {
    if (!sStderrOn) { return; }
    sStderrOn = NO; // 读线程轮询退出；fd 保留（恢复 stderr 需宿主重启，见 README）
}

@implementation DLPOrchestrator

+ (void)applyCurrentProfile {
    @synchronized(self) {
        BOOL enabled = DLPGetBoolDef(kDLPEnabled, YES);
        // 设置入口永远常驻（即使总开关 OFF 也要能进设置再打开，否则自锁）
        [DLPSettings install];
        if (!enabled) {
            [self shutdownAll];
            return;
        }
        // 各模块按开关启停（顺序：日志→探针→追踪→性能→崩溃→设置）
        if (DLPGetBoolDef(kDLPModuleClassProbe, YES)) { [DLPClassProbe runOnce]; }
        if (DLPGetBoolDef(kDLPModuleEventTracer, YES)) { [DLPEventTracer install]; }
        else { [DLPEventTracer uninstall]; }
        if (DLPGetBoolDef(kDLPModulePerfProbe, YES)) { [DLPPerfProbe install]; }
        else { [DLPPerfProbe uninstall]; }
        if (DLPGetBoolDef(kDLPModuleCrashCatcher, YES)) { [DLPCrashCatcher install]; }
        else { [DLPCrashCatcher uninstall]; }
        if (DLPGetBoolDef(kDLPModuleBypassCatcher, YES)) { [DLPBypassCatcher install]; }
        else { [DLPBypassCatcher uninstall]; }
        if (DLPGetBoolDef(kDLPModuleLongPressEntry, YES)) { [DLPLongPressEntry install]; }
        else { [DLPLongPressEntry uninstall]; }
        if (DLPGetBoolDef(kDLPStderrCapture, YES)) { DLPInstallStderrCapture(); }
        else { DLPRemoveStderrCapture(); }
        [DLPLogHub cleanupOldLogs];
        DLPLog(@"sys", YES, @"DLPOrchestrator", @"applyCurrentProfile", @"enabled v%@", DLP_VERSION);
    }
}

+ (void)shutdownAll {
    // 按序卸载（CrashLogger shutdownAll 同款顺序思想：追踪→性能→崩溃→管道）
    [DLPEventTracer uninstall];
    [DLPPerfProbe uninstall];
    [DLPCrashCatcher uninstall];
    [DLPBypassCatcher uninstall];
    [DLPLongPressEntry uninstall];
    DLPRemoveStderrCapture();
    DLPLog(@"sys", YES, @"DLPOrchestrator", @"shutdownAll", @"all modules off");
}

@end
