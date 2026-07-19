#!/usr/bin/env bash
# 游戏环境一键安装
# 适用：Fedora 44 / AMD GPU
set -euo pipefail

echo "==> 1/4 安装游戏工具"
sudo dnf install -y \
  vulkan-tools \
  mangohud \
  gamescope \
  gamemode \
  mesa-dri-drivers.i686 \
  mesa-vulkan-drivers.i686

echo "==> 2/4 安装 GPU 性能切换脚本"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp -f "$SCRIPT_DIR/gpu-profile.sh" /usr/local/bin/gpu-profile.sh
sudo chmod +x /usr/local/bin/gpu-profile.sh

echo "==> 3/4 验证 Vulkan"
vulkaninfo --summary 2>&1 | grep -E "Vulkan Instance|deviceName" | head -3 || echo "警告：vulkaninfo 未正常输出"

echo "==> 4/4 完成"
echo
echo "GPU 状态："
sudo /usr/local/bin/gpu-profile.sh status 2>&1 || echo "（需要 sudo 查看状态）"
echo
echo "下一步："
echo "  游戏：sudo gpu-profile.sh performance"
echo "  日常：sudo gpu-profile.sh auto"
echo "  Steam 启动参数：mangohud gamemoderun %command%"
