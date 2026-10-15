//
//  DLPSettings.h
//  DouyinLogProbe
//
//  设置页注入：hook AWESettingsViewModel.sectionDataArray，插入「日志探针」分区。
//  开关拨动即时生效（applyCurrentProfile），CrashLogger 同款热切换。
//  设置页入口常驻，无卸载（总开关关时分区仍在，只显示已停用）。
//

#import <Foundation/Foundation.h>

@interface DLPSettings : NSObject

+ (void)install; // 幂等

@end
