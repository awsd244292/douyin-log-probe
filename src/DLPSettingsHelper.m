//
//  DLPSettingsHelper.m
//  DouyinLogProbe
//

#import "DLPSettingsHelper.h"

@implementation DLPSettingItem
@end

@implementation DLPSettingSection
@end

@implementation DLPSettingsHelper

+ (DLPSettingItem *)createSettingItem:(NSDictionary *)dict {
    DLPSettingItem *it = [DLPSettingItem new];
    it.key = dict[@"identifier"];
    it.title = dict[@"title"] ?: @"";
    it.subTitle = dict[@"subTitle"];
    NSNumber *cellType = dict[@"cellType"];
    // cellType 6=开关（DYYY/医生习惯），其他=点击
    if (cellType && [cellType integerValue] == 6) {
        it.kind = DLPSettingKindSwitch;
        NSNumber *defOn = dict[@"defaultOn"];
        it.defaultOn = defOn ? [defOn boolValue] : YES;
    } else {
        it.kind = DLPSettingKindTap;
        it.defaultOn = NO;
    }
    void (^tap)(UIViewController *) = dict[@"tap"];
    if (tap) { it.tap = tap; }
    return it;
}

+ (DLPSettingSection *)createSectionWithTitle:(NSString *)title items:(NSArray<DLPSettingItem *> *)items {
    DLPSettingSection *sec = [DLPSettingSection new];
    sec.title = title ?: @"";
    sec.items = items ?: @[];
    return sec;
}

+ (DLPSettingItem *)createSwitchItem:(NSString *)key title:(NSString *)title subTitle:(NSString *)subTitle defaultOn:(BOOL)defaultOn {
    return [self createSettingItem:@{
        @"identifier": key ?: @"",
        @"title": title ?: @"",
        @"subTitle": subTitle ?: @"",
        @"cellType": @6,
        @"defaultOn": @(defaultOn),
    }];
}

+ (DLPSettingItem *)createTapItem:(NSString *)title subTitle:(NSString *)subTitle tap:(void (^)(UIViewController *))tap {
    NSMutableDictionary *dict = [@{
        @"title": title ?: @"",
        @"subTitle": subTitle ?: @"",
        @"cellType": @26,
    } mutableCopy];
    if (tap) { dict[@"tap"] = [tap copy]; }
    return [self createSettingItem:dict];
}

+ (void)showTextInputAlert:(NSString *)title
               defaultText:(NSString *)defaultText
               placeholder:(NSString *)placeholder
                 onConfirm:(void (^)(NSString *))onConfirm
                  onCancel:(void (^)(void))onCancel {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = defaultText;
        tf.placeholder = placeholder;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *text = alert.textFields.firstObject.text ?: @"";
        if (onConfirm) { onConfirm(text); }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        if (onCancel) { onCancel(); }
    }]];
    // 找顶层 VC present（1.5.20 修正：与 DLPSettings.m 的 DLPTopViewController 保持同一套逻辑）
    // 此前取「第一个有 rootViewController 的 window」，但 iOS 13+ 抖音会同时存在多个
    // window（主窗/悬浮/弹窗层），第一个未必是 keyWindow → 可能 present 到不可见那一层。
    // 改为：优先 keyWindow，其次第一个可见 window，最后兜底第一个有 rootVC 的。
    UIViewController *top = nil;
    @try {
        id app = [UIApplication performSelector:@selector(sharedApplication)];
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
    } @catch (NSException *e) {}
    if (top) {
        [top presentViewController:alert animated:YES completion:nil];
    } else {
        // 取不到顶层 VC = 弹窗必然不出现，必须留痕（NSLog 不受 DLP 总开关约束）
        NSLog(@"[DLP] showTextInputAlert 失败：取不到顶层 VC，弹窗未显示");
    }
}

+ (BOOL)getBool:(NSString *)key default:(BOOL)def {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    if ([ud objectForKey:key] == nil) { return def; }
    return [ud boolForKey:key];
}

+ (void)setBool:(BOOL)value forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
