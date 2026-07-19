#!/usr/bin/env bash
# Shell 环境一键安装
# 适用：Fedora 44 (GNOME)
set -euo pipefail

GH_PROXY="https://gh-proxy.com"

echo "==> 1/5 安装 dnf 包"
sudo dnf install -y zsh fzf ripgrep fd-find zoxide eza btop git-delta bat tmux

echo "==> 2/5 安装 starship"
if ! command -v starship >/dev/null 2>&1 && [ ! -x ~/.local/bin/starship ]; then
  mkdir -p ~/.local/bin
  curl -fsSL -o /tmp/starship.tar.gz \
    "$GH_PROXY/https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
  tar -xzf /tmp/starship.tar.gz -C ~/.local/bin
  rm -f /tmp/starship.tar.gz
fi

echo "==> 3/5 写入配置"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SCRIPT_DIR/zshrc" ~/.zshrc
mkdir -p ~/.config
cp -f "$SCRIPT_DIR/starship.toml" ~/.config/starship.toml

echo "==> 4/5 切换默认 shell 到 zsh"
if [ "$(getent passwd $USER | cut -d: -f7)" != "/usr/bin/zsh" ]; then
  chsh -s /usr/bin/zsh
fi

echo "==> 5/5 验证"
echo "默认 shell: $(getent passwd $USER | cut -d: -f7)"
echo "starship:   $(~/.local/bin/starship --version 2>/dev/null | head -1)"
echo
echo "完成！注销重新登录后 zsh 与 starship 生效。"
echo "若要立即体验：exec zsh"
