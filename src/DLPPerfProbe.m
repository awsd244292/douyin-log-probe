//
//  DLPPerfProbe.m
//  DouyinLogProbe
//

#import "DLPPerfProbe.h"
#import "DLPLogHub.h"
#import <objc/message.h>
#import <mach/mach.h>
#import <pthread.h>
#import <unistd.h>

/// CADisplayLink 只在运行时获取（NSClassFromString），这里只做 selector 的
/// 编译期前向声明（tweak 常用写法；真机上由 CADisplayLink 实现）。
@interface NSObject (DLPDisplayLinkFwd)
- (void)addToRunLoop:(id)runloop forMode:(id)mode;
- (void)invalidate;
@end

static id sDisplayLink = nil;
static NSUInteger sFrameCount = 0;
static NSTimeInterval sFpsWindowStart = 0;
static dispatch_source_t sMemTimer = nil;

// 看门狗状态
static CFRunLoopObserverRef sObserver = NULL;
static volatile BOOL sWatchdogStop = NO;
static pthread_t sWatchdogThread;
static volatile NSTimeInterval sLastMainActivity = 0;
static BOOL sWatchdogRunning = NO;

#pragma mark - FPS

static void dlp_displayLinkTick(id self, SEL _cmd, id link) {
    (void)self; (void)_cmd; (void)link;
    sFrameCount++;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (sFpsWindowStart == 0) { sFpsWindowStart = now; return; }
    NSTimeInterval elapsed = now - sFpsWindowStart;
    if (elapsed >= 5.0) {
        double fps = sFrameCount / elapsed;
        DLPLog(@"perf", NO, @"CADisplayLink", @"fps", @"%.1f", fps);
        sFrameCount = 0;
        sFpsWindowStart = now;
    }
}

static void DLPInstallFPS(void) {
    @try {
        Class dlCls = objc_getClass("CADisplayLink");
        if (!dlCls) { return; }
        // displayLinkWithTarget:selector: —— SEL 不是对象，走 objc_msgSend
        id (*msgSend)(id, SEL, id, SEL) = (id (*)(id, SEL, id, SEL))objc_msgSend;
        id target = [DLPPerfProbe class];
        // 给 target 动态加一个 tick 方法（避免在类上声明私有 selector）
        SEL tickSel = @selector(dlp_tick:);
        if (!class_getInstanceMethod(object_getClass(target), tickSel)) {
            class_addMethod(object_getClass(target), tickSel, (IMP)dlp_displayLinkTick, "v@:@");
        }
        id link = msgSend((id)dlCls, @selector(displayLinkWithTarget:selector:), target, tickSel);
        if (!link) { return; }
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        sDisplayLink = link; // ARC 下 id 强引用，runloop 也持有
    } @catch (NSException *e) { }
}

#pragma mark - 内存

static void DLPInstallMemTimer(void) {
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    sMemTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(sMemTimer, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC),
                              15 * NSEC_PER_SEC, 2 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(sMemTimer, ^{
        @try {
            mach_task_basic_info_data_t info;
            mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
            if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
                DLPLog(@"perf", NO, @"task_info", @"memory", @"resident=%.1fMB",
                       info.resident_size / 1024.0 / 1024.0);
            }
        } @catch (NSException *e) { }
    });
    dispatch_resume(sMemTimer);
}

#pragma mark - 看门狗（DCLWatchdog 双路：observer + 独立线程）

static void dlp_runloopObserver(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    (void)observer; (void)activity; (void)info;
    sLastMainActivity = [[NSDate date] timeIntervalSince1970];
}

static void *dlp_watchdogEntry(void *arg) {
    (void)arg;
    @autoreleasepool {
        while (!sWatchdogStop) {
            usleep(500 * 1000);
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval idle = now - sLastMainActivity;
            if (sLastMainActivity > 0 && idle > 2.0) {
                // 卡顿 K 级：记时长，不抓栈（抓栈见 README 后续项）
                DLPLog(@"perf", YES, @"Watchdog", @"stall", @"main_idle=%.1fs", idle);
                // 避免同一卡顿刷屏：把基准前移
                sLastMainActivity = now;
            }
        }
    }
    return NULL;
}

static void DLPInstallWatchdog(void) {
    if (sWatchdogRunning) { return; }
    sWatchdogRunning = YES;
    sWatchdogStop = NO;
    sLastMainActivity = [[NSDate date] timeIntervalSince1970];
    CFRunLoopObserverContext ctx = {0, NULL, NULL, NULL, NULL};
    sObserver = CFRunLoopObserverCreate(NULL, kCFRunLoopAllActivities, YES, 0, dlp_runloopObserver, &ctx);
    if (sObserver) {
        CFRunLoopAddObserver(CFRunLoopGetMain(), sObserver, kCFRunLoopCommonModes);
    }
    pthread_create(&sWatchdogThread, NULL, dlp_watchdogEntry, NULL);
    pthread_detach(sWatchdogThread);
}

static void DLPRemoveWatchdog(void) {
    if (!sWatchdogRunning) { return; }
    sWatchdogStop = YES; // 原子退出标志（DCL 同款，不用 pthread_cancel）
    if (sObserver) {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), sObserver, kCFRunLoopCommonModes);
        CFRelease(sObserver);
        sObserver = NULL;
    }
    sWatchdogRunning = NO;
}

#pragma mark -

@implementation DLPPerfProbe

+ (void)install {
    // 主线程装配（CADisplayLink 必须在主线程 runloop）
    if ([NSThread isMainThread]) {
        DLPInstallFPS();
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ DLPInstallFPS(); });
    }
    DLPInstallMemTimer();
    DLPInstallWatchdog();
    DLPLog(@"sys", YES, @"DLPPerfProbe", @"install", @"done");
}

+ (void)uninstall {
    @try {
        if (sDisplayLink) {
            id link = sDisplayLink; sDisplayLink = nil;
            if ([NSThread isMainThread]) { [link invalidate]; }
            else { dispatch_async(dispatch_get_main_queue(), ^{ [link invalidate]; }); }
        }
    } @catch (NSException *e) { }
    if (sMemTimer) { dispatch_source_cancel(sMemTimer); sMemTimer = nil; }
    DLPRemoveWatchdog();
}

@end
