#!/usr/bin/env bash
# input-remapper 鼠标侧键映射一键安装（Rapoo 侧键 → Ctrl+Alt+←/→ 切工作区）
# 适用：Fedora 44 (GNOME)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESET_DIR="$HOME/.config/input-remapper-2"

echo "==> 1/6 安装 input-remapper 与 lsof（健康检查依赖 lsof）"
sudo dnf install -y input-remapper lsof

echo "==> 2/6 启用 system 服务"
sudo systemctl enable --now input-remapper

echo "==> 3/6 部署配置（preset + autoload + 登录自启）"
mkdir -p "$PRESET_DIR/presets/Rapoo Rapoo Gaming Device" ~/.config/autostart
cp -f "$SCRIPT_DIR/config.json" "$PRESET_DIR/config.json"
cp -f "$SCRIPT_DIR/presets/Rapoo Rapoo Gaming Device/WorkspaceSwitch.json" \
  "$PRESET_DIR/presets/Rapoo Rapoo Gaming Device/WorkspaceSwitch.json"
cp -f "$SCRIPT_DIR/autostart/input-remapper-autoload.desktop" ~/.config/autostart/

echo "==> 4/6 将用户加入 input 组（CLI 枚举设备所需）"
sudo usermod -aG input "$USER"

echo "==> 5/6 安装注入健康检查（软掉线自愈）"
# timer 以 root 运行、读不到用户 $HOME，故把家目录写进脚本。
# 用 printf %q 生成可直接求值的赋值行，再整行替换，避免 sed replacement 的转义陷阱。
ir_line="$(printf 'IR_HOME=%q' "$HOME")"
IR_LINE="$ir_line" awk '/^IR_HOME=/ {print ENVIRON["IR_LINE"]; next} {print}' \
  "$SCRIPT_DIR/healthcheck.sh" \
  | sudo tee /usr/local/sbin/input-remapper-healthcheck >/dev/null
sudo chmod 755 /usr/local/sbin/input-remapper-healthcheck
sudo install -m644 "$SCRIPT_DIR/units/input-remapper-healthcheck.service" \
  "$SCRIPT_DIR/units/input-remapper-healthcheck.timer" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now input-remapper-healthcheck.timer

echo "==> 6/6 完成"
echo "需要注销重新登录（input 组生效 + 登录自启接管本次注入）。"
echo "重登后验证：input-remapper-control --command autoload  （应输出 Autoloading...）"
echo "说明：映射仅作用于 Rapoo 鼠标设备；真实键盘的 Ctrl+←/→ 不受影响。"
