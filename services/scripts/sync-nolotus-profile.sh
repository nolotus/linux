#!/bin/bash
# 从 clash-configs 仓库同步最新配置到本机 Clash Verge Rev profile，并安全热重载。
# 用法: sync-nolotus-profile.sh
set -euo pipefail

REPO="$HOME/clash-configs"
VERGE_DIR="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
PROFILE="$VERGE_DIR/profiles/nolotus.yaml"
TMP_PROFILE="$PROFILE.tmp"

# 校验失败时清掉临时文件，别在 profile 目录留垃圾
trap 'rm -f "$TMP_PROFILE"' EXIT

# 拉取失败（比如仓库里正有未提交改动）不该让整个同步中断：
# 工作区内容仍是有效配置来源，提示一句后继续
if ! git -C "$REPO" pull --ff-only; then
  echo "WARN: git pull 失败（仓库可能有未提交改动），改用当前工作区内容继续" >&2
fi

mkdir -p "$(dirname "$PROFILE")"
if [ -f "$PROFILE" ]; then          # 首次部署时 profile 还不存在
  cp -p "$PROFILE" "$PROFILE.bak.$(date +%Y%m%d%H%M%S)"
fi

# 先写临时文件、校验通过再原子替换：
# 否则源配置一旦非法，生效路径已被写入破损内容，内核此刻重启就会直接读到坏配置
python3 "$VERGE_DIR/localize-profile.py" "$REPO/clash/mihomo.yaml" "$TMP_PROFILE"
/usr/bin/verge-mihomo -t -f "$TMP_PROFILE"
mv -f "$TMP_PROFILE" "$PROFILE"

"$VERGE_DIR/reload-safe.sh" sync
