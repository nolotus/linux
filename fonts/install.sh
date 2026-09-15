#!/usr/bin/env bash
# 字体配置一键安装
# 适用：Fedora 44 (GNOME)
# 说明：Noto CJK（生僻字兜底）自动安装；MiSans（界面主字体）需手动下载；JetBrainsMono 自动下载
set -euo pipefail

GH_PROXY="https://gh-proxy.com"

echo "==> 1/5 安装 Noto CJK 字体包（生僻字兜底）"
sudo dnf install -y \
  google-noto-sans-cjk-vf-fonts \
  google-noto-serif-cjk-vf-fonts \
  google-noto-sans-mono-cjk-vf-fonts

echo "==> 2/5 检查 MiSans 中文字体（界面主字体）"
if ls ~/.local/share/fonts/MiSans/*.ttf >/dev/null 2>&1; then
  echo "    MiSans 已安装"
else
  echo "    未检测到 MiSans —— fontconfig 将回退到 Noto。"
  echo "    请从小米官方下载字体包，解压 .ttf 到 ~/.local/share/fonts/MiSans/ 后重跑本脚本："
  echo "      https://hyperos.mi.com/font/zh/download/"
fi

echo "==> 3/5 下载 JetBrainsMono Nerd Font（若尚未安装）"
if ! fc-list | grep -q "JetBrainsMono Nerd Font"; then
  mkdir -p ~/.local/share/fonts/JetBrainsMono
  # Nerd Font release 资产较大（~60MB），用 gh-proxy 加速
  curl -L -o /tmp/jbmono.zip \
    "$GH_PROXY/https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  cd /tmp && unzip -q -o jbmono.zip -d JetBrainsMono
  cp JetBrainsMono/*.ttf ~/.local/share/fonts/JetBrainsMono/ 2>/dev/null || true
  rm -rf /tmp/JetBrainsMono /tmp/jbmono.zip
fi

echo "==> 4/5 应用 fontconfig 配置"
mkdir -p ~/.config/fontconfig/conf.d
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SCRIPT_DIR/fonts.conf" ~/.config/fontconfig/fonts.conf
ln -sf ~/.config/fontconfig/fonts.conf ~/.config/fontconfig/conf.d/99-user-fonts.conf

echo "==> 5/5 刷新字体缓存"
fc-cache -f

echo
echo "完成！验证："
echo "  fc-match sans-serif          -> $(fc-match sans-serif)"
echo "  fc-match monospace           -> $(fc-match monospace)"
echo "  fc-match 'sans-serif:lang=zh' -> $(fc-match 'sans-serif:lang=zh')"
