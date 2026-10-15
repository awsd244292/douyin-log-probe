//
//  mach/vm_map.h — 语法体检桩
//
//  V3.2.12：符号重绑定模块（patch/pdp_fishhook.c）需要临时放开页写权限。
//  这里补出 vm_protect 与内存保护常量。
//
//  ⚠️⚠️ 桩与真机的一处**已知不一致**，踩过一次坑，记录在此：
//      真实 SDK 的 <mach/vm_map.h> **不**包含 <mach/mach.h>，
//      因此 mach_task_self() 在那个头里是拿不到的。
//      但本桩因为需要 vm_map_t / kern_return_t 这些基础类型，
//      #include 了 <mach/mach.h>，于是**顺手把 mach_task_self() 带了出来** ——
//      结果 pdp_fishhook.c 漏引 <mach/mach.h> 时本地全绿，CI 真机编译才报
//      「call to undeclared function 'mach_task_self'」。
//
//      修法不是拆掉这个 include（那些类型确实需要），而是在
//      tools/check_stub_include_parity.py 里加了一条**反向断言**：
//      凡是用到 mach_task_self() 的源文件，必须自己显式 include <mach/mach.h>。
//      这样桩的「顺手」不会再掩盖缺失。
//
#ifndef PDP_STUB_MACH_VM_MAP_H
#define PDP_STUB_MACH_VM_MAP_H
#include <mach/mach.h>

typedef int vm_prot_t;
typedef int boolean_t;

#define VM_PROT_NONE    0x00
#define VM_PROT_READ    0x01
#define VM_PROT_WRITE   0x02
#define VM_PROT_EXECUTE 0x04
/* 写时复制：改写只读页时让内核复制一份，不污染共享共享页 */
#define VM_PROT_COPY    0x10

extern kern_return_t vm_protect(vm_map_t target_task,
                                vm_address_t address,
                                vm_size_t size,
                                boolean_t set_maximum,
                                vm_prot_t new_protection);

/* 页大小。真机由 <mach/vm_page_size.h> 提供。
   iOS 上 arm64 恒为 16KB，但也存在 4KB 的旧设备/模拟器，
   代码里只用来做「页对齐」，取哪个值都不影响正确性 —— 只要 >= 真实页大小即可。 */
#ifndef PAGE_SIZE
#define PAGE_SIZE 16384
#endif

#endif
