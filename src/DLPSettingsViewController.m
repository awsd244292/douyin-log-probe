//
//  DLPSettingsViewController.m
//  DouyinLogProbe
//

#import "DLPSettingsViewController.h"
#import "DLPConstants.h"
#import "DLPLogHub.h"
#import "DLPOrchestrator.h"
#import "DLPLogViewController.h"

typedef NS_ENUM(NSInteger, DLPSettingKind) {
    DLPSettingKindSwitch,
    DLPSettingKindTap,
};

@interface DLPSettingItem : NSObject
@property (nonatomic, copy) NSString *key;      // NSUserDefaults key（tap 类型可为 nil）
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subTitle;
@property (nonatomic, assign) BOOL defaultOn;
@property (nonatomic, assign) DLPSettingKind kind;
@property (nonatomic, copy, nullable) void (^tap)(UIViewController *host);
@end
@implementation DLPSettingItem
@end

@interface DLPSettingsViewController ()
@property (nonatomic, strong) NSArray<NSString *> *sectionTitles;
@property (nonatomic, strong) NSArray<NSArray<DLPSettingItem *> *> *sections;
@end

@implementation DLPSettingsViewController

static DLPSettingItem *DLPMakeSwitch(NSString *key, NSString *title, NSString *sub, BOOL defOn) {
    DLPSettingItem *it = [DLPSettingItem new];
    it.key = key; it.title = title; it.subTitle = sub;
    it.defaultOn = defOn; it.kind = DLPSettingKindSwitch;
    return it;
}
static DLPSettingItem *DLPMakeTap(NSString *title, NSString *sub, void (^tap)(UIViewController *)) {
    DLPSettingItem *it = [DLPSettingItem new];
    it.title = title; it.subTitle = sub;
    it.kind = DLPSettingKindTap; it.tap = tap;
    return it;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"探针设置";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:self action:@selector(dlp_done)];

    DLPSettingItem *master = DLPMakeSwitch(kDLPEnabled, @"启用日志探针", @"总开关：关则全部模块卸载", YES);

    NSArray *modules = @[
        DLPMakeSwitch(kDLPModuleClassProbe, @"类名探针", @"后台枚举全量类→classmap.json", YES),
        DLPMakeSwitch(kDLPModuleEventTracer, @"事件追踪", @"页面/网络/播放器/登录/数据落盘", YES),
        DLPMakeSwitch(kDLPModulePerfProbe, @"性能探针", @"FPS/内存/主线程卡顿", YES),
        DLPMakeSwitch(kDLPModuleCrashCatcher, @"崩溃抓捕", @"12信号+未捕获异常", YES),
        DLPMakeSwitch(kDLPModuleBypassCatcher, @"绕过登录捕捉器", @"诊断bypass失效：开关/官方真相/弹窗时间线", YES),
        DLPMakeSwitch(kDLPModuleLongPressEntry, @"长按面板入口", @"视频长按菜单加「查看日志」", YES),
    ];
    NSArray *logs = @[
        DLPMakeSwitch(kDLPDetailEnabled, @"细节日志", @"全量默认开：D级与K级同步输出", YES),
        DLPMakeSwitch(kDLPLogToFile, @"落盘日志", @"Documents/DLPLogs/ 按日轮转", YES),
        DLPMakeSwitch(kDLPStderrCapture, @"收其他插件日志", @"stderr重定向：DYYY/DCL/aweJ", YES),
    ];
    __weak typeof(self) weakSelf = self;
    NSArray *ops = @[
        DLPMakeTap(@"查看实时日志", @"内存2000行，支持搜索", ^(UIViewController *host) {
            DLPLogViewController *vc = [[DLPLogViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }),
        DLPMakeTap(@"清空内存日志", @"不删落盘文件", ^(UIViewController *host) {
            [DLPLogHub clearLogs];
            DLPLog(@"sys", YES, @"DLPSettingsViewController", @"clearLogs", @"ok");
        }),
        DLPMakeTap(@"关于探针", @"版本与说明", ^(UIViewController *host) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@\n长按视频→「查看日志」是无登录时的唯一入口。",
                             DLP_NAME, DLP_VERSION];
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志探针"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:a animated:YES completion:nil];
        }),
    ];

    // 总开关单独一组置顶
    self.sectionTitles = @[@"", @"模块", @"日志", @"操作"];
    self.sections = @[@[master], modules, logs, ops];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (void)dlp_done { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return [self.sections count]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [[self.sections objectAtIndex:s] count]; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return [self.sectionTitles objectAtIndex:s]; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    DLPSettingItem *it = [[self.sections objectAtIndex:ip.section] objectAtIndex:ip.row];
    cell.textLabel.text = it.title;
    cell.detailTextLabel.text = it.subTitle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    // 清掉复用残留
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (it.kind == DLPSettingKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = DLPGetBoolDef(it.key, it.defaultOn);
        sw.tag = ip.section * 1000 + ip.row;
        [sw addTarget:self action:@selector(dlp_switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
    } else {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    return cell;
}

- (void)dlp_switchChanged:(UISwitch *)sw {
    NSInteger section = sw.tag / 1000, row = sw.tag % 1000;
    DLPSettingItem *it = [[self.sections objectAtIndex:section] objectAtIndex:row];
    [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:it.key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [DLPOrchestrator applyCurrentProfile]; // 热切换
    DLPLog(@"sys", YES, @"DLPSettingsViewController", @"switch",
           @"%@=%@", it.key, sw.isOn ? @"ON" : @"OFF");
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    DLPSettingItem *it = [[self.sections objectAtIndex:ip.section] objectAtIndex:ip.row];
    if (it.kind == DLPSettingKindTap && it.tap) { it.tap(self); }
}

@end

/// C 入口：供长按/日志页 dlsym 或直接调用
void DLPPresentSettingsPage(UIViewController *host) {
    if (!host) { return; }
    DLPSettingsViewController *vc = [[DLPSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [host presentViewController:nav animated:YES completion:nil];
}
