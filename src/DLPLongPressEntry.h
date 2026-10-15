//
//  DLPLongPressEntry.h
//  DouyinLogProbe
//
//  长按面板入口：hook 原生视频长按面板的数据源，只往 viewModels 里加
//  一个"查看日志"按钮数据（蹭 DYDLongPressPanel 那套，不自建 UI）。
//  点一下：先关面板（completion 里再进，避免 dismiss 未播完 present 失败），
//  直接进 DLPLogViewController，不用进设置翻。
//

#import <Foundation/Foundation.h>

@interface DLPLongPressEntry : NSObject

+ (void)install;
+ (void)uninstall;

@end
