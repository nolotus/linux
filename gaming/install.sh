#!/usr/bin/env bash
# 游戏环境一键安装
# 适用：Fedora 44 / AMD GPU
set -euo pipefail

echo "==> 1/3 安装游戏工具"
sudo dnf install -y \
  vulkan-tools \
  mangohud \
  gamescope \
  gamemode \
  mesa-dri-drivers.i686 \
  mesa-vulkan-drivers.i686

echo "==> 2/3 验证 Vulkan"
vulkaninfo --summary 2>&1 | grep -E "Vulkan Instance|deviceName" | head -3 || echo "警告：vulkaninfo 未正常输出"

echo "==> 3/3 完成"
echo
echo "下一步："
echo "  Steam 启动参数：mangohud gamemoderun %command%"
echo "  Steam → 设置 → 兼容性 → 启用 Steam Play（Proton Experimental）"
