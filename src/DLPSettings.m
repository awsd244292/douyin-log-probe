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
/// 1.5.20 修正：此前取「第一个有 rootViewController 的 window」，
/// 但 iOS 13+ 抖音会同时存在多个 window（主窗/悬浮/弹窗层），
/// 第一个未必是 keyWindow → 可能拿错 window、push 到不可见 VC → 用户感觉「点了没反应」。
/// 改为：优先 keyWindow，其次第一个可见 window，最后兜底第一个有 rootVC 的。
static UIViewController *DLPTopViewController(void) {
    UIViewController *top = nil;
    @try {
        id app = [objc_getClass("UIApplication") performSelector:@selector(sharedApplication)];
        NSArray *windows = [app valueForKey:@"windows"];
        id keyWin = nil;
        @try { keyWin = [app valueForKey:@"keyWindow"]; } @catch (NSException *e) {}
        if (keyWin) {
            id root = [keyWin valueForKey:@"rootViewController"];
            if (root) { top = root; }
        }
        if (!top) {
            for (id window in windows) {
                id root = [window valueForKey:@"rootViewController"];
                if (!root) { continue; }
                // 跳过已隐藏的 window，避免选到不可见那层
                BOOL hidden = NO;
                @try { hidden = [[window valueForKey:@"hidden"] boolValue]; } @catch (NSException *e) {}
                if (hidden) { continue; }
                top = root; break;
            }
        }
        if (!top) {  // 兜底：不挑可见性
            for (id window in windows) {
                id root = [window valueForKey:@"rootViewController"];
                if (root) { top = root; break; }
            }
        }
        while (top.presentedViewController) { top = top.presentedViewController; }
    } @catch (NSException *e) { }
    return top;
}

static NSArray *dlp_sectionDataArray(id self, SEL _cmd) {
    NSArray *(*orig)(id, SEL) = (NSArray *(*)(id, SEL))s_sectionDataArray.orig;
    NSArray *original = orig ? orig(self, _cmd) : @[];
    // 1.5.20 诊断：前 3 次调用打日志（对齐 DLPLongPressEntry 的做法），
    // 用于确认「hook 到底有没有被调到」——入口不显示时这是第一手证据。
    static int s_callCount = 0;
    int callNo = __sync_add_and_fetch(&s_callCount, 1);
    @try {
        // 只在主设置页插一次（有「账号」分区即主设置页，DYD 同款判定）
        BOOL isMain = NO, exists = NO;
        for (id section in original) {
            NSString *title = nil;
            @try { title = [section valueForKey:@"sectionHeaderTitle"]; } @catch (NSException *e) {}
            if ([title isEqualToString:@"账号"]) { isMain = YES; }
            if ([title isEqualToString:DLP_NAME]) { exists = YES; }
        }
        if (callNo <= 3 || (isMain && !exists)) {
            DLPLog(@"sys", YES, @"DLPSettings", @"sectionDataArray",
                   @"第%d次 self=%@ sections=%lu isMain=%d exists=%d",
                   callNo, NSStringFromClass([self class]), (unsigned long)original.count,
                   isMain, exists);
        }
        if (!isMain || exists) { return original; }

        NSMutableArray *items = [NSMutableArray array];
        id it = nil;
        // 总入口：一行「日志探针」，点进去 push 独立设置页（DLPSettingsViewController），
        // 开关收拢到第二个页面，不再散落原生设置页。
        it = DLPMakeTapItem(@"DLPMainEntry", @"日志探针", @"总入口", ^{
            UIViewController *top = DLPTopViewController();
            if (!top) {
                // 1.5.20：此前这里静默 return，用户只看到「点了没反应」。
                // 拿不到 top VC 的常见原因：app 尚未有 window / windows 为空。
                DLPLog(@"sys", YES, @"DLPSettings", @"tapEntry",
                       @"FAILED top VC 为 nil（windows 为空？），入口点击无响应");
                NSLog(@"[DLP] 设置入口点击失败：取不到顶层 VC");
                return;
            }
            Class vcCls = NSClassFromString(@"DLPSettingsViewController");
            if (!vcCls) {
                DLPLog(@"sys", YES, @"DLPSettings", @"tapEntry",
                       @"FAILED DLPSettingsViewController 类未加载");
                NSLog(@"[DLP] 设置入口点击失败：DLPSettingsViewController 类不存在");
                return;
            }
            UIViewController *vc = [[vcCls alloc] initWithStyle:1]; // UITableViewStyleGrouped
            // 三条路径：① top 本身是导航栈 → push；② top 在导航栈里 → push；
            //          ③ 都没有 → 包一层 nav 再 present（modal 兜底）
            if ([top isKindOfClass:[UINavigationController class]]) {
                [(UINavigationController *)top pushViewController:vc animated:YES];
                DLPLog(@"sys", YES, @"DLPSettings", @"tapEntry", @"ok push(top=nav)");
            } else if (top.navigationController) {
                [top.navigationController pushViewController:vc animated:YES];
                DLPLog(@"sys", YES, @"DLPSettings", @"tapEntry", @"ok push(top.nav)");
            } else {
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
                [top presentViewController:nav animated:YES completion:nil];
                DLPLog(@"sys", YES, @"DLPSettings", @"tapEntry", @"ok modal(no nav)");
            }
        });
        if (it) {
            [items addObject:it];
        } else {
            // DLPMakeTapItem 返回 nil = AWESettingItemModel 类不存在或 KVC 失败
            DLPLog(@"sys", YES, @"DLPSettings", @"sectionDataArray",
                   @"FAILED 构造入口 item 失败（AWESettingItemModel 不可用？）");
        }

        Class secCls = objc_getClass("AWESettingSectionModel");
        if (!secCls || items.count == 0) {
            // 这里是入口行不被加入的最终闸门，必须留痕（此前静默 return，无从定位）
            DLPLog(@"sys", YES, @"DLPSettings", @"sectionDataArray",
                   @"FAILED 放弃注入：secCls=%@ items=%lu",
                   secCls ? @"有" : @"无", (unsigned long)items.count);
            return original;
        }
        id section = [[secCls alloc] init];
        [section setValue:items forKey:@"itemArray"];
        [section setValue:@0 forKey:@"type"];
        [section setValue:@40 forKey:@"sectionHeaderHeight"];
        [section setValue:DLP_NAME forKey:@"sectionHeaderTitle"];

        NSMutableArray *newSections = [NSMutableArray arrayWithArray:original];
        [newSections insertObject:section atIndex:0];
        DLPLog(@"sys", YES, @"DLPSettings", @"sectionDataArray",
               @"ok 已插入「%@」分区（sections %lu→%lu）",
               DLP_NAME, (unsigned long)original.count, (unsigned long)newSections.count);
        return newSections;
    } @catch (NSException *e) {
        NSLog(@"[DLP] sectionDataArray 注入异常：%@", e);
        DLPLog(@"sys", YES, @"DLPSettings", @"sectionDataArray", @"EXC %@", e);
        return original;
    }
}

@implementation DLPSettings

+ (void)install {
    // 1.5.20：安装结果必须留痕。此前这里是「装了没装都不知道」的静默区：
    //   - 总开关 OFF 时，DLPOrchestrator 只执行本函数（防自锁），
    //     而 DLPLog 又被总开关静默 → 一旦装不上，日志里连一条记录都没有，彻底瞎。
    //   - 故这里除 DLPLog 外再补一路 NSLog（NSLog 不受 DLP 总开关约束）。
    BOOL ok = DLPHookInstall(&s_sectionDataArray, "AWESettingsViewModel",
                             @selector(sectionDataArray), (IMP)dlp_sectionDataArray, NO);
    if (ok) {
        DLPLog(@"sys", YES, @"DLPSettings", @"install", @"ok AWESettingsViewModel.sectionDataArray");
    } else {
        // 装不上 = 设置页入口必然消失，这是 P0 现象，必须显式报出来
        NSLog(@"[DLP] 设置页入口 hook 安装失败：AWESettingsViewModel.sectionDataArray"
               "（类/方法在宿主版本可能已改名；总开关 OFF 时本行仍会打印）");
        DLPLog(@"sys", YES, @"DLPSettings", @"install",
               @"FAILED AWESettingsViewModel.sectionDataArray（入口将不可见）");
    }
}

@end
