#!/usr/bin/env bash
# ptyxis-theme-sync — 让 Ptyxis 调色板跟随 GNOME 日夜模式
# 浅色 → Catppuccin Latte，深色 → Catppuccin Mocha（与 Ghostty 配置一致）
set -u

PROFILE_UUID="$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")"
PROFILE_SCHEMA="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${PROFILE_UUID}/"

apply_palette() {
  case "$1" in
    *prefer-dark*) gsettings set "$PROFILE_SCHEMA" palette 'Catppuccin Mocha' ;;
    *)             gsettings set "$PROFILE_SCHEMA" palette 'Catppuccin Latte' ;;
  esac
}

# 启动时先对齐一次，再持续监听系统外观变化
apply_palette "$(gsettings get org.gnome.desktop.interface color-scheme)"
gsettings monitor org.gnome.desktop.interface color-scheme |
  while read -r change; do
    apply_palette "$change"
  done
