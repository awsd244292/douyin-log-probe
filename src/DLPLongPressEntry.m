//
//  DLPLongPressEntry.m
//  DouyinLogProbe
//

#import "DLPLongPressEntry.h"
#import "DLPLogHub.h"
#import "DLPConstants.h"
#import "DLPRouter.h" // DLPHookInstall / DLPHookRemove
#import "DLPLogViewController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 三类 hook：DYY hook 两个面板类（Modern 新版 + 旧版），39.7.0 可能用旧版；
// 用户日志又发现 AWEVideoLongPressPanelViewController（外层容器），也加上。
// 三个 slot 各存各的 orig，替换函数按 self 的实际类名分发。
static DLPHookSlot s_lpDataArrayModern = {0};
static DLPHookSlot s_lpDataArrayLegacy = {0};
static DLPHookSlot s_lpDataArrayVideo = {0};

/// 从 presenter（或 keyWindow）找到当前最顶 VC
static UIViewController *DLPLP_TopVC(UIViewController *hint) {
    UIViewController *top = hint;
    if (!top) {
        @try {
            id app = [objc_getClass("UIApplication") performSelector:@selector(sharedApplication)];
            for (id window in [app valueForKey:@"windows"]) {
                id root = [window valueForKey:@"rootViewController"];
                if (root) { top = root; break; }
            }
        } @catch (NSException *e) {}
    }
    @try {
        while (top.presentedViewController) { top = top.presentedViewController; }
    } @catch (NSException *e) {}
    return top;
}

static int s_lpCallCount = 0;

static NSArray *dlp_longPressDataArray(id self, SEL _cmd) {
    // 诊断：前 3 次调用打日志，确认 hook 是否真的被调到（1.5.8：入口不显示定位）
    int callNo = __sync_add_and_fetch(&s_lpCallCount, 1);
    if (callNo <= 3) {
        DLPLog(@"sys", YES, @"DLPLongPressEntry", @"dataArray",
               @"第%d次触发 self类=%@", callNo, NSStringFromClass([self class]));
    }
    // 按 self 的实际类找对应的 orig（三类 hook，各调各的 orig，链式共存）
    DLPHookSlot *slot = &s_lpDataArrayModern;
    @try {
        NSString *clsName = NSStringFromClass([self class]);
        if ([clsName isEqualToString:@"AWELongPressPanelTableViewController"]) {
            slot = &s_lpDataArrayLegacy;
        } else if ([clsName isEqualToString:@"AWEVideoLongPressPanelViewController"]) {
            slot = &s_lpDataArrayVideo;
        }
    } @catch (NSException *e) {}
    NSArray *(*orig)(id, SEL) = (NSArray *(*)(id, SEL))slot->orig;
    NSArray *original = orig ? orig(self, _cmd) : @[];
    if (!original) { original = @[]; }
    // 开关：默认开，不用可关
    if (!DLPGetBoolDef(kDLPModuleLongPressEntry, YES)) {
        if (callNo <= 3) {
            DLPLog(@"sys", YES, @"DLPLongPressEntry", @"dataArray", @"开关已关闭，跳过注入");
        }
        return original;
    }

    Class vmCls = objc_getClass("AWELongPressPanelBaseViewModel");
    Class groupCls = objc_getClass("AWELongPressPanelViewGroupModel");
    if (!vmCls || !groupCls) {
        DLPLog(@"sys", YES, @"DLPLongPressEntry", @"dataArray",
               @"viewModel类缺失 BaseViewModel=%s GroupModel=%s，无法注入",
               vmCls ? "YES" : "NO", groupCls ? "YES" : "NO");
        return original;
    }

    @try {
        // presenter 提前取好，action block 里不再碰 self（避循环引用）
        UIViewController *presenter = nil;
        @try { presenter = [(UIViewController *)self presentingViewController]; }
        @catch (NSException *e) {}
        __weak UIViewController *wPresenter = presenter;

        id vm = [[vmCls alloc] init];
        [vm setValue:@(666) forKey:@"actionType"];
        [vm setValue:@"ic_videosearch_outlined_20" forKey:@"duxIconName"];
        [vm setValue:@"查看日志" forKey:@"describeString"];
        // model 带上（面板惯例，无害）；action 里不用它，日志 viewer 不需要视频 model
        @try {
            id aweme = [self valueForKey:@"awemeModel"];
            if (aweme) { [vm setValue:aweme forKey:@"awemeModel"]; }
        } @catch (NSException *e) {}
        [vm setValue:[^{
            __strong UIViewController *p = wPresenter;
            // 进日志页
            void (^go)(void) = ^{
                UIViewController *top = DLPLP_TopVC(p);
                if (!top) { return; }
                DLPLogViewController *vc = [[DLPLogViewController alloc] init];
                UINavigationController *nav =
                    [[UINavigationController alloc] initWithRootViewController:vc];
                [top presentViewController:nav animated:YES completion:nil];
            };
            // 先关面板，completion 里再进日志页（避 P1：dismiss 未播完 present 失败）
            // dismissWithAnimation:completion: 有 2 个实参，超 performSelector 上限，用 IMP 直调
            @try {
                Class managerCls = objc_getClass("AWELongPressPanelManager");
                id manager = [managerCls performSelector:@selector(shareInstance)];
                SEL dismissSel = @selector(dismissWithAnimation:completion:);
                if (manager && [manager respondsToSelector:dismissSel]) {
                    void (*dismissFn)(id, SEL, BOOL, id) =
                        (void (*)(id, SEL, BOOL, id))[manager methodForSelector:dismissSel];
                    dismissFn(manager, dismissSel, YES, [go copy]);
                    DLPLog(@"sys", YES, @"DLPLongPressEntry", @"openLogViewer", @"fromLongPress");
                    return;
                }
            } @catch (NSException *e) {}
            go(); // 兜底：manager 拿不到就直接进
        } copy] forKey:@"action"];

        // 组装：照抄 DYYY 旧版类路径（39.7.0 实测有效）——groupType=0、插首位、
        // 不设 isModern / numberOfRowsInSection（DYYY 也不设）
        id group = [[groupCls alloc] init];
        [group setValue:@(0) forKey:@"groupType"];
        [group setValue:@[vm] forKey:@"groupArr"];
        NSMutableArray *result = [original mutableCopy];
        [result insertObject:group atIndex:0];
        if (callNo <= 3) {
            DLPLog(@"sys", YES, @"DLPLongPressEntry", @"dataArray",
                   @"已注入「查看日志」 原组数=%lu", (unsigned long)original.count);
        }
        return [result copy];
    } @catch (NSException *e) {
        return original;
    }
}

@implementation DLPLongPressEntry

+ (void)install {
    // ── 诊断（1.5.8）：hook 前先探明类/方法存在性，入口不显示时看这几行 ──
    const char *probeClasses[] = {
        "AWEModernLongPressPanelTableViewController",
        "AWELongPressPanelTableViewController",
        "AWEVideoLongPressPanelViewController",
    };
    for (int i = 0; i < 3; i++) {
        Class cls = objc_getClass(probeClasses[i]);
        if (!cls) {
            DLPLog(@"sys", YES, @"DLPLongPressEntry", @"install", @"%s 类不存在", probeClasses[i]);
            continue;
        }
        Method m = class_getInstanceMethod(cls, @selector(dataArray));
        // 列出名字含 data/array/viewmodel/group 的方法，帮定位新版方法名
        unsigned int n = 0;
        Method *methods = class_copyMethodList(cls, &n);
        NSMutableArray *cands = [NSMutableArray array];
        for (unsigned int j = 0; j < n; j++) {
            NSString *name = NSStringFromSelector(method_getName(methods[j]));
            NSString *lower = name.lowercaseString;
            if ([lower containsString:@"data"] || [lower containsString:@"array"] ||
                [lower containsString:@"viewmodel"] || [lower containsString:@"group"]) {
                [cands addObject:name];
            }
        }
        if (methods) free(methods);
        DLPLog(@"sys", YES, @"DLPLongPressEntry", @"install", @"%s dataArray=%s 候选=%@",
               probeClasses[i], m ? "YES" : "NO",
               cands.count ? [cands componentsJoinedByString:@","] : @"(无)");
    }
    DLPLog(@"sys", YES, @"DLPLongPressEntry", @"install", @"BaseViewModel=%s GroupModel=%s",
           objc_getClass("AWELongPressPanelBaseViewModel") ? "YES" : "NO",
           objc_getClass("AWELongPressPanelViewGroupModel") ? "YES" : "NO");

    // 三个面板类都 hook（Modern 新版 + 旧版 + Video 外层容器），哪个存在 hook 哪个
    BOOL r1 = DLPHookInstall(&s_lpDataArrayModern, "AWEModernLongPressPanelTableViewController",
                   @selector(dataArray), (IMP)dlp_longPressDataArray, NO);
    BOOL r2 = DLPHookInstall(&s_lpDataArrayLegacy, "AWELongPressPanelTableViewController",
                   @selector(dataArray), (IMP)dlp_longPressDataArray, NO);
    BOOL r3 = DLPHookInstall(&s_lpDataArrayVideo, "AWEVideoLongPressPanelViewController",
                   @selector(dataArray), (IMP)dlp_longPressDataArray, NO);
    DLPLog(@"sys", YES, @"DLPLongPressEntry", @"install",
           @"hook结果 modern=%d legacy=%d video=%d", r1, r2, r3);
}

+ (void)uninstall {
    DLPHookRemove(&s_lpDataArrayModern);
    DLPHookRemove(&s_lpDataArrayLegacy);
    DLPHookRemove(&s_lpDataArrayVideo);
}

@end
