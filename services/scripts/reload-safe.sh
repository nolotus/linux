#!/bin/bash
# 安全重载 profile 到运行中的 mihomo 内核。
#
# 为什么不能直接 PUT /configs：mihomo 在 TUN 已开启时热重载会「拆掉旧 TUN 再建新的」，
# 若此刻设备仍被占用，新建会失败，留下「Meta 网卡在、但没有 IPv4 也没有策略路由」的半残状态，
# 且此后任何热重载都无法恢复（只能重启内核）。本脚本先原子关掉 TUN，再整体加载配置，
# 让 TUN 每次都是干净的单次激活；加载后再校验状态并重试到收敛。
#
# 用法: reload-safe.sh [日志标签]
set -uo pipefail

VERGE_DIR="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
PROFILE="$VERGE_DIR/profiles/nolotus.yaml"
# socket 路径可覆盖：便于在隔离环境里做测试，避免误打到真机内核
SOCK="${VERGE_MIHOMO_SOCK:-/tmp/verge/verge-mihomo.sock}"
TAG="${1:-reload-safe}"
MAX_ATTEMPTS=3

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$TAG] $*"; }

tun_live() {  # true / false / 空（内核未就绪）
  curl -s --max-time 5 --unix-socket "$SOCK" http://localhost/configs 2>/dev/null \
    | python3 -c 'import sys,json;print(str(json.load(sys.stdin)["tun"]["enable"]).lower())' 2>/dev/null
}

tun_wanted() {  # profile 期望的 tun 状态：true / false / unknown
  python3 - "$PROFILE" <<'PY' 2>/dev/null
import sys
try:
    import yaml
    cfg = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))
    print(str(bool((cfg.get("tun") or {}).get("enable"))).lower())
except Exception:
    print("unknown")
PY
}

refresh_gui_timestamp() {
  # GUI 的订阅卡片显示 profiles.yaml 里的 updated 字段；该条目无 url，Verge 不会自己更新，
  # 且每次启动都会用内存里的旧值把它回写掉（表现为卡片一直显示建条目那天）。
  # 每次真正加载 profile 时刷一遍，让卡片时间 = 配置实际生效时间。
  python3 - "$VERGE_DIR/profiles.yaml" <<'PYEOF'
import sys, time

path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
except OSError:
    sys.exit(0)

in_target = False
for i, line in enumerate(lines):
    if line.lstrip().startswith("- uid:"):   # 容错缩进形式
        # 只认 nolotus 那条，多 profile 时不会刷错条目
        in_target = line.split(":", 1)[1].strip() == "nolotus"
    elif in_target and line.strip().startswith("updated:"):
        indent = line[: len(line) - len(line.lstrip())]
        lines[i] = f"{indent}updated: {int(time.time())}\n"
        open(path, "w", encoding="utf-8").write("".join(lines))
        sys.exit(0)
PYEOF
}

# 互斥：守护进程的 core-start 重载与手工 sync 可能并发，
# 两个实例交错执行「关 TUN / 加载」会互相踩（实测出现过 TUN 被对方关掉的瞬时窗口）
LOCK="$VERGE_DIR/.reload-safe.lock"
acquire_lock() {
  exec 9>"$LOCK"
  if ! flock -w 60 9; then
    log "ERROR: 等待其它重载实例超时（60s）"
    exit 1
  fi
}

wait_ready() {
  for _ in $(seq 1 15); do
    [ -n "$(tun_live)" ] && return 0
    sleep 1
  done
  return 1
}

put_profile() {
  curl -s --max-time 10 --unix-socket "$SOCK" -X PUT http://localhost/configs \
    -H 'Content-Type: application/json' -d "{\"path\":\"$PROFILE\"}" -o /dev/null -w '%{http_code}'
}

tun_off() {
  curl -s --max-time 10 --unix-socket "$SOCK" -X PATCH http://localhost/configs \
    -H 'Content-Type: application/json' -d '{"tun":{"enable":false}}' -o /dev/null -w '%{http_code}'
}

[ -S "$SOCK" ] || { log "ERROR: 内核 socket 不存在，跳过"; exit 1; }
[ -f "$PROFILE" ] || { log "ERROR: profile 不存在: $PROFILE"; exit 1; }

acquire_lock
wait_ready || { log "ERROR: 内核 API 一直未就绪"; exit 1; }

refresh_gui_timestamp

want=$(tun_wanted)

for attempt in $(seq 0 "$MAX_ATTEMPTS"); do
  if [ "$(tun_live)" = "true" ]; then
    log "先关闭 TUN（http $(tun_off)）"     # TUN 开着时热重载会拆建撞车
    sleep 2
  fi
  code=$(put_profile)
  if [ "$code" != "204" ]; then log "ERROR: 加载失败 http $code"; exit 1; fi
  sleep 3

  got=$(tun_live)
  if [ "$want" = "unknown" ] || [ "$got" = "$want" ]; then
    log "Profile loaded OK (tun: expected=$want actual=$got)"
    exit 0
  fi
  log "WARN: TUN expected=$want actual=$got，第 $((attempt + 1)) 次重试"
done

log "ERROR: TUN 状态未收敛 (expected=$want actual=$(tun_live))"
exit 1
