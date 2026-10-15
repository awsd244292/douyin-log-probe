//
//  DLPLogUploader.m
//  DouyinLogProbe
//

#import "DLPLogUploader.h"
#import "DLPLogHub.h"
#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

// 收件人：用户自己的 Gmail（助手用 Gmail 连接器读取）
static NSString *const kDLPUploadRecipient = @"awsd244292@gmail.com";

@interface DLPLogUploader () <MFMailComposeViewControllerDelegate>
@end

@implementation DLPLogUploader

+ (void)presentMailComposerFrom:(UIViewController *)vc {
    if (![MFMailComposeViewController canSendMail]) {
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"发不出"
                                               message:@"本机没配邮件帐户，请改用「复制」按钮粘贴发送"
                                        preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 日志正文：内存缓冲全部（最多 2000 行），时间正序
    NSArray<NSString *> *lines = [DLPLogHub allLogs] ?: @[];
    NSMutableString *body = [NSMutableString string];
    NSInteger cap = MIN((NSInteger)lines.count, 2000);
    for (NSInteger i = cap - 1; i >= 0; i--) {
        NSString *l = lines[(NSUInteger)i];
        if (body.length + l.length > 500 * 1024) { break; }
        [body appendString:l];
        [body appendString:@"\n"];
    }
    NSData *logData = [body dataUsingEncoding:NSUTF8StringEncoding];

    // 类名地图附件
    NSString *classmapPath = [[DLPLogHub logDirectory] stringByAppendingPathComponent:@"classmap.json"];
    NSData *mapData = [NSData dataWithContentsOfFile:classmapPath];

    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    // delegate 用一个常驻单例，避免 composer 弹出来后 delegate 被释放
    mc.mailComposeDelegate = (id)[self sharedDelegate];
    [mc setToRecipients:@[kDLPUploadRecipient]];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm";
    [mc setSubject:[NSString stringWithFormat:@"[DLP] 日志 %@", [df stringFromDate:[NSDate date]]]];
    [mc setMessageBody:[NSString stringWithFormat:@"探针日志 %lu 行，类名地图见附件。", (unsigned long)cap]
                isHTML:NO];
    if (logData.length > 0) {
        [mc addAttachmentData:logData mimeType:@"text/plain" fileName:@"dlp.log"];
    }
    if (mapData.length > 0) {
        [mc addAttachmentData:mapData mimeType:@"application/json" fileName:@"classmap.json"];
    }
    [vc presentViewController:mc animated:YES completion:nil];
    DLPLog(@"net", YES, @"DLPLogUploader", @"presentMailComposer", @"lines=%ld", (long)cap);
}

+ (instancetype)sharedDelegate {
    static DLPLogUploader *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[DLPLogUploader alloc] init]; });
    return s;
}

#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(UIViewController *)controller
         didFinishWithResult:(MFMailComposeResult)result
                       error:(NSError *)error {
    NSString *msg = @"已取消";
    if (result == MFMailComposeResultSent) { msg = @"已发送，助手稍后查收"; }
    else if (result == MFMailComposeResultFailed) { msg = @"发送失败，请改用「复制」"; }
    else if (result == MFMailComposeResultSaved) { msg = @"已存草稿"; }
    DLPLog(@"net", YES, @"DLPLogUploader", @"mailResult", @"%@", msg);
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
