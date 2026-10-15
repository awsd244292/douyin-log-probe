//
//  DLPPerfProbe.h
//  DouyinLogProbe
//
//  性能探针（D 级，细节开关开时输出；卡顿为 K 级）：
//   - FPS：CADisplayLink（运行时获取，不静态引用，防版本漂移）
//   - 内存：task_info(TASK_BASIC_INFO)，15s 一次
//   - 看门狗：主线程 CFRunLoopObserver + 独立 pthread 双路（照抄 DCLWatchdog），
//     主线程 2s 无响应记一次卡顿（K 级，只记时长不抓栈；抓栈见 README 后续）
//

#import <Foundation/Foundation.h>

@interface DLPPerfProbe : NSObject

+ (void)install;   // 幂等
+ (void)uninstall; // 停 CADisplayLink/定时器/看门狗线程

@end
