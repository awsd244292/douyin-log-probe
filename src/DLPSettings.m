//
//  DLPSettings.m
//  DouyinLogProbe
//

#import "DLPSettings.h"
#import "DLPRouter.h"
#import "DLPConstants.h"
#import "DLPLogHub.h"
#import "DLPClassProbe.h"
#import "DLPLogViewController.h"
#import "DLPHostHeaders.h"
#import "DLPOrchestrator.h"

static DLPHookSlot s_sectionDataArray = {0};

/// 开关 item（cellType=6，DYYY 开关样式）
static id DLPMakeSwitchItem(NSString *identifier, NSString *title, NSString *subTitle, BOOL defaultOn) {
    Class itemCls = objc_getClass("AWESettingItemModel");
    if (!itemCls) { return nil; }
    id item = [[itemCls alloc] init];
    @try {
        [item setValue:identifier forKey:@"identifier"];
        [item setValue:title forKey:@"title"];
        [item setValue:(subTitle ?: @"") forKey:@"subTitle"];
        [item setValue:@6 forKey:@"cellType"];
        [item setValue:@YES forKey:@"isEnable"];
        [item setValue:@(DLPGetBoolDef(identifier, defaultOn)) forKey:@"isSwitchOn"];
        __weak id weakItem = item;
        [item setValue:[^{
            id strongItem = weakItem;
            if (!strongItem) { return; }
            BOOL on = ![[strongItem valueForKey:@"isSwitchOn"] boolValue];
            [strongItem setValue:@(on) forKey:@"isSwitchOn"];
            [[NSUserDefaults standardUserDefaults] setBool:on forKey:identifier];
            [DLPOrchestrator applyCurrentProfile]; // 热切换
            @try { [strongItem performSelector:@selector(refreshCell)]; } @catch (NSException *e) {}
        } copy] forKey:@"switchChangedBlock"];
    } @catch (NSException *e) { return nil; }
    return item;
}

/// 点击型 item（cellType=26）
static id DLPMakeTapItem(NSString *identifier, NSString *title, NSString *subTitle, void (^tap)(void)) {
    Class itemCls = objc_getClass("AWESettingItemModel");
    if (!itemCls) { return nil; }
    id item = [[itemCls alloc] init];
    @try {
        [item setValue:identifier forKey:@"identifier"];
        [item setValue:title forKey:@"title"];
        [item setValue:(subTitle ?: @"") forKey:@"subTitle"];
        [item setValue:@26 forKey:@"cellType"];
        [item setValue:@YES forKey:@"isEnable"];
        [item setValue:[tap copy] forKey:@"cellTappedBlock"];
    } @catch (NSException *e) { return nil; }
    return item;
}

/// 取顶层 VC（用于 present 日志查看器）
static UIViewController *DLPTopViewController(void) {
    UIViewController *top = nil;
    @try {
        id app = [objc_getClass("UIApplication") performSelector:@selector(sharedApplication)];
        for (id window in [app valueForKey:@"windows"]) {
            id root = [window valueForKey:@"rootViewController"];
            if (root) { top = root; break; }
        }
        while (top.presentedViewController) { top = top.presentedViewController; }
    } @catch (NSException *e) { }
    return top;
}

static NSArray *dlp_sectionDataArray(id self, SEL _cmd) {
    NSArray *(*orig)(id, SEL) = (NSArray *(*)(id, SEL))s_sectionDataArray.orig;
    NSArray *original = orig ? orig(self, _cmd) : @[];
    @try {
        // 只在主设置页插一次（有「账号」分区即主设置页，DYD 同款判定）
        BOOL isMain = NO, exists = NO;
        for (id section in original) {
            NSString *title = nil;
            @try { title = [section valueForKey:@"sectionHeaderTitle"]; } @catch (NSException *e) {}
            if ([title isEqualToString:@"账号"]) { isMain = YES; }
            if ([title isEqualToString:DLP_NAME]) { exists = YES; }
        }
        if (!isMain || exists) { return original; }

        NSMutableArray *items = [NSMutableArray array];
        id it = nil;
        // 总入口：一行「日志探针」，点进去 push 独立设置页（DLPSettingsViewController），
        // 开关收拢到第二个页面，不再散落原生设置页。
        it = DLPMakeTapItem(@"DLPMainEntry", @"日志探针", @"总入口", ^{
            UIViewController *top = DLPTopViewController();
            if (!top) { return; }
            Class vcCls = NSClassFromString(@"DLPSettingsViewController");
            if (!vcCls) { return; }
            UIViewController *vc = [[vcCls alloc] initWithStyle:1]; // UITableViewStyleGrouped
            if ([top isKindOfClass:[UINavigationController class]]) {
                [(UINavigationController *)top pushViewController:vc animated:YES];
            } else if (top.navigationController) {
                [top.navigationController pushViewController:vc animated:YES];
            } else {
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
                [top presentViewController:nav animated:YES completion:nil];
            }
        });
        if (it) [items addObject:it];

        Class secCls = objc_getClass("AWESettingSectionModel");
        if (!secCls || items.count == 0) { return original; }
        id section = [[secCls alloc] init];
        [section setValue:items forKey:@"itemArray"];
        [section setValue:@0 forKey:@"type"];
        [section setValue:@40 forKey:@"sectionHeaderHeight"];
        [section setValue:DLP_NAME forKey:@"sectionHeaderTitle"];

        NSMutableArray *newSections = [NSMutableArray arrayWithArray:original];
        [newSections insertObject:section atIndex:0];
        return newSections;
    } @catch (NSException *e) {
        return original;
    }
}

@implementation DLPSettings

+ (void)install {
    DLPHookInstall(&s_sectionDataArray, "AWESettingsViewModel",
                   @selector(sectionDataArray), (IMP)dlp_sectionDataArray, NO);
}

@end
