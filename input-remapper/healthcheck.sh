#!/usr/bin/env bash
# input-remapper 注入健康检查（由 input-remapper-healthcheck.timer 每 60 秒调用）
#
# 解决什么问题：
#   input-remapper 自带的 udev 规则（99-input-remapper.rules）只在真实 USB 重新枚举
#   触发 add 事件时才 autoload。设备"软掉线"（内核 fd 断裂但 USB 未重新枚举、不产生
#   udev 事件）会让注入循环停掉、进程却还活着，注入从此失效且不会自愈。
#   实测案例：2026-11-06 00:25 鼠标软掉线后注入丢失，udev 全程无 input 事件记录。
#
# 判据：注入正常时 input-remapper-service 会持有物理事件节点的 fd；丢失时没有。
#   无侵入 —— 只读 lsof 结果，不 grab 设备，不干扰正常注入。
#
# 退出码：0 = 正常，或已成功恢复；非 0 = 检查/恢复失败（由 systemd 记录为 failed）
set -uo pipefail

IR_HOME="${IR_HOME:-/home/nolotus}"
CFG_DIR="$IR_HOME/.config/input-remapper-2"
CTRL="/usr/bin/input-remapper-control"
# 侧键所在的物理键盘接口（by-id 是稳定路径，不受 eventN 编号漂移影响）。
# 换鼠标后此路径随设备序列号变化，需同步修改。
DEV_ID="${IR_DEV_ID:-/dev/input/by-id/usb-Rapoo_Rapoo_Gaming_Device_2607-54L-if01-event-kbd}"
TAG="input-remapper-hc"

# 依赖缺失必须显式失败：不能把"查不到"当成"无 fd"，否则会每轮误触发 autoload
if ! command -v lsof >/dev/null 2>&1; then
    logger -t "$TAG" "缺少 lsof，跳过检查（不触发恢复）"
    exit 1
fi

[ -e "$DEV_ID" ] || exit 0
dev="$(readlink -f "$DEV_ID" 2>/dev/null)" || exit 0
[ -e "$dev" ] || exit 0

# 设备路径必须是 /dev/input/event*。防止 DEV_ID 被环境变量污染（例如解析成 /dev/null）
# 后把错误路径传给 autoload，制造"注入丢失"的假象。
case "$dev" in
    /dev/input/event*) ;;
    *) logger -t "$TAG" "设备路径异常（$dev），放弃本次检查"; exit 1 ;;
esac

# 服务不在则重启，并按实际就绪状态等待（不盲等固定秒数）
if ! systemctl is-active --quiet input-remapper.service; then
    logger -t "$TAG" "service 不在运行，重启"
    if ! systemctl restart input-remapper.service; then
        logger -t "$TAG" "重启失败，放弃本次检查"
        exit 1
    fi
    for _ in $(seq 1 20); do
        systemctl is-active --quiet input-remapper.service && break
        sleep 0.5
    done
    if ! systemctl is-active --quiet input-remapper.service; then
        logger -t "$TAG" "重启后服务仍未就绪，放弃本次检查"
        exit 1
    fi
fi

holders="$(lsof -n "$dev" 2>/dev/null | awk 'NR>1 && $1 ~ /^input-rem/{printf "%s ", $2}')"
[ "${DEBUG:-0}" = 1 ] && echo "dev=$dev holders=[${holders}]"

if [ -n "$holders" ]; then
    exit 0   # 注入在线
fi

logger -t "$TAG" "注入丢失（$dev 无 input-remapper fd），触发 autoload"
if ! out="$("$CTRL" --config-dir "$CFG_DIR" --command autoload --device "$dev" 2>&1)"; then
    printf '%s\n' "$out" | grep -v -E 'UserWarning|pydantic|from pydantic' | logger -t "$TAG"
    logger -t "$TAG" "autoload 失败"
    exit 1
fi
printf '%s\n' "$out" | grep -v -E 'UserWarning|pydantic|from pydantic' | logger -t "$TAG"
exit 0
