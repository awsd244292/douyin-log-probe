// DLP stub：MessageUI 最小声明（syntaxcheck 用，真机构建走系统 SDK）
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, MFMailComposeResult) {
    MFMailComposeResultCancelled = 0,
    MFMailComposeResultSaved = 1,
    MFMailComposeResultSent = 2,
    MFMailComposeResultFailed = 3
};
@protocol MFMailComposeViewControllerDelegate <NSObject>
@optional
- (void)mailComposeController:(UIViewController *)controller
         didFinishWithResult:(MFMailComposeResult)result
                       error:(NSError *)error;
@end
@interface MFMailComposeViewController : UIViewController
+ (BOOL)canSendMail;
- (void)setToRecipients:(NSArray<NSString *> *)toRecipients;
- (void)setSubject:(NSString *)subject;
- (void)setMessageBody:(NSString *)body isHTML:(BOOL)isHTML;
- (void)addAttachmentData:(NSData *)attachment mimeType:(NSString *)mimeType fileName:(NSString *)filename;
@property (nonatomic, weak) id<MFMailComposeViewControllerDelegate> mailComposeDelegate;
@end
