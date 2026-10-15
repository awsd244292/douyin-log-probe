//
//  DLPLogViewController.m
//  DouyinLogProbe
//

#import "DLPLogViewController.h"
#import "DLPLogHub.h"
#import "DLPLogUploader.h"

@interface DLPLogViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISearchBar *searchBar;
@property(nonatomic, strong) UISegmentedControl *filterSeg;
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

    // 插件跳转：蹭原生 UI。日志页是从探针设置分区（抖音原生设置页内）进来的，
    // 跳转=关掉日志 modal 回到原生设置，医生分区就在那，不调任何插件自建 VC。
    UIButton *jumpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [jumpBtn setTitle:@"🔧 回抖音设置" forState:UIControlStateNormal];
    jumpBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [jumpBtn addTarget:self action:@selector(dlp_jumpPlugin)
      forControlEvents:UIControlEventTouchUpInside];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[jumpBtn, self.searchBar, self.tableView]];
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

#pragma mark - 插件跳转（蹭原生 UI）

// 不 dlsym、不调 douyin-doctor 的自建 VC：日志页是从探针设置分区
// （抖音原生设置页内）modal 进来的，直接 dismiss 回到原生 UI。
// 落点=探针设置分区，再点返回就是抖音设置主页（医生分区）。
- (void)dlp_jumpPlugin {
    UINavigationController *nav = self.navigationController;
    void (^done)(void) = ^{
        DLPLog(@"sys", YES, @"DLPLogViewController", @"jumpPlugin", @"backToNativeSettings");
    };
    if (nav) {
        [nav dismissViewControllerAnimated:YES completion:done];
    } else {
        [self dismissViewControllerAnimated:YES completion:done];
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
    // iPad 弹出位置（iPhone 上无影响）
    sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
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
    av.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
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

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self dlp_applyFilter];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

@end
