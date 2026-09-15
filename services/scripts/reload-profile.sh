#!/bin/bash
# Clash Verge Profile Auto-Reload
#
# 职责：内核每次启动（PID 变化）后，把 profile 安全加载进运行中的内核。
# 加载动作委托 reload-safe.sh（先原子关 TUN 再整体加载，避免 TUN 拆建撞车留下半残状态）。
#
# 注意：本 daemon 是**单 profile 锁定**设计——只要 profiles.yaml 的 current 不是 nolotus，
# 就视为被 GUI 重置并强制改回。多 profile 场景请勿启用。
set -uo pipefail

VERGE_DIR="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
PROFILE="$VERGE_DIR/profiles/nolotus.yaml"
PROFILES_YAML="$VERGE_DIR/profiles.yaml"
SAFE_RELOAD="$VERGE_DIR/reload-safe.sh"
LOG="$VERGE_DIR/reload-profile.log"

FIXED_PROFILES='current: nolotus
items:
- uid: nolotus
  type: remote
  name: nolotus
  file: nolotus.yaml
  updated: 1785305815
- uid: Merge
  type: merge
  name: null
  file: Merge.yaml
  updated: 1785305815
- uid: Script
  type: script
  name: null
  file: Script.js
  updated: 1785305815'

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

fix_profiles_yaml() {
  if ! grep -q "current: nolotus" "$PROFILES_YAML" 2>/dev/null; then
    log "WARNING: profiles.yaml was corrupted (current != nolotus), restoring..."
    # 时间戳按当前时间写，避免恢复出来的卡片又显示成历史日期
    printf '%s\n' "$FIXED_PROFILES" | sed "0,/^  updated:.*/s//  updated: $(date +%s)/" > "$PROFILES_YAML"
    # 首次部署时 profile 可能还没生成（install.sh 先于 sync 启动服务），cp 要容错
    if [ -f "$PROFILE" ]; then
      cp "$PROFILE" "$VERGE_DIR/clash-verge.yaml"
      cp "$PROFILE" "$VERGE_DIR/clash-verge-check.yaml"
    fi
    log "profiles.yaml and clash-verge.yaml restored"
  fi
}

log "=== reload-profile started ==="

last_pid=""
while true; do
  fix_profiles_yaml
  pid=$(pgrep -x verge-mihomo | head -1)
  if [ -n "$pid" ] && [ "$pid" != "$last_pid" ]; then
    sleep 3                    # 等内核把启动配置加载完
    if "$SAFE_RELOAD" core-start >> "$LOG" 2>&1; then
      last_pid="$pid"          # 仅成功才记账，失败留待下个周期重试
    else
      log "WARN: safe reload 未成功，稍后重试 (pid=$pid)"
      sleep 20                 # 退避，别每 5 秒硬撞一次
    fi
  fi
  sleep 5
done
