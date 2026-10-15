//
//  DLPEventTracer.m
//  DouyinLogProbe
//

#import "DLPEventTracer.h"
#import "DLPRouter.h"
#import "DLPLogHub.h"
#import <objc/message.h>

#pragma mark - hook 槽位（每 hook 点一个）

static DLPHookSlot s_vcAppear = {0}, s_vcDisappear = {0};
static DLPHookSlot s_sendEvent = {0};
static DLPHookSlot s_taskWithReq = {0}, s_taskWithURL = {0}, s_taskResume = {0};
static DLPHookSlot s_avPlay = {0}, s_avPause = {0}, s_avRate = {0}, s_avReplace = {0}, s_avInitItem = {0}, s_avInitURL = {0};
static DLPHookSlot s_tvePlay = {0}, s_tvePause = {0}, s_tveSeek = {0}, s_tveSpeed = {0}, s_tveScale = {0};
static DLPHookSlot s_loginListener = {0}, s_loginBroadcast = {0};
// 绕过登录功能点（用户自研 DYYYLoginBypass + DYYY 2.3-0  port 共同触及的类）
static DLPHookSlot s_acctMgrIsLogin = {0}, s_acctMgrHasLogin = {0}, s_acctIsLogin = {0};
static DLPHookSlot s_loginVCAppear = {0}, s_phoneLoginVCAppear = {0}, s_normalLoginVCAppear = {0};
static DLPHookSlot s_bundleID = {0}, s_bundleInfoKey = {0}, s_bundleInfo = {0};
static DLPHookSlot s_udSet = {0};
static DLPHookSlot s_fmCreate = {0}, s_fmRemove = {0};

#pragma mark - 页面跳转（K）

static void dlp_vcDidAppear(id self, SEL _cmd, BOOL animated) {
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))s_vcAppear.orig;
    if (orig) orig(self, _cmd, animated);
    @try { DLPLog(@"page", YES, NSStringFromClass([self class]), @"viewDidAppear:", @""); }
    @catch (NSException *e) {}
}
static void dlp_vcWillDisappear(id self, SEL _cmd, BOOL animated) {
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))s_vcDisappear.orig;
    if (orig) orig(self, _cmd, animated);
    @try { DLPLog(@"page", YES, NSStringFromClass([self class]), @"viewWillDisappear:", @""); }
    @catch (NSException *e) {}
}

#pragma mark - 用户行为：sendEvent 全量嗅探（D）

static void dlp_sendEvent(id self, SEL _cmd, id event) {
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))s_sendEvent.orig;
    if (orig) orig(self, _cmd, event);
    @try {
        if (!event) { return; }
        NSInteger type = 0;
        @try { type = [[event valueForKey:@"type"] integerValue]; } @catch (NSException *e) {}
        NSString *target = @"?";
        @try {
            id allTouches = [event valueForKey:@"allTouches"];
            id touch = nil;
            if ([allTouches respondsToSelector:@selector(anyObject)]) {
                touch = ((id (*)(id, SEL))objc_msgSend)(allTouches, @selector(anyObject));
            }
            id view = touch ? [touch valueForKey:@"view"] : nil;
            if (view) { target = NSStringFromClass([view class]); }
        } @catch (NSException *e) {}
        DLPLog(@"ui", NO, @"UIApplication", @"sendEvent:", @"type=%ld,target=%@", (long)type, target);
    } @catch (NSException *e) {}
}

#pragma mark - 网络请求（D）

static NSString *DLPTaskURLString(id task) {
    @try {
        id req = [task valueForKey:@"originalRequest"] ?: [task valueForKey:@"currentRequest"];
        id url = req ? [req valueForKey:@"URL"] : nil;
        NSString *abs = url ? [url valueForKey:@"absoluteString"] : nil;
        if (abs.length > 160) { abs = [abs substringToIndex:160]; }
        return abs ?: @"?";
    } @catch (NSException *e) { return @"?"; }
}
static id dlp_dataTaskWithRequest(id self, SEL _cmd, id request, id handler) {
    id (*orig)(id, SEL, id, id) = (id (*)(id, SEL, id, id))s_taskWithReq.orig;
    id task = orig ? orig(self, _cmd, request, handler) : nil;
    @try {
        NSString *url = @"?", *method = @"?";
        @try {
            id u = [request valueForKey:@"URL"];
            url = [u valueForKey:@"absoluteString"] ?: @"?";
            if (url.length > 160) { url = [url substringToIndex:160]; }
            method = [request valueForKey:@"HTTPMethod"] ?: @"?";
        } @catch (NSException *e) {}
        DLPLog(@"net", NO, @"NSURLSession", @"dataTaskWithRequest:", @"%@ %@", method, url);
    } @catch (NSException *e) {}
    return task;
}
static id dlp_dataTaskWithURL(id self, SEL _cmd, id url, id handler) {
    id (*orig)(id, SEL, id, id) = (id (*)(id, SEL, id, id))s_taskWithURL.orig;
    id task = orig ? orig(self, _cmd, url, handler) : nil;
    @try {
        NSString *abs = @"?";
        @try { abs = [url valueForKey:@"absoluteString"] ?: @"?"; if (abs.length > 160) abs = [abs substringToIndex:160]; }
        @catch (NSException *e) {}
        DLPLog(@"net", NO, @"NSURLSession", @"dataTaskWithURL:", @"%@", abs);
    } @catch (NSException *e) {}
    return task;
}
static void dlp_taskResume(id self, SEL _cmd) {
    void (*orig)(id, SEL) = (void (*)(id, SEL))s_taskResume.orig;
    if (orig) orig(self, _cmd);
    @try { DLPLog(@"net", NO, NSStringFromClass([self class]), @"resume", @"%@", DLPTaskURLString(self)); }
    @catch (NSException *e) {}
}

#pragma mark - 播放器：AVPlayer（K=play/pause，D=其余；CrashLogger 同款 6 方法）

static void dlp_avPlay(id self, SEL _cmd) {
    void (*orig)(id, SEL) = (void (*)(id, SEL))s_avPlay.orig;
    if (orig) orig(self, _cmd);
    @try { DLPLog(@"player", YES, NSStringFromClass([self class]), @"play", @""); } @catch (NSException *e) {}
}
static void dlp_avPause(id self, SEL _cmd) {
    void (*orig)(id, SEL) = (void (*)(id, SEL))s_avPause.orig;
    if (orig) orig(self, _cmd);
    @try { DLPLog(@"player", YES, NSStringFromClass([self class]), @"pause", @""); } @catch (NSException *e) {}
}
static void dlp_avSetRate(id self, SEL _cmd, float rate) {
    void (*orig)(id, SEL, float) = (void (*)(id, SEL, float))s_avRate.orig;
    if (orig) orig(self, _cmd, rate);
    @try { DLPLog(@"player", NO, NSStringFromClass([self class]), @"setRate:", @"%.2f", rate); } @catch (NSException *e) {}
}
static void dlp_avReplace(id self, SEL _cmd, id item) {
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))s_avReplace.orig;
    if (orig) orig(self, _cmd, item);
    @try { DLPLog(@"player", NO, NSStringFromClass([self class]), @"replaceCurrentItemWithPlayerItem:", @"item=%@", item ? NSStringFromClass([item class]) : @"nil"); } @catch (NSException *e) {}
}
static id dlp_avInitItem(id self, SEL _cmd, id item) {
    id (*orig)(id, SEL, id) = (id (*)(id, SEL, id))s_avInitItem.orig;
    id r = orig ? orig(self, _cmd, item) : nil;
    @try { DLPLog(@"player", NO, @"AVPlayer", @"initWithPlayerItem:", @""); } @catch (NSException *e) {}
    return r;
}
static id dlp_avInitURL(id self, SEL _cmd, id url) {
    id (*orig)(id, SEL, id) = (id (*)(id, SEL, id))s_avInitURL.orig;
    id r = orig ? orig(self, _cmd, url) : nil;
    @try {
        NSString *abs = @"?";
        @try { abs = [url valueForKey:@"absoluteString"] ?: @"?"; if (abs.length > 160) abs = [abs substringToIndex:160]; }
        @catch (NSException *e2) {}
        DLPLog(@"player", NO, @"AVPlayer", @"initWithURL:", @"%@", abs);
    } @catch (NSException *e) {}
    return r;
}

#pragma mark - 播放器：TTVideoEngine 自研引擎（K=play/pause，D=其余）

static void dlp_tvePlay(id self, SEL _cmd) {
    void (*orig)(id, SEL) = (void (*)(id, SEL))s_tvePlay.orig;
    if (orig) orig(self, _cmd);
    @try { DLPLog(@"player", YES, @"TTVideoEngine", @"play", @""); } @catch (NSException *e) {}
}
static void dlp_tvePause(id self, SEL _cmd) {
    void (*orig)(id, SEL) = (void (*)(id, SEL))s_tvePause.orig;
    if (orig) orig(self, _cmd);
    @try { DLPLog(@"player", YES, @"TTVideoEngine", @"pause", @""); } @catch (NSException *e) {}
}
static void dlp_tveSeek(id self, SEL _cmd, double t) {
    void (*orig)(id, SEL, double) = (void (*)(id, SEL, double))s_tveSeek.orig;
    if (orig) orig(self, _cmd, t);
    @try { DLPLog(@"player", NO, @"TTVideoEngine", @"setCurrentPlaybackTime:", @"%.1f", t); } @catch (NSException *e) {}
}
static void dlp_tveSpeed(id self, SEL _cmd, float s) {
    void (*orig)(id, SEL, float) = (void (*)(id, SEL, float))s_tveSpeed.orig;
    if (orig) orig(self, _cmd, s);
    @try { DLPLog(@"player", NO, @"TTVideoEngine", @"setPlaybackSpeed:", @"%.2f", s); } @catch (NSException *e) {}
}
static void dlp_tveScale(id self, SEL _cmd, long mode) {
    void (*orig)(id, SEL, long) = (void (*)(id, SEL, long))s_tveScale.orig;
    if (orig) orig(self, _cmd, mode);
    @try { DLPLog(@"player", NO, @"TTVideoEngine", @"setImageScaleType:", @"%ld", mode); } @catch (NSException *e) {}
}

#pragma mark - 登录态：DYYY 2.3-0 的 2 个监听点（K，只记类名+selector）

static void dlp_loginListener(id self, SEL _cmd, id uid) {
    void (*orig)(id, SEL, id) = (void (*)(id, SEL, id))s_loginListener.orig;
    if (orig) orig(self, _cmd, uid);
    // DYYY 语义：只监听，不拦截。uid 类型版本间可能漂移，只记事件本身。
    DLPLog(@"login", YES, @"AWEUserServiceListener", @"didFinishLoginWithUid:", @"");
}
static void dlp_loginBroadcast(id self, SEL _cmd, id a1, id a2, id a3) {
    void (*orig)(id, SEL, id, id, id) = (void (*)(id, SEL, id, id, id))s_loginBroadcast.orig;
    if (orig) orig(self, _cmd, a1, a2, a3);
    // 私有三参方法：参数类型不做假设，只记类名+selector（核心诉求）。
    DLPLog(@"login", YES, @"TTAccountMulticast", @"broadcastLoginSuccess:platform:reason:", @"");
}

#pragma mark - 绕过登录功能点（K/D）：AWEAccountManager/AWEUserAccount isLogin+hasLogin，三个登录 VC
// 用户自研 DYYYLoginBypass 与 DYYY 2.3-0 port（DYDLoginBypassManager）共同触及的类。
// 只监听、不干预：isLogin 类方法被高频调用，记 D 级；登录页出现记 K 级。

static BOOL dlp_acctMgrIsLogin(id self, SEL _cmd) {
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))s_acctMgrIsLogin.orig;
    BOOL r = orig ? orig(self, _cmd) : NO;
    @try { DLPLog(@"login", NO, @"AWEAccountManager", @"isLogin", @"->%@", r ? @"YES" : @"NO"); }
    @catch (NSException *e) {}
    return r;
}
static BOOL dlp_acctMgrHasLogin(id self, SEL _cmd) {
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))s_acctMgrHasLogin.orig;
    BOOL r = orig ? orig(self, _cmd) : NO;
    @try { DLPLog(@"login", NO, @"AWEAccountManager", @"hasLogin", @"->%@", r ? @"YES" : @"NO"); }
    @catch (NSException *e) {}
    return r;
}
static BOOL dlp_acctIsLogin(id self, SEL _cmd) {
    BOOL (*orig)(id, SEL) = (BOOL (*)(id, SEL))s_acctIsLogin.orig;
    BOOL r = orig ? orig(self, _cmd) : NO;
    @try { DLPLog(@"login", NO, @"AWEUserAccount", @"isLogin", @"->%@", r ? @"YES" : @"NO"); }
    @catch (NSException *e) {}
    return r;
}
static void dlp_loginVCAppear(id self, SEL _cmd, BOOL animated) {
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))s_loginVCAppear.orig;
    if (orig) orig(self, _cmd, animated);
    DLPLog(@"login", YES, @"AWELoginViewController", @"viewDidAppear:", @"");
}
static void dlp_phoneLoginVCAppear(id self, SEL _cmd, BOOL animated) {
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))s_phoneLoginVCAppear.orig;
    if (orig) orig(self, _cmd, animated);
    DLPLog(@"login", YES, @"AWEPhoneLoginViewController", @"viewDidAppear:", @"");
}
static void dlp_normalLoginVCAppear(id self, SEL _cmd, BOOL animated) {
    void (*orig)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))s_normalLoginVCAppear.orig;
    if (orig) orig(self, _cmd, animated);
    DLPLog(@"login", YES, @"AWENormalLoginViewController", @"viewDidAppear:", @"");
}

#pragma mark - NSBundle 伪装点（D，aweJ 五件套中的三件）

static id dlp_bundleID(id self, SEL _cmd) {
    id (*orig)(id, SEL) = (id (*)(id, SEL))s_bundleID.orig;
    id r = orig ? orig(self, _cmd) : nil;
    @try { DLPLog(@"sys", NO, @"NSBundle", @"bundleIdentifier", @"%@", r ?: @"nil"); } @catch (NSException *e) {}
    return r;
}
static id dlp_bundleInfoKey(id self, SEL _cmd, id key) {
    id (*orig)(id, SEL, id) = (id (*)(id, SEL, id))s_bundleInfoKey.orig;
    id r = orig ? orig(self, _cmd, key) : nil;
    @try { DLPLog(@"sys", NO, @"NSBundle", @"objectForInfoDictionaryKey:", @"%@", key ?: @"nil"); } @catch (NSException *e) {}
    return r;
}
static id dlp_bundleInfo(id self, SEL _cmd) {
    id (*orig)(id, SEL) = (id (*)(id, SEL))s_bundleInfo.orig;
    id r = orig ? orig(self, _cmd) : nil;
    @try { DLPLog(@"sys", NO, @"NSBundle", @"infoDictionary", @"keys=%lu", (unsigned long)([r respondsToSelector:@selector(count)] ? [r count] : 0)); } @catch (NSException *e) {}
    return r;
}

#pragma mark - 数据落盘嗅探（D，只记登录相关 key/路径，不记 value）

static BOOL DLPIsLoginKey(NSString *key) {
    if (!key) { return NO; }
    NSString *k = key.lowercaseString;
    return [k containsString:@"login"] || [k containsString:@"kdya"] ||
           [k containsString:@"ttaccount"] || [k containsString:@"persist"];
}
static void dlp_udSet(id self, SEL _cmd, id obj, id key) {
    void (*orig)(id, SEL, id, id) = (void (*)(id, SEL, id, id))s_udSet.orig;
    if (orig) orig(self, _cmd, obj, key);
    @try {
        if ([key isKindOfClass:[NSString class]] && DLPIsLoginKey(key)) {
            DLPLog(@"data", NO, @"NSUserDefaults", @"setObject:forKey:", @"key=%@", key);
        }
    } @catch (NSException *e) {}
}
static BOOL DLPIsAccountPath(NSString *path) {
    if (!path) { return NO; }
    NSString *p = path.lowercaseString;
    return [p containsString:@"ttaccount"] || [p containsString:@"mmkv"];
}
static BOOL dlp_fmCreate(id self, SEL _cmd, id path, id data, id attrs) {
    BOOL (*orig)(id, SEL, id, id, id) = (BOOL (*)(id, SEL, id, id, id))s_fmCreate.orig;
    BOOL r = orig ? orig(self, _cmd, path, data, attrs) : NO;
    @try {
        if ([path isKindOfClass:[NSString class]] && DLPIsAccountPath(path)) {
            DLPLog(@"data", NO, @"NSFileManager", @"createFileAtPath:", @"%@", [path lastPathComponent]);
        }
    } @catch (NSException *e) {}
    return r;
}
static BOOL dlp_fmRemove(id self, SEL _cmd, id path, id *error) {
    BOOL (*orig)(id, SEL, id, id *) = (BOOL (*)(id, SEL, id, id *))s_fmRemove.orig;
    BOOL r = orig ? orig(self, _cmd, path, error) : NO;
    @try {
        if ([path isKindOfClass:[NSString class]] && DLPIsAccountPath(path)) {
            DLPLog(@"data", NO, @"NSFileManager", @"removeItemAtPath:", @"%@", [path lastPathComponent]);
        }
    } @catch (NSException *e) {}
    return r;
}

#pragma mark - 装配

/// 标量参数 hook 的安全安装：签名对不上就跳过并记日志（K 级），宁可少抓一条也不崩
static void DLPInstallCheckedOrSkip(DLPHookSlot *slot, const char *clsName, SEL sel, IMP imp, char argType) {
    if (!DLPHookInstallChecked(slot, clsName, sel, imp, NO, argType)) {
        DLPLog(@"sys", YES, @"DLPEventTracer", @"skip", @"%s.%@ sig!=%c",
               clsName, NSStringFromSelector(sel), argType);
    }
}

@implementation DLPEventTracer

+ (void)install {
    // 页面（K）
    DLPHookInstall(&s_vcAppear, "UIViewController", @selector(viewDidAppear:), (IMP)dlp_vcDidAppear, NO);
    DLPHookInstall(&s_vcDisappear, "UIViewController", @selector(viewWillDisappear:), (IMP)dlp_vcWillDisappear, NO);
    // 用户行为（D）
    DLPHookInstall(&s_sendEvent, "UIApplication", @selector(sendEvent:), (IMP)dlp_sendEvent, NO);
    // 网络（D）
    DLPHookInstall(&s_taskWithReq, "NSURLSession", @selector(dataTaskWithRequest:completionHandler:), (IMP)dlp_dataTaskWithRequest, NO);
    DLPHookInstall(&s_taskWithURL, "NSURLSession", @selector(dataTaskWithURL:completionHandler:), (IMP)dlp_dataTaskWithURL, NO);
    DLPHookInstall(&s_taskResume, "NSURLSessionTask", @selector(resume), (IMP)dlp_taskResume, NO);
    // AVPlayer（CrashLogger 同款 6 方法）
    DLPHookInstall(&s_avPlay, "AVPlayer", @selector(play), (IMP)dlp_avPlay, NO);
    DLPHookInstall(&s_avPause, "AVPlayer", @selector(pause), (IMP)dlp_avPause, NO);
    DLPInstallCheckedOrSkip(&s_avRate, "AVPlayer", @selector(setRate:), (IMP)dlp_avSetRate, 'f');
    DLPHookInstall(&s_avReplace, "AVPlayer", @selector(replaceCurrentItemWithPlayerItem:), (IMP)dlp_avReplace, NO);
    DLPHookInstall(&s_avInitItem, "AVPlayer", @selector(initWithPlayerItem:), (IMP)dlp_avInitItem, NO);
    DLPHookInstall(&s_avInitURL, "AVPlayer", @selector(initWithURL:), (IMP)dlp_avInitURL, NO);
    // TTVideoEngine（K=play/pause；标量参数走签名校验）
    DLPHookInstall(&s_tvePlay, "TTVideoEngine", @selector(play), (IMP)dlp_tvePlay, NO);
    DLPHookInstall(&s_tvePause, "TTVideoEngine", @selector(pause), (IMP)dlp_tvePause, NO);
    DLPInstallCheckedOrSkip(&s_tveSeek, "TTVideoEngine", @selector(setCurrentPlaybackTime:), (IMP)dlp_tveSeek, 'd');
    DLPInstallCheckedOrSkip(&s_tveSpeed, "TTVideoEngine", @selector(setPlaybackSpeed:), (IMP)dlp_tveSpeed, 'f');
    DLPInstallCheckedOrSkip(&s_tveScale, "TTVideoEngine", @selector(setImageScaleType:), (IMP)dlp_tveScale, 'q');
    // 登录监听（DYYY 2.3-0 的 2 个点，K）
    DLPHookInstall(&s_loginListener, "AWEUserServiceListener", @selector(didFinishLoginWithUid:), (IMP)dlp_loginListener, NO);
    DLPHookInstall(&s_loginBroadcast, "TTAccountMulticast", @selector(broadcastLoginSuccess:platform:reason:), (IMP)dlp_loginBroadcast, NO);
    // 绕过登录功能点（用户要求加抓：自研 bypass + DYDLoginBypassManager 触及的类）
    DLPHookInstall(&s_acctMgrIsLogin, "AWEAccountManager", @selector(isLogin), (IMP)dlp_acctMgrIsLogin, NO);
    DLPHookInstall(&s_acctMgrHasLogin, "AWEAccountManager", @selector(hasLogin), (IMP)dlp_acctMgrHasLogin, NO);
    DLPHookInstall(&s_acctIsLogin, "AWEUserAccount", @selector(isLogin), (IMP)dlp_acctIsLogin, NO);
    DLPHookInstall(&s_loginVCAppear, "AWELoginViewController", @selector(viewDidAppear:), (IMP)dlp_loginVCAppear, NO);
    DLPHookInstall(&s_phoneLoginVCAppear, "AWEPhoneLoginViewController", @selector(viewDidAppear:), (IMP)dlp_phoneLoginVCAppear, NO);
    DLPHookInstall(&s_normalLoginVCAppear, "AWENormalLoginViewController", @selector(viewDidAppear:), (IMP)dlp_normalLoginVCAppear, NO);
    // NSBundle（D）
    DLPHookInstall(&s_bundleID, "NSBundle", @selector(bundleIdentifier), (IMP)dlp_bundleID, NO);
    DLPHookInstall(&s_bundleInfoKey, "NSBundle", @selector(objectForInfoDictionaryKey:), (IMP)dlp_bundleInfoKey, NO);
    DLPHookInstall(&s_bundleInfo, "NSBundle", @selector(infoDictionary), (IMP)dlp_bundleInfo, NO);
    // 数据落盘（D）
    DLPHookInstall(&s_udSet, "NSUserDefaults", @selector(setObject:forKey:), (IMP)dlp_udSet, NO);
    DLPHookInstall(&s_fmCreate, "NSFileManager", @selector(createFileAtPath:contents:attributes:), (IMP)dlp_fmCreate, NO);
    DLPHookInstall(&s_fmRemove, "NSFileManager", @selector(removeItemAtPath:error:), (IMP)dlp_fmRemove, NO);
    DLPLog(@"sys", YES, @"DLPEventTracer", @"install", @"done");
}

+ (void)uninstall {
    DLPHookRemove(&s_vcAppear); DLPHookRemove(&s_vcDisappear);
    DLPHookRemove(&s_sendEvent);
    DLPHookRemove(&s_taskWithReq); DLPHookRemove(&s_taskWithURL); DLPHookRemove(&s_taskResume);
    DLPHookRemove(&s_avPlay); DLPHookRemove(&s_avPause); DLPHookRemove(&s_avRate);
    DLPHookRemove(&s_avReplace); DLPHookRemove(&s_avInitItem); DLPHookRemove(&s_avInitURL);
    DLPHookRemove(&s_tvePlay); DLPHookRemove(&s_tvePause); DLPHookRemove(&s_tveSeek);
    DLPHookRemove(&s_tveSpeed); DLPHookRemove(&s_tveScale);
    DLPHookRemove(&s_loginListener); DLPHookRemove(&s_loginBroadcast);
    DLPHookRemove(&s_acctMgrIsLogin); DLPHookRemove(&s_acctMgrHasLogin); DLPHookRemove(&s_acctIsLogin);
    DLPHookRemove(&s_loginVCAppear); DLPHookRemove(&s_phoneLoginVCAppear); DLPHookRemove(&s_normalLoginVCAppear);
    DLPHookRemove(&s_bundleID); DLPHookRemove(&s_bundleInfoKey); DLPHookRemove(&s_bundleInfo);
    DLPHookRemove(&s_udSet);
    DLPHookRemove(&s_fmCreate); DLPHookRemove(&s_fmRemove);
}

@end
