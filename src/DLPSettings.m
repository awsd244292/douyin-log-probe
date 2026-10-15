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
        it = DLPMakeSwitchItem(kDLPEnabled, @"启用日志探针", @"总开关：关则全部模块卸载", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPModuleClassProbe, @"类名探针", @"后台枚举全量类→classmap.json", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPModuleEventTracer, @"事件追踪", @"页面/网络/播放器/登录/数据落盘", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPModulePerfProbe, @"性能探针", @"FPS/内存/主线程卡顿", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPModuleCrashCatcher, @"崩溃抓捕", @"12信号+未捕获异常", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPModuleBypassCatcher, @"绕过登录捕捉器", @"诊断bypass失效：开关/官方真相/弹窗时间线", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPDetailEnabled, @"细节日志", @"全量默认开：D级与K级同步输出", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPLogToFile, @"落盘日志", @"Documents/DLPLogs/ 按日轮转", YES);
        if (it) [items addObject:it];
        it = DLPMakeSwitchItem(kDLPStderrCapture, @"收其他插件日志", @"stderr重定向：DYYY/DCL/aweJ", YES);
        if (it) [items addObject:it];
        it = DLPMakeTapItem(@"DLPViewLogs", @"查看实时日志", @"内存2000行，支持搜索", ^{
            UIViewController *top = DLPTopViewController();
            DLPLogViewController *vc = [[DLPLogViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
            [top presentViewController:nav animated:YES completion:nil];
        });
        if (it) [items addObject:it];
        it = DLPMakeTapItem(@"DLPClassmap", @"类名地图路径", @"classmap.json 导出位置", ^{
            DLPLog(@"sys", YES, @"DLPSettings", @"classmap", @"path=%@", [DLPClassProbe classmapPath]);
        });
        if (it) [items addObject:it];
        it = DLPMakeTapItem(@"DLPClearLogs", @"清空内存日志", @"不删落盘文件", ^{
            [DLPLogHub clearLogs];
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
