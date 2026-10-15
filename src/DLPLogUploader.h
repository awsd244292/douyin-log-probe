//
//  DLPLogUploader.h
//  DouyinLogProbe
//
//  日志上传：调系统邮件把日志发到用户 Gmail，助手用 Gmail 连接器直接读。
//  用户已确认日志里只有抖音业务、无隐私（2026-10-16）。
//

#import <Foundation/Foundation.h>

@class UIViewController;

@interface DLPLogUploader : NSObject

/// 从指定 VC 弹出邮件发送界面（收件人已预填用户 Gmail，附件=日志+类名地图）
+ (void)presentMailComposerFrom:(UIViewController *)vc;

@end
