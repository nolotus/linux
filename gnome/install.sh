#!/usr/bin/env bash
# GNOME 桌面配置一键安装（键位交换 / 全屏键 / Dock / 全屏空间 / 扩展 / 壁纸工具链）
# 适用：Fedora 44 (GNOME)
set -euo pipefail

GH_PROXY="https://gh-proxy.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 0/7 前置检查"
if [ -z "${XDG_CURRENT_DESKTOP:-}" ] || [[ "$XDG_CURRENT_DESKTOP" != *GNOME* ]]; then
  echo "!! 当前不是 GNOME 会话，配置将在下次登录 GNOME 时生效"
fi

echo "==> 1/7 安装 Dash to Dock（Fedora 官方包）"
sudo dnf install -y gnome-shell-extension-dash-to-dock

echo "==> 2/7 部署 ScreenToSpace 扩展（全屏 = 独立工作区）"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/screentospace@dilzhan.dev"
if [ ! -d "$EXT_DIR" ]; then
  rm -rf /tmp/ScreenToSpace
  git clone --depth 1 -q "$GH_PROXY/https://github.com/DilZhaan/ScreenToSpace.git" /tmp/ScreenToSpace
  mkdir -p "$EXT_DIR"
  cp -r /tmp/ScreenToSpace/src/. "$EXT_DIR/"
  rm -rf /tmp/ScreenToSpace
else
  echo "    已存在，跳过（删除 $EXT_DIR 可重装）"
fi
glib-compile-schemas "$EXT_DIR/schemas/"

echo "==> 3/7 部署 HideTopBar 扩展（收纳的扩展本体）"
HTB_DIR="$HOME/.local/share/gnome-shell/extensions/hidetopbar@mathieu.bidon.ca"
mkdir -p "$HTB_DIR"
cp -rf "$SCRIPT_DIR/extensions/hidetopbar@mathieu.bidon.ca/." "$HTB_DIR/"
glib-compile-schemas "$HTB_DIR/schemas/"

echo "==> 4/7 应用 dconf 配置"
dconf load /org/gnome/desktop/input-sources/ < "$SCRIPT_DIR/dconf/10-keymap.dconf"
dconf load /org/gnome/desktop/wm/keybindings/ < "$SCRIPT_DIR/dconf/20-keybindings.dconf"
dconf load /org/gnome/shell/extensions/dash-to-dock/ < "$SCRIPT_DIR/dconf/30-dash-to-dock.dconf"
dconf load /org/gnome/shell/extensions/screentospace/ < "$SCRIPT_DIR/dconf/40-screentospace.dconf"
dconf load /org/gnome/shell/extensions/hidetopbar/ < "$SCRIPT_DIR/dconf/45-hidetopbar.dconf"
dconf load /org/gnome/shell/ < "$SCRIPT_DIR/dconf/50-extensions.dconf"
dconf load /org/gnome/desktop/session/ < "$SCRIPT_DIR/dconf/55-session.dconf"
dconf load /org/gnome/desktop/peripherals/touchpad/ < "$SCRIPT_DIR/dconf/56-touchpad.dconf"
dconf load /org/gnome/desktop/background/ < "$SCRIPT_DIR/dconf/57-background.dconf"
dconf load /org/gnome/desktop/interface/ < "$SCRIPT_DIR/dconf/58-interface-fonts.dconf"

echo "==> 5/7 部署 macOS 壁纸工具链（壁纸本体需自行下载）"
BGDIR="$HOME/.local/share/backgrounds/mac"
mkdir -p "$BGDIR"
cp -rf "$SCRIPT_DIR/backgrounds/." "$BGDIR/"
if ! ls "$BGDIR"/*/frame_00.jpg >/dev/null 2>&1; then
  echo "    壁纸帧尚未下载：cd $BGDIR && ./fetch.sh && ./fetch_natural.sh（约几 GB），完成后 ls 各子目录可见帧文件"
fi

echo "==> 7/7 完成"
echo "扩展与键位在注销重新登录后生效。验证：gnome-extensions list --enabled"
