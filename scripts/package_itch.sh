#!/usr/bin/env bash
# 《失真 Distortion》打包 itch.io 网页版。
#
# itch.io 托管整包游戏(无 25MB 单文件限制)，网页版直连 Moonshot(已验证 Moonshot
# 允许浏览器 CORS)，因此无需任何后端/代理。本脚本：注入 key→导出 Web→打 zip。
#
# ⚠️ key 会嵌入公开网页包(任何玩家可扒)。务必在 Moonshot 后台设消费上限，
#    评委试玩结束后轮换该 key。仓库内 llm.gd 始终留占位 REPLACE_WITH_KIMI_API_KEY，
#    key 只来自 .edgeone/moonshot_key(gitignored) 或环境变量 MOONSHOT_API_KEY。
#
# 用法：  bash scripts/package_itch.sh
# 产物：  build/distortion_web.zip  → 上传到 itch.io(类型 HTML,勾选"在浏览器中运行")
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
CLIENT="$ROOT/Game/client"
OUT="$ROOT/build/web"
ZIP="$ROOT/build/distortion_web.zip"
LLM="$CLIENT/game/llm.gd"

# 取 key：环境变量优先，否则读 gitignored 文件
KEY="${MOONSHOT_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$ROOT/.edgeone/moonshot_key" ]; then KEY="$(cat "$ROOT/.edgeone/moonshot_key")"; fi
if [ -z "$KEY" ]; then
  echo "❌ 没拿到 key。请设环境变量 MOONSHOT_API_KEY，或写入 .edgeone/moonshot_key"; exit 1
fi

# 注入 key 到 llm.gd(仅导出期间)，无论成功失败都还原，绝不把 key 留在工作区/仓库。
restore() { if [ -f "$LLM.bak" ]; then mv -f "$LLM.bak" "$LLM"; fi; }
trap restore EXIT
cp "$LLM" "$LLM.bak"
KEY="$KEY" perl -0pi -e 's/REPLACE_WITH_KIMI_API_KEY/$ENV{KEY}/g' "$LLM"
if ! grep -q "REPLACE_WITH_KIMI_API_KEY" "$LLM"; then echo "[1/3] 已注入 key(导出期临时)"; else echo "❌ key 注入失败"; exit 1; fi

echo "[2/3] 导出 Godot 网页版 → $OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$CLIENT" --export-release "Web" "$OUT/index.html"

restore; trap - EXIT   # 导出完立刻还原 llm.gd(占位回来)

# 注入网页音频解锁脚本到 <head>(首次交互唤醒被 autoplay 冻结的 AudioContext)
SNIP="$ROOT/scripts/audio_unlock.html"
if [ -f "$SNIP" ] && ! grep -q "Patched.prototype = Real.prototype" "$OUT/index.html"; then
  perl -0pi -e 'BEGIN{local $/; open(F,"<:raw",$ENV{SNIP}); $s=<F>; close F;} s/(<head>)/$1\n$s/' "$OUT/index.html"
  echo "[2.5/3] 已注入音频解锁脚本到 index.html"
fi

echo "[3/3] 打包 zip → $ZIP"
rm -f "$ZIP"
( cd "$OUT" && zip -qr "$ZIP" . )
echo "✅ 完成：$ZIP"
echo "   上传到 itch.io：Kind of project = HTML，上传此 zip，勾选 'This file will be played in the browser'。"
