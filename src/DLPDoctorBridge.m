//
//  DLPDoctorBridge.m
//  DouyinLogProbe
//

#import "DLPDoctorBridge.h"
#import <objc/runtime.h>

@implementation DLPDoctorBridge

+ (BOOL)doctorPresent {
    return NSClassFromString(@"DYDLogManager") != nil;
}

+ (NSArray<NSString *> *)pullDoctorLogs {
    Class cls = NSClassFromString(@"DYDLogManager");
    if (!cls) { return @[]; }
    SEL sel = NSSelectorFromString(@"allLogs");
    if (![cls respondsToSelector:sel]) { return @[]; }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id result = [cls performSelector:sel];
#pragma clang diagnostic pop
    if ([result isKindOfClass:[NSArray class]]) {
        return (NSArray<NSString *> *)result;
    }
    return @[];
}

@end
