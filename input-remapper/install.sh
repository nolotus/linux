#!/usr/bin/env bash
# input-remapper 鼠标侧键映射一键安装（Rapoo 侧键 → Super+Alt+←/→ 切工作区）
# 适用：Fedora 44 (GNOME)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESET_DIR="$HOME/.config/input-remapper-2"

echo "==> 1/5 安装 input-remapper"
sudo dnf install -y input-remapper

echo "==> 2/5 启用 system 服务"
sudo systemctl enable --now input-remapper

echo "==> 3/5 部署配置（preset + autoload + 登录自启）"
mkdir -p "$PRESET_DIR/presets/Rapoo Rapoo Gaming Device" ~/.config/autostart
cp -f "$SCRIPT_DIR/config.json" "$PRESET_DIR/config.json"
cp -f "$SCRIPT_DIR/presets/Rapoo Rapoo Gaming Device/mac-workspaces.json" \
  "$PRESET_DIR/presets/Rapoo Rapoo Gaming Device/mac-workspaces.json"
cp -f "$SCRIPT_DIR/autostart/input-remapper-autoload.desktop" ~/.config/autostart/

echo "==> 4/5 将用户加入 input 组（CLI 枚举设备所需）"
sudo usermod -aG input "$USER"

echo "==> 5/5 完成"
echo "需要注销重新登录（input 组生效 + 登录自启接管本次注入）。"
echo "重登后验证：input-remapper-control --command autoload  （应输出 Autoloading...）"
echo "说明：映射仅作用于 Rapoo 鼠标设备；真实键盘的 Ctrl+←/→ 不受影响。"
