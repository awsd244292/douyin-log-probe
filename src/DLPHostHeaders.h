//
//  DLPHostHeaders.h
//  DouyinLogProbe
//
//  宿主（抖音）私有类声明子集：仅含设置页注入用到的 AWESetting* 系列。
//  摘自 DYYY 的 AwemeHeaders.h，未改声明内容。
//

#import <UIKit/UIKit.h>

@interface AWESettingItemModel : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subTitle;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, copy) NSString *iconImageName;
@property(nonatomic, copy) NSString *svgIconImageName;
@property(nonatomic, assign) NSInteger cellType;
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, assign) BOOL isEnable;
@property(nonatomic, assign) BOOL isSwitchOn;
@property(nonatomic, copy) void (^cellTappedBlock)(void);
@property(nonatomic, copy) void (^switchChangedBlock)(void);
- (void)refreshCell;
@end

@interface AWESettingBaseViewModel : NSObject
@end

@interface AWESettingBaseViewController : UIViewController
@property(nonatomic, strong) UIView *view;
@property(nonatomic, strong) UITableView *tableView;
- (AWESettingBaseViewModel *)viewModel;
@end

@interface AWESettingsViewModel : AWESettingBaseViewModel
@property(nonatomic, assign) NSInteger colorStyle;
@property(nonatomic, strong) NSArray *sectionDataArray;
@property(nonatomic, weak) id controllerDelegate;
@property(nonatomic, strong) NSString *traceEnterFrom;
- (AWESettingItemModel *)createSettingItem:(NSDictionary *)dict;
@end

@interface AWESettingSectionModel : NSObject
@property(nonatomic, assign) NSInteger type;
@property(nonatomic, assign) CGFloat sectionHeaderHeight;
@property(nonatomic, copy) NSString *sectionHeaderTitle;
@property(nonatomic, copy) NSString *sectionFooterTitle;
@property(nonatomic, strong) NSArray *itemArray;
@end
