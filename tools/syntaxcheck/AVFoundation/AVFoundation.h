// 语法检查用最小桩：AVFoundation
// 目的：在没有 iOS SDK 的 Linux 上做 clang -fsyntax-only 语法校验。
// 只覆盖本工程实际用到的 API（V3.3.7 视频清晰度上限），不参与真机编译。
#ifndef PDP_STUB_AVFOUNDATION_H
#define PDP_STUB_AVFOUNDATION_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>   /* AVPlayerLayer : CALayer */

@interface AVURLAsset : NSObject
+ (instancetype)assetWithURL:(NSURL *)url;
@property (nonatomic, readonly) BOOL playable;
@end

@interface AVPlayerItem : NSObject
/// 期望峰值码率（bps），0 = 不限。HLS 自适应选档时不会超过该值。
@property (nonatomic, assign) double preferredPeakBitRate;
- (void)setPreferredPeakBitRate:(double)preferredPeakBitRate;
/// V3.3.11：期望前向缓冲时长（秒），0 = 不设偏好。播放器囤多少秒才开播/续播。
@property (nonatomic, assign) NSTimeInterval preferredForwardBufferDuration;
- (void)setPreferredForwardBufferDuration:(NSTimeInterval)preferredForwardBufferDuration;
@end

#endif /* PDP_STUB_AVFOUNDATION_H */

/* V3.3.9：AVPlayerLayer.videoGravity（画面比例开关） */
typedef NSString * AVLayerVideoGravity;
extern AVLayerVideoGravity const AVLayerVideoGravityResizeAspect;
extern AVLayerVideoGravity const AVLayerVideoGravityResizeAspectFill;
extern AVLayerVideoGravity const AVLayerVideoGravityResize;

@interface AVPlayerLayer : CALayer
@property (nonatomic, copy) AVLayerVideoGravity videoGravity;
- (void)setVideoGravity:(AVLayerVideoGravity)videoGravity;
@end
