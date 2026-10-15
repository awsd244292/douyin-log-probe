//
//  mach-o/nlist.h — 语法体检桩
//
//  V3.2.12：符号重绑定模块需要读符号表项。
//
#ifndef PDP_STUB_MACH_O_NLIST_H
#define PDP_STUB_MACH_O_NLIST_H

#include <stdint.h>

struct nlist_64 {
    union {
        uint32_t n_strx;   /* 字符串表索引 */
    } n_un;
    uint8_t  n_type;
    uint8_t  n_sect;
    uint16_t n_desc;
    uint64_t n_value;
};

#endif
