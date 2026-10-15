//
//  mach.h — 语法体检桩（仅用于 Linux clang -fsyntax-only，不参与真机编译）
//
//  覆盖 PerfMainThreadWatchdog 用到的 mach 只读接口：
//  task_threads / thread_get_state / vm_read_overwrite / vm_deallocate
//

#ifndef PDP_STUB_MACH_H
#define PDP_STUB_MACH_H

#include <stddef.h>
#include <stdint.h>
#include <pthread.h>

typedef unsigned int mach_port_t;
typedef unsigned int vm_map_t;
typedef mach_port_t  task_t;
typedef mach_port_t  thread_act_t;
typedef thread_act_t thread_t;
typedef thread_t    *thread_act_array_t;
typedef unsigned int mach_msg_type_number_t;
#ifndef PDP_STUB_KERN_RETURN_T
#define PDP_STUB_KERN_RETURN_T
typedef int          kern_return_t;
#endif
typedef unsigned long vm_address_t;
typedef unsigned long vm_size_t;
typedef int           thread_state_flavor_t;
typedef unsigned int *thread_state_t;

#define KERN_SUCCESS 0

/* mach port 空值与 deallocate：归还 task_threads / mach_thread_self 交出来的 send right */
#define MACH_PORT_NULL ((mach_port_t)0)
extern kern_return_t mach_port_deallocate(task_t task, mach_port_t name);

/* thread_get_state 的 flavor（arm64） */
#define ARM_THREAD_STATE64 6
#define ARM_THREAD_STATE64_COUNT ((mach_msg_type_number_t)(sizeof(uint64_t) * 68))

/*
 * arm64 线程状态。字段名**刻意加了 _raw 后缀**，与真机 SDK 对齐：
 *
 * 真机 SDK（chained fixups + PAC）在 arm64e 下把 pc / fp / lr / sp 换成受指针认证保护的
 * 表示，`_STRUCT_ARM_THREAD_STATE64` 上**不存在** __pc / __fp 这些成员名 —— 只能通过
 * <mach/arm/thread_status.h> 的官方访问器读取：
 *
 *     arm_thread_state64_get_pc(ts)   → 剥掉 PAC 签名位的 data pointer
 *     arm_thread_state64_get_fp(ts)
 *
 * 本桩早期图省事直接留了裸的 __pc / __fp，于是「本地体检全绿、CI 真机编译挂」：
 * V3.2.9 第五次 CI 构建 arm64 编过、arm64e 报
 *     error: no member named '__pc' in 'struct __darwin_arm_thread_state64'
 * 加 _raw 后缀后，任何直接点裸字段的写法在本地就会立刻失败 —— 与真机同款报错，
 * 不再需要等 CI。
 */
typedef struct {
    uint64_t __x[29];
    uint64_t __fp_raw;
    uint64_t __lr_raw;
    uint64_t __sp_raw;
    uint64_t __pc_raw;
    uint32_t __cpsr;
    uint32_t __pad;
} _STRUCT_ARM_THREAD_STATE64;

/* 官方访问器（真机在 <mach/arm/thread_status.h> 的 __arm64__ 分支里定义） */
#define arm_thread_state64_get_pc(ts) ((uint64_t)((ts).__pc_raw))
#define arm_thread_state64_get_fp(ts) ((uint64_t)((ts).__fp_raw))
#define arm_thread_state64_get_lr(ts) ((uint64_t)((ts).__lr_raw))
#define arm_thread_state64_get_sp(ts) ((uint64_t)((ts).__sp_raw))

extern mach_port_t mach_task_self(void);
extern thread_t    mach_thread_self(void);

extern kern_return_t task_threads(task_t target_task,
                                  thread_act_array_t *act_list,
                                  mach_msg_type_number_t *act_list_cnt);

extern kern_return_t thread_get_state(thread_act_t target_act,
                                      thread_state_flavor_t flavor,
                                      thread_state_t old_state,
                                      mach_msg_type_number_t *old_state_cnt);

extern kern_return_t vm_read_overwrite(vm_map_t target_task,
                                       vm_address_t address,
                                       vm_size_t size,
                                       vm_address_t data,
                                       vm_size_t *out_size);

extern kern_return_t vm_deallocate(vm_map_t target_task,
                                   vm_address_t address,
                                   vm_size_t size);

extern char *mach_error_string(kern_return_t kr);

/* ------------------------------------------------------------------
 * task_info 家族（V3.1.2 补桩）
 * 用途：PDPStats 读取进程常驻内存做现场读数（phys_footprint / resident_size）。
 *
 * ⚠️ 注意：本桩的字段布局是**简化版**，只为让 clang 通过语法与类型检查，
 *    **不代表真机的真实结构偏移**。真机定义见 <mach/task_info.h>：
 *      task_vm_info_data_t 是数十个字段的大结构，phys_footprint 位于其中部。
 *    因此本桩**只能**校验「符号是否存在、类型是否匹配」，
 *    无法校验字段偏移正确性 —— 那需要真机运行验证（见 docs/24 的验证清单）。
 * ------------------------------------------------------------------ */
typedef unsigned int natural_t;
typedef natural_t   *task_info_t;

/* MACH_TASK_BASIC_INFO：只取 resident_size */
#define MACH_TASK_BASIC_INFO 20
typedef struct {
    vm_size_t virtual_size;
    vm_size_t resident_size;
    vm_size_t resident_size_max;
} mach_task_basic_info_data_t;
#define MACH_TASK_BASIC_INFO_COUNT \
    ((mach_msg_type_number_t)(sizeof(mach_task_basic_info_data_t) / sizeof(natural_t)))

/* TASK_VM_INFO：工程只读 phys_footprint 一个字段（桩布局，非真机偏移） */
#define TASK_VM_INFO 22
typedef struct {
    unsigned long long virtual_size;    /* 桩占位 */
    unsigned long long phys_footprint;  /* 工程真正读取的字段 */
} task_vm_info_data_t;
#define TASK_VM_INFO_COUNT \
    ((mach_msg_type_number_t)(sizeof(task_vm_info_data_t) / sizeof(natural_t)))

extern kern_return_t task_info(task_t target_task,
                               int flavor,
                               task_info_t task_info_out,
                               mach_msg_type_number_t *task_info_out_cnt);

/* iOS 私有但公开可用的 mach ↔ pthread 转换 */
extern pthread_t pthread_from_mach_thread_np(thread_t th);
extern int pthread_getname_np(pthread_t th, char *buf, size_t len);

/* ---- V3.2.4 CPU 现场取证：THREAD_BASIC_INFO ---- */
/* cpu_usage 为 scaled 整数，TH_USAGE_SCALE = 1000 表示 100%（相对**一个核**）。 */
#define THREAD_BASIC_INFO 3
#define TH_USAGE_SCALE 1000
typedef int      integer_t;
typedef int      policy_t;
typedef natural_t *thread_info_t;   /* 真机为 natural_t *，与 task_info_t 同族 */
/* 只补齐工程实际读取的字段布局；user_time/system_time 用两个 int 占位即可，
   工程不读它们（cpu_usage 才是唯一被消费的字段）。 */
typedef struct {
    int             user_time_seconds;
    int             user_time_microseconds;
    int             system_time_seconds;
    int             system_time_microseconds;
    integer_t       cpu_usage;
    policy_t        policy;
    integer_t       run_state;
    integer_t       flags;
    integer_t       suspend_count;
    integer_t       sleep_time;
} thread_basic_info_data_t;
#define THREAD_BASIC_INFO_COUNT \
    ((mach_msg_type_number_t)(sizeof(thread_basic_info_data_t) / sizeof(natural_t)))

extern kern_return_t thread_info(thread_act_t target_act,
                                 int flavor,
                                 thread_info_t thread_info_out,
                                 mach_msg_type_number_t *thread_info_out_cnt);

#endif /* PDP_STUB_MACH_H */
