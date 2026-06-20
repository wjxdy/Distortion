#!/usr/bin/env bash
# 《审讯室 / 失真》打包桌面单机版(macOS + Windows),内置 API key。
#
# 导出原生可执行版给人本地下载运行(非网页)。key 在导出期临时注入 llm.gd,
# 完事立刻还原占位,绝不留在工作区/仓库。key 来自环境变量 MOONSHOT_API_KEY
# 或 gitignored 的 .edgeone/moonshot_key。
#
# 用法：  bash scripts/package_desktop.sh
# 产物：  build/mac/Distortion.zip      (内含 Distortion.app)
#         build/win/Distortion.exe (+.pck) → 打包成 build/Distortion_win.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
CLIENT="$ROOT/Game/client"
LLM="$CLIENT/game/llm.gd"

KEY="${MOONSHOT_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$ROOT/.edgeone/moonshot_key" ]; then KEY="$(cat "$ROOT/.edgeone/moonshot_key")"; fi
if [ -z "$KEY" ]; then echo "❌ 没拿到 key(设 MOONSHOT_API_KEY 或写 .edgeone/moonshot_key)"; exit 1; fi

# 注入 key,trap 保证无论成败都还原占位
restore() { if [ -f "$LLM.bak" ]; then mv -f "$LLM.bak" "$LLM"; fi; }
trap restore EXIT
cp "$LLM" "$LLM.bak"
KEY="$KEY" perl -0pi -e 's/REPLACE_WITH_KIMI_API_KEY/$ENV{KEY}/g' "$LLM"
grep -q "REPLACE_WITH_KIMI_API_KEY" "$LLM" && { echo "❌ key 注入失败"; exit 1; }
echo "[1/4] 已注入 key(导出期临时)"

mkdir -p "$ROOT/build/mac" "$ROOT/build/win"

echo "[2/4] 导出 macOS → build/mac/Distortion.zip"
"$GODOT" --headless --path "$CLIENT" --export-release "macOS" "$ROOT/build/mac/Distortion.zip"

echo "[3/4] 导出 Windows → build/win/Distortion.exe"
"$GODOT" --headless --path "$CLIENT" --export-release "Windows Desktop" "$ROOT/build/win/Distortion.exe"

restore; trap - EXIT   # 导出完立刻还原 llm.gd(占位回来)

echo "[4/4] 打包 Windows 文件夹为 zip → build/Distortion_win.zip"
WINZIP="$ROOT/build/Distortion_win.zip"
rm -f "$WINZIP"
( cd "$ROOT/build/win" && zip -qr "$WINZIP" . )

echo "✅ 完成："
echo "   macOS:   $ROOT/build/mac/Distortion.zip   (解压得 Distortion.app)"
echo "   Windows: $WINZIP                          (解压得 Distortion.exe + .pck,一起放同目录)"
echo "⚠️ key 已内置;Moonshot 设消费上限 + demo 后轮换。"
echo "⚠️ macOS 未签名:首次打开右键→打开,或终端 xattr -dr com.apple.quarantine Distortion.app"
