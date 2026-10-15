//
//  DLPClassProbe.h
//  DouyinLogProbe
//
//  类名探针（本插件核心诉求：找出所有类名对应什么）：
//   - 启动后在后台线程做一次 runtime 全量类枚举
//   - 按来源 image（AwemeCore/系统/其他）+ 前缀（AWE/TT/IES/DYY/DCL/SJJ/DLP…）聚类
//   - 交叉标注三插件已知的 hook 类（DYYY 监听点 / aweJ 备份·NSBundle 点 / CrashLogger 三处）
//   - 落盘紧凑 JSON：Documents/DLPLogs/classmap.json（AI 可直接读）
//   - K 级日志输出总量摘要
//

#import <Foundation/Foundation.h>

@interface DLPClassProbe : NSObject

/// 执行一次全量探测（后台线程，幂等：一次启动只跑一次）
+ (void)runOnce;

/// classmap.json 路径
+ (NSString *)classmapPath;

@end
