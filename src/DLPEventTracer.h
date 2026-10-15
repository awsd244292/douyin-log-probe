//
//  DLPEventTracer.h
//  DouyinLogProbe
//
//  大小事事件追踪。hook 点 = 三插件开关功能涉及到的地方（逆向实证）+ 自研补充。
//  参数读取规则（防崩）：无参数或公开 API 的方法可读参数；私有
//  多参方法只记类名+selector（抓到业务类名是核心诉求，参数是赠品）。
//

#import <Foundation/Foundation.h>

@interface DLPEventTracer : NSObject

+ (void)install;   // 幂等
+ (void)uninstall; // IMP 比对还原

@end
