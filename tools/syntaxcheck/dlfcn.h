//
//  dlfcn.h — 语法体检桩（Linux glibc 需 _GNU_SOURCE 才声明 dladdr，这里直接给出）
//
#ifndef PDP_STUB_DLFCN_H
#define PDP_STUB_DLFCN_H

typedef struct dl_info {
    const char *dli_fname;   /* 镜像路径 */
    void       *dli_fbase;   /* 镜像基址 */
    const char *dli_sname;   /* 最近符号名（strip 后为 NULL） */
    void       *dli_saddr;   /* 最近符号地址 */
} Dl_info;

extern int dladdr(const void *addr, Dl_info *info);

/* dlsym / RTLD_* —— PDPPlaybackProbe 用它权威地取 AVFoundation 通知名常量
   （比字面量兜底可靠，且取不到时能如实报「符号未找到」）。
   真机 dlfcn.h 里 RTLD_DEFAULT 在 iOS 上为 ((void *)-2)。 */
#define RTLD_DEFAULT  ((void *)0)
#define RTLD_NEXT     ((void *)-1)
#define RTLD_NOW      0x2
#define RTLD_LAZY     0x1
#define RTLD_NOLOAD   0x4

extern void *dlsym(void *handle, const char *symbol);
extern void *dlopen(const char *path, int mode);
extern int   dlclose(void *handle);

#endif
