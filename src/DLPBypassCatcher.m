//
//  DLPBypassCatcher.m
//  DouyinLogProbe
//

#import "DLPBypassCatcher.h"
#import "DLPRouter.h"
#import "DLPLogHub.h"
#import "DLPConstants.h"
#import <objc/runtime.h>

static DLPHookSlot s_presentVC = {0}, s_dismissVC = {0};
static dispatch_source_t sPollTimer = nil;
static BOOL sPollRunning = NO;

// 登录弹窗追踪：className -> @{@"at": ts, @"dismissed": @(NO)}
static NSMutableDictionary<NSString *, NSMutableDictionary *> *sLoginFlow = nil;

// 上次快照（变化才记）
static BOOL sSnapInit = NO;
static BOOL sLastK1 = NO, sLastK2 = NO, sLastK3 = NO;
static BOOL sLastOfficial = NO;
static NSString *sLastUID = nil;

static BOOL DLPBIsLoginClass(NSString *clsName) {
    if (!clsName) { return NO; }
    return [clsName rangeOfString:@"login" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

#pragma mark - 快照轮询（2s，变化才记 K）

static void DLPBPollOnce(void) {
    @try {
        BOOL k1 = DLPGetBool(@"DYDBypassLoginEnabled");   // 另一个窗口 port 的 DYYY 2.3-0（douyin-doctor）
        BOOL k2 = DLPGetBool(@"DYYYBypassLoginEnabled");  // 用户自研 DYYYLoginBypass
        BOOL k3 = DLPGetBool(@"DYYYEnableLoginBypass");   // DYYY 2.3-0 原版

        BOOL official = NO;
        NSString *uid = nil;
        Class svcCls = objc_getClass("AWEUserService");
        id service = nil;
        if (svcCls && [svcCls respondsToSelector:@selector(sharedService)]) {
            service = [svcCls performSelector:@selector(sharedService)];
        }
        if ([service respondsToSelector:@selector(isLogin)]) {
            // isLogin 返回 BOOL，不能用 performSelector（它按 id 解释返回值，
            // YES=1 会被当成 0x1 对象指针，后面 boolValue 直接崩）。
            // 用 objc_msgSend 直调并按 BOOL 签名取返回值。
            BOOL (*msgSendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
            official = msgSendBool(service, @selector(isLogin));
        }
        if ([service respondsToSelector:@selector(userID)]) {
            id u = [service performSelector:@selector(userID)];
            if ([u isKindOfClass:[NSString class]]) { uid = u; }
            else if (u) { uid = [u description]; }
        }

        BOOL changed = !sSnapInit || k1 != sLastK1 || k2 != sLastK2 || k3 != sLastK3 ||
                       official != sLastOfficial || (uid != sLastUID && ![uid isEqualToString:sLastUID]);
        if (changed) {
            DLPLog(@"bypass", YES, @"state", @"snapshot",
                   @"DYD=%d,DYYY_own=%d,DYYY230=%d,official=%d,uid=%@",
                   k1, k2, k3, official, uid ?: @"?");
            // 开关 ON→OFF：若非用户手动，疑似 DYYY 自动禁用管线触发（这是"还是失效"的头号嫌疑）
            if (sSnapInit && ((sLastK1 && !k1) || (sLastK2 && !k2) || (sLastK3 && !k3))) {
                DLPLog(@"bypass", YES, @"state", @"hint",
                       @"开关被关：若非手动，疑似DYYY自动禁用管线触发（收到官方登录事件）");
            }
            // host 认为已登录但 bypass 开关开着 → 状态不一致
            if ((k1 || k2 || k3) && official) {
                DLPLog(@"bypass", YES, @"state", @"hint", @"host已登录但bypass开关开着：状态不一致");
            }
            sLastK1 = k1; sLastK2 = k2; sLastK3 = k3;
            sLastOfficial = official; sLastUID = uid;
            sSnapInit = YES;
        }
    } @catch (NSException *e) { }
}

static void DLPBStartPoll(void) {
    if (sPollRunning) { return; }
    sPollRunning = YES;
    DLPBPollOnce(); // 先记一次初态
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    sPollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(sPollTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                              2 * NSEC_PER_SEC, NSEC_PER_SEC);
    dispatch_source_set_event_handler(sPollTimer, ^{ DLPBPollOnce(); });
    dispatch_resume(sPollTimer);
}

static void DLPBStopPoll(void) {
    sPollRunning = NO;
    sSnapInit = NO;
    if (sPollTimer) { dispatch_source_cancel(sPollTimer); sPollTimer = nil; }
}

#pragma mark - present/dismiss 追踪

static void dlp_presentVC(id self, SEL _cmd, id vc, BOOL animated, id completion) {
    void (*orig)(id, SEL, id, BOOL, id) = (void (*)(id, SEL, id, BOOL, id))s_presentVC.orig;
    NSString *clsName = nil;
    @try { clsName = vc ? NSStringFromClass([vc class]) : nil; } @catch (NSException *e) {}
    BOOL isLogin = DLPBIsLoginClass(clsName);
    if (isLogin) {
        @synchronized([DLPBypassCatcher class]) {
            if (!sLoginFlow) { sLoginFlow = [NSMutableDictionary dictionary]; }
            sLoginFlow[clsName] = [@{@"at": @([[NSDate date] timeIntervalSince1970]),
                                     @"dismissed": @NO} mutableCopy];
        }
        DLPLog(@"bypass", YES, clsName, @"present", @"登录弹窗出现");
        // 3s 后检查：dismiss 没发生 → bypass 拦截可能失效
        NSString *key = [clsName copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @try {
                BOOL dismissed = NO;
                @synchronized([DLPBypassCatcher class]) {
                    NSDictionary *rec = sLoginFlow[key];
                    dismissed = rec ? [rec[@"dismissed"] boolValue] : YES; // 记录没了视为已处理
                }
                if (!dismissed) {
                    DLPLog(@"bypass", YES, key, @"hint", @"出现3s未被dismiss：bypass拦截可能失效");
                }
            } @catch (NSException *e) { }
        });
    }
    if (orig) orig(self, _cmd, vc, animated, completion);
}

static void dlp_dismissVC(id self, SEL _cmd, BOOL animated, id completion) {
    // bypass 是在登录 VC 自身 viewDidAppear 里调 dismiss：self 就是登录 VC，
    // presentedViewController 反而是 nil，所以两边都查。
    NSString *selfCls = nil, *pvcCls = nil;
    @try {
        selfCls = NSStringFromClass([self class]);
        id pvc = [self valueForKey:@"presentedViewController"];
        if (pvc) { pvcCls = NSStringFromClass([pvc class]); }
    } @catch (NSException *e) {}
    NSString *hit = DLPBIsLoginClass(selfCls) ? selfCls : (DLPBIsLoginClass(pvcCls) ? pvcCls : nil);

    void (*orig)(id, SEL, BOOL, id) = (void (*)(id, SEL, BOOL, id))s_dismissVC.orig;
    if (orig) orig(self, _cmd, animated, completion);

    if (hit) {
        @synchronized([DLPBypassCatcher class]) {
            NSMutableDictionary *rec = sLoginFlow[hit];
            if (rec) { rec[@"dismissed"] = @YES; }
        }
        DLPLog(@"bypass", YES, hit, @"dismiss", @"dismiss已调用");
    }
}

#pragma mark -

@implementation DLPBypassCatcher

+ (void)install {
    DLPBStartPoll();
    DLPHookInstall(&s_presentVC, "UIViewController",
                   @selector(presentViewController:animated:completion:),
                   (IMP)dlp_presentVC, NO);
    DLPHookInstall(&s_dismissVC, "UIViewController",
                   @selector(dismissViewControllerAnimated:completion:),
                   (IMP)dlp_dismissVC, NO);
    DLPLog(@"sys", YES, @"DLPBypassCatcher", @"install", @"done");
}

+ (void)uninstall {
    DLPBStopPoll();
    DLPHookRemove(&s_presentVC);
    DLPHookRemove(&s_dismissVC);
    @synchronized(self) { [sLoginFlow removeAllObjects]; }
}

@end
