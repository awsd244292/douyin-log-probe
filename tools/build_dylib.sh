#!/usr/bin/env bash
#
# build_dylib.sh —— 交叉编译 DouyinLogProbe.dylib
#
# 不需要 Xcode、不需要越狱设备、不需要 Theos。
# 只需要：clang（>= 14）+ LLVM 的 ld64.lld（Mach-O 后端）+ 一份 iPhoneOS SDK。
#
# 用法：
#   bash tools/build_dylib.sh                      # 默认 arm64 / iOS 13.0 / iPhoneOS16.5.sdk
#   MIN_IOS=15.0 bash tools/build_dylib.sh
#   SDK_SYSROOT=/path/to/iPhoneOS.sdk bash tools/build_dylib.sh
#
# 产物：build/DouyinLogProbe.dylib（Mach-O arm64 dynamic lib，未签名）
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MIN_IOS="${MIN_IOS:-13.0}"
ARCH="${ARCH:-arm64}"

# arm64e（指针认证 ABI）在 LLVM 上游未实现：即便 -arch arm64e 能通过，
# 产物的 cpusubtype 仍是 0x0，与 arm64 逐字节相同 —— 是假货。
# Apple 的 ptrauth ABI 只有 Xcode 自带的 ld64 支持，这里直接拒绝，避免交付误导性产物。
if [[ "$ARCH" != "arm64" ]]; then
    echo "❌ 本脚本只支持 ARCH=arm64。"
    echo "   arm64e 需要 Apple 私有 ptrauth ABI（Xcode ld64），LLVM ld64.lld 编出来的"
    echo "   cpusubtype 是 0x0，实际就是 arm64，属于误导。请在 macOS + Theos 下编 arm64e。"
    exit 1
fi
SDK_VERSION="${SDK_VERSION:-iPhoneOS16.5.sdk}"
SDK_SYSROOT="${SDK_SYSROOT:-$HOME/.pdp-sdks/$SDK_VERSION}"
SDK_REPO="${SDK_REPO:-https://github.com/theos/sdks.git}"
OUT="${OUT:-$ROOT/build/DouyinLogProbe.dylib}"
BUILD="$ROOT/build/.objs"
GEN="$ROOT/build/.gen"

# ---------------------------------------------------------------- 工具链定位
CC="${CC:-}"
LD="${LD:-}"
if [[ -z "$CC" ]]; then
    for c in clang-18 clang-17 clang-16 clang; do command -v "$c" >/dev/null 2>&1 && { CC="$c"; break; }; done
fi
if [[ -z "$LD" ]]; then
    for l in /usr/lib/llvm-*/bin/ld64.lld /opt/homebrew/opt/llvm/bin/ld64.lld ld64.lld; do
        [[ -x "$l" ]] && { LD="$l"; break; }
    done
fi
[[ -n "$CC" ]] || { echo "❌ 找不到 clang"; exit 1; }
[[ -n "$LD" ]] || { echo "❌ 找不到 ld64.lld（LLVM 的 Mach-O 链接器）。apt install lld"; exit 1; }

# ---------------------------------------------------------------- SDK 准备
if [[ ! -d "$SDK_SYSROOT" ]]; then
    echo "📦 SDK 不存在，正在拉取 $SDK_VERSION（首次约需几分钟）..."
    mkdir -p "$(dirname "$SDK_SYSROOT")"
    tmp="$(mktemp -d)"
    git clone --filter=blob:none --no-checkout --depth 1 "$SDK_REPO" "$tmp/repo" >/dev/null 2>&1
    ( cd "$tmp/repo" && git sparse-checkout init --cone && \
      git sparse-checkout set "$SDK_VERSION" && git checkout >/dev/null 2>&1 )
    mv "$tmp/repo/$SDK_VERSION" "$SDK_SYSROOT"
    rm -rf "$tmp"
fi
[[ -d "$SDK_SYSROOT/usr/include" ]] || { echo "❌ SDK 结构异常：$SDK_SYSROOT"; exit 1; }

SDK_MIN_VER="$(python3 -c "
import re,json,sys,os
p='$SDK_SYSROOT/SDKSettings.json'
v='16.5'
try:
    d=json.load(open(p)); v=d.get('DefaultDeploymentTarget',{}).get('iOS','16.5')
except Exception: pass
print(v)" 2>/dev/null || echo 16.5)"

echo "🔧 编译器   : $CC"
echo "🔧 链接器   : $LD"
echo "📱 SDK      : $SDK_SYSROOT (${SDK_VERSION}, SDK 版本 $SDK_MIN_VER)"
echo "🎯 目标     : $ARCH-apple-ios$MIN_IOS"
echo ""

# ---------------------------------------------------------------- 构建目录准备
# 本插件无 Logos、无 Tweak.xm：入口是 src/DLPEntry.m 的 __attribute__((constructor))。
# Hook 全部走运行时 method_setImplementation。
rm -rf "$BUILD"
mkdir -p "$BUILD" "$GEN" "$(dirname "$OUT")"

SOURCES=($(find "$ROOT/src" -name '*.m' | sort))
if [ ${#SOURCES[@]} -eq 0 ]; then
    echo "❌ src/ 下没有 .m 源文件。"
    exit 1
fi

# ---------------------------------------------------------------- 编译
CFLAGS=(
    -target "$ARCH-apple-ios$MIN_IOS"
    -mios-version-min="$MIN_IOS"
    -isysroot "$SDK_SYSROOT"
    -I"$SDK_SYSROOT/usr/include"
    -I"$ROOT/src" -I"$GEN"
    -fobjc-arc
    -fobjc-abi-version=2
    -Wall -Wno-deprecated-declarations -Wno-unused-parameter
    -Wno-unused-command-line-argument
    -O2 -gline-tables-only
)

echo "▶ 编译 ${#SOURCES[@]} 个源文件"
for f in "${SOURCES[@]}"; do
    name="$(basename "$f" .m)"
    printf "   %-28s" "$name"
    if "$CC" "${CFLAGS[@]}" -c "$f" -o "$BUILD/$name.o" 2>"$BUILD/$name.log"; then
        echo "✅"
    else
        echo "❌"
        sed 's/^/      /' "$BUILD/$name.log" | head -20
        exit 1
    fi
done

# ---------------------------------------------------------------- 链接
echo "▶ 链接 dylib"
OBJS=("$BUILD"/*.o)

# 注意：不加 -undefined dynamic_lookup，缺失符号直接报错 —— 比运行时崩更容易定位
"$LD" \
    -arch "$ARCH" \
    -platform_version ios "$MIN_IOS" "$SDK_MIN_VER" \
    -dylib \
    -install_name "@rpath/DouyinLogProbe.dylib" \
    -syslibroot "$SDK_SYSROOT" \
    -ObjC \
    -o "$OUT" \
    "${OBJS[@]}" \
    -framework Foundation \
    -framework UIKit \
    -framework CoreGraphics \
    -framework QuartzCore \
    -framework CoreMedia \
    -framework AVFoundation \
    -lobjc \
    -lSystem \
    -lc++ 2>"$BUILD/link.log" || {
        echo "❌ 链接失败："
        sed 's/^/      /' "$BUILD/link.log" | head -40
        exit 1
    }

echo ""
echo "✅ 产物：$OUT"
echo "   大小  : $(du -h "$OUT" | cut -f1)"
echo "   类型  : $(file -b "$OUT")"
echo ""

# ---------------------------------------------------------------- 结构自检
if command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT/tools/verify_dylib.py" "$OUT" || exit 1
fi

echo "⚠️  该 dylib 尚未签名。注入 IPA 后由 Sideloadly / AltStore 统一重签；"
echo "   手动场景请在 macOS 上执行：codesign -f -s - $(basename "$OUT")"
