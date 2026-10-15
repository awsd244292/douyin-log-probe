//
//  DLPEntry.m
//  DouyinLogProbe
//
//  插件入口：__attribute__((constructor))，注入后在主队列应用当前配置。
//  无 Logos，所有 hook 走 DLPRouter 运行时安装。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DLPOrchestrator.h"
#import "DLPLogHub.h"

__attribute__((constructor)) static void dlp_ctor(void) {
    @autoreleasepool {
        // 主队列延迟 1s 装配：让宿主先完成基本启动，降低启动期 hook 风险
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            @try {
                [DLPOrchestrator applyCurrentProfile];
            } @catch (NSException *e) { }
        });
    }
}
