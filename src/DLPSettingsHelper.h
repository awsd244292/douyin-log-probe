//
//  DLPSettingsHelper.h
//  DouyinLogProbe
//
//  设置体系工厂（对齐 douyin-doctor 的 DYDSettingsHelper 模式）：
//  - 字典式创建 setting item，section 工厂
//  - 纯 UIKit，不依赖 AWESetting*，天然无空白页问题
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, DLPSettingKind) {
    DLPSettingKindSwitch,
    DLPSettingKindTap,
};

@interface DLPSettingItem : NSObject
@property (nonatomic, copy, nullable) NSString *key;      // NSUserDefaults key（tap 类型可为 nil）
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *subTitle;
@property (nonatomic, assign) BOOL defaultOn;
@property (nonatomic, assign) DLPSettingKind kind;
@property (nonatomic, copy, nullable) void (^tap)(UIViewController *host);
@end

@interface DLPSettingSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSArray<DLPSettingItem *> *items;
@end

@interface DLPSettingsHelper : NSObject

/// 字典式创建 item（对齐 DYDSettingsHelper.createSettingItem:）：
/// @{ @"identifier": key, @"title": t, @"subTitle": s, @"cellType": @(6=开关/@26=点击),
///    @"defaultOn": @(YES), @"tap": ^(UIViewController *host){} }
+ (DLPSettingItem *)createSettingItem:(NSDictionary *)dict;

/// Section 工厂（对齐 DYDSettingsHelper.createSectionWithTitle:items:）
+ (DLPSettingSection *)createSectionWithTitle:(NSString *)title items:(NSArray<DLPSettingItem *> *)items;

/// 快捷：创建开关 item
+ (DLPSettingItem *)createSwitchItem:(NSString *)key title:(NSString *)title subTitle:(nullable NSString *)subTitle defaultOn:(BOOL)defaultOn;

/// 快捷：创建点击 item
+ (DLPSettingItem *)createTapItem:(NSString *)title subTitle:(nullable NSString *)subTitle tap:(void (^)(UIViewController *host))tap;

/// 文本输入弹窗（对齐 DYDSettingsHelper.showTextInputAlert:）
+ (void)showTextInputAlert:(NSString *)title
               defaultText:(nullable NSString *)defaultText
               placeholder:(nullable NSString *)placeholder
                 onConfirm:(void (^)(NSString *text))onConfirm
                  onCancel:(nullable void (^)(void))onCancel;

/// NSUserDefaults 读写（对齐 DYDSettingsHelper）
+ (BOOL)getBool:(NSString *)key default:(BOOL)def;
+ (void)setBool:(BOOL)value forKey:(NSString *)key;

@end
