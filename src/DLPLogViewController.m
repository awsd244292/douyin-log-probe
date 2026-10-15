//
//  DLPLogViewController.m
//  DouyinLogProbe
//

#import "DLPLogViewController.h"
#import "DLPLogHub.h"
#import "DLPLogUploader.h"
#import <dlfcn.h>

// 直达医生设置：douyin-doctor 导出的设置入口 C 函数（DYDSettingsPage.m），
// dlsym 动态探测，零头文件依赖；未安装时弹提示。
static const char *kDLPDoctorSymbol = "showDYDSettingsVC";

/// popover 锚点：iPad / 横屏 Regular 宽度下，actionSheet 与分享面板走
/// UIPopoverPresentationController，不给有效锚点会在
/// presentationTransitionWillBegin 抛 NSInvalidArgumentException 直接闪退
///（v1.5.2 在用户横屏看视频时复现，SIGABRT）。
/// 用 sourceView+sourceRect（导航栏右上角），确定性有效，不依赖 barButtonItem。
static void DLPAnchorPopover(UIViewController *presented, UIViewController *srcVC) {
    UIPopoverPresentationController *pop = presented.popoverPresentationController;
    UIView *v = srcVC.view;
    if (!pop || !v) { return; }
    pop.sourceView = v;
    CGFloat w = v.bounds.size.width;
    if (w <= 0) { w = 390; }
    pop.sourceRect = CGRectMake(w - 44, 0, 44, 44);
    pop.permittedArrowDirections = UIPopoverArrowDirectionUp;
}

@interface DLPLogViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UISegmentedControl *filterSeg;
@property(nonatomic, strong) UIStackView *jumpRow;
@property(nonatomic, strong) NSArray<NSString *> *allLines;
@property(nonatomic, strong) NSArray<NSString *> *shownLines;
@property(nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation DLPLogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"日志探针·实时";
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                     target:self action:@selector(dlp_close)];
    UIBarButtonItem *uploadItem =
        [[UIBarButtonItem alloc] initWithTitle:@"上传" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(dlp_upload)];
    UIBarButtonItem *copyItem =
        [[UIBarButtonItem alloc] initWithTitle:@"复制" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(dlp_copy)];
    UIBarButtonItem *clearItem =
        [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(dlp_clear)];
    self.navigationItem.rightBarButtonItems = @[uploadItem, copyItem, clearItem];

    self.filterSeg = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"K", @"D"]];
    self.filterSeg.selectedSegmentIndex = 0;
    [self.filterSeg addTarget:self action:@selector(dlp_refilter) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.filterSeg;

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.placeholder = @"搜类名/事件/域，如 AWEUserService";
    self.searchBar.delegate = self;

    // 跳转入口（两个都留，用户自己选）：
    //  1. 「回抖音设置」——蹭原生 UI：dismiss 日志 modal 回到探针设置分区
    //  2. 「医生设置」——dlsym 直达 douyin-doctor 设置页（push 进来，返回即回日志）
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [backBtn setTitle:@"🔧 回抖音设置" forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [backBtn addTarget:self action:@selector(dlp_backToSettings)
      forControlEvents:UIControlEventTouchUpInside];
    UIButton *docBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [docBtn setTitle:@"🩺 医生设置" forState:UIControlStateNormal];
    docBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [docBtn addTarget:self action:@selector(dlp_jumpDoctor)
      forControlEvents:UIControlEventTouchUpInside];
    UIStackView *jumpRow = [[UIStackView alloc] initWithArrangedSubviews:@[backBtn, docBtn]];
    jumpRow.axis = UILayoutConstraintAxisHorizontal;
    jumpRow.distribution = UIStackViewDistributionFillEqually;
    self.jumpRow = jumpRow;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[jumpRow, self.searchBar, self.tableView]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    [self dlp_reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 跳转双按钮常驻（用户定：点一下就跳，不用开关）
    // 跳转插件设置再返回时恢复刷新（push/pop 会触发 willDisappear/willAppear，
    // timer 只在 viewDidLoad 建的话，回来后列表就停更了）
    if (!self.refreshTimer) {
        self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                           selector:@selector(dlp_reload)
                                                           userInfo:nil repeats:YES];
    }
    [self dlp_reload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)dlp_close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dlp_clear { [DLPLogHub clearLogs]; [self dlp_reload]; }
- (void)dlp_refilter { [self dlp_applyFilter]; }

#pragma mark - 跳转入口（两个都留）

/// 1. 回抖音设置：蹭原生 UI。日志页是从探针设置分区（抖音原生设置页内）
/// modal 进来的，直接 dismiss 回到原生 UI，不调任何插件自建 VC。
- (void)dlp_backToSettings {
    UINavigationController *nav = self.navigationController;
    void (^done)(void) = ^{
        DLPLog(@"sys", YES, @"DLPLogViewController", @"backToSettings", @"ok");
    };
    if (nav) {
        [nav dismissViewControllerAnimated:YES completion:done];
    } else {
        [self dismissViewControllerAnimated:YES completion:done];
    }
}

/// 2. 直达医生设置：dlsym 调 douyin-doctor 的 showDYDSettingsVC，
/// 对方设置页 push 进当前导航栈，返回键即回日志。
- (void)dlp_jumpDoctor {
    void *sym = dlsym(RTLD_DEFAULT, kDLPDoctorSymbol);
    if (!sym) {
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"没探测到"
                                               message:@"当前进程里没发现抖音医生（douyin-doctor）"
                                        preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    void (*openSettings)(UIViewController *) = (void (*)(UIViewController *))sym;
    @try {
        openSettings(self);
        DLPLog(@"sys", YES, @"DLPLogViewController", @"jumpDoctor", @"ok");
    } @catch (NSException *e) {
        DLPLog(@"sys", YES, @"DLPLogViewController", @"jumpDoctor", @"fail=%@",
               e.reason ?: @"?");
    }
}

/// 上传：二级选单——邮件发送 / 分享面板（可分享进 Muse App）
- (void)dlp_upload {
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:@"上传日志"
                                           message:nil
                                    preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"邮件发送" style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        [DLPLogUploader presentMailComposerFrom:self];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"分享面板" style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        [self dlp_share];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    // popover 锚点（iPad/横屏不设会闪退，见 DLPAnchorPopover）
    DLPAnchorPopover(sheet, self);
    [self presentViewController:sheet animated:YES completion:nil];
}

/// 分享面板：把日志写成临时 .log 文件交出去（可进 Muse 分享扩展）
- (void)dlp_share {
    NSArray<NSString *> *lines = [DLPLogHub allLogs] ?: @[];
    NSMutableString *buf = [NSMutableString string];
    NSInteger cap = MIN((NSInteger)lines.count, 2000);
    for (NSInteger i = cap - 1; i >= 0; i--) {
        NSString *l = lines[(NSUInteger)i];
        if (buf.length + l.length > 200 * 1024) { break; }
        [buf appendString:l];
        [buf appendString:@"\n"];
    }
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"dlp.log"];
    NSError *err = nil;
    [buf writeToFile:tmp atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (err) {
        DLPLog(@"net", YES, @"DLPLogViewController", @"share", @"write tmp fail");
        return;
    }
    UIActivityViewController *av =
        [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:tmp]]
                                        applicationActivities:nil];
    // popover 锚点（iPad/横屏不设会闪退，见 DLPAnchorPopover）
    DLPAnchorPopover(av, self);
    [self presentViewController:av animated:YES completion:nil];
    DLPLog(@"net", YES, @"DLPLogViewController", @"share", @"lines=%ld", (long)cap);
}

/// 复制当前筛选结果到剪贴板（时间正序，最多 2000 行 / 200KB），直接粘贴发出来即可
- (void)dlp_copy {
    NSArray<NSString *> *lines = self.shownLines ?: @[];
    NSMutableString *buf = [NSMutableString string];
    // shownLines 是倒序（新在上），粘贴时改回正序方便阅读
    NSInteger cap = MIN((NSInteger)lines.count, 2000);
    for (NSInteger i = cap - 1; i >= 0; i--) {
        NSString *l = lines[(NSUInteger)i];
        if (buf.length + l.length > 200 * 1024) { break; }
        [buf appendString:l];
        [buf appendString:@"\n"];
    }
    [UIPasteboard generalPasteboard].string = buf;
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"已复制"
                                           message:[NSString stringWithFormat:@"%lu 行已进剪贴板，直接粘贴发送即可",
                                                    (unsigned long)(cap)]
                                    preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dlp_reload {
    self.allLines = [DLPLogHub allLogs];
    [self dlp_applyFilter];
}

- (void)dlp_applyFilter {
    NSString *q = self.searchBar.text ?: @"";
    NSInteger seg = self.filterSeg.selectedSegmentIndex; // 0全部 1K 2D
    NSMutableArray *out = [NSMutableArray array];
    // 倒序：最新的在最上面
    for (NSInteger i = (NSInteger)self.allLines.count - 1; i >= 0; i--) {
        NSString *line = self.allLines[i];
        if (seg == 1 && [line rangeOfString:@"|K|"].location == NSNotFound) { continue; }
        if (seg == 2 && [line rangeOfString:@"|D|"].location == NSNotFound) { continue; }
        if (q.length > 0 && [line rangeOfString:q options:NSCaseInsensitiveSearch].location == NSNotFound) { continue; }
        [out addObject:line];
        if (out.count >= 500) { break; } // 列表只展 500 行，防卡
    }
    self.shownLines = out;
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.shownLines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *rid = @"dlp_log_cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
        cell.textLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
        cell.textLabel.numberOfLines = 0;
    }
    NSString *line = self.shownLines[indexPath.row];
    cell.textLabel.text = line;
    // K 级高亮
    cell.textLabel.textColor = [line rangeOfString:@"|K|"].location != NSNotFound
        ? [UIColor colorWithRed:0.65 green:0.1 blue:0.1 alpha:1.0] : [UIColor darkGrayColor];
    return cell;
}

/// 点行：类名/整行可点——弹选单（复制类名 / 按此类筛选 / 复制整行）
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *line = self.shownLines[(NSUInteger)indexPath.row];
    if (!line.length) { return; }
    // 格式 ts|K|domain|class|event|detail，class 是第 4 段
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@"|"];
    NSString *cls = parts.count > 3 ? parts[3] : @"";
    UIAlertController *sheet =
        [UIAlertController alertControllerWithTitle:cls.length ? cls : @"日志行"
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    if (cls.length) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"复制类名" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *a) {
            [UIPasteboard generalPasteboard].string = cls;
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"按此类筛选" style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *a) {
            self.searchBar.text = cls;
            [self dlp_applyFilter];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制整行" style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *a) {
        [UIPasteboard generalPasteboard].string = line;
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    DLPAnchorPopover(sheet, self);
    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self dlp_applyFilter];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
