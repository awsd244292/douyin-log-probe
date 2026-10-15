//
//  DLPRouter.h
//  DouyinLogProbe
//
//  通用运行时 hook 基础设施（照抄 CrashLogger 手写 Runtime 风格 + douyin-doctor 规范）：
//   - 只用 method_setImplementation，无 MSHook/fishhook/Logos
//   - 类名全部 NSClassFromString 动态解析，类/方法不存在 → 静默跳过（宿主版本漂移不崩）
//   - 幂等：同 slot 重复 install 不会叠加
//   - 卸载：比对当前 IMP 仍是 hook 才用保存的原 IMP 还原（CrashLogger 同款幂等保护）
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/// 一个 hook 点的状态槽。每个 hook 点在模块里声明一个 static 变量。
typedef struct {
    Class cls;      // 目标类（install 时解析）
    SEL sel;        // 目标 selector
    IMP orig;       // 保存的原 IMP
    IMP hook;       // 安装的 hook IMP（用于卸载时比对）
    BOOL installed; // 是否已安装
    BOOL isClassMethod; // YES 则 hook 元类（+方法）
} DLPHookSlot;

/// 安装 hook。className 不存在 / 方法不存在 / 已安装 → 返回 NO，不做任何事。
/// 成功返回 YES，slot->orig 为原 IMP。
BOOL DLPHookInstall(DLPHookSlot *slot, const char *className, SEL sel, IMP newIMP, BOOL isClassMethod);

/// 卸载 hook：仅当 slot 已安装且当前 IMP 仍是 hook 时才还原。
/// 还原后 slot->installed = NO。
void DLPHookRemove(DLPHookSlot *slot);
