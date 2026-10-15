//
//  DLPLogHub.m
//  DouyinLogProbe
//

#import "DLPLogHub.h"
#import "DLPConstants.h"

static NSMutableArray<NSString *> *sRing = nil;
static const NSUInteger kDLPRingCap = 2000;
static NSFileHandle *sFileHandle = nil;
static NSString *sCurrentLogDate = nil;

static NSString *DLPSanitize(NSString *s) {
    if (!s) { return @""; }
    NSMutableString *m = [s mutableCopy];
    [m replaceOccurrencesOfString:@"|" withString:@"/" options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, m.length)];
    [m replaceOccurrencesOfString:@"\r" withString:@" " options:0 range:NSMakeRange(0, m.length)];
    if (m.length > 220) { [m deleteCharactersInRange:NSMakeRange(220, m.length - 220)]; }
    return m;
}

void DLPLog(NSString *domain, BOOL critical, NSString *clsName, NSString *event, NSString *detailFormat, ...) {
    if (!DLPGetBoolDef(kDLPEnabled, YES)) { return; }          // 总开关关 → 全静默
    if (!critical && !DLPGetBoolDef(kDLPDetailEnabled, NO)) { return; } // D 级需细节开关
    @try {
        NSString *detail = @"";
        if (detailFormat) {
            va_list ap; va_start(ap, detailFormat);
            detail = [[NSString alloc] initWithFormat:detailFormat arguments:ap];
            va_end(ap);
        }
        long ts = (long)[[NSDate date] timeIntervalSince1970];
        NSString *line = [NSString stringWithFormat:@"%ld|%@|%@|%@|%@|%@",
                          ts, critical ? @"K" : @"D",
                          DLPSanitize(domain), DLPSanitize(clsName),
                          DLPSanitize(event), DLPSanitize(detail)];
        @synchronized([DLPLogHub class]) {
            if (!sRing) { sRing = [NSMutableArray array]; }
            [sRing addObject:line];
            if (sRing.count > kDLPRingCap) {
                [sRing removeObjectsInRange:NSMakeRange(0, sRing.count - kDLPRingCap)];
            }
        }
        NSLog(@"[DLP] %@", line);
        // 落盘（与内存格式一致，AI 可直接读文件）
        if (DLPGetBoolDef(kDLPLogToFile, YES)) {
            @synchronized([DLPLogHub class]) {
                NSString *today = nil;
                NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                fmt.dateFormat = @"yyyy-MM-dd";
                today = [fmt stringFromDate:[NSDate date]];
                if (![today isEqualToString:sCurrentLogDate]) {
                    [sFileHandle closeFile]; sFileHandle = nil;
                    sCurrentLogDate = today;
                }
                if (!sFileHandle) {
                    NSString *dir = [DLPLogHub logDirectory];
                    NSString *path = [dir stringByAppendingPathComponent:
                                      [NSString stringWithFormat:@"dlp-%@.log", today]];
                    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
                        [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
                    }
                    sFileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
                    [sFileHandle seekToEndOfFile];
                }
                NSString *withNL = [line stringByAppendingString:@"\n"];
                [sFileHandle writeData:[withNL dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    } @catch (NSException *e) { }
}

@implementation DLPLogHub

+ (NSArray<NSString *> *)allLogs {
    @synchronized(self) {
        return sRing ? [sRing copy] : @[];
    }
}

+ (void)clearLogs {
    @synchronized(self) {
        [sRing removeAllObjects];
    }
}

+ (NSString *)logDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *dir = [[paths firstObject] stringByAppendingPathComponent:@"DLPLogs"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (void)cleanupOldLogs {
    @try {
        NSString *dir = [self logDirectory];
        NSInteger keepDays = DLPGetIntDef(kDLPLogKeepDays, 7);
        NSTimeInterval cutoff = [[NSDate date] timeIntervalSince1970] - keepDays * 86400;
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil]) {
            if (![name hasPrefix:@"dlp-"] || ![name hasSuffix:@".log"]) { continue; }
            NSString *path = [dir stringByAppendingPathComponent:name];
            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            NSDate *mtime = attr[NSFileModificationDate];
            if (mtime && [mtime timeIntervalSince1970] < cutoff) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
    } @catch (NSException *e) { }
}

@end
