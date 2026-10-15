#!/usr/bin/env bash
#
# 语法检查：在没有 iOS SDK 的 Linux 上，用 clang -fsyntax-only 校验本工程
# 全部 Objective-C 源文件的语法、类型与符号引用。
#
# 原理：tools/syntaxcheck/ 下提供最小 Foundation / UIKit / runtime / dispatch 桩头文件，
#      让 #import <Foundation/Foundation.h> 与 <UIKit/UIKit.h> 能够解析。
#
# 能检出：语法错误、类型不匹配、未声明符号、ARC 违规、Nullability 错误
# 检不出：selector 是否存在于真实 SDK、私有类是否存在（那需要真机 + class-dump）
#
# 用法：bash tools/syntaxcheck.sh
#
set -uo pipefail

# clang 缺失时直接 exit 1，绝不静默放行（V3.3.6 教训：静默全过比报错更危险）。
if ! command -v clang >/dev/null 2>&1; then
    echo "❌ syntaxcheck 需要 clang，但当前机器上没有。"
    exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STUB="-I tools/syntaxcheck"
FLAGS="-fsyntax-only -x objective-c -fobjc-arc -fblocks -fobjc-runtime=ios-17.0"
FLAGS="$FLAGS -Wformat=2"

# 本插件无 Tweak.xm：入口是 src/DLPEntry.m 的 __attribute__((constructor))，直接参与检查。
passed=0
failed=0

for f in src/*.m; do
  [ -e "$f" ] || continue
  out=$(clang $FLAGS $STUB -I src "$f" 2>&1)
  rc=$?
  # 以 clang 退出码为准（2026-10-16 教训：只 grep "error:" 文本会漏报，
  # stub 检查三轮全过，交叉编译却抓出真 error）。文本 grep 只做展示。
  if [ $rc -ne 0 ] || echo "$out" | grep -q "error:"; then
    failed=$((failed + 1))
    echo "❌ $f"
    echo "$out" | grep -E "error:" | sed 's/^/     /' | head -15
    echo
  else
    passed=$((passed + 1))
    echo "✅ $f"
  fi
done

echo
echo "──────────────────────────────"
echo "通过 $passed 个，失败 $failed 个"

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "全部源文件语法检查通过"
