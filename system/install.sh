#!/usr/bin/env bash
# 系统级优化一键应用
# 适用：Fedora 44 (GNOME, AMD GPU)
set -euo pipefail

echo "==> 1/5 应用 DNF 镜像与配置"
sudo cp -f fedora.repo /etc/yum.repos.d/fedora.repo
sudo cp -f fedora-updates.repo /etc/yum.repos.d/fedora-updates.repo
sudo cp -f dnf.conf /etc/dnf/dnf.conf
sudo dnf clean all
sudo dnf makecache

echo "==> 2/5 应用 DNS（无 DoH，避免网络问题）"
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo cp -f resolved-dns.conf /etc/systemd/resolved.conf.d/dns.conf
# 让 NetworkManager 不用路由器 DNS 覆盖
nmcli connection modify "有线连接 1" \
  ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
  ipv4.dns "223.5.5.5 119.29.29.29" ipv6.dns "2400:3200::1" 2>/dev/null || true
nmcli connection up "有线连接 1" 2>/dev/null || true
sudo systemctl restart systemd-resolved

echo "==> 3/5 安装 VA-API 硬件解码"
sudo dnf install -y libva-utils gstreamer1-vaapi ffmpeg

echo "==> 4/5 切换 tuned 到 desktop profile"
sudo tuned-adm profile desktop

echo "==> 5/5 禁用不必要服务"
sudo systemctl disable --now ModemManager 2>/dev/null || true
sudo systemctl disable --now avahi-daemon 2>/dev/null || true
sudo systemctl disable --now sssd-kcm 2>/dev/null || true

echo
echo "完成！验证："
echo "  DNS:       $(resolvectl status 2>/dev/null | grep 'Current DNS Server' | head -1)"
echo "  VA-API:    vainfo | head -5"
echo "  tuned:     $(tuned-adm active 2>/dev/null)"
