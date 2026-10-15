//
//  mach_time.h — 语法体检桩（仅用于 Linux clang -fsyntax-only，不参与真机编译）
//
//  覆盖 PerfMainThreadWatchdog 的单调时钟接口（V3.0.9）：
//  mach_absolute_time / mach_timebase_info
//

#ifndef PDP_STUB_MACH_TIME_H
#define PDP_STUB_MACH_TIME_H

#include <stdint.h>

/* kern_return_t 由 mach.h 定义，但本桩可能被单独 include（PDPAuditTimeline 只用时钟），
   因此这里用独立宏做一次幂等声明，避免两处都定义时重复 typedef。 */
#ifndef PDP_STUB_KERN_RETURN_T
#define PDP_STUB_KERN_RETURN_T
typedef int kern_return_t;
#endif

typedef struct {
    uint32_t numer;
    uint32_t denom;
} mach_timebase_info_data_t;

typedef mach_timebase_info_data_t *mach_timebase_info_t;

#ifdef __cplusplus
extern "C" {
#endif

uint64_t mach_absolute_time(void);
kern_return_t mach_timebase_info(mach_timebase_info_t info);

#ifdef __cplusplus
}
#endif

#endif /* PDP_STUB_MACH_TIME_H */
