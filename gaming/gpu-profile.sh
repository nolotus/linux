#!/usr/bin/env bash
# AMD GPU 性能模式切换（游戏 / 日常）
# 用法：
#   sudo gpu-profile.sh performance   # 游戏：锁定最高频率
#   sudo gpu-profile.sh auto          # 日常：自动调频

set -euo pipefail
MODE="${1:-auto}"
GPU_DEV="/sys/class/drm/card1/device"
HWMON=$(ls /sys/class/hwmon/hwmon*/ | grep -l amdgpu 2>/dev/null | head -1)
[ -z "$HWMON" ] && HWMON="/sys/class/hwmon/hwmon1"

case "$MODE" in
  performance|high)
    # 7900 XT 上 "performance" 不支持，用 "high"
    echo "high" > "$GPU_DEV/power_dpm_force_performance_level"
    # 功耗上限拉到最大（PP 表不允许手动锁频率，但功耗上限拉满会让 GPU 自动跑满）
    cat "$HWMON/power1_cap_max" > "$HWMON/power1_cap"
    echo "✓ GPU 性能模式：功耗上限 $(($(cat $HWMON/power1_cap)/1000000))W（自动升频到最高）"
    ;;
  auto|default)
    echo "auto" > "$GPU_DEV/power_dpm_force_performance_level"
    cat "$HWMON/power1_cap_default" > "$HWMON/power1_cap"
    echo "✓ GPU 自动模式：功耗上限 $(($(cat $HWMON/power1_cap)/1000000))W"
    ;;
  status)
    echo "性能级别: $(cat $GPU_DEV/power_dpm_force_performance_level)"
    echo "当前功耗: $(($(cat $HWMON/power1_average)/1000000))W / 上限 $(($(cat $HWMON/power1_cap)/1000000))W"
    echo "温度: $(($(cat $HWMON/temp1_input)/1000))°C"
    echo "风扇: $(cat $HWMON/fan1_input) RPM"
    echo "SCLK: $(($(cat $HWMON/freq1_input)/1000000))MHz"
    ;;
  *)
    echo "用法: $0 {performance|auto|status}"
    exit 1
    ;;
esac
