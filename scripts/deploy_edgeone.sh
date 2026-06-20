#!/usr/bin/env bash
# 《失真 Distortion》一键部署到 EdgeOne Makers(Pages)。
#
# 做三件事：① 导出 Godot 网页版 → build/web；② 把 edge-functions(LLM 代理,
# V8 边缘运行时,免构建)组装进部署根；③ edgeone makers deploy 上传。
# 产出一个公开访问链接给评委试玩。
#
# 前置(只做一次)：
#   1) 安装 CLI：  npm install -g edgeone@latest      (需 ≥1.2.30)
#   2) 登录国内站：edgeone login --site china
#   3) 首次部署成功后，去 EdgeOne 控制台 → 本项目 → 环境变量，
#      新增 MOONSHOT_API_KEY = <你的 Moonshot key>，再重跑本脚本(或控制台重部署)。
#      ⚠️ key 只存控制台环境变量，绝不写进仓库/前端。
#
# 用法：  bash scripts/deploy_edgeone.sh [项目名]      默认项目名 distortion
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
NAME="${1:-distortion}"
OUT="$ROOT/build/web"

echo "[1/3] 导出 Godot 网页版 → $OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT/Game/client" --export-release "Web" "$OUT/index.html"

echo "[2/3] 组装 edge-functions(LLM 代理) → 部署根"
rm -rf "$OUT/edge-functions" "$OUT/cloud-functions"
cp -R "$ROOT/edge-functions" "$OUT/edge-functions"

echo "[3/3] 部署到 EdgeOne Makers (project=$NAME)"
cd "$OUT"
PAGES_SOURCE=skills edgeone makers deploy . -n "$NAME"

echo "✅ 完成。若 LLM 不回话(/api/chat 报 500)，多半是控制台还没设 MOONSHOT_API_KEY 环境变量。"
