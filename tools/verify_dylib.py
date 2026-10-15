#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_dylib.py —— 校验产出的 DouyinLogProbe.dylib 是真·iOS 动态库

不依赖 macOS / otool / Xcode，纯 Python 解析 Mach-O。
校验项：
  1. Mach-O 头：magic / CPU 类型 / 文件类型 = MH_DYLIB
  2. LC_ID_DYLIB：install_name
  3. LC_BUILD_VERSION：platform=iOS / minos / sdk
  4. LC_LOAD_DYLIB：依赖库清单
  5. __mod_init_func：构造函数数量（必须 ≥1，否则注入后不会自动装配）
  6. __objc_classlist：解析出全部 Objective-C 类名，核对 PDP* 模块是否齐全

用法：python3 tools/verify_dylib.py [dylib路径]
退出码：0 全通过，1 存在失败项
"""

import struct
import sys
import os

# Mach-O 常量
MH_MAGIC_64 = 0xFEEDFACF
MH_CIGAM_64 = 0xCFFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_SWAPPED = 0xBEBAFECA          # 小端读到的大端 fat
FAT_MAGIC_64 = 0xCAFEBABF
FAT_MAGIC_64_SWAPPED = 0xBFBAFECA
CPU_TYPE_ARM64 = 0x0100000C
CPU_TYPE_ARM64E = 0x01000002
CPU_SUBTYPE_ARM64E = 0x02
MH_DYLIB = 6

LC_SEGMENT_64 = 0x19
LC_ID_DYLIB = 0x0D
LC_LOAD_DYLIB = 0x0C
LC_BUILD_VERSION = 0x32
LC_VERSION_MIN_IPHONEOS = 0x25
# ⚠️ 带 LC_REQ_DYLD(0x80000000) 前缀，别写成裸 0x33 —— 裸值是 LC_DYLD_INFO_ONLY，
#    两者差一个 bit，写成裸值会静默匹配不到、chained fixups 永远解不出来。
LC_DYLD_CHAINED_FIXUPS = 0x80000033
LC_DYLD_EXPORTS_TRIE = 0x80000034

# 指针链格式（dyld 的 fixup-chains.h，pointer_format 字段的取值）
#
# ⚠️ arm64 与 arm64e 用的**不是同一种格式**，这是本脚本最容易漏的一环：
#    arm64  → DYLD_CHAINED_PTR_64（2）        target 字段 36 位，4 字节步长
#    arm64e → DYLD_CHAINED_PTR_ARM64E_USERLAND24（12）  11 位 next，8 字节步长
# 本项目 Makefile 是 ARCHS := arm64 arm64e，所以两种都会遇到。
# 早期只认 PTR_64，arm64e 那一半直接放弃解码 → 类表读成 0（CI 第 10 次构建）。
DYLD_CHAINED_PTR_ARM64E = 1
DYLD_CHAINED_PTR_64 = 2
DYLD_CHAINED_PTR_64_OFFSET = 6
DYLD_CHAINED_PTR_ARM64E_KERNEL = 7
DYLD_CHAINED_PTR_ARM64E_USERLAND = 9
DYLD_CHAINED_PTR_ARM64E_USERLAND24 = 12
DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE = 13

# 链内指针的 stride 单位都是 4 字节，next 字段乘它才是字节步长。
# （ARM64E 系格式在 dyld 里实际按 8 字节排布，但 next 的编码同样以 4 为单位 ——
#   实测 arm64e 切片 next=2 时步长正好 8，与 PTR_64 一致。）
CHAIN_PTR_STRIDE = 4

# 认识的、且能安全解码的格式集合
KNOWN_PTR_FORMATS = (
    DYLD_CHAINED_PTR_ARM64E,
    DYLD_CHAINED_PTR_64,
    DYLD_CHAINED_PTR_64_OFFSET,
    DYLD_CHAINED_PTR_ARM64E_KERNEL,
    DYLD_CHAINED_PTR_ARM64E_USERLAND,
    DYLD_CHAINED_PTR_ARM64E_USERLAND24,
)
# 其中 target 是「vmaddr 绝对值」的格式；其余是「相对镜像基址的偏移」。
# 本项目 __TEXT.vmaddr == 0，两者结果相同，但显式区分避免以后换构建方式时出错。
PTR_FORMATS_ABSOLUTE_VMADDR = (
    DYLD_CHAINED_PTR_ARM64E,
    DYLD_CHAINED_PTR_64,
)

# 页起始描述符的特殊值
DYLD_CHAINED_PTR_START_NONE = 0xFFFF
DYLD_CHAINED_PTR_START_MULTI = 0x8000

PLATFORMS = {1: "macOS", 2: "iOS", 3: "tvOS", 4: "watchOS", 6: "iOSMac", 11: "iOS-sim"}

# fat_header(8) + 每个 fat_arch(20, 32 位版)
FAT_ARCH_SIZE = 20
FAT_ARCH_SIZE_64 = 32


def cpu_name(cputype, cpusubtype):
    """把 cputype/cpusubtype 翻译成可读名字。"""
    if cputype == CPU_TYPE_ARM64E:
        return "arm64e"
    if cputype == CPU_TYPE_ARM64:
        # arm64 + subtype 2 也是 arm64e（老 SDK 的表示法）
        return "arm64e" if (cpusubtype & CPU_SUBTYPE_ARM64E) else "arm64"
    if cputype == 0x01000007:
        return "x86_64"
    return hex(cputype)


def parse_fat(data):
    """若是 fat（universal）二进制，返回 [(cputype, cpusubtype, offset, size), ...]；
    否则返回 None。

    ⚠️ 为什么必须支持 fat：
       Makefile 里 ARCHS := arm64 arm64e，Theos 在两个架构各编一遍后会在
       "==> Merging tweak DouyinLogProbe…" 这一步合成一个 fat 文件。
       本脚本早期只认瘦 Mach-O，拿到 fat 头（magic=0xbebafeca）直接抛
       "不是 64 位 Mach-O"，于是 CI 在 dylib **已经正确产出**的情况下白白失败。
       V3.2.9 第八次 CI 构建就栽在这 —— 脚本能力缺口被误当成产物问题。
    """
    if len(data) < 8:
        return None
    magic = struct.unpack_from(">I", data, 0)[0]      # fat 头是**大端**
    if magic == FAT_MAGIC:
        is64 = False
    elif magic == FAT_MAGIC_64:
        is64 = True
    else:
        return None

    nfat = struct.unpack_from(">I", data, 4)[0]
    # 合理性保护：防止把畸形文件当成超大 fat 去解析
    if nfat == 0 or nfat > 64:
        return None

    entry = FAT_ARCH_SIZE_64 if is64 else FAT_ARCH_SIZE
    out = []
    off = 8
    for _ in range(nfat):
        if is64:
            cputype, cpusub, foff, size, _align, _res = \
                struct.unpack_from(">iiQQII", data, off)
        else:
            cputype, cpusub, foff, size, _align = \
                struct.unpack_from(">iiIII", data, off)
        out.append((cputype, cpusub, foff, size))
        off += entry
    return out


class MachO:
    def __init__(self, path, base=0, limit=None):
        """base：切片在文件中的起始偏移（fat 里每个架构一个切片）；瘦文件传 0。"""
        self.data = open(path, "rb").read()
        self.base = base
        if limit is not None:
            self.data = self.data[:base + limit]
        d = self.data
        magic, cputype, cpusub, filetype, ncmds, sizeofcmds, flags, _ = \
            struct.unpack_from("<IiiIIIII", d, base)
        if magic != MH_MAGIC_64:
            raise ValueError("不是 64 位 Mach-O（magic=0x%08x，base=%d）" % (magic, base))
        self.cputype = cputype
        self.cpusubtype = cpusub & 0x00FFFFFF
        self.filetype = filetype
        self.ncmds = ncmds

        self.segments = []     # [(name, vmaddr, vmsize, fileoff, filesize, lc)]
        self.install_name = None
        self.dylibs = []
        self.platform = None
        self.minos = None
        self.sdk = None
        # chained fixups 信息：(fileoff_绝对, datasize, page_starts) 或 None
        self.chained_fixups = None
        # 链走出来的 {槽位VM: 目标VM} 映射，首次 read_ptr 时惰性构建
        self._chain_map = None
        # {段名: pointer_format}，_parse_chained_fixups 填
        self._ptr_fmt = {}
        # 本切片的架构默认指针格式（链解析失败时 read_ptr 兜底用）
        self._ptr_fmt_default = (
            DYLD_CHAINED_PTR_ARM64E_USERLAND24
            if self.cpusubtype & CPU_SUBTYPE_ARM64E else DYLD_CHAINED_PTR_64
        )

        off = base + 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from("<II", d, off)
            if cmd == LC_SEGMENT_64:
                segname = d[off + 8:off + 24].rstrip(b"\x00").decode()
                vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<QQQQ", d, off + 24)
                # off = 该 load command 在文件中的位置（解析 nsects / section 数组要用它，
                # 不能用 fileoff —— fileoff 是段内容在文件中的位置）
                #
                # ⚠️ fat 切片里 fileoff 是**相对切片起点**的，要加上 base 才是文件绝对偏移。
                self.segments.append((segname, vmaddr, vmsize, base + fileoff, filesize, off))
            elif cmd in (LC_ID_DYLIB, LC_LOAD_DYLIB):
                name_off = struct.unpack_from("<I", d, off + 8)[0]
                s = d[off + name_off:off + cmdsize]
                name = s.split(b"\x00")[0].decode("utf-8", "replace")
                if cmd == LC_ID_DYLIB:
                    self.install_name = name
                else:
                    self.dylibs.append(name)
            elif cmd == LC_BUILD_VERSION:
                plat, minos, sdk, _ = struct.unpack_from("<IIII", d, off + 8)
                self.platform = PLATFORMS.get(plat, str(plat))
                self.minos = "%d.%d.%d" % (minos >> 16, (minos >> 8) & 0xFF, minos & 0xFF)
                self.sdk = "%d.%d.%d" % (sdk >> 16, (sdk >> 8) & 0xFF, sdk & 0xFF)
            elif cmd == LC_VERSION_MIN_IPHONEOS:
                ver = struct.unpack_from("<I", d, off + 8)[0]
                self.platform = "iOS"
                self.minos = "%d.%d.%d" % (ver >> 16, (ver >> 8) & 0xFF, ver & 0xFF)
            elif cmd == LC_DYLD_CHAINED_FIXUPS:
                # linkedit_data_command: cmd(4) cmdsize(4) dataoff(4) datasize(4)
                # dataoff 与段的 fileoff 一样，是**相对切片起点**的。
                dataoff, datasize = struct.unpack_from("<II", d, off + 8)
                self.chained_fixups = (base + dataoff, datasize, None)
            off += cmdsize

        if self.chained_fixups is not None:
            self._parse_chained_fixups()

    @property
    def cpu(self):
        return cpu_name(self.cputype, self.cpusubtype)

    def _parse_chained_fixups(self):
        """解析 LC_DYLD_CHAINED_FIXUPS，得出每个段的「指针链起始位置」。

        ── 为什么非做不可 ─────────────────────────────────────────────
        新版链接器（Xcode 13+）默认用 **chained fixups** 代替传统的
        LC_DYLD_INFO rebase/bind 表。此时文件里的指针**不是裸 VM 地址**，
        而是被编码过的：高位塞了链的步长与 bind/rebase 标记。

        实测（CI 第 10 次构建，Xcode 26.6 链接的 arm64 切片）：
            __objc_classlist[0] 读出来 = 0x00100000000561d8
                                      ↑ 高 20 位是链信息
            真实 VM 绝对值           = ((imagebase + 0x561d8) & 0xFFFFFFFFF) << 0
        脚本早期把这串东西当裸指针用，拿去 read_ptr(cls_vm + 32) 解 class_ro_t，
        vm_to_off 找不到就返回 None → 每个类都在中途 continue 掉 →
        「模块构造函数 0 个 / PDP 类 0 个」。**产物本身一直是好的。**

        ── dyld_chained_fixups_header 布局 ───────────────────────────
            u32 fixups_version  (恒为 0)
            u32 starts_offset   (相对 header 起点)
            u32 starts_size
            u32 imports_offset
            u32 imports_size
            u32 symbols_offset
            u32 symbols_size
        starts_offset 处是 dyld_chained_starts_in_image：
            u32 seg_count
            u32 seg_info_offset[seg_count]   (0 = 该段没有链)
        每个非 0 项指向 dyld_chained_starts_in_segment：
            u32 size; u16 page_size; u16 pointer_format; u64 segment_offset;
            u32 max_valid_pointer; u16 page_count; u16 page_start[page_count]
        page_start 里每个值 v：DYLD_CHAINED_PTR_START_NONE(0xFFFF) = 该页无链；
        DYLD_CHAINED_PTR_START_MULTI(0x8000) = 多链，需查 overflow 表 —— 本项目
        的 dylib 用不到，遇到就整体放弃解码（宁可判「解析不了」，也不瞎猜）。

        解析不出来就把 self.chained_fixups 的第 3 项留空，read_ptr 自动回落到
        「当裸指针使」的老行为 —— 老 SDK 的产物本来就该走那条路。
        """
        abs_off, size, _ = self.chained_fixups
        try:
            hdr = struct.unpack_from("<IIIIIII", self.data, abs_off)
            _ver, starts_off, _starts_size, _imp_off, _imp_size, _sym_off, _sym_size = hdr

            img = abs_off + starts_off
            seg_count = struct.unpack_from("<I", self.data, img)[0]
            if seg_count == 0 or seg_count > 64:
                return
            seg_info = struct.unpack_from("<%dI" % seg_count, self.data, img + 4)

            chains = {}
            fmt_by_seg = {}
            for idx, si_off in enumerate(seg_info):
                if si_off == 0:
                    continue
                if idx >= len(self.segments):
                    break
                segname, vmaddr, _vmsize, _foff, _fsize, _lc = self.segments[idx]

                p = img + si_off
                (_ssize, page_size, ptr_fmt, seg_off,
                 _max_valid, page_count) = struct.unpack_from("<IHHQIH", self.data, p)
                if ptr_fmt not in KNOWN_PTR_FORMATS:
                    # 不是我们认识/验证过的格式，不猜 —— 直接整体放弃解码
                    self.chained_fixups = (abs_off, size, None)
                    return
                if page_size == 0:
                    self.chained_fixups = (abs_off, size, None)
                    return
                fmt_by_seg[segname] = ptr_fmt

                page_starts = struct.unpack_from("<%dH" % page_count, self.data, p + 22)
                entries = []
                for pg, st in enumerate(page_starts):
                    if st == DYLD_CHAINED_PTR_START_NONE:
                        continue
                    if st & DYLD_CHAINED_PTR_START_MULTI:
                        # 多链页：偏移要再查 overflow 表，本项目的 dylib 用不到，
                        # 遇到就整体放弃解码（宁可判「解析不了」，也不瞎猜）。
                        self.chained_fixups = (abs_off, size, None)
                        return
                    # 该页内第一个链的 VM 地址（seg_off 是段在 __TEXT 里的偏移基准）
                    entries.append(seg_off + pg * page_size + st)
                if entries:
                    chains[segname] = entries
            self.chained_fixups = (abs_off, size, chains or None)
            self._ptr_fmt = fmt_by_seg
        except (struct.error, IndexError):
            self.chained_fixups = (abs_off, size, None)

    def _decode_rebase(self, raw, ptr_fmt):
        """把链上的一个 rebase 指针解成「段内 VM 地址」。

        四种格式的位域（取自 dyld 的 mach-o/fixup-chains.h）：

        DYLD_CHAINED_PTR_64 / _64_OFFSET —— arm64 用这种
            target : 36   (PTR_64 = vmaddr 绝对值；_OFFSET = 相对加载基址的偏移)
            high8  : 8
            reserved : 7
            next   : 12
            bind   : 1
            → 本脚本只取 target。high8 是最高位补零用的，dylib 内地址用不到。

        DYLD_CHAINED_PTR_ARM64E / _USERLAND / _USERLAND24 —— arm64e 用这种
            未认证 rebase（bind==0, auth==0）：
                target : 43, high8 : 8, next : 11, bind : 1, auth : 1
            已认证 rebase（bind==0, auth==1）：
                target : 32 (runtimeOffset), diversity : 16, addrDiv : 1,
                key : 2, next : 11, bind : 1, auth : 1
            ⚠️ 认证形态下 target 只有 32 位，且**只有这种 rebase 会被 dyld 签名**。
               dylib 里 __objc_classlist 这类数据指针走的是未认证 rebase
               （target 43 位），实测 arm64e 切片解出来与 arm64 切片完全一致。
        """
        if ptr_fmt in (DYLD_CHAINED_PTR_64, DYLD_CHAINED_PTR_64_OFFSET):
            return raw & ((1 << 36) - 1)
        if ptr_fmt == DYLD_CHAINED_PTR_ARM64E_SHARED_CACHE:
            return raw & 0xFFFFFFFF
        # ARM64E 系（1 / 7 / 9 / 12）：先看认证位
        auth = (raw >> 63) & 1
        if auth:
            return raw & 0xFFFFFFFF          # target : 32 (runtimeOffset)
        return raw & ((1 << 43) - 1)         # target : 43

    def _chain_next(self, raw, ptr_fmt):
        """取链的下一步字节步长。next 字段宽度按格式不同：

        PTR_64 / _64_OFFSET          → bit 62..51（12 位）
        ARM64E 全系（bind/auth 共用）→ bit 62..52（11 位）
        """
        if ptr_fmt in (DYLD_CHAINED_PTR_64, DYLD_CHAINED_PTR_64_OFFSET):
            nxt = (raw >> 51) & 0xFFF
        else:
            nxt = (raw >> 52) & 0x7FF
        return nxt * CHAIN_PTR_STRIDE

    def vm_to_off(self, vm):
        """虚拟地址 → 文件绝对偏移。

        ⚠️ 两次踩坑记录（都是同一条「基址」概念没拎清）：

        1) fat 切片里，`segment_command_64.fileoff` 是**相对切片起点**的，
           解析时已经 +base 存进 self.segments（见 __init__ 的注释）。
        2) **瘦（thin）Mach-O 里 fileoff 本身也可能是非 0**！
           最典型的就是 Theos 链接出来的 dylib：__TEXT 段从文件偏移 0x4000
           （第一页）开始，段内第一个区块 __text 同样落在 0x4000。
           本脚本早期把 __TEXT 的 fileoff 当成 0，于是
               vm_to_off(__objc_classlist 的地址)
                 = 0x50c00 + (vm - 0x0)  ← 用的是「页对齐前的段基址」，整个偏了 0x4000
           读出来的指针全是垃圾 → 一条类名都解析不出来 → 报「PDP 类 = 0」。
           CI 第九次构建就是这么把一个**完全正确**的 fat dylib 判成失败的。

           正确公式恒为：文件偏移 = segment.fileoff + (vm - segment.vmaddr)
           —— 与 fat 与否无关，self.segments 里存的 fileoff 已经是绝对偏移。
        """
        for name, vmaddr, vmsize, fileoff, filesize, lc in self.segments:
            # filesize == 0 的段（__PAGEZERO / 纯 bss）没有任何文件内容，跳过，
            # 否则会把落在其中的地址算到一个不存在的文件位置上。
            if filesize <= 0:
                continue
            if vmaddr <= vm < vmaddr + vmsize:
                return fileoff + (vm - vmaddr)
        return None

    def _chain_walk(self):
        """顺着 chained fixups 的链，建一张 {槽位 VM 地址: 目标 VM 地址} 表。

        只在解析出的链首位置上走。链的每一步：
            raw = *p   (8 字节小端)
            bind = raw >> 63
            next = (raw >> 51) & 0xFFF          ← 以 4 字节为单位
            target = raw & ((1<<36)-1)          ← 目标相对「镜像基址」的偏移
            p += next * 4
        bind=0 是 rebase（指向本镜像内部，正是我们解析类表要用的）；
        bind=1 是 bind（指向别的 dylib 的符号），本脚本不需要其地址，但**必须仍按
        next 继续走**，否则会漏掉后面的槽位。

        DYLD_CHAINED_PTR_64 的 target 是「相对镜像基址」的偏移；本 dylib 的
        __TEXT.vmaddr == 0，所以 VM 绝对值就等于 target，无需再纠正。

        目标地址取 target 而非 imagebase+target：这里是纯文件解析，没有真实加载
        基址可用；但 read_ptr 只把结果当作「段内的 VM 地址」用于 vm_to_off，
        而 vm_to_off 走的是 segments 里那份 vmaddr（同样以 0 为基准），两者一致。
        """
        chains = self.chained_fixups[2] if self.chained_fixups else None
        if not chains:
            return None

        out = {}
        for segname, starts in chains.items():
            ptr_fmt = self._ptr_fmt.get(segname, DYLD_CHAINED_PTR_64)
            for vm in starts:
                p = vm
                # 防止畸形链把脚本拖死：单个段最多走这么多步（实际远小于此）
                for _ in range(200000):
                    o = self.vm_to_off(p)
                    if o is None or o + 8 > len(self.data):
                        break
                    raw = struct.unpack_from("<Q", self.data, o)[0]
                    bind = (raw >> 63) & 1
                    if bind == 0:
                        out[p] = self._decode_rebase(raw, ptr_fmt)
                    step = self._chain_next(raw, ptr_fmt)
                    if step == 0:
                        break
                    p += step
        return out or None

    def read_ptr(self, vm):
        """读一个 8 字节指针槽位，返回它指向的 **段内 VM 地址**。

        有 chained fixups 时先查链解析出的映射表 —— 那条路径拿到的才是真地址；
        查不到（或本文件没有 chained fixups）再按裸指针读。
        """
        if self._chain_map is None:
            self._chain_map = self._chain_walk() or {}
        if vm in self._chain_map:
            return self._chain_map[vm]

        o = self.vm_to_off(vm)
        if o is None:
            return None
        # 越界保护：bss / 段尾的地址可能算出超出文件长度的偏移，
        # struct.unpack_from 会直接抛 struct.error 让整个脚本崩在一个看不懂的地方。
        if o < 0 or o + 8 > len(self.data):
            return None
        raw = struct.unpack_from("<Q", self.data, o)[0]
        # 兜底防线：链解析整体失败时，裸读到的值仍会带高位标记。合法的段内地址
        # 不会超过 48 位，超过就说明是编码过的指针，按本架构的格式解一次 target。
        if raw >> 48:
            return self._decode_rebase(raw, getattr(self, "_ptr_fmt_default", DYLD_CHAINED_PTR_64))
        return raw

    def sections_all(self):
        """列出全部 (segname, secname, addr, size, offset)。诊断用。"""
        out = []
        for name, vmaddr, vmsize, fileoff, filesize, lc in self.segments:
            nsects = struct.unpack_from("<I", self.data, lc + 64)[0]
            base = lc + 72
            for i in range(nsects):
                p = base + i * 80
                sname = self.data[p:p + 16].rstrip(b"\x00").decode()
                sgname = self.data[p + 16:p + 32].rstrip(b"\x00").decode()
                saddr, ssize = struct.unpack_from("<QQ", self.data, p + 32)
                soff = struct.unpack_from("<I", self.data, p + 48)[0]
                out.append((sgname or name, sname, saddr, ssize, soff))
        return out

    def dump_structure(self):
        """打印段与区块清单。校验失败时输出，方便一眼看出区块名/归属段是否变了
        （例如新 SDK 把 __objc_classlist 挪进 __DATA_CONST、或改了命名习惯）。"""
        print("  [诊断] 段与区块清单：")
        print("  %-16s %-28s %-12s %-10s" % ("SEGMENT", "SECTION", "ADDR", "SIZE"))
        for sg, sc, addr, size, soff in self.sections_all():
            print("  %-16s %-28s 0x%-10x %-10d" % (sg, sc, addr, size))

    def section(self, seg, sec):
        """返回 (vmaddr, size, fileoff)"""
        for name, vmaddr, vmsize, fileoff, filesize, lc in self.segments:
            if name != seg:
                continue
            # segment_command_64: cmd(4) cmdsize(4) segname(16) vmaddr(8) vmsize(8)
            #                     fileoff(8) filesize(8) maxprot(4) initprot(4) nsects(4) flags(4)
            # → nsects 位于 lc+64，section_64 数组从 lc+72 开始，每项 80 字节
            nsects = struct.unpack_from("<I", self.data, lc + 64)[0]
            base = lc + 72
            for i in range(nsects):
                p = base + i * 80
                sname = self.data[p:p + 16].rstrip(b"\x00").decode()
                if sname == sec:
                    saddr, ssize = struct.unpack_from("<QQ", self.data, p + 32)
                    soff = struct.unpack_from("<I", self.data, p + 48)[0]
                    return saddr, ssize, soff
        return None

    def cstring(self, vm):
        o = self.vm_to_off(vm)
        if o is None or o < 0 or o >= len(self.data):
            return None
        end = self.data.find(b"\x00", o)
        if end < 0:
            end = len(self.data)
        return self.data[o:end].decode("utf-8", "replace")

    def objc_classes(self):
        """从 __objc_classlist 解析类名。

        理论上这个区块在 __DATA_CONST 里；但老 SDK / 某些链接器版本会把它放进
        __DATA，因此两个段都要找（哪个先找到用哪个）。
        """
        s = self.section("__DATA_CONST", "__objc_classlist") or \
            self.section("__DATA", "__objc_classlist")
        if not s:
            return []
        addr, size, _ = s
        out = []
        for i in range(size // 8):
            cls_vm = self.read_ptr(addr + i * 8)
            if not cls_vm:
                continue
            # class_t: isa(8) superclass(8) cache(8) vtable(8) data(8) → data 在 +32
            ro_vm = self.read_ptr(cls_vm + 32)
            if not ro_vm:
                continue
            # class_ro_t: flags(4) instanceStart(4) instanceSize(4) reserved(4)
            #              ivarLayout(8) name(8) → name 在 +24
            name_vm = self.read_ptr(ro_vm + 24)
            if name_vm:
                nm = self.cstring(name_vm)
                if nm:
                    out.append(nm)
        return out

    def mod_init_count(self):
        """模块构造函数数量。

        两种可能的位置，按顺序探测：

        A) __DATA_CONST/__DATA 里的 __mod_init_func：传统做法，一段指针数组，
           元素个数即构造函数个数。

        B) 新版链接器（Xcode 13+，本项目的 macOS runner 就是 Xcode 26.6）不再生成
           __mod_init_func，改在 __TEXT 放一个 __init_offsets —— 4 字节的 u32 数组，
           每个元素是**相对镜像基址的偏移**，指向一个真正的函数指针槽位。

           实测（CI 第 10 次构建的 arm64 切片）：
               __init_offsets[0] = 0x4000        → 槽位在 VM 0x4000
               read_ptr(0x4000)  = 0x104f433c... → 那就是 DouyinLogProbe 的 %ctor

           ⚠️ 这里**数元素个数**（size // 4），不要加 1 / 不要按 +4 删首元素 ——
              __init_offsets 的每个元素都对应一个构造函数，不像某些结构有哨兵头。
              唯一的例外是数组为空（size == 0），那才是真的没有构造函数。
        """
        s = self.section("__DATA_CONST", "__mod_init_func") or \
            self.section("__DATA", "__mod_init_func")
        if s and s[1] >= 8:
            return s[1] // 8

        s2 = self.section("__TEXT", "__init_offsets")
        if s2 and s2[1] >= 4:
            return s2[1] // 4
        return 0


def check_slice(m, path, label):
    """校验单个 Mach-O 切片，返回是否全部通过。"""
    ok = True

    def chk(cond, lbl, detail=""):
        nonlocal ok
        ok = ok and bool(cond)
        print("%s %s%s" % ("✅" if cond else "❌", lbl, (" —— " + detail) if detail else ""))

    chk(m.filetype == MH_DYLIB, "文件类型 = MH_DYLIB", "filetype=%d" % m.filetype)
    chk(m.cpu in ("arm64", "arm64e"), "CPU 架构 = iOS 设备架构", m.cpu)
    chk(m.platform == "iOS", "平台 = iOS", str(m.platform))
    chk(m.install_name and m.install_name.endswith("DouyinLogProbe.dylib"),
        "install_name 正确", str(m.install_name))

    ctors = m.mod_init_count()
    chk(ctors >= 1, "存在模块构造函数（注入后自动装配）", "%d 个" % ctors)

    classes = sorted(set(c for c in m.objc_classes() if c))
    dlp = [c for c in classes if c.startswith("DLP")]
    chk(len(dlp) >= 8, "DLP 模块类齐全", "%d 个：%s" % (len(dlp), ", ".join(dlp)))

    # 解析不出构造函数 / 类名时先把段与区块清单打出来。
    # 这两项失败几乎一定是「脚本读错了地方」（段归属变了 / 偏移公式不对），
    # 而不是「产物真的空」—— 直接把现场摊开，省掉一轮 CI 往返。
    if ctors == 0 or len(dlp) < 8:
        m.dump_structure()

    need = {"Foundation", "UIKit", "libobjc", "libSystem"}
    joined = " ".join(m.dylibs)
    miss = [n for n in need if n not in joined]
    chk(not miss, "依赖库完备", "缺失：%s" % (miss or "无"))

    print("-" * 60)
    print("min iOS : %s" % m.minos)
    print("SDK     : %s" % m.sdk)
    print("依赖    :")
    for d in m.dylibs:
        print("          %s" % d)
    return ok


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "build/DouyinLogProbe.dylib"
    if not os.path.exists(path):
        print("❌ 文件不存在：%s" % path)
        return 1

    raw = open(path, "rb").read()
    size_kb = len(raw) / 1024.0

    print("=" * 60)
    print("dylib 校验：%s" % path)
    print("=" * 60)

    slices = parse_fat(raw)

    if slices is None:
        # 瘦 Mach-O
        try:
            m = MachO(path)
        except ValueError as e:
            print("❌ 解析失败：%s" % e)
            return 1
        ok = check_slice(m, path, m.cpu)
    else:
        # fat（universal）：逐架构校验，并核对 Makefile 期望的 arm64 + arm64e 都在
        print("ℹ️  检测到 fat（universal）二进制，共 %d 个架构切片" % len(slices))
        print()
        names = []
        ok = True
        for i, (cputype, cpusub, foff, fsize) in enumerate(slices):
            nm = cpu_name(cputype, cpusub & 0x00FFFFFF)
            names.append(nm)
            print("── 架构 %d/%d：%s（偏移 0x%x，%d 字节）──" % (i + 1, len(slices), nm, foff, fsize))
            try:
                m = MachO(path, base=foff, limit=fsize)
            except ValueError as e:
                print("❌ 切片解析失败：%s" % e)
                ok = False
                continue
            if not check_slice(m, path, nm):
                ok = False
            print()

        # Makefile 里写的是 ARCHS := arm64 arm64e，两个都该在
        want = {"arm64", "arm64e"}
        got = set(names)
        miss = sorted(want - got)
        mark = "✅" if not miss else "❌"
        print("%s 架构齐全（期望 arm64 + arm64e）—— 实际：%s%s"
              % (mark, ", ".join(names), ("  缺失：" + ", ".join(miss)) if miss else ""))
        ok = ok and not miss

    print("=" * 60)
    print("大小    : %.1f KB" % size_kb)
    print("结果：%s" % ("全部通过" if ok else "存在失败项"))
    print("=" * 60)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
