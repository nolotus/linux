#!/usr/bin/env bash
# IBus + Rime + 雾凇拼音 + 八股文语法模型 一键安装
# 适用：Fedora 44 (GNOME)
set -euo pipefail

GH_PROXY="https://gh-proxy.com"

echo "==> 1/6 安装软件包"
sudo dnf install -y ibus-rime librime-octagram

echo "==> 2/6 下载雾凇拼音词库"
mkdir -p ~/.config/ibus/rime
if [ ! -f /tmp/rime-ice.zip ] || [ "$(stat -c%s /tmp/rime-ice.zip 2>/dev/null || echo 0)" -lt 1000000 ]; then
  curl -L -o /tmp/rime-ice.zip "$GH_PROXY/https://github.com/iDvel/rime-ice/archive/refs/heads/main.zip"
fi
cd /tmp
rm -rf rime-ice-main
unzip -q rime-ice.zip
cp -r rime-ice-main/. ~/.config/ibus/rime/
rm -rf ~/.config/ibus/rime/.github ~/.config/ibus/rime/.gitignore \
        ~/.config/ibus/rime/AGENTS.md ~/.config/ibus/rime/.gitattributes

echo "==> 3/6 下载八股文语法模型 (40MB)"
if [ ! -f ~/.config/ibus/rime/zh-hans-t-essay-bgw.gram ]; then
  curl -L -o ~/.config/ibus/rime/zh-hans-t-essay-bgw.gram \
    "$GH_PROXY/https://github.com/lotem/rime-octagram-data/raw/hans/zh-hans-t-essay-bgw.gram"
fi

echo "==> 4/6 写入配置"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$SCRIPT_DIR/rime_ice.custom.yaml" "$SCRIPT_DIR/default.custom.yaml" ~/.config/ibus/rime/

echo "==> 5/6 配置输入源（移除 libpinyin，只留 Rime）"
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'rime')]"
gsettings set org.gnome.desktop.input-sources mru-sources "[('ibus', 'rime'), ('xkb', 'us')]"

echo "==> 6/6 重新部署"
rm -rf ~/.config/ibus/rime/build
systemctl --user restart org.freedesktop.IBus.session.GNOME.service

echo
echo "完成！按 Super+Space 切换到 Rime 即可使用。"
echo "验证：grep grammar ~/.config/ibus/rime/build/rime_ice.schema.yaml"
