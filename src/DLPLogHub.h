//
//  DLPLogHub.h
//  DouyinLogProbe
//
//  日志中枢：
//   - 行格式（AI 可读：内容全、字符少）：ts|K|domain|class|event|detail
//       ts=秒级时间戳(10字符) K=关键常驻 D=细节按需
//       domain∈{login,player,page,net,perf,crash,ui,data,sys,probe,plugin}
//   - 三路输出：NSLog（前缀 [DLP]）+ 内存环形缓冲（2000 行）+ 落盘
//     Documents/DLPLogs/dlp-YYYY-MM-dd.log（按日轮转，保留 N 天，默认 7）
//   - detail 做清洗：|→/、换行→空格、超 220 字符截断
//

#import <Foundation/Foundation.h>

/// 打日志。critical=YES 为 K 级（常驻）；NO 为 D 级（仅细节开关开时输出）。
void DLPLog(NSString *domain, BOOL critical, NSString *clsName, NSString *event, NSString *detailFormat, ...) NS_FORMAT_FUNCTION(5, 6);

@interface DLPLogHub : NSObject

/// 取全部缓存日志（时间正序，AI 可读格式原样）
+ (NSArray<NSString *> *)allLogs;

/// 清空内存缓存（不删落盘文件）
+ (void)clearLogs;

/// 日志目录（Documents/DLPLogs/，不存在则创建）
+ (NSString *)logDirectory;

/// 启动时清理过期日志文件（保留 kDLPLogKeepDays 天）
+ (void)cleanupOldLogs;

@end
