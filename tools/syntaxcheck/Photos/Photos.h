//
//  Photos stub —— 仅供 tools/syntaxcheck.sh 语法体检。
//  Photos framework syntax stub.
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PHAuthorizationStatus) {
    PHAuthorizationStatusNotDetermined = 0,
    PHAuthorizationStatusRestricted,
    PHAuthorizationStatusDenied,
    PHAuthorizationStatusAuthorized,
    PHAuthorizationStatusLimited,
};

typedef NS_ENUM(NSInteger, PHAssetResourceType) {
    PHAssetResourceTypePhoto = 1,
    PHAssetResourceTypeVideo = 2,
};

@interface PHAssetResourceCreationOptions : NSObject
@property (nonatomic, copy) NSString *originalFilename;
@end

@interface PHAssetCreationRequest : NSObject
+ (instancetype)creationRequestForAsset;
- (void)addResourceWithType:(PHAssetResourceType)type
                    fileURL:(NSURL *)fileURL
                    options:(PHAssetResourceCreationOptions *)options;
@end

@interface PHPhotoLibrary : NSObject
+ (instancetype)sharedPhotoLibrary;
+ (void)requestAuthorization:(void(^)(PHAuthorizationStatus status))handler;
- (void)performChanges:(void(^)(void))changeBlock
     completionHandler:(void(^)(BOOL success, NSError * _Nullable error))completionHandler;
@end
