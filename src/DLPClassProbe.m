//
//  DLPClassProbe.m
//  DouyinLogProbe
//

#import "DLPClassProbe.h"
#import "DLPLogHub.h"
#import "DLPConstants.h"
#import <objc/runtime.h>

static BOOL sDidRun = NO;

/// 三插件已知的 hook 类 → 标注来源（逆向实证，见三份报告）
static NSDictionary<NSString *, NSString *> *DLPKnownHookedClasses(void) {
    static NSDictionary *d = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{
            // DYYY 2.3-0「启用绕登录」：监听+自动清理状态机（2 个监听点）
            @"AWEUserServiceListener" : @"DYYY,DLP",
            @"TTAccountMulticast" : @"DYYY,DLP",
            // aweJ 1.2.0：数据备份/恢复 + NSBundle 伪装 + URL 拦截
            @"SJJAccountDataBackupController" : @"aweJ",
            @"TTAccountHttpRequest" : @"aweJ,DLP",
            // CrashLogger 1.4.9：播放器追踪 + 摇一摇 + 设置页
            @"AVPlayer" : @"DCL,DLP",
            @"UIApplication" : @"DCL,DLP",
            @"AWESettingsViewModel" : @"DCL,DYD,DLP",
            // 用户自研绕登录方案 hook 的类（awsd244292/DYYY-login-bypass）
            @"AWEAccountManager" : @"bypass,DLP",
            @"AWEUserAccount" : @"bypass,DLP",
            // 另一个窗口 port 的 DYYY 2.3-0（douyin-doctor 内）
            @"DYDLoginBypassManager" : @"DYD",
            @"DYYYLoginBypass" : @"bypass",
            // douyin-doctor 下载/接口解析（探针跨插件捕获）
            @"DYDDownloadManager" : @"DYD,DLP",
            @"DYDUtils" : @"DYD,DLP",
            @"AWELoginViewController" : @"bypass,DLP",
            @"AWEPhoneLoginViewController" : @"bypass,DLP",
            @"AWENormalLoginViewController" : @"bypass,DLP",
            // 本插件自有
            @"UIViewController" : @"DLP",
            @"NSURLSession" : @"DLP",
            @"NSBundle" : @"aweJ,DLP",
        };
    });
    return d;
}

/// 取类名前导大写前缀（AWEUserService→AWE，TTVideoEngine→TT，_TtC→Tt）
static NSString *DLPClassPrefix(NSString *name) {
    NSMutableString *pre = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        if ((c >= 'A' && c <= 'Z') || c == '_') { [pre appendFormat:@"%C", c]; }
        else { break; }
    }
    if (pre.length == 0) { return @"?"; }
    if (pre.length > 5) { return [pre substringToIndex:5]; }
    return pre;
}

@implementation DLPClassProbe

+ (NSString *)classmapPath {
    return [[DLPLogHub logDirectory] stringByAppendingPathComponent:@"classmap.json"];
}

+ (void)runOnce {
    if (sDidRun) { return; }
    sDidRun = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @try {
            unsigned int count = 0;
            // 两遍调用：先取数量再取列表（类数量在枚举瞬间可能变化，取小值防越界）
            unsigned int n = objc_getClassList(NULL, 0);
            Class *classes = (Class *)malloc(sizeof(Class) * (n + 64));
            count = objc_getClassList(classes, n + 64);

            NSDictionary *known = DLPKnownHookedClasses();
            NSMutableDictionary<NSString *, NSNumber *> *imageCount = [NSMutableDictionary dictionary];
            NSMutableDictionary<NSString *, NSNumber *> *prefixCount = [NSMutableDictionary dictionary];
            NSMutableArray *hooked = [NSMutableArray array];

            for (unsigned int i = 0; i < count; i++) {
                Class cls = classes[i];
                if (!cls) { continue; }
                const char *cname = class_getName(cls);
                if (!cname) { continue; }
                NSString *name = [NSString stringWithUTF8String:cname];
                const char *cimg = class_getImageName(cls);
                NSString *img = cimg ? [[NSString stringWithUTF8String:cimg] lastPathComponent] : @"?";
                NSNumber *ic = (NSNumber *)imageCount[img];
                imageCount[img] = @(ic.integerValue + 1);
                NSString *pre = DLPClassPrefix(name);
                NSNumber *pc = (NSNumber *)prefixCount[pre];
                prefixCount[pre] = @(pc.integerValue + 1);
                NSString *tag = known[name];
                if (tag) { [hooked addObject:@{@"n": name, @"by": tag}]; }
            }
            free(classes);

            // 紧凑 JSON：AI 可读，字符少
            NSDictionary *map = @{
                @"ts": @((long)[[NSDate date] timeIntervalSince1970]),
                @"total": @(count),
                @"images": imageCount,
                @"prefix": prefixCount,
                @"hooked": hooked,
            };
            NSData *json = [NSJSONSerialization dataWithJSONObject:map options:0 error:nil];
            [json writeToFile:[self classmapPath] atomically:YES];

            // Top 前缀摘要进 K 级日志（一行搞定）
            NSArray *sortedPre = [prefixCount keysSortedByValueUsingComparator:^NSComparisonResult(id a, id b) {
                return [b compare:a];
            }];
            NSMutableString *top = [NSMutableString string];
            for (NSUInteger i = 0; i < MIN(12, sortedPre.count); i++) {
                NSString *p = sortedPre[i];
                [top appendFormat:@"%@=%@,", p, prefixCount[p]];
            }
            DLPLog(@"probe", YES, @"objc", @"classmap", @"total=%u,top12=%@,hooked=%lu,file=classmap.json",
                   count, top, (unsigned long)hooked.count);
        } @catch (NSException *e) {
            DLPLog(@"probe", YES, @"objc", @"classmap", @"fail=%@", e.reason ?: @"?");
        }
    });
}

@end
