//
//  os/log.h — 语法体检桩
//
//  V3.2.15：PDPLogTap 补上 os_log 拦截，需要 os_log_t / os_log_type_t
//  与 OS_LOG_DEFAULT 这些基础类型。
//
//  ⚠️ 真机编译走 iPhoneOS SDK 里的真实 <os/log.h>，本桩不参与。
//     这里**只**给出拦截 os_log 所需的类型与常量 ——
//     真正产生 os_log 调用的宏（os_log / os_log_error / ...）本工程不用，
//     因为它们是编译期宏，展开后才是对 _os_log_impl 的调用，
//     而我们要 hook 的正是展开后那一层。
//
#ifndef PDP_STUB_OS_LOG_H
#define PDP_STUB_OS_LOG_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* os_log_t 在真机上是 struct os_log_s *（不透明句柄）。 */
typedef struct os_log_s *os_log_t;
typedef uintptr_t os_log_type_t;

/* 五个标准等级。真机在 <os/log.h> 里是枚举值；
   本工程只**转发**，不比较具体取值，故这里给互不相同的整数即可。 */
#define OS_LOG_TYPE_DEFAULT 0x00
#define OS_LOG_TYPE_INFO    0x01
#define OS_LOG_TYPE_DEBUG   0x02
#define OS_LOG_TYPE_ERROR   0x10
#define OS_LOG_TYPE_FAULT   0x11

/* 默认日志对象（subsystem/category 均为默认值）。 */
extern os_log_t OS_LOG_DEFAULT;

/*
 * 四个底层入口（真实的写入点，会被 fishhook 拦截）。
 *
 * 签名来源：solarana.dev《Intercepting os_log》对 libsystem_trace 的实测，
 *          与 Apple 开源 libtrace 的 _os_log_impl 声明一致。
 *
 * 参数说明（决定了为什么可以零解码转发）：
 *   dso    当前动态共享对象（用于归属判定）
 *   log    日志对象（决定 subsystem / category）
 *   type   等级
 *   format **纯 C 字符串**的格式串（注意：不是 NSString）
 *   buf    已按 format 编码好的二进制参数缓冲
 *   size   buf 的字节数
 *
 * ★ buf 是「预编码」的：调用点在宏展开时就把参数编好了。
 *   所以拦截实现完全不需要解析它 —— 原样转发即可，
 *   这是 os_log 比 NSLog 更好处理的地方（NSLog 要面对 va_list）。
 */
extern void _os_log_impl(void *dso, os_log_t log, os_log_type_t type,
                         const char *format, uint8_t *buf, uint32_t size);
extern void _os_log_debug_impl(void *dso, os_log_t log, os_log_type_t type,
                               const char *format, uint8_t *buf, uint32_t size);
extern void _os_log_error_impl(void *dso, os_log_t log, os_log_type_t type,
                               const char *format, uint8_t *buf, uint32_t size);
extern void _os_log_fault_impl(void *dso, os_log_t log, os_log_type_t type,
                               const char *format, uint8_t *buf, uint32_t size);

#ifdef __cplusplus
}
#endif

#endif /* PDP_STUB_OS_LOG_H */
