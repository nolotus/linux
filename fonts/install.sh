#!/usr/bin/env bash
# 字体配置一键安装
# 适用：Fedora 44 (GNOME)
# 说明：Noto CJK（生僻字兜底）自动安装；MiSans（中文主字体）需手动下载；
#       Inter（西文主字体）自动安装；JetBrainsMono Nerd Font 自动下载
set -euo pipefail

GH_PROXY="https://gh-proxy.com"

echo "==> 1/6 安装 Noto CJK 字体包（生僻字兜底）"
sudo dnf install -y \
  google-noto-sans-cjk-vf-fonts \
  google-noto-serif-cjk-vf-fonts \
  google-noto-sans-mono-cjk-vf-fonts

echo "==> 2/6 检查 MiSans 中文字体（界面中文主字体）"
if ls ~/.local/share/fonts/MiSans/*.ttf >/dev/null 2>&1; then
  echo "    MiSans 已安装"
else
  echo "    未检测到 MiSans —— 中文将回退到 Noto。"
  echo "    请从小米官方下载字体包，解压 .ttf 到 ~/.local/share/fonts/MiSans/ 后重跑本脚本："
  echo "      https://hyperos.mi.com/font/zh/download/"
fi

echo "==> 3/6 安装 Inter 西文字体（界面西文主字体，用户级免 root）"
if fc-list | grep -qi "Inter"; then
  echo "    Inter 已安装"
else
  # 取 Fedora 仓库的 rsms-inter-fonts，但不装系统级：
  # 只下载 rpm 并解出字体文件到 ~/.local/share/fonts，避免 sudo 和污染系统字体目录
  TMP="$(mktemp -d)"
  (cd "$TMP" && dnf download -y --destdir "$TMP" rsms-inter-fonts >/dev/null 2>&1) || true
  RPM="$(ls "$TMP"/rsms-inter-fonts*.rpm 2>/dev/null | head -1)"
  if [ -n "$RPM" ]; then
    mkdir -p "$TMP/x"
    (cd "$TMP/x" && rpm2cpio "$RPM" | cpio -idm >/dev/null 2>&1)
    mkdir -p ~/.local/share/fonts
    find "$TMP/x" -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.ttc' \) \
      -exec cp -n {} ~/.local/share/fonts/ \;
    echo "    已解出 $(find ~/.local/share/fonts -iname 'Inter*.ttf' | wc -l) 个 Inter 字体文件"
  else
    echo "    !! 未能取得 rsms-inter-fonts（需要网络/Fedora 仓库）"
    echo "       手动下载：https://github.com/rsms/inter/releases"
  fi
  rm -rf "$TMP"
fi

echo "==> 4/6 下载 JetBrainsMono Nerd Font（若尚未安装）"
if ! fc-list | grep -q "JetBrainsMono Nerd Font"; then
  mkdir -p ~/.local/share/fonts/JetBrainsMono
  # Nerd Font release 资产较大（~60MB），用 gh-proxy 加速
  curl -L -o /tmp/jbmono.zip \
    "$GH_PROXY/https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  cd /tmp && unzip -q -o jbmono.zip -d JetBrainsMono
  cp JetBrainsMono/*.ttf ~/.local/share/fonts/JetBrainsMono/ 2>/dev/null || true
  rm -rf /tmp/JetBrainsMono /tmp/jbmono.zip
fi

echo "==> 5/6 应用 fontconfig 配置"
mkdir -p ~/.config/fontconfig/conf.d
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SCRIPT_DIR/fonts.conf" ~/.config/fontconfig/fonts.conf
ln -sf ~/.config/fontconfig/fonts.conf ~/.config/fontconfig/conf.d/99-user-fonts.conf

echo "==> 6/6 刷新字体缓存"
fc-cache -f

echo
echo "完成！验证："
echo "  fc-match sans-serif          -> $(fc-match sans-serif)"
echo "  fc-match monospace           -> $(fc-match monospace)"
echo "  fc-match 'sans-serif:lang=zh' -> $(fc-match 'sans-serif:lang=zh')"
echo
echo "GNOME 界面字体（Inter Medium 11.5 + subpixel 抗锯齿）由 gnome/install.sh 的 dconf 应用。"
