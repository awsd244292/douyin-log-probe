// 语法检查用最小桩：Objective-C runtime
// 只声明 clang 在 ObjC 模式下尚未内置、而本工程实际用到的符号
// （Class / SEL / IMP / id / BOOL 由编译器内置，此处不重复定义）
#ifndef PDP_STUB_OBJC_RUNTIME_H
#define PDP_STUB_OBJC_RUNTIME_H

#include <stddef.h>
#include <stdlib.h>

// clang 内置：Class / SEL / id / Protocol
// 非内置、需在此补齐：BOOL / IMP
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO  ((BOOL)0)
typedef id (*IMP)(id, SEL, ...);

typedef struct objc_method *Method;
typedef struct objc_ivar *Ivar;
typedef struct objc_property *objc_property_t;

Class NSClassFromString(id name);
id objc_getClass(const char *name);
id NSStringFromSelector(SEL sel);
id NSStringFromClass(Class cls);
SEL NSSelectorFromString(id name);
Method class_getInstanceMethod(Class cls, SEL sel);
Method class_getClassMethod(Class cls, SEL sel);
Method *class_copyMethodList(Class cls, unsigned int *outCount);
SEL method_getName(Method m);
BOOL class_addMethod(Class cls, SEL name, IMP imp, const char *types);
// DLP 补：类名探针用 class_getImageName 取来源 image（真机 SDK 有）
const char *class_getImageName(Class cls);
IMP method_getImplementation(Method m);
IMP method_setImplementation(Method m, IMP imp);
const char *method_getTypeEncoding(Method m);
// DLP 补：参数签名校验用（真机 SDK 有）
unsigned int method_getNumberOfArguments(Method m);
void method_getArgumentType(Method m, unsigned int index, char *dst, size_t dst_len);
Class object_getClass(id obj);

// 属性元数据（V3.0 元属性清洗用）
typedef struct {
    const char *name;   // 属性名
    const char *value;  // 属性值
} objc_property_attribute_t;

objc_property_t *class_copyPropertyList(Class cls, unsigned int *outCount);
const char *property_getName(objc_property_t prop);
const char *property_getAttributes(objc_property_t prop);
// 注意：真机 SDK（iPhoneOS16.5）里该 API 返回 **void**，桩必须与真机一致，
// 否则会出现「桩上编译通过、真机编译失败」。调用方不要依赖它的返回值。
BOOL class_addProperty(Class cls, const char *name, const objc_property_attribute_t *attrs, unsigned int n);
void class_replaceProperty(Class cls, const char *name,
                           const objc_property_attribute_t *attrs,
                           unsigned int n);
Class *objc_copyClassList(unsigned int *outCount);
const char *class_getName(Class cls);
Class class_getSuperclass(Class cls);
/// V3.2.10：类名考古探针用它枚举全进程已加载类。
/// 传 NULL 返回总数；否则填充数组并返回实际写入个数。
int objc_getClassList(Class *buffer, int bufferCount);

// 关联对象
typedef unsigned long objc_AssociationPolicy;
#define OBJC_ASSOCIATION_ASSIGN 0
#define OBJC_ASSOCIATION_RETAIN_NONATOMIC 1
#define OBJC_ASSOCIATION_COPY_NONATOMIC 3
void objc_setAssociatedObject(id object, const void *key, id value, objc_AssociationPolicy policy);
id objc_getAssociatedObject(id object, const void *key);

// V3.2.7：宿主长按面板入口 —— 用 Block 当新 IMP 交换宿主的 dataArray。
// imp_implementationWithBlock 属于 <objc/runtime.h>；objc_msgSend 属于
// <objc/message.h>（见该桩文件），这里不再重复声明，避免与真机头文件结构不一致。
IMP imp_implementationWithBlock(id block);

#endif
