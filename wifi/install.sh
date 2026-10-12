#!/usr/bin/env bash
# WiFi 诊断工具安装
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 安装 iperf3（带宽/丢包测试）"
sudo dnf install -y iperf3

echo "==> 部署诊断脚本"
mkdir -p ~/.local/bin
cp -f "$SCRIPT_DIR/diag.sh" ~/.local/bin/wifi-diag
chmod +x ~/.local/bin/wifi-diag
echo "    已安装 wifi-diag（~/.local/bin 需在 PATH 中）"
echo
echo "用法："
echo "  wifi-diag              # 诊断默认接口 wlp35s0"
echo "  wifi-diag wlan0        # 指定接口"
echo "  iperf3 -c <对端IP>     # 与对端测带宽/丢包/抖动"
