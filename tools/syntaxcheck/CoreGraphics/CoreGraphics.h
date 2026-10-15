// 最小 CoreGraphics 桩头文件（仅用于 Linux 语法体检，不参与真机编译）
// 覆盖本工程实际用到的几何类型与常量。
#ifndef PDP_STUB_COREGRAPHICS_H
#define PDP_STUB_COREGRAPHICS_H

#include <stddef.h>

typedef double CGFloat;

typedef struct CGPoint { CGFloat x; CGFloat y; } CGPoint;
typedef struct CGSize  { CGFloat width; CGFloat height; } CGSize;
typedef struct CGRect  { CGPoint origin; CGSize size; } CGRect;

// 颜色引用：真实 SDK 里是不透明结构体指针，CALayer.borderColor 用它。
// 桩里给个不完整类型即可满足语法体检（不参与真机编译）。
typedef struct CGColor *CGColorRef;

static const CGFloat CGFLOAT_MIN = -1.7976931348623157e+308;

// 零值常量（真机由 CoreGraphics 提供）
extern const CGPoint CGPointZero;
extern const CGSize  CGSizeZero;
extern const CGRect  CGRectZero;

static inline CGPoint CGPointMake(CGFloat x, CGFloat y) { CGPoint p; p.x = x; p.y = y; return p; }
static inline CGSize  CGSizeMake(CGFloat w, CGFloat h) { CGSize s; s.width = w; s.height = h; return s; }
static inline CGRect  CGRectMake(CGFloat x, CGFloat y, CGFloat w, CGFloat h) {
    CGRect r; r.origin.x = x; r.origin.y = y; r.size.width = w; r.size.height = h; return r;
}
static inline CGFloat CGRectGetWidth(CGRect r)  { return r.size.width; }
static inline CGFloat CGRectGetHeight(CGRect r) { return r.size.height; }
static inline CGFloat CGRectGetMinX(CGRect r)   { return r.origin.x; }
static inline CGFloat CGRectGetMinY(CGRect r)   { return r.origin.y; }
static inline CGFloat CGRectGetMidX(CGRect r)   { return r.origin.x + r.size.width / 2.0; }
static inline CGFloat CGRectGetMidY(CGRect r)   { return r.origin.y + r.size.height / 2.0; }
static inline CGFloat CGRectGetMaxX(CGRect r)   { return r.origin.x + r.size.width; }
static inline CGFloat CGRectGetMaxY(CGRect r)   { return r.origin.y + r.size.height; }
static inline int CGRectContainsPoint(CGRect r, CGPoint p) {
    return p.x >= r.origin.x && p.x <= r.origin.x + r.size.width &&
           p.y >= r.origin.y && p.y <= r.origin.y + r.size.height;
}

#endif /* PDP_STUB_COREGRAPHICS_H */
