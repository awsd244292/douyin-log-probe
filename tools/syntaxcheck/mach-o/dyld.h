//
//  mach-o/dyld.h — 语法体检桩
//
//  只提供本插件用到的只读查询接口：镜像枚举。
//  ⚠️ 只做语法体检，不参与真机编译；真机走 iPhoneOS SDK 里的真实头文件。
//
#ifndef PDP_STUB_MACH_O_DYLD_H
#define PDP_STUB_MACH_O_DYLD_H

#include <stdint.h>

/* 返回已加载镜像总数 */
extern uint32_t _dyld_image_count(void);

/* 返回第 index 个镜像的路径（可能为 NULL，例如 dyld 共享缓存内的镜像） */
extern const char *_dyld_get_image_name(uint32_t image_index);

/* 返回第 index 个镜像的 mach header 指针（此桩不展开结构体，仅声明） */
extern const void *_dyld_get_image_header(uint32_t image_index);

/* 返回第 index 个镜像的滑动偏移 */
extern intptr_t _dyld_get_image_vmaddr_slide(uint32_t image_index);

#endif
