//
//  DLPSettingsViewController.m
//  DouyinLogProbe
//
//  探针独立设置页：纯 UIKit（UITableViewController），
//  用 DLPSettingsHelper 工厂构建（对齐医生设置体系模式），天然无空白页。
//

#import "DLPSettingsViewController.h"
#import "DLPSettingsHelper.h"
#import "DLPConstants.h"
#import "DLPLogHub.h"
#import "DLPOrchestrator.h"
#import "DLPLogViewController.h"

@interface DLPSettingsViewController ()
@property (nonatomic, strong) NSArray<DLPSettingSection *> *sections;
@end

@implementation DLPSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"探针设置";
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:self action:@selector(dlp_done)];

    // ── 总开关（置顶独立分区）──
    DLPSettingSection *masterSec = [DLPSettingsHelper createSectionWithTitle:@"" items:@[
        [DLPSettingsHelper createSwitchItem:kDLPEnabled title:@"启用日志探针" subTitle:@"总开关：关则全部模块卸载" defaultOn:YES],
    ]];

    // ── 模块 ──
    DLPSettingSection *modulesSec = [DLPSettingsHelper createSectionWithTitle:@"模块" items:@[
        [DLPSettingsHelper createSwitchItem:kDLPModuleClassProbe title:@"类名探针" subTitle:@"后台枚举全量类→classmap.json" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPModuleEventTracer title:@"事件追踪" subTitle:@"页面/网络/播放器/登录/数据落盘" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPModulePerfProbe title:@"性能探针" subTitle:@"FPS/内存/主线程卡顿" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPModuleCrashCatcher title:@"崩溃抓捕" subTitle:@"12信号+未捕获异常" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPModuleBypassCatcher title:@"绕过登录捕捉器" subTitle:@"诊断bypass失效：开关/官方真相/弹窗时间线" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPModuleLongPressEntry title:@"长按面板入口" subTitle:@"视频长按菜单加「查看日志」" defaultOn:YES],
    ]];

    // ── 日志 ──
    DLPSettingSection *logsSec = [DLPSettingsHelper createSectionWithTitle:@"日志" items:@[
        [DLPSettingsHelper createSwitchItem:kDLPDetailEnabled title:@"细节日志" subTitle:@"全量默认开：D级与K级同步输出" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPLogToFile title:@"落盘日志" subTitle:@"Documents/DLPLogs/ 按日轮转" defaultOn:YES],
        [DLPSettingsHelper createSwitchItem:kDLPStderrCapture title:@"收其他插件日志" subTitle:@"stderr重定向：DYYY/DCL/aweJ" defaultOn:YES],
    ]];

    // ── 操作 ──
    __weak typeof(self) weakSelf = self;
    DLPSettingSection *opsSec = [DLPSettingsHelper createSectionWithTitle:@"操作" items:@[
        [DLPSettingsHelper createTapItem:@"查看实时日志" subTitle:@"内存2000行，支持搜索" tap:^(UIViewController *host) {
            DLPLogViewController *vc = [[DLPLogViewController alloc] init];
            [weakSelf.navigationController pushViewController:vc animated:YES];
        }],
        [DLPSettingsHelper createTapItem:@"清空内存日志" subTitle:@"不删落盘文件" tap:^(UIViewController *host) {
            [DLPLogHub clearLogs];
            DLPLog(@"sys", YES, @"DLPSettingsViewController", @"clearLogs", @"ok");
        }],
        [DLPSettingsHelper createTapItem:@"关于探针" subTitle:@"版本与说明" tap:^(UIViewController *host) {
            NSString *msg = [NSString stringWithFormat:@"%@ %@\n长按视频→「查看日志」是无登录时的唯一入口。",
                             DLP_NAME, DLP_VERSION];
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"日志探针"
                                                                       message:msg
                                                                preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [weakSelf presentViewController:a animated:YES completion:nil];
        }],
    ]];

    self.sections = @[masterSec, modulesSec, logsSec, opsSec];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (void)dlp_done { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return [self.sections count]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return [[self.sections objectAtIndex:s].items count]; }
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s { return [self.sections objectAtIndex:s].title; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [t dequeueReusableCellWithIdentifier:@"cell" forIndexPath:ip];
    DLPSettingItem *it = [[self.sections objectAtIndex:ip.section].items objectAtIndex:ip.row];
    cell.textLabel.text = it.title;
    cell.detailTextLabel.text = it.subTitle;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    // 清掉复用残留
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (it.kind == DLPSettingKindSwitch) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = [DLPSettingsHelper getBool:it.key default:it.defaultOn];
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
    DLPSettingItem *it = [[self.sections objectAtIndex:section].items objectAtIndex:row];
    [DLPSettingsHelper setBool:sw.isOn forKey:it.key];
    [DLPOrchestrator applyCurrentProfile]; // 热切换
    DLPLog(@"sys", YES, @"DLPSettingsViewController", @"switch",
           @"%@=%@", it.key, sw.isOn ? @"ON" : @"OFF");
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    DLPSettingItem *it = [[self.sections objectAtIndex:ip.section].items objectAtIndex:ip.row];
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
