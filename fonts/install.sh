#!/usr/bin/env bash
# 字体配置一键安装
# 适用：Fedora 44 (GNOME)
# 前置：用户字体已放在 ~/.local/share/fonts/（如重装系统需先下载 Nerd Font）
set -euo pipefail

GH_PROXY="https://gh-proxy.com"

echo "==> 1/4 安装 Noto CJK 字体包"
sudo dnf install -y \
  google-noto-sans-cjk-vf-fonts \
  google-noto-serif-cjk-vf-fonts \
  google-noto-sans-mono-cjk-vf-fonts

echo "==> 2/4 下载 JetBrainsMono Nerd Font（若尚未安装）"
if ! fc-list | grep -q "JetBrainsMono Nerd Font"; then
  mkdir -p ~/.local/share/fonts/JetBrainsMono
  # Nerd Font release 资产较大（~60MB），用 gh-proxy 加速
  curl -L -o /tmp/jbmono.zip \
    "$GH_PROXY/https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  cd /tmp && unzip -q -o jbmono.zip -d JetBrainsMono
  cp JetBrainsMono/*.ttf ~/.local/share/fonts/JetBrainsMono/ 2>/dev/null || true
  rm -rf /tmp/JetBrainsMono /tmp/jbmono.zip
fi

echo "==> 3/4 应用 fontconfig 配置"
mkdir -p ~/.config/fontconfig/conf.d
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SCRIPT_DIR/fonts.conf" ~/.config/fontconfig/fonts.conf
ln -sf ~/.config/fontconfig/fonts.conf ~/.config/fontconfig/conf.d/99-user-fonts.conf

echo "==> 4/4 刷新字体缓存"
fc-cache -f

echo
echo "完成！验证："
echo "  fc-match sans-serif       -> $(fc-match sans-serif)"
echo "  fc-match monospace        -> $(fc-match monospace)"
echo "  fc-match 'sans-serif:lang=zh' -> $(fc-match 'sans-serif:lang=zh')"
