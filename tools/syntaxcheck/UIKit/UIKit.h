// 语法检查用最小桩：UIKit + CoreGraphics
// 目的：在没有 iOS SDK 的 Linux 上做 clang -fsyntax-only 语法校验。
// 只覆盖本工程实际用到的 API，不参与真机编译。
#ifndef PDP_STUB_UIKIT_H
#define PDP_STUB_UIKIT_H

#include <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>

@class UIGestureRecognizer, UIPanGestureRecognizer, UILongPressGestureRecognizer, UITapGestureRecognizer;
@class UIEvent, UIWindow, UIScreen, UIColor, UIFont, UIView, UILabel, UIButton, UISwitch, UIProgressView, UISearchBar;
@class UIViewController, UITableView, UITableViewCell, UIStackView, NSLayoutConstraint;

typedef NS_ENUM(NSInteger, UITableViewCellSeparatorStyle) {
    UITableViewCellSeparatorStyleNone = 0,
    UITableViewCellSeparatorStyleSingleLine = 1,
};
@class CALayer, UIBarButtonItem, UINavigationItem, UINavigationController, UIAlertController;
@class UICollectionViewLayoutAttributes, UICollectionViewFlowLayout, UIApplication, UIScene, UIWindowScene;
@class NSLayoutAnchor, NSLayoutDimension, NSLayoutXAxisAnchor, NSLayoutYAxisAnchor, UILayoutGuide;
@class UIPopoverPresentationController, UIImageView, UIImage, UIActivityIndicatorView, UIScrollView;

typedef struct UIEdgeInsets { CGFloat top, left, bottom, right; } UIEdgeInsets;
typedef struct UIOffset { CGFloat horizontal, vertical; } UIOffset;

static inline UIEdgeInsets UIEdgeInsetsMake(CGFloat top, CGFloat left,
                                            CGFloat bottom, CGFloat right) {
    UIEdgeInsets i; i.top = top; i.left = left; i.bottom = bottom; i.right = right; return i;
}
extern const UIEdgeInsets UIEdgeInsetsZero;

CGRect UIScreenMainBounds(void);

typedef NS_ENUM(NSInteger, UIViewAutoresizing) {
    UIViewAutoresizingNone = 0,
    UIViewAutoresizingFlexibleWidth = 1 << 1,
    UIViewAutoresizingFlexibleHeight = 1 << 4
};

typedef NS_ENUM(NSInteger, UIControlEvents) {
    UIControlEventTouchUpInside = 1 << 6,
    UIControlEventValueChanged = 1 << 12
};

typedef NS_ENUM(NSInteger, UITableViewStyle) {
    UITableViewStylePlain = 0,
    UITableViewStyleGrouped = 1,
    UITableViewStyleInsetGrouped = 2
};

typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
    UITableViewCellStyleDefault = 0,
    UITableViewCellStyleValue1 = 1,
    UITableViewCellStyleValue2 = 2,
    UITableViewCellStyleSubtitle = 3
};

typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
    UITableViewCellAccessoryNone = 0,
    UITableViewCellAccessoryDisclosureIndicator = 1,
    UITableViewCellAccessoryDetailDisclosureButton = 2,
    UITableViewCellAccessoryCheckmark = 3,
    UITableViewCellAccessoryDetailButton = 4
};

typedef NS_ENUM(NSInteger, UITableViewScrollPosition) {
    UITableViewScrollPositionNone = 0,
    UITableViewScrollPositionTop = 1,
    UITableViewScrollPositionMiddle = 2,
    UITableViewScrollPositionBottom = 3
};

typedef NS_ENUM(NSUInteger, UIPopoverArrowDirection) {
    UIPopoverArrowDirectionUp = 1ULL << 0,
    UIPopoverArrowDirectionDown = 1ULL << 1,
    UIPopoverArrowDirectionLeft = 1ULL << 2,
    UIPopoverArrowDirectionRight = 1ULL << 3,
    UIPopoverArrowDirectionAny = 0xFF,
    UIPopoverArrowDirectionUnknown = 0
};

extern const CGFloat UITableViewAutomaticDimension;

typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) {
    UITableViewCellSelectionStyleNone = 0,
    UITableViewCellSelectionStyleDefault = 1
};

typedef NS_ENUM(NSInteger, UITableViewRowAnimation) {
    UITableViewRowAnimationAutomatic = 0,
    UITableViewRowAnimationNone = 1,
    UITableViewRowAnimationFade = 2
};

typedef NS_ENUM(NSInteger, UIButtonType) {
    UIButtonTypeCustom = 0,
    UIButtonTypeSystem = 1
};

typedef NS_ENUM(NSInteger, UIBarButtonItemStyle) {
    UIBarButtonItemStylePlain = 0
};

typedef NS_ENUM(long, UIBarButtonSystemItem) {
    UIBarButtonSystemItemDone = 0
};

typedef NS_ENUM(NSInteger, UIAlertControllerStyle) {
    UIAlertControllerStyleActionSheet = 0,
    UIAlertControllerStyleAlert = 1
};

typedef NS_ENUM(NSInteger, UIAlertActionStyle) {
    UIAlertActionStyleDefault = 0,
    UIAlertActionStyleCancel = 1,
    UIAlertActionStyleDestructive = 2
};

typedef NS_ENUM(NSInteger, UIStackViewDistribution) {
    UIStackViewDistributionFillEqually = 0
};

typedef NS_ENUM(NSInteger, UILayoutConstraintAxis) {
    UILayoutConstraintAxisHorizontal = 0,
    UILayoutConstraintAxisVertical = 1
};

typedef NS_ENUM(NSInteger, UIModalPresentationStyle) {
    UIModalPresentationPageSheet = 1,
    // V3.2.21：模态之上再叠模态时改用全屏，避免 nav bar 被外层 sheet 顶出可视区。
    UIModalPresentationFullScreen = 0
};

typedef NS_ENUM(NSInteger, UIGestureRecognizerState) {
    UIGestureRecognizerStateBegan = 1,
    UIGestureRecognizerStateChanged = 2,
    UIGestureRecognizerStateEnded = 3
};

typedef NS_ENUM(unsigned long, UIControlState) {
    UIControlStateNormal = 0,
    UIControlStateHighlighted = 1,
    UIControlStateDisabled = 2,
    UIControlStateSelected = 4
};

typedef NS_ENUM(NSInteger, UIFontWeight) {
    UIFontWeightRegular = 0,
    UIFontWeightMedium = 1,
    UIFontWeightSemibold = 2,
    UIFontWeightBold = 3
};

typedef NS_ENUM(NSInteger, NSTextAlignment) {
    NSTextAlignmentCenter = 1
};

typedef NS_ENUM(NSInteger, UILineBreakMode) {
    NSLineBreakByWordWrapping = 0
};

typedef CGFloat UIWindowLevel;
extern const UIWindowLevel UIWindowLevelNormal;
extern const UIWindowLevel UIWindowLevelAlert;

@interface UIColor : NSObject
@property (class, readonly, strong) UIColor *systemBackgroundColor;
@property (class, readonly, strong) UIColor *systemGroupedBackgroundColor;
@property (class, readonly, strong) UIColor *secondarySystemBackgroundColor;
@property (class, readonly, strong) UIColor *systemBlueColor;
@property (class, readonly, strong) UIColor *systemGreenColor;
@property (class, readonly, strong) UIColor *systemOrangeColor;
@property (class, readonly, strong) UIColor *systemRedColor;
@property (class, readonly, strong) UIColor *systemYellowColor;
@property (class, readonly, strong) UIColor *systemGrayColor;
// DLP 补
@property (class, readonly, strong) UIColor *darkGrayColor;
@property (class, readonly, strong) UIColor *systemGray4Color;
@property (class, readonly, strong) UIColor *labelColor;
@property (class, readonly, strong) UIColor *whiteColor;
@property (class, readonly, strong) UIColor *blackColor;
@property (class, readonly, strong) UIColor *secondaryLabelColor;
@property (class, readonly, strong) UIColor *tertiaryLabelColor;
/// V3.2.12：档位按钮边框用 layer.borderColor = color.CGColor
@property (nonatomic, readonly) CGColorRef CGColor;
+ (UIColor *)clearColor;
+ (UIColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (UIColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (UIColor *)colorWithAlphaComponent:(CGFloat)alpha;
@end

@interface UIFont : NSObject
+ (UIFont *)systemFontOfSize:(CGFloat)size;
+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
+ (UIFont *)boldSystemFontOfSize:(CGFloat)size;
+ (UIFont *)monospacedSystemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
@end

@interface CALayer : NSObject
@property (nonatomic) CGRect frame;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic) BOOL masksToBounds;
/// V3.2.12：档位按钮描边（borderWidth / borderColor）
@property (nonatomic) CGFloat borderWidth;
@property (nonatomic) CGColorRef borderColor;
// V3.3.0：DYYY 式渐变流光标题所需
@property (nonatomic, strong) CALayer *mask;
@property (nonatomic, strong) NSArray *colors;
@property (nonatomic, assign) CGPoint startPoint;
@property (nonatomic, assign) CGPoint endPoint;
- (void)addSublayer:(CALayer *)layer;
- (void)addAnimation:(id)anim forKey:(NSString *)key;
@end

@interface CAGradientLayer : CALayer
+ (instancetype)layer;
@end

@interface UIView : NSObject
// V3.2.21：判「这个 view 是否还在窗口层级里」——present 前的前置检查。
@property (nonatomic, readonly, strong) UIWindow *window;
@property (nonatomic, readonly) CALayer *layer;
- (void)addGestureRecognizer:(UIGestureRecognizer *)gr;
- (void)removeGestureRecognizer:(UIGestureRecognizer *)gr;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic) CGRect frame;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGPoint center;
@property (nonatomic, assign) UIColor *backgroundColor;
@property (nonatomic, readonly) UIView *superview;
@property (nonatomic, readonly) NSArray<UIView *> *subviews;
@property (nonatomic) UIViewAutoresizing autoresizingMask;
@property (nonatomic) BOOL userInteractionEnabled;
@property (nonatomic) BOOL translatesAutoresizingMaskIntoConstraints;
@property (nonatomic) BOOL hidden;
@property (nonatomic) NSInteger tag;
@property (nonatomic, copy) NSString *accessibilityIdentifier;
@property (nonatomic, copy) NSString *accessibilityLabel;
@property (nonatomic) BOOL isAccessibilityElement;
@property (nonatomic) CGFloat alpha;
// V3.2.5：折叠区收起时高度被强制为 0，必须裁剪，否则残留内容会溢出到下一行
@property (nonatomic) BOOL clipsToBounds;
- (UIView *)viewWithTag:(NSInteger)tag;
/// V3.2.8：整行可点展开要判断「这个触摸的落点是不是开关自己」
- (BOOL)isDescendantOfView:(UIView *)view;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
- (void)sizeToFit;
- (void)setNeedsLayout;
- (void)layoutIfNeeded;
- (UIView *)hitTest:(CGPoint)point withEvent:(id)event;
- (CGPoint)convertPoint:(CGPoint)point toView:(UIView *)view;
- (CGPoint)convertPoint:(CGPoint)point fromView:(UIView *)view;
// Auto Layout：锚点与布局参考线
@property (nonatomic, readonly) UILayoutGuide *layoutMarginsGuide;
@property (nonatomic, readonly) UILayoutGuide *safeAreaLayoutGuide;
@property (nonatomic) UIEdgeInsets layoutMargins;
@property (nonatomic, readonly) NSLayoutXAxisAnchor *leadingAnchor;
@property (nonatomic, readonly) NSLayoutXAxisAnchor *trailingAnchor;
@property (nonatomic, readonly) NSLayoutXAxisAnchor *centerXAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *topAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *bottomAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *centerYAnchor;
@property (nonatomic, readonly) NSLayoutDimension *widthAnchor;
@property (nonatomic, readonly) NSLayoutDimension *heightAnchor;
@end

@interface UILayoutGuide : NSObject
@property (nonatomic, readonly) NSLayoutXAxisAnchor *leadingAnchor;
@property (nonatomic, readonly) NSLayoutXAxisAnchor *trailingAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *topAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *bottomAnchor;
@property (nonatomic, readonly) NSLayoutYAxisAnchor *centerYAnchor;
@property (nonatomic, readonly) NSLayoutXAxisAnchor *centerXAnchor;
@property (nonatomic, readonly) NSLayoutDimension *widthAnchor;
@property (nonatomic, readonly) NSLayoutDimension *heightAnchor;
@end

@interface NSLayoutAnchor<AnchorType> : NSObject
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor;
- (NSLayoutConstraint *)constraintEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c;
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c;
- (NSLayoutConstraint *)constraintLessThanOrEqualToAnchor:(NSLayoutAnchor *)anchor constant:(CGFloat)c;
@end

@interface NSLayoutXAxisAnchor : NSLayoutAnchor
@end

@interface NSLayoutYAxisAnchor : NSLayoutAnchor
@end

@interface NSLayoutDimension : NSLayoutAnchor
- (NSLayoutConstraint *)constraintEqualToConstant:(CGFloat)c;
- (NSLayoutConstraint *)constraintGreaterThanOrEqualToConstant:(CGFloat)c;
- (NSLayoutConstraint *)constraintLessThanOrEqualToConstant:(CGFloat)c;
@end

/* V3.2.5：动态间距需要改 constant / 开关 active / 降优先级。
   属性补在 269 行那个唯一的 NSLayoutConstraint 定义里，此处只放类型与常量。 */
typedef float UILayoutPriority;
static const UILayoutPriority UILayoutPriorityDefaultHigh = 750;
static const UILayoutPriority UILayoutPriorityRequired    = 1000;

@interface UILabel : UIView
@property (nonatomic, assign) UILineBreakMode lineBreakMode;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) UIColor *textColor;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) NSTextAlignment textAlignment;
/// V3.2.8：徽章不想被标题挤扁，要把横向压缩抗性提到 Required
- (void)setContentCompressionResistancePriority:(UILayoutPriority)priority
                                        forAxis:(UILayoutConstraintAxis)axis;
@end

@interface UIControl : UIView
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events;
@end

@interface UIButton : UIControl
+ (instancetype)buttonWithType:(UIButtonType)type;
@property (nonatomic, readonly) UILabel *titleLabel;
- (void)setTitle:(NSString *)title forState:(unsigned)state;
- (void)setTitleColor:(UIColor *)color forState:(unsigned)state;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events;
@end

@interface UISwitch : UIControl
// V3.2.21：一键省电开关需要自定义开启色（默认绿太像「已启用危险功能」）。
@property (nonatomic, strong) UIColor *onTintColor;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic, assign, getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end

@interface UIBarButtonItem : NSObject
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)item
                                    target:(id)target
                                    action:(SEL)action;
- (instancetype)initWithTitle:(NSString *)title
                        style:(UIBarButtonItemStyle)style
                       target:(id)target
                                    action:(SEL)action;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) NSInteger tag;
@property (nonatomic, copy) NSString *accessibilityIdentifier;
@end

@interface UINavigationItem : NSObject
@property (nonatomic, strong) UIView *titleView;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *prompt;
@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *leftBarButtonItems;
@property (nonatomic, copy) NSArray<UIBarButtonItem *> *rightBarButtonItems;
@end

@interface UIViewController : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, readonly) UINavigationItem *navigationItem;
@property (nonatomic, readonly) UINavigationController *navigationController;
@property (nonatomic, readonly) UIPopoverPresentationController *popoverPresentationController;
@property (nonatomic, readonly) UIViewController *presentedViewController;
@property (nonatomic, readonly) UIViewController *presentingViewController;
@property (nonatomic, readonly) BOOL isBeingDismissed;
@property (nonatomic, assign) UIModalPresentationStyle modalPresentationStyle;
@property (nonatomic, assign) BOOL definesPresentationContext;
@property (nonatomic, assign) BOOL hidesBottomBarWhenPushed;
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion;
@end

@interface UINavigationController : UIViewController
- (instancetype)initWithRootViewController:(UIViewController *)root;
- (void)pushViewController:(UIViewController *)vc animated:(BOOL)animated;
- (nullable UIViewController *)popViewControllerAnimated:(BOOL)animated;
@property (nonatomic, readonly) NSArray<UIViewController *> *viewControllers;
@end

@interface UITableViewCell : UIView
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) CGFloat sectionHeaderTopPadding;
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid;
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic) UITableViewCellAccessoryType accessoryType;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) UILabel *textLabel;
@property (nonatomic, readonly) UILabel *detailTextLabel;
@property (nonatomic, readonly) UIImageView *imageView;
@property (nonatomic, readonly) NSString *title;
- (void)prepareForReuse;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
@end

@interface UIImageView : UIView
@property (nonatomic, strong) UIImage *image;
@end

@interface UIImage : NSObject
+ (UIImage *)systemImageNamed:(NSString *)name;
@end

@protocol UITableViewDataSource <NSObject>
- (NSInteger)tableView:(id)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(id)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (NSInteger)numberOfSectionsInTableView:(id)tableView;
@end

@protocol UITableViewDelegate <NSObject>
@optional
- (void)tableView:(id)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(id)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface UITableView : UIView
@property (nonatomic, assign) UITableViewCellSeparatorStyle separatorStyle;
@property (nonatomic, assign) UIEdgeInsets contentInset;
@property (nonatomic, assign) CGFloat sectionHeaderTopPadding;
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style;
@property (nonatomic, weak) id<UITableViewDataSource> dataSource;
@property (nonatomic, weak) id<UITableViewDelegate> delegate;
@property (nonatomic, strong) UIView *tableHeaderView;
@property (nonatomic, strong) UIView *tableFooterView;
- (void)registerClass:(Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (id)dequeueReusableCellWithIdentifier:(NSString *)identifier;
- (void)reloadData;
- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)paths
              withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadSections:(id)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)cell;
- (NSIndexPath *)indexPathForSelectedRow;
- (NSArray<NSIndexPath *> *)indexPathsForVisibleRows;
@property (nonatomic, assign, readonly) BOOL dragging;
@property (nonatomic, assign, readonly) BOOL decelerating;
- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath
              atScrollPosition:(UITableViewScrollPosition)position
                      animated:(BOOL)animated;
- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)beginUpdates;
- (void)endUpdates;
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic) CGFloat estimatedRowHeight;
@property (nonatomic) UIEdgeInsets separatorInset;
@end

@interface UICollectionViewLayoutAttributes : NSObject <NSCopying>
@end

// V3.2.21：cell 尺寸 hook 需要 UICollectionView（取 bounds 算等分宽度）。
// 桩里只补本工程实际用到的成员，不追求完整复刻——桩越薄，越不容易掩盖真问题。
@interface UICollectionView : UIView
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly, strong) id collectionViewLayout;
- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(id)layout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface UICollectionViewFlowLayout : NSObject
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect;
@end

@interface UIStackView : UIView
- (instancetype)initWithArrangedSubviews:(NSArray<UIView *> *)views;
@property (nonatomic) UILayoutConstraintAxis axis;
@property (nonatomic) CGFloat spacing;
@property (nonatomic) UIStackViewDistribution distribution;
/// V3.2.12：档位区三档按钮横排，动态增删子视图
- (void)addArrangedSubview:(UIView *)view;
@property (nonatomic, readonly, copy) NSArray<UIView *> *arrangedSubviews;
@end

@interface NSLayoutConstraint : NSObject
// V3.2.5：动态间距需要改 constant、开关 active、降优先级
@property (nonatomic) CGFloat constant;
@property (nonatomic, getter=isActive) BOOL active;
@property (nonatomic) UILayoutPriority priority;
+ (NSArray<NSLayoutConstraint *> *)constraintsWithVisualFormat:(NSString *)format
                                                      options:(unsigned)opts
                                                      metrics:(NSDictionary *)metrics
                                                        views:(NSDictionary *)views;
+ (void)activateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
+ (void)deactivateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
@end
NSDictionary *NSDictionaryOfVariableBindings_helper(void);
#define NSDictionaryOfVariableBindings(...) (NSDictionaryOfVariableBindings_helper())

// V3.2.8：整行可点展开用到了手势代理 —— 桩原来没有这个协议，导致
// 「cannot find protocol declaration for 'UIGestureRecognizerDelegate'」。
// 代理方法签名里用到了 UITouch，而桩里没有这个类，会报「expected a type」——
// 所以先给它一个最小声明（真实 SDK 里它有大量属性，我们只用到 view）。
// 注意：这是**语法桩**，只保证「写得出来」，不保证语义正确。
@class UITouch, UIView;
@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch;
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g;
@end

/// V3.2.8：整行可点展开要判断触摸落在哪个视图上
@interface UITouch : NSObject
@property (nonatomic, readonly, nullable) UIView *view;
- (CGPoint)locationInView:(nullable UIView *)view;
@end

@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(id)target action:(SEL)action;
@property (nonatomic) UIGestureRecognizerState state;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic, weak, nullable) id<UIGestureRecognizerDelegate> delegate;
/// 真实 SDK 存在：让 another 手势先识别失败后，本手势才触发（双击优先于单击）
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other;
/// V3.2.8：整行点击要判断「点在开关上了没」，需要坐标转换
- (CGPoint)locationInView:(UIView *)view;
@end

@interface UIPanGestureRecognizer : UIGestureRecognizer
- (CGPoint)locationInView:(UIView *)view;
@end

@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSTimeInterval minimumPressDuration;
@end

@interface UIAlertAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title
                          style:(UIAlertActionStyle)style
                        handler:(void (^)(UIAlertAction *action))handler;
@end

@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(NSString *)title
                                message:(NSString *)message
                         preferredStyle:(UIAlertControllerStyle)style;
- (void)addAction:(UIAlertAction *)action;
@end

// 系统分享面板：把沙盒里的取证文件（freeze_*.txt / 快照 JSON）交出去
@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)activityItems
                applicationActivities:(NSArray *)applicationActivities;
@end

// 冻屏快照全文展示
@interface UITextView : UIView
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, assign) UIColor *textColor;
@property (nonatomic, assign) UIColor *backgroundColor;
@property (nonatomic) BOOL editable;
@property (nonatomic, readonly) UIScrollView *scrollViewForStub;
@end

@interface UIScreen : NSObject
@property (class, readonly, strong) UIScreen *mainScreen;
@property (nonatomic, readonly) CGRect bounds;
@end

@interface UIWindow : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithWindowScene:(UIWindowScene *)scene;
@property (nonatomic, strong) UIWindowScene *windowScene;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic) UIWindowLevel windowLevel;
@property (nonatomic, readonly) BOOL isKeyWindow;
- (void)makeKeyAndVisible;
@end

typedef NS_ENUM(NSInteger, UISceneActivationState) {
    UISceneActivationStateUnattached = -1,
    UISceneActivationStateForegroundActive = 0,
    UISceneActivationStateForegroundInactive = 1,
    UISceneActivationStateBackground = 2
};

extern NSNotificationName const UISceneDidActivateNotification;

@interface UIScene : NSObject
@property (nonatomic, readonly) UISceneActivationState activationState;
- (void)sceneDidBecomeActive:(UIScene *)scene;
@end

// 注意：真实 UIKit 中 UIWindowScene 继承自 UIScene，activationState 定义在 UIScene 上。
// 此前的桩把 UIWindowScene 写成 : NSObject，导致任何用 UIWindowScene.activationState
// 的代码在桩上编译不过（误报为代码错误）。此处按真实继承关系建模。
@interface UIWindowScene : UIScene
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@end

@interface UIApplication : NSObject
@property (class, readonly, strong) UIApplication *sharedApplication;
@property (nonatomic, readonly) UIWindow *keyWindow;
@property (nonatomic, readonly) NSSet<UIScene *> *connectedScenes;
@property (nonatomic, readonly) NSArray<UIWindow *> *windows;
@end

@interface UIView (Animation)
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations;
+ (void)animateWithDuration:(NSTimeInterval)duration
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion;
+ (void)performWithoutAnimation:(void (^)(void))actionsWithoutAnimation;
@end

@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@end

/// 触觉反馈（iOS 10+，真机 UIKit 提供）。用于抓栈完成后的即时反馈。
typedef NS_ENUM(NSInteger, UIImpactFeedbackStyle) {
    UIImpactFeedbackStyleLight = 0,
    UIImpactFeedbackStyleMedium = 1,
    UIImpactFeedbackStyleHeavy = 2
};

@interface UIImpactFeedbackGenerator : NSObject
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)prepare;
- (void)impactOccurred;
@end

@interface UIPopoverPresentationController : NSObject
@property (nonatomic, weak) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;
@property (nonatomic) UIPopoverArrowDirection permittedArrowDirections;
@property (nonatomic, weak) UIBarButtonItem *barButtonItem;
@end

extern NSNotificationName const UIApplicationDidBecomeActiveNotification;
extern NSNotificationName const UIApplicationWillEnterForegroundNotification;
extern NSNotificationName const UIApplicationWillResignActiveNotification;
extern NSNotificationName const UIApplicationDidEnterBackgroundNotification;
extern NSNotificationName const UIApplicationDidFinishLaunchingNotification;

#endif


// ── V3.3.0：DYYY 式渐变流光标题所需（QuartzCore 桩，只覆盖用到的 API）──
#ifndef HUGE_VALF
#define HUGE_VALF (__builtin_huge_valf())
#endif

@interface CABasicAnimation : NSObject
+ (instancetype)animationWithKeyPath:(NSString *)path;
@property (nonatomic, strong) id toValue;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) BOOL autoreverses;
@property (nonatomic, assign) float repeatCount;
- (void)addAnimation:(id)anim forKey:(NSString *)key;
@end

/* V3.3.10：下载接口 URL 输入框 */
typedef NS_ENUM(NSInteger, UITextFieldViewMode) {
    UITextFieldViewModeNever = 0,
    UITextFieldViewModeWhileEditing = 1,
};
@interface UITextField : UIView
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSString *placeholder;
@property (nonatomic, assign) UITextFieldViewMode clearButtonMode;
@end
@interface UIAlertController (TextField)
- (void)addTextFieldWithConfigurationHandler:(void(^)(UITextField *tf))handler;
@property (nonatomic, readonly, copy) NSArray<UITextField *> *textFields;
@end
typedef NSInteger UIProgressViewStyle;
static const UIProgressViewStyle UIProgressViewStyleDefault = 0;
static const UIProgressViewStyle UIProgressViewStyleBar = 1;
@interface UIProgressView : UIView
- (instancetype)initWithProgressViewStyle:(UIProgressViewStyle)style;
@property (nonatomic, assign) float progress;
@end
@protocol UISearchBarDelegate <NSObject>
@optional
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText;
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
@end
@interface UISearchBar : UIView
@property (nonatomic, copy) NSString *placeholder;
@property (nonatomic, weak) id<UISearchBarDelegate> delegate;
@property (nonatomic, assign) BOOL showsCancelButton;
@property (nonatomic, copy) NSString *text;
- (void)resignFirstResponder;
@end

// DLP 补：日志查看器的 K/D/全部三档过滤
@interface UISegmentedControl : UIView
- (instancetype)initWithItems:(NSArray *)items;
@property (nonatomic) NSInteger selectedSegmentIndex;
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(NSUInteger)events;
@end
