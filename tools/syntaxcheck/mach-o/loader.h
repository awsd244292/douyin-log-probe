//
//  mach-o/loader.h — 语法体检桩
//
//  V3.2.12：符号重绑定模块（patch/pdp_fishhook.c）需要解析 Mach-O 头部。
//  这里只给出该模块实际用到的结构体与常量，够 clang 做语法与类型体检即可。
//  ⚠️ 真机编译走 iPhoneOS SDK 里的真实头文件，本桩不参与。
//
#ifndef PDP_STUB_MACH_O_LOADER_H
#define PDP_STUB_MACH_O_LOADER_H

#include <stdint.h>

/* ---- 魔数 ---- */
#define MH_MAGIC_64   0xfeedfacf
#define MH_CIGAM_64   0xcffaedfe

/* ---- load command 类型 ---- */
#define LC_SEGMENT_64 0x19
#define LC_SYMTAB     0x02
#define LC_DYSYMTAB   0x0b

/* ---- 段名 ---- */
#define SEG_LINKEDIT  "__LINKEDIT"

/* ---- 间接符号表的特殊下标 ---- */
#define INDIRECT_SYMBOL_LOCAL 0x80000000
#define INDIRECT_SYMBOL_ABS   0x40000000

struct mach_header {
    uint32_t magic;
    int32_t  cputype;
    int32_t  cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
};

struct mach_header_64 {
    uint32_t magic;
    int32_t  cputype;
    int32_t  cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
    uint32_t reserved;
};

struct load_command {
    uint32_t cmd;
    uint32_t cmdsize;
};

struct segment_command_64 {
    uint32_t cmd;
    uint32_t cmdsize;
    char     segname[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    int32_t  maxprot;
    int32_t  initprot;
    uint32_t nsects;
    uint32_t flags;
};

struct section_64 {
    char     sectname[16];
    char     segname[16];
    uint64_t addr;
    uint64_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
    uint32_t reserved1;
    uint32_t reserved2;
    uint32_t reserved3;
};

struct symtab_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t symoff;
    uint32_t nsyms;
    uint32_t stroff;
    uint32_t strsize;
};

struct dysymtab_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t ilocalsym;
    uint32_t nlocalsym;
    uint32_t iextdefsym;
    uint32_t nextdefsym;
    uint32_t iundefsym;
    uint32_t nundefsym;
    uint32_t tocoff;
    uint32_t ntoc;
    uint32_t modtaboff;
    uint32_t nmodtab;
    uint32_t extrefsymoff;
    uint32_t nextrefsyms;
    uint32_t indirectsymoff;   /* 间接符号表在 __LINKEDIT 里的偏移 */
    uint32_t nindirectsyms;
    uint32_t extreloff;
    uint32_t nextrel;
    uint32_t locreloff;
    uint32_t nlocrel;
};

#endif
