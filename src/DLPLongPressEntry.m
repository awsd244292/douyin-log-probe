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

static DLPHookSlot s_lpDataArray = {0};

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

static NSArray *dlp_longPressDataArray(id self, SEL _cmd) {
    NSArray *(*orig)(id, SEL) = (NSArray *(*)(id, SEL))s_lpDataArray.orig;
    NSArray *original = orig ? orig(self, _cmd) : @[];
    if (!original) { original = @[]; }
    // 开关：默认开，不用可关
    if (!DLPGetBoolDef(kDLPModuleLongPressEntry, YES)) { return original; }

    Class vmCls = objc_getClass("AWELongPressPanelBaseViewModel");
    Class groupCls = objc_getClass("AWELongPressPanelViewGroupModel");
    if (!vmCls || !groupCls) { return original; }

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

        id group = [[groupCls alloc] init];
        [group setValue:@(11) forKey:@"groupType"];
        [group setValue:@(YES) forKey:@"isModern"];
        [group setValue:@[vm] forKey:@"groupArr"];
        NSMutableArray *result = [original mutableCopy];
        [result addObject:group];
        return [result copy];
    } @catch (NSException *e) {
        return original;
    }
}

@implementation DLPLongPressEntry

+ (void)install {
    DLPHookInstall(&s_lpDataArray, "AWEModernLongPressPanelTableViewController",
                   @selector(dataArray), (IMP)dlp_longPressDataArray, NO);
}

+ (void)uninstall {
    DLPHookRemove(&s_lpDataArray);
}

@end
