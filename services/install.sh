#!/usr/bin/env bash
# 用户级 systemd 服务一键部署（llama-server / steam-guard / ptyxis-theme-sync / clash-reload）
# 适用：Fedora 44 (GNOME)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"
BIN_DIR="$HOME/.local/bin"

echo "==> 1/4 部署脚本"
mkdir -p "$BIN_DIR"
cp -f "$SCRIPT_DIR/scripts/steam-llama-guard" "$BIN_DIR/"
cp -f "$SCRIPT_DIR/scripts/ptyxis-theme-sync.sh" "$BIN_DIR/"
cp -f "$SCRIPT_DIR/scripts/start-qwen-api.sh" "$HOME/"
chmod +x "$BIN_DIR/steam-llama-guard" "$BIN_DIR/ptyxis-theme-sync.sh" "$HOME/start-qwen-api.sh"

echo "==> 2/4 部署 Clash 工具链（需已安装 Clash Verge Rev）"
VERGE_DIR="$HOME/.local/share/io.github.clash-verge-rev.clash-verge-rev"
mkdir -p "$VERGE_DIR"
for s in reload-profile.sh reload-safe.sh restore-profile.sh sync-nolotus-profile.sh; do
  cp -f "$SCRIPT_DIR/scripts/$s" "$VERGE_DIR/"
  chmod +x "$VERGE_DIR/$s"
done

echo "==> 3/4 部署并启用 systemd 用户服务"
mkdir -p "$UNIT_DIR"
cp -f "$SCRIPT_DIR/units/"*.service "$UNIT_DIR/"
systemctl --user daemon-reload
systemctl --user enable --now llama-server.service steam-llama-guard.service ptyxis-theme-sync.service clash-profile-reload.service

echo "==> 4/4 状态"
systemctl --user --no-pager list-units 'llama-server*' 'steam-llama-guard*' 'ptyxis-theme-sync*' 'clash-profile-reload*' || true
echo "提示：llama-server 依赖 ~/llama-bin 与 ~/models（模型不入库）；clash-profile-reload 依赖 Clash Verge Rev 与 ~/clash-configs 仓库"
