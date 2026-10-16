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
    // 找顶层 VC present
    UIViewController *top = nil;
    @try {
        id app = [UIApplication performSelector:@selector(sharedApplication)];
        for (id window in [app valueForKey:@"windows"]) {
            id root = [window valueForKey:@"rootViewController"];
            if (root) { top = root; break; }
        }
        while (top.presentedViewController) { top = top.presentedViewController; }
    } @catch (NSException *e) {}
    if (top) { [top presentViewController:alert animated:YES completion:nil]; }
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
