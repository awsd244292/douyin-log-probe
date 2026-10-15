// 语法检查用最小桩：Foundation
// 目的：在没有 iOS SDK 的 Linux 上，用 clang -fsyntax-only 校验本工程的
//       Objective-C 语法、类型与符号引用。只覆盖本工程实际用到的 API。
// 注意：这是「语法检查夹具」，不参与真机编译，切勿加入 Makefile 的头文件搜索路径。
#ifndef PDP_STUB_FOUNDATION_H
#define PDP_STUB_FOUNDATION_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <limits.h>
#include <stdarg.h>   // V3.2.12：NSLogv 需要 va_list
#include <objc/runtime.h>
#include <dispatch/dispatch.h>

#ifndef NSInteger
#define NSInteger long
#define NSUInteger unsigned long
#define NSUIntegerMax ULONG_MAX

#endif
typedef unsigned short unichar;

// 前向声明：解决桩内部接口之间的相互引用顺序问题
@class NSString, NSMutableString, NSArray, NSMutableArray, NSDictionary, NSMutableDictionary;
@class NSSet, NSMutableSet, NSHashTable, NSNumber, NSValue, NSDate, NSDateFormatter;
@class NSNotification, NSNotificationCenter, NSOperationQueue, NSUserDefaults, NSFileManager;
@class NSData, NSJSONSerialization, NSException, NSError, NSLock, NSRecursiveLock, NSIndexPath;
@class NSCharacterSet, NSBundle;

typedef struct _NSRange { NSUInteger location; NSUInteger length; } NSRange;
NSRange NSMakeRange(NSUInteger loc, NSUInteger len);
#ifndef NS_INLINE
#define NS_INLINE static inline
#endif
#ifndef nil
#define nil ((void *)0)
#endif
#ifndef Nil
#define Nil ((Class)0)
#endif
#ifndef MIN
#define MIN(a,b) (((a) < (b)) ? (a) : (b))
#endif
#ifndef MAX
#define MAX(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef CGFLOAT_TYPE
typedef double NSTimeInterval;
#endif

#define NS_ENUM(_type, _name) _type _name; enum
typedef NS_ENUM(NSInteger, NSComparisonResult) {
    NSOrderedAscending = -1,
    NSOrderedSame = 0,
    NSOrderedDescending = 1
};
#define NS_OPTIONS(_type, _name) _type _name; enum
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define NS_ASSUME_NONNULL_END   _Pragma("clang assume_nonnull end")
#define NS_AVAILABLE_IOS(x)
#define NS_DESIGNATED_INITIALIZER
#define NS_UNAVAILABLE
#define NS_REQUIRES_NIL_TERMINATION
#define NS_SWIFT_NAME(x)
#define NS_FORMAT_FUNCTION(a, b)
#define NS_RETURNS_RETAINED
#define UIKIT_EXTERN extern

@protocol NSObject
- (id)self;
- (Class)class;
- (BOOL)isEqual:(id)object;
- (BOOL)conformsToProtocol:(Protocol *)aProtocol;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (id)copy;
- (id)mutableCopy;
@end

@protocol NSCopying
- (id)copyWithZone:(void *)zone;
@end

@protocol NSMutableCopying
- (id)mutableCopyWithZone:(void *)zone;
@end

@protocol NSFastEnumeration
@end

/* V3.2.7：NSMethodSignature 的类声明在 NSObject 之后，而 NSObject 新方法要用到它 —— 前向声明。 */
@class NSMethodSignature;

@interface NSObject <NSObject>
+ (instancetype)alloc;
+ (instancetype)new;
- (instancetype)init;
- (id)copy;
- (BOOL)isKindOfClass:(Class)aClass;
- (BOOL)respondsToSelector:(SEL)aSelector;
- (void)doesNotRecognizeSelector:(SEL)aSelector;
- (NSString *)description;
- (NSString *)debugDescription;
/* KVC / 运行时派发：PDPPlaybackProbe 不链接 AVFoundation，靠 KVC 被动读 AVAudioSession 状态，
   KVC 在键不存在时返回 nil 而非崩溃，正是这种「读得到就读、读不到就算」场景需要的。 */
- (id)valueForKey:(NSString *)key;
- (void)setValue:(id)value forKey:(NSString *)key;
- (id)performSelector:(SEL)aSelector;
- (id)performSelector:(SEL)aSelector withObject:(id)object;
+ (id)performSelector:(SEL)aSelector;
+ (BOOL)instancesRespondToSelector:(SEL)aSelector;
/* V3.2.7：宿主长按面板入口用 NSInvocation 调宿主的 dismissWithAnimation:completion:，
   需要先取方法签名 —— 桩里补上，否则「桩上过、真机过不了」的反面也会出现。 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;
+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector;
/* V3.2.11：DYStorage 桥接用 IMP 直调（寄存器/参数个数超过 performSelector 的限制），
   需要先拿到方法实现指针。真机 SDK 里这个声明在 NSObject 上。 */
- (IMP)methodForSelector:(SEL)aSelector;
+ (IMP)methodForSelector:(SEL)aSelector;
@end

@interface NSMethodSignature : NSObject
+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)types;
@property (nonatomic, readonly) NSUInteger numberOfArguments;
@property (nonatomic, readonly) const char *methodReturnType;
- (const char *)getArgumentTypeAtIndex:(NSUInteger)idx;
@end

@interface NSInvocation : NSObject
+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig;
@property (nonatomic, assign) SEL selector;
@property (nonatomic, weak) id target;
- (void)setArgument:(void *)argLocation atIndex:(NSInteger)idx;
- (void)getArgument:(void *)argLocation atIndex:(NSInteger)idx;
- (void)getReturnValue:(void *)retLoc;
- (void)invoke;
- (void)invokeWithTarget:(id)target;
- (void)retainArguments;
@end

@interface NSCoder : NSObject
@end

@interface NSLocale : NSObject
@property (class, readonly, strong) NSLocale *currentLocale;
+ (instancetype)localeWithLocaleIdentifier:(NSString *)identifier;
- (id)objectForKey:(id)key;
@end
extern NSString *const NSLocaleIdentifier;

@interface NSString : NSObject <NSCopying>
+ (instancetype)stringWithFormat:(NSString *)format, ...;
+ (instancetype)stringWithUTF8String:(const char *)str;
+ (instancetype)stringWithContentsOfFile:(NSString *)path encoding:(unsigned)enc error:(void **)error;
- (NSString *)stringByAppendingPathComponent:(NSString *)str;
- (NSString *)stringByAppendingString:(NSString *)str;
- (NSString *)stringByTrimmingCharactersInSet:(id)set;
- (NSArray *)componentsSeparatedByString:(NSString *)separator;
- (NSString *)substringToIndex:(NSUInteger)idx;
- (NSString *)uppercaseString;
- (NSString *)stringByReplacingCharactersInRange:(NSRange)range withString:(NSString *)replacement;
- (NSString *)lowercaseString;
- (BOOL)hasPrefix:(NSString *)prefix;
- (BOOL)hasSuffix:(NSString *)suffix;
/// V3.2.10：类名考古探针里用于对齐输出（把类名补空格到固定宽度，便于人眼扫读）。
- (NSString *)stringByPaddingToLength:(NSUInteger)newLength
                           withString:(NSString *)padString
                      startingAtIndex:(NSUInteger)padIndex;
- (BOOL)isEqualToString:(NSString *)other;
- (BOOL)containsString:(NSString *)other;
/// V3.2.8：单参数版 rangeOfString:（无 option 遮罩）。
/// 桩原先只有带 options 的那个，导致「no visible @interface ... rangeOfString:」。
- (NSRange)rangeOfString:(NSString *)s;
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set;
/// V3.3.10：URL 编码
- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)set;
- (NSArray *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)set;
- (NSString *)stringByAppendingPathExtension:(NSString *)ext;  // V3.3.10
- (NSString *)pathExtension;
- (NSString *)stringByDeletingPathExtension;
- (NSString *)substringFromIndex:(NSUInteger)idx;
- (NSRange)rangeOfString:(NSString *)s options:(unsigned)mask;
- (NSUInteger)length;
- (NSString *)stringByDeletingLastPathComponent;
- (NSString *)lastPathComponent;
- (NSString *)stringByAppendingFormat:(NSString *)format, ...;
- (const char *)UTF8String;
- (unichar)characterAtIndex:(NSUInteger)idx;
- (NSString *)substringWithRange:(NSRange)range;
- (NSString *)stringByReplacingOccurrencesOfString:(NSString *)target
                                        withString:(NSString *)replacement;
- (BOOL)getCString:(char *)buffer
         maxLength:(unsigned long)maxBufferCount
          encoding:(unsigned)enc;
// V3.2.9：Tweak.xm 的探针用 fileSystemRepresentation 取 NSString 的 C 字符串路径。
// 真机 SDK 上它声明在 NSString (NSStringPathExtensions) 分类里，桩里补上以免本地
// 语法体检误报 "property 'fileSystemRepresentation' not found"（CI 真机编译不会报）。
@property (readonly) const char *fileSystemRepresentation;
// DLP 补：日志中枢/类名探针用到的常用 Foundation 方法（真机 SDK 均有，桩补齐防误报）
- (instancetype)initWithFormat:(NSString *)format arguments:(va_list)argList;
- (NSData *)dataUsingEncoding:(unsigned)enc;
@end

@interface NSString (FileWrite)
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag encoding:(unsigned)enc error:(NSError **)error;
@end

@interface NSMutableString : NSString
+ (instancetype)string;
// DLP 补
- (NSUInteger)replaceOccurrencesOfString:(NSString *)target
                             withString:(NSString *)replacement
                                options:(unsigned)opts
                                  range:(NSRange)range;
- (void)deleteCharactersInRange:(NSRange)range;
/// V3.2.10：类名考古探针按容量预分配（抖音类表很大，避免反复 realloc）
+ (instancetype)stringWithCapacity:(NSUInteger)capacity;
/// V3.2.10：探针里用 stringWithString: 复制一行再做后缀处理
+ (instancetype)stringWithString:(NSString *)str;
- (void)appendFormat:(NSString *)format, ...;
- (void)appendString:(NSString *)str;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag encoding:(unsigned)enc error:(NSError **)error;
@end

@interface NSValue : NSObject <NSCopying>
@end

@interface NSNumber : NSValue
+ (NSNumber *)numberWithInteger:(NSInteger)value;
+ (NSNumber *)numberWithBool:(BOOL)value;
+ (NSNumber *)numberWithDouble:(double)value;
+ (NSNumber *)numberWithLong:(long)value;
+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value;
- (unsigned long long)unsignedLongLongValue;
// DLP 补
- (NSInteger)integerValue;
+ (NSNumber *)numberWithInt:(int)value;
+ (NSNumber *)numberWithUnsignedInteger:(NSUInteger)value;
- (NSComparisonResult)compare:(NSNumber *)other;
+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value;
+ (NSNumber *)numberWithUnsignedInt:(unsigned int)value;
- (NSInteger)integerValue;
- (BOOL)boolValue;
- (double)doubleValue;
@end

@interface NSArray<ObjectType> : NSObject <NSCopying>
+ (instancetype)array;
+ (instancetype)arrayWithObject:(ObjectType)obj;
+ (instancetype)arrayWithObjects:(ObjectType)first, ...;
+ (instancetype)arrayWithObjects:(const ObjectType *)objects count:(NSUInteger)cnt;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(NSUInteger)len;
- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (NSUInteger)count;
- (ObjectType)firstObject;
- (ObjectType)lastObject;
- (ObjectType)objectAtIndex:(NSUInteger)idx;
- (NSArray *)subarrayWithRange:(NSRange)range;
- (NSString *)componentsJoinedByString:(NSString *)separator;
- (BOOL)containsObject:(ObjectType)obj;
- (NSArray *)arrayByAddingObject:(ObjectType)obj;
// V3.2.12：档位预设用它拼接开关集合
- (NSArray<ObjectType> *)arrayByAddingObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (NSUInteger)indexOfObject:(ObjectType)obj;
// V3.2.14：PDPLogClassifier 预编译规则表时按 key 排序，保证跨运行顺序稳定
- (NSArray<ObjectType> *)sortedArrayUsingSelector:(SEL)comparator;
@end

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
+ (instancetype)arrayWithArray:(NSArray *)other;
+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)obj;
- (void)addObjectsFromArray:(NSArray *)other;
- (void)insertObject:(ObjectType)obj atIndex:(NSUInteger)idx;
- (void)sortUsingComparator:(NSComparisonResult (^)(ObjectType a, ObjectType b))cmptr;
- (void)removeObject:(ObjectType)obj;
- (void)removeObjectAtIndex:(NSUInteger)idx;
- (void)removeAllObjects;
- (void)removeObjectsInRange:(NSRange)range;
@end

@interface NSDictionary<KeyType, ObjectType> : NSObject <NSCopying>
+ (instancetype)dictionary;
+ (instancetype)dictionaryWithDictionary:(NSDictionary *)other;
+ (instancetype)dictionaryWithObjects:(const id *)objects forKeys:(const id *)keys count:(NSUInteger)cnt;
- (id)objectForKeyedSubscript:(id)key;
+ (instancetype)dictionaryWithContentsOfFile:(NSString *)path;
- (NSUInteger)count;
- (ObjectType)objectForKey:(KeyType)key;
- (NSArray<KeyType> *)allKeys;
- (NSArray<ObjectType> *)allValues;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(NSUInteger)len;
// DLP 补
- (NSArray *)keysSortedByValueUsingComparator:(NSComparisonResult (^)(id, id))cmpr;
@end

@interface NSMutableDictionary<KeyType, ObjectType> : NSDictionary<KeyType, ObjectType>
- (void)setObject:(ObjectType)obj forKey:(KeyType)key;
- (void)removeObjectForKey:(KeyType)key;
- (void)removeAllObjects;
- (void)addEntriesFromDictionary:(NSDictionary *)other;
- (void)setObject:(id)obj forKeyedSubscript:(id)key;
@end

@interface NSSet<ObjectType> : NSObject <NSCopying>
+ (instancetype)set;
+ (instancetype)setWithArray:(NSArray *)array;
+ (instancetype)setWithObjects:(ObjectType)firstObj, ...;   // 真机 SDK 同名 API（Tweak.xm 在用）
- (NSUInteger)count;
- (BOOL)containsObject:(ObjectType)obj;
- (NSArray<ObjectType> *)allObjects;
- (void)addObject:(ObjectType)obj;
/// V3.2.12：档位判定要按「集合完全相等」比对（低档 6 项 + 多开 1 项 → 自定义）
- (BOOL)isEqualToSet:(NSSet<ObjectType> *)otherSet;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(NSUInteger)len;
@end

@interface NSMutableSet<ObjectType> : NSSet<ObjectType>
- (void)addObject:(ObjectType)obj;
- (void)removeObject:(ObjectType)obj;
- (void)removeAllObjects;
@end

@interface NSHashTable<ObjectType> : NSObject <NSCopying>
+ (NSHashTable *)weakObjectsHashTable;
- (void)addObject:(ObjectType)obj;
- (void)removeObject:(ObjectType)obj;
- (void)removeAllObjects;
- (NSUInteger)count;
- (NSArray<ObjectType> *)allObjects;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(NSUInteger)len;
@end

typedef NS_ENUM(NSInteger, NSProcessInfoThermalState) {
    NSProcessInfoThermalStateNominal = 0,
    NSProcessInfoThermalStateFair = 1,
    NSProcessInfoThermalStateSerious = 2,
    NSProcessInfoThermalStateCritical = 3,
};
// V3.3.0 PDPPowerGovernor 用到的通知名（extern 常量，桩里只声明）
extern NSString *NSProcessInfoPowerStateDidChangeNotification;
extern NSString *NSProcessInfoThermalStateDidChangeNotification;

@interface NSProcessInfo : NSObject
@property (class, readonly, strong) NSProcessInfo *processInfo;
@property (nonatomic, readonly, copy) NSString *processName;
// V3.2.4：CPU 现场取证需要核数来把「占用多少核」换算成「相对总 CPU 百分比」
@property (nonatomic, readonly) NSUInteger activeProcessorCount;
/// V3.2.10：类名考古探针在文件头写系统版本，便于把「类名清单」和「抖音版本」对齐
@property (nonatomic, readonly, copy) NSString *operatingSystemVersionString;
// V3.3.0 PDPPowerGovernor：低电量与热状态感知
@property (nonatomic, readonly, getter=isLowPowerModeEnabled) BOOL lowPowerModeEnabled;
@property (nonatomic, readonly) NSProcessInfoThermalState thermalState;
@end

@interface NSDate : NSObject
+ (instancetype)date;
+ (instancetype)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs;
- (NSTimeInterval)timeIntervalSince1970;
- (NSTimeInterval)timeIntervalSinceReferenceDate;
@end

@interface NSDateFormatter : NSObject
+ (NSString *)localizedStringFromDate:(NSDate *)date
                           dateStyle:(unsigned long)dstyle
                           timeStyle:(unsigned long)tstyle;
@property (nonatomic, copy) NSString *dateFormat;
@property (nonatomic, strong) NSLocale *locale;
- (NSString *)stringFromDate:(NSDate *)date;
- (NSDate *)dateFromString:(NSString *)string;
@end

typedef NSString *NSNotificationName;
extern NSNotificationName const NSNotificationNameNone;

@interface NSNotification : NSObject <NSCopying>
@property (readonly, copy) NSNotificationName name;
@property (readonly, retain) id object;
@property (readonly, copy) NSDictionary *userInfo;
@end

@interface NSNotificationCenter : NSObject
@property (class, readonly, strong) NSNotificationCenter *defaultCenter;
- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(id)obj;
- (id)addObserverForName:(NSNotificationName)name
                  object:(id)obj
                   queue:(id)queue
              usingBlock:(void (^)(NSNotification *note))block;
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject;
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)userInfo;
- (void)removeObserver:(id)observer;
@end

@interface NSOperationQueue : NSObject
@property (class, readonly, strong) NSOperationQueue *mainQueue;
@end

@interface NSUserDefaults : NSObject
@property (class, readonly, strong) NSUserDefaults *standardUserDefaults;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
- (BOOL)synchronize;
@end

@interface NSURL : NSObject  // V3.3.10
+ (instancetype)URLWithString:(NSString *)s;
+ (instancetype)fileURLWithPath:(NSString *)path;
@property (nonatomic, readonly, copy) NSString *lastPathComponent;
@end

@interface NSURLResponse : NSObject
@property (nonatomic, readonly) int64_t expectedContentLength;
@property (nonatomic, readonly, copy) NSString *MIMEType;
@end
static const int64_t NSURLResponseUnknownLength = -1;
typedef NSInteger NSURLSessionResponseDisposition;
static const NSURLSessionResponseDisposition NSURLSessionResponseAllow = 1;

@interface NSURLCache : NSObject  // V3.3.11：网络缓存清理
+ (NSURLCache *)sharedURLCache;
- (void)removeAllCachedResponses;
@property (nonatomic, readonly) NSUInteger currentMemoryUsage;
@property (nonatomic, readonly) NSUInteger currentDiskUsage;
@end

@interface NSURLSessionTask : NSObject
- (void)resume;
@end
@interface NSURLSessionDataTask : NSURLSessionTask
@end
@interface NSURLSessionConfiguration : NSObject
+ (instancetype)defaultSessionConfiguration;
+ (instancetype)ephemeralSessionConfiguration;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForRequest;
@property (nonatomic, assign) NSTimeInterval timeoutIntervalForResource;
@property (nonatomic, copy, nullable) NSDictionary *HTTPAdditionalHeaders;
@end
@protocol NSURLSessionDataDelegate <NSObject>
@end
@interface NSURLSession : NSObject
+ (instancetype)sharedSession;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)cfg delegate:(id)d delegateQueue:(id)q;
+ (instancetype)sessionWithConfiguration:(NSURLSessionConfiguration *)cfg;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;
- (NSURLSessionTask *)dataTaskWithURL:(NSURL *)url
                    completionHandler:(void(^)(NSData *data, NSURLResponse *resp, NSError *err))handler;
- (NSURLSessionTask *)downloadTaskWithURL:(NSURL *)url
                       completionHandler:(void(^)(NSURL *loc, NSURLResponse *resp, NSError *err))handler;
@end

@interface NSUUID : NSObject  // V3.3.10
+ (instancetype)UUID;
@property (nonatomic, readonly, copy) NSString *UUIDString;
@end

@interface NSFileManager : NSObject
@property (class, readonly, strong) NSFileManager *defaultManager;
- (BOOL)createDirectoryAtPath:(NSString *)path
  withIntermediateDirectories:(BOOL)createIntermediates
                  attributes:(NSDictionary *)attributes
                       error:(NSError **)error;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dst error:(NSError **)error;
- (BOOL)moveItemAtURL:(NSURL *)src toURL:(NSURL *)dst error:(NSError **)err;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)err;
// DLP 补
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
@end

static NSString *const NSFileSize = @"NSFileSize";
// DLP 补
static NSString *const NSFileModificationDate = @"NSFileModificationDate";

@interface NSFileHandle : NSObject
+ (instancetype)fileHandleForReadingAtPath:(NSString *)path;
// DLP 补
+ (instancetype)fileHandleForWritingAtPath:(NSString *)path;
- (void)seekToEndOfFile;
- (void)writeData:(NSData *)data;
- (NSData *)readDataOfLength:(NSUInteger)length;
- (void)closeFile;
@end

@interface NSData : NSObject
+ (instancetype)data;
@property (readonly) const void *bytes;
+ (instancetype)dataWithContentsOfFile:(NSString *)path;
@property (readonly) NSUInteger length;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)flag;
- (NSUInteger)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(NSUInteger)len;
- (BOOL)writeToFile:(NSString *)path options:(unsigned)mask error:(NSError **)error;
@end

@interface NSMutableData : NSData
- (void)appendData:(NSData *)data;
@end

@interface NSJSONSerialization : NSObject
+ (NSData *)dataWithJSONObject:(id)obj options:(unsigned)opt error:(NSError **)error;
+ (id)JSONObjectWithData:(NSData *)data options:(unsigned)opt error:(NSError **)error;
@end

@interface NSException : NSObject
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *reason;
@property (readonly, copy) NSArray *callStackSymbols;
+ (void)raise:(NSString *)name format:(NSString *)format, ...;
@end

// 未捕获异常处理器（真实定义在 Foundation/NSException.h）。
// 用于审计「谁动了全局异常处理器」——查它的当前地址属于哪个镜像。
// DLP 修正：真机 SDK 里 NSUncaughtExceptionHandler 是函数类型（不是函数指针），
// NSGetUncaughtExceptionHandler 返回 NSUncaughtExceptionHandler *。桩之前多包了一层 *。
typedef void NSUncaughtExceptionHandler(NSException *exception);
extern NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void);
// DLP 补
void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *handler);

// NSNull：JSON 序列化里表示「空值」的单例（用于「查不到」与「查到 0」的区分）
@interface NSNull : NSObject
+ (NSNull *)null;
@end

@interface NSError : NSObject
@property (readonly, copy) NSString *localizedDescription;
@property (readonly) NSInteger code;
@end

typedef NS_ENUM(NSInteger, NSQualityOfService) {
    NSQualityOfServiceUserInteractive = 0x21,
    NSQualityOfServiceUserInitiated   = 0x19,
    NSQualityOfServiceUtility         = 0x11,
    NSQualityOfServiceBackground      = 0x09,
    NSQualityOfServiceDefault         = -1
};

@interface NSThread : NSObject
@property (class, readonly) BOOL isMainThread;
+ (void)sleepForTimeInterval:(NSTimeInterval)ti;
- (instancetype)initWithTarget:(id)target selector:(SEL)selector object:(id)argument;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSQualityOfService qualityOfService;
@property (nonatomic) NSUInteger stackSize;
- (void)start;
@end

@interface NSLock : NSObject
@property (copy) NSString *name;
- (void)lock;
- (void)unlock;
@end

@interface NSRecursiveLock : NSObject
@property (copy) NSString *name;
- (void)lock;
- (void)unlock;
@end

@interface NSIndexPath : NSObject
@property (readonly) NSInteger row;
@property (readonly) NSInteger section;
/// V3.2.21：UICollectionView 的 index path 用 item 而非 row。
/// 真机上 NSIndexPath 由 UIKit 扩展出 item（UIKitAdditions），
/// 桩里补一条，让 cell 尺寸 hook 能过语法体检。
@property (readonly) NSInteger item;
+ (NSIndexPath *)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
@end

@interface NSCharacterSet : NSObject
@property (class, readonly, copy) NSCharacterSet *URLQueryAllowedCharacterSet;  // V3.3.10
@property (class, readonly, copy) NSCharacterSet *whitespaceAndNewlineCharacterSet;
/// V3.2.8：常见用法 —— 按空白裁剪字符串
@property (class, readonly, copy) NSCharacterSet *whitespaceCharacterSet;
/// V3.2.8：按给定字符集切分（用于「取第一个句号之前」这类摘要逻辑）
+ (instancetype)characterSetWithCharactersInString:(NSString *)s;
@end

@interface NSBundle : NSObject
@property (class, readonly, strong) NSBundle *mainBundle;
@property (nonatomic, readonly, copy) NSString *executablePath;
/// V3.2.10：类名考古探针在文件头写 bundle id，确认探针确实写在宿主进程里
@property (nonatomic, readonly, copy) NSString *bundleIdentifier;
@end

enum {
    NSCaseInsensitiveSearch = 1,
    NSRegularExpressionSearch = 1024,
    NSLiteralSearch = 2
};

/// V3.2.14：PDPLogClassifier 改用**预编译**正则替换 NSRegularExpressionSearch option。
///
/// 桩注意：这里只声明本插件真正用到的三个成员。
/// 不是完整的 NSRegularExpression 接口，够语法体检用即可 ——
/// 真机编译走的是真 SDK 头文件，两边必须对得上的是**调用点**，不是头文件全貌。
@interface NSTextCheckingResult : NSObject
@end

@interface NSRegularExpression : NSObject
@property (nonatomic, readonly) NSUInteger numberOfCaptureGroups;
+ (NSRegularExpression *)regularExpressionWithPattern:(NSString *)pattern
                                              options:(NSUInteger)options
                                                error:(NSError **)error;
/// 只关心「有没有命中」，不需要枚举全部结果 —— 命中即返回，开销更小
- (NSTextCheckingResult *)firstMatchInString:(NSString *)string
                                     options:(NSUInteger)options
                                       range:(NSRange)range;
- (NSUInteger)numberOfMatchesInString:(NSString *)string
                              options:(NSUInteger)options
                                range:(NSRange)range;
@end

/// NSRegularExpression 的 options 常量（桩里给 0 即可，语法体检不校验语义）
enum {
    NSRegularExpressionCaseInsensitive = 1 << 0
};

enum {
    NSJSONWritingPrettyPrinted = 1,
    NSDataWritingAtomic = 1
};

enum {
    NSNotFound = 0x7fffffff
};

enum {
    NSUTF8StringEncoding = 4
};

enum {
    NSLibraryDirectory = 5,
    NSDocumentDirectory = 9,
    NSUserDomainMask = 1
};

enum {
    NSDateFormatterNoStyle = 0,
    NSDateFormatterShortStyle = 1,
    NSDateFormatterMediumStyle = 2,
    NSDateFormatterLongStyle = 3
};

NSArray<NSString *> *NSSearchPathForDirectoriesInDomains(NSUInteger directory,
                                                         NSUInteger domainMask,
                                                         BOOL expandTilde);
NSString *NSTemporaryDirectory(void);
// getpid 真机来自 <unistd.h>（经 UIKit/Foundation 间接引入），桩里补一个声明即可
int getpid(void);
// 带 format 属性后 clang 的 -Wformat 会逐个校验 NSLog 的占位符与实参类型
// （%@ 只接受对象；整型给 %@ 会被当成指针去 deref，arm64 上直接 EXC_BAD_ACCESS）。
// 少了这个属性，整份工程的 NSLog 格式串错误都逃过语法体检。
void NSLog(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));

// V3.2.12：NSLogv 是 NSLog 的 va_list 版本（iOS 2.0+ 公开 API，声明在
// Foundation/NSObjCRuntime.h）。日志拦截模块靠它把宿主日志原样转发回系统 ——
// 直接调 NSLog 无法跨函数传递 va_list，这是唯一标准解法。
// 需 <stdarg.h> 的 va_list，工程其它文件已间接引入。
void NSLogv(NSString *format, va_list args);

extern NSNotificationName const UIApplicationDidReceiveMemoryWarningNotification;

// ---- V3.2.3 RunLoop 相位标记所需声明 ----
// 真机来自 <CoreFoundation/CFRunLoop.h>（经 UIKit/Foundation 间接引入）。
// 这里只补本模块实际用到的最小集合，够 clang 做语法与类型体检即可。
typedef long CFIndex;
typedef unsigned long CFOptionFlags;
typedef const void *CFTypeRef;
typedef const struct __CFString *CFStringRef;
typedef const struct __CFAllocator *CFAllocatorRef;
typedef unsigned char Boolean;

typedef CFOptionFlags CFRunLoopActivity;
enum {
    kCFRunLoopEntry         = (1UL << 0),
    kCFRunLoopBeforeTimers  = (1UL << 1),
    kCFRunLoopBeforeSources = (1UL << 2),
    kCFRunLoopBeforeWaiting = (1UL << 5),
    kCFRunLoopAfterWaiting  = (1UL << 6),
    kCFRunLoopExit          = (1UL << 7),
    kCFRunLoopAllActivities = 0x0FFFFFFFU
};

typedef struct __CFRunLoopObserver *CFRunLoopObserverRef;
typedef struct __CFRunLoop *CFRunLoopRef;
typedef struct {
    CFIndex version;
    void *info;
    const void *(*retain)(const void *info);
    void (*release)(const void *info);
    CFStringRef (*copyDescription)(const void *info);
} CFRunLoopObserverContext;
typedef void (*CFRunLoopObserverCallBack)(CFRunLoopObserverRef observer,
                                          CFRunLoopActivity activity,
                                          void *info);

CFRunLoopRef CFRunLoopGetMain(void);
CFRunLoopObserverRef CFRunLoopObserverCreate(CFAllocatorRef allocator,
                                             CFOptionFlags activities,
                                             Boolean repeats,
                                             CFIndex order,
                                             CFRunLoopObserverCallBack callout,
                                             const CFRunLoopObserverContext *context);
void CFRunLoopAddObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef mode);
// DLP 补：看门狗卸载用
void CFRunLoopRemoveObserver(CFRunLoopRef rl, CFRunLoopObserverRef observer, CFStringRef mode);
void CFRelease(CFTypeRef cf);

extern CFStringRef const kCFRunLoopCommonModes;
extern CFAllocatorRef const kCFAllocatorDefault;

#endif

// ── V3.3.0 面板实时刷新桩 ──
@interface NSTimer : NSObject
+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)target selector:(SEL)sel userInfo:(id)ui repeats:(BOOL)rep;
// DLP 补
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)target selector:(SEL)sel userInfo:(id)ui repeats:(BOOL)rep;
@property (nonatomic, readonly, getter=isValid) BOOL valid;
- (void)invalidate;
@end

@interface NSRunLoop : NSObject
+ (NSRunLoop *)mainRunLoop;
- (void)addTimer:(NSTimer *)timer forMode:(NSString *)mode;
@end

extern NSString * const NSRunLoopCommonModes;

@interface NSCondition : NSObject
- (void)lock;
- (void)unlock;
- (void)wait;
- (BOOL)waitUntilDate:(NSDate *)date;
- (void)signal;
- (void)broadcast;
@end

@interface NSIndexSet : NSObject <NSCopying>
+ (instancetype)indexSetWithIndex:(NSUInteger)index;
- (NSUInteger)count;
- (BOOL)containsIndex:(NSUInteger)index;
@end
