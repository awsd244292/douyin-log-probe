//
//  DLPRouter.m
//  DouyinLogProbe
//

#import "DLPRouter.h"

BOOL DLPHookInstall(DLPHookSlot *slot, const char *className, SEL sel, IMP newIMP, BOOL isClassMethod) {
    if (!slot || !className || !sel || !newIMP) { return NO; }
    if (slot->installed) { return YES; } // 幂等
    @try {
        Class cls = objc_getClass(className);
        if (!cls) { return NO; }
        if (isClassMethod) { cls = object_getClass(cls); if (!cls) { return NO; } }
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) { return NO; }
        IMP orig = method_getImplementation(m);
        if (!orig || orig == newIMP) { return NO; }
        method_setImplementation(m, newIMP);
        slot->cls = cls;
        slot->sel = sel;
        slot->orig = orig;
        slot->hook = newIMP;
        slot->installed = YES;
        slot->isClassMethod = isClassMethod;
        return YES;
    } @catch (NSException *e) {
        return NO;
    }
}

void DLPHookRemove(DLPHookSlot *slot) {
    if (!slot || !slot->installed) { return; }
    @try {
        Method m = class_getInstanceMethod(slot->cls, slot->sel);
        if (m) {
            // 幂等保护：当前仍是我们的 hook 才还原（CrashLogger 同款逻辑）
            if (method_getImplementation(m) == slot->hook) {
                method_setImplementation(m, slot->orig);
            }
        }
    } @catch (NSException *e) {
    }
    slot->installed = NO;
    slot->orig = NULL;
    slot->hook = NULL;
}

BOOL DLPHookInstallChecked(DLPHookSlot *slot, const char *className, SEL sel, IMP newIMP,
                           BOOL isClassMethod, char expectedArgType) {
    if (!slot || !className || !sel) { return NO; }
    @try {
        Class cls = objc_getClass(className);
        if (!cls) { return NO; }
        if (isClassMethod) { cls = object_getClass(cls); if (!cls) { return NO; } }
        Method m = class_getInstanceMethod(cls, sel);
        if (!m) { return NO; }
        // 必须恰好 3 个参数 (self, _cmd, arg)，且第 1 个实参类型匹配
        if (method_getNumberOfArguments(m) != 3) { return NO; }
        char buf[16] = {0};
        method_getArgumentType(m, 2, buf, sizeof(buf));
        if (buf[0] != expectedArgType) { return NO; }
    } @catch (NSException *e) {
        return NO;
    }
    return DLPHookInstall(slot, className, sel, newIMP, isClassMethod);
}
