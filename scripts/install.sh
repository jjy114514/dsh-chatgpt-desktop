#!/usr/bin/env bash
# dsh-chatgpt-desktop 一键安装（macOS / Linux / Windows Git Bash）
# 用法：bash scripts/install.sh [profile名，默认 desktop]
set -euo pipefail

PROFILE="${1:-desktop}"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE_DIR="$DSH_HOME/profiles/$PROFILE"
PLUGIN_DIR="$PROFILE_DIR/plugins/dsh-chatgpt-desktop"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$PROFILE_DIR" ]; then
  echo "未找到 DSH profile 目录：$PROFILE_DIR"
  echo "请先安装并运行一次 DSH，或用第一个参数指定正确的 profile 名。"
  exit 1
fi

# 1. 拷贝插件本体
mkdir -p "$PLUGIN_DIR/lib"
cp "$SRC_DIR/package.json" "$PLUGIN_DIR/package.json"
cp "$SRC_DIR/lib/"* "$PLUGIN_DIR/lib/"
echo "[1/4] 插件文件已复制到 $PLUGIN_DIR"

# 2. 登记 file: 依赖
PKG_FILE="$PROFILE_DIR/package.json"
NODE="$(command -v node || true)"
if [ -z "$NODE" ] && [ -n "${APPDATA:-}" ]; then
  CAND="$APPDATA/DSH Desktop/runtime-commands/private/node-bin/node.cmd"
  [ -f "$CAND" ] && NODE="$CAND"
fi
if [ -z "$NODE" ]; then
  echo "找不到 node，请手动编辑 $PKG_FILE，在 dependencies 中加入："
  echo '  "dsh-chatgpt-desktop": "file:plugins/dsh-chatgpt-desktop"'
else
  "$NODE" -e '
    const fs = require("fs");
    const file = process.argv[1];
    const j = JSON.parse(fs.readFileSync(file, "utf8"));
    j.dependencies = j.dependencies || {};
    j.dependencies["dsh-chatgpt-desktop"] = "file:plugins/dsh-chatgpt-desktop";
    fs.writeFileSync(file, JSON.stringify(j, null, 2) + "\n");
    console.log("[2/4] package.json 已登记依赖");
  ' "$PKG_FILE"
fi

# 3. 追加 cordis.patch.yml 挂载条目
PATCH_FILE="$PROFILE_DIR/cordis.patch.yml"
if [ -f "$PATCH_FILE" ] && grep -q "dsh-chatgpt-desktop" "$PATCH_FILE"; then
  echo "[3/4] cordis.patch.yml 已存在挂载条目，跳过"
else
  printf -- '\n- insert:\n    - id: chatgpt-desktop-theme\n      name: dsh-chatgpt-desktop\n' >> "$PATCH_FILE"
  echo "[3/4] cordis.patch.yml 已追加挂载条目"
fi

# 4. pnpm install 生成依赖链接
PNPM="$(command -v pnpm || true)"
if [ -z "$PNPM" ] && [ -n "${APPDATA:-}" ]; then
  CAND="$APPDATA/DSH Desktop/runtime-commands/bin/pnpm.cmd"
  [ -f "$CAND" ] && PNPM="$CAND"
fi
if [ -z "$PNPM" ]; then
  echo "[4/4] 未找到 pnpm，请手动在 $PROFILE_DIR 下执行 pnpm install"
else
  (cd "$PROFILE_DIR" && "$PNPM" install --silent)
  echo "[4/4] 依赖链接完成"
fi

echo ""
echo "安装完成！重启 DSH 即可看到 ChatGPT 风格界面。"
echo "可选：接入第三模型 5.6 Terra（Kimi）请见 README.md「可选：接入 Kimi」一节。"
