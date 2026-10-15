//
//  DLPCrashCatcher.m
//  DouyinLogProbe
//

#import "DLPCrashCatcher.h"
#import "DLPLogHub.h"
#import <signal.h>
#import <execinfo.h>
#import <dlfcn.h>
#import <fcntl.h>
#import <unistd.h>
#import <stdio.h>
#import <string.h>
#import <time.h>

static BOOL sInstalled = NO;
static dispatch_source_t sHealTimer = nil;

// SIGEMT 是 BSD/macOS 信号（iOS 上值为 7）；Linux 宿主 signal.h 没有，
// stub 检查时排除，真机编译时纳入。用动态计数，不写死 12。
static const int kDLPSignals[] = {
    SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE,
    SIGTRAP, SIGSYS,
#ifdef SIGEMT
    SIGEMT,
#endif
    SIGXCPU, SIGXFSZ, SIGTERM
};
#define kDLPSignalCount (sizeof(kDLPSignals) / sizeof(kDLPSignals[0]))
static struct sigaction sOldActs[13];
static NSUncaughtExceptionHandler *sOldExceptionHandler = NULL;

static const char *DLPSigName(int sig) {
    switch (sig) {
        case SIGABRT: return "SIGABRT"; case SIGILL: return "SIGILL";
        case SIGSEGV: return "SIGSEGV"; case SIGFPE: return "SIGFPE";
        case SIGBUS: return "SIGBUS"; case SIGPIPE: return "SIGPIPE";
        case SIGTRAP: return "SIGTRAP"; case SIGSYS: return "SIGSYS";
#ifdef SIGEMT
        case SIGEMT: return "SIGEMT";
#endif
        case SIGXCPU: return "SIGXCPU"; case SIGXFSZ: return "SIGXFSZ"; case SIGTERM: return "SIGTERM";
        default: return "?";
    }
}

/// 崩溃日志文件（独立文件，signal handler 里只用 async-safe 的 write）
static int DLPCrashLogFD(void) {
    static int fd = -1;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = [[DLPLogHub logDirectory]
                          stringByAppendingPathComponent:@"dlp-crash.log"];
        fd = open(path.UTF8String, O_WRONLY | O_CREAT | O_APPEND, 0644);
    });
    return fd;
}

/// signal handler：只做 async-safe 操作（snprintf + write），然后交还默认处理
static void dlp_signalHandler(int sig, siginfo_t *info, void *ucontext) {
    (void)info; (void)ucontext;
    char buf[512];
    long ts = (long)time(NULL);
    // 抓 12 层栈，dladdr 解析符号（async-safe 性近似，崩溃路径可接受）
    void *frames[12];
    int n = backtrace(frames, 12);
    int len = snprintf(buf, sizeof(buf), "%ld|K|crash|signal|%s|frames=%d\n",
                       ts, DLPSigName(sig), n);
    int fd = DLPCrashLogFD();
    if (fd >= 0 && len > 0) {
        ssize_t w = write(fd, buf, (size_t)len); (void)w;
        for (int i = 0; i < n; i++) {
            Dl_info dlinfo;
            char fbuf[256];
            int flen = 0;
            if (dladdr(frames[i], &dlinfo) && dlinfo.dli_sname) {
                flen = snprintf(fbuf, sizeof(fbuf), "  #%d %s+0x%lx\n", i, dlinfo.dli_sname,
                                (unsigned long)((uintptr_t)frames[i] - (uintptr_t)dlinfo.dli_saddr));
            } else {
                flen = snprintf(fbuf, sizeof(fbuf), "  #%d %p\n", i, frames[i]);
            }
            if (flen > 0) { ssize_t w2 = write(fd, fbuf, (size_t)flen); (void)w2; }
        }
    }
    // 恢复默认并重发，让系统/看门狗做后续处理
    signal(sig, SIG_DFL);
    raise(sig);
}

static void dlp_uncaughtException(NSException *e) {
    @try {
        NSString *line = [NSString stringWithFormat:@"%ld|K|crash|NSException|%@|reason=%@",
                          (long)[[NSDate date] timeIntervalSince1970],
                          e.name, e.reason ?: @"?"];
        NSString *path = [[DLPLogHub logDirectory] stringByAppendingPathComponent:@"dlp-crash.log"];
        NSString *withNL = [line stringByAppendingString:@"\n"];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!fh) {
            [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
            fh = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        [fh seekToEndOfFile];
        [fh writeData:[withNL dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
        // 同时进主日志（AI 可读格式统一）
        DLPLog(@"crash", YES, @"NSException", (NSString *)e.name ?: @"?",
               @"%@", e.reason ?: @"?");
    } @catch (NSException *e2) { }
    if (sOldExceptionHandler) { sOldExceptionHandler(e); }
}

/// 自愈：检查各信号的 handler 是否还是我们的，被覆盖则恢复
static void DLPStartSelfHeal(void) {
    if (sHealTimer) { return; }
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    sHealTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(sHealTimer, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC),
                              60 * NSEC_PER_SEC, 5 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(sHealTimer, ^{
        @try {
            for (int i = 0; i < (int)kDLPSignalCount; i++) {
                struct sigaction cur;
                if (sigaction(kDLPSignals[i], NULL, &cur) == 0) {
                    void *curHandler = (void *)cur.sa_sigaction;
                    // 被覆盖（且不是默认/忽略）→ 恢复我们的
                    if (curHandler != (void *)dlp_signalHandler &&
                        curHandler != (void *)SIG_DFL && curHandler != (void *)SIG_IGN) {
                        struct sigaction act;
                        memset(&act, 0, sizeof(act));
                        act.sa_sigaction = dlp_signalHandler;
                        act.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESETHAND;
                        sigemptyset(&act.sa_mask);
                        sigaction(kDLPSignals[i], &act, NULL);
                        DLPLog(@"crash", YES, @"DLPCrashCatcher", @"heal",
                               @"restored %s", DLPSigName(kDLPSignals[i]));
                    }
                }
            }
        } @catch (NSException *e) { }
    });
    dispatch_resume(sHealTimer);
}

@implementation DLPCrashCatcher

+ (void)install {
    if (sInstalled) { return; }
    sInstalled = YES;
    @try {
        // 备用信号栈（栈溢出时 handler 仍有栈可用）
        static uint8_t altStack[SIGSTKSZ * 4];
        stack_t ss;
        ss.ss_sp = altStack;
        ss.ss_size = sizeof(altStack);
        ss.ss_flags = 0;
        sigaltstack(&ss, NULL);

        for (int i = 0; i < (int)kDLPSignalCount; i++) {
            struct sigaction act;
            memset(&act, 0, sizeof(act));
            act.sa_sigaction = dlp_signalHandler;
            act.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESETHAND;
            sigemptyset(&act.sa_mask);
            sigaction(kDLPSignals[i], &act, &sOldActs[i]);
        }
        sOldExceptionHandler = NSGetUncaughtExceptionHandler();
        NSSetUncaughtExceptionHandler(&dlp_uncaughtException);
        DLPStartSelfHeal();
        DLPLog(@"sys", YES, @"DLPCrashCatcher", @"install", @"signals+altstack+heal");
    } @catch (NSException *e) {
        DLPLog(@"sys", YES, @"DLPCrashCatcher", @"install", @"fail=%@", e.reason ?: @"?");
    }
}

+ (void)uninstall {
    if (!sInstalled) { return; }
    sInstalled = NO;
    @try {
        if (sHealTimer) { dispatch_source_cancel(sHealTimer); sHealTimer = nil; }
        for (int i = 0; i < (int)kDLPSignalCount; i++) {
            sigaction(kDLPSignals[i], &sOldActs[i], NULL); // 逐个还原
        }
        NSSetUncaughtExceptionHandler(sOldExceptionHandler);
    } @catch (NSException *e) { }
}

@end
