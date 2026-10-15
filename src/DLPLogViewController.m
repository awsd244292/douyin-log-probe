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

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 44;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.searchBar, self.tableView]];
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
    // 1s 刷新一次（只在可见时）
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                       selector:@selector(dlp_reload)
                                                       userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)dlp_close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dlp_clear { [DLPLogHub clearLogs]; [self dlp_reload]; }
- (void)dlp_refilter { [self dlp_applyFilter]; }

/// 上传：调系统邮件把日志+类名地图发到用户 Gmail，助手用 Gmail 连接器直接读
- (void)dlp_upload { [DLPLogUploader presentMailComposerFrom:self]; }

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
