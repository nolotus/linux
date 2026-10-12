#!/usr/bin/env bash
# 系统级优化一键应用
# 适用：Fedora 44 (GNOME, AMD GPU)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 1/9 应用 DNF 镜像与配置"
sudo cp -f "$SCRIPT_DIR/fedora.repo" /etc/yum.repos.d/fedora.repo
sudo cp -f "$SCRIPT_DIR/fedora-updates.repo" /etc/yum.repos.d/fedora-updates.repo
sudo cp -f "$SCRIPT_DIR/dnf.conf" /etc/dnf/dnf.conf
sudo dnf clean all
sudo dnf makecache

echo "==> 2/9 应用 DNS（无 DoH，避免网络问题）"
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo cp -f "$SCRIPT_DIR/resolved-dns.conf" /etc/systemd/resolved.conf.d/dns.conf
# 让 NetworkManager 不用路由器 DNS 覆盖
nmcli connection modify "有线连接 1" \
  ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
  ipv4.dns "223.5.5.5 119.29.29.29" ipv6.dns "2400:3200::1" 2>/dev/null || true
nmcli connection up "有线连接 1" 2>/dev/null || true
sudo systemctl restart systemd-resolved

echo "==> 3/9 启用 RPM Fusion 仓库（freeworld 编解码/驱动来源，阿里云镜像）"
if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
  sudo dnf install -y \
    https://mirrors.aliyun.com/rpmfusion/free/fedora/rpmfusion-free-release-44.noarch.rpm \
    https://mirrors.aliyun.com/rpmfusion/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm
else
  echo "    RPM Fusion 已启用，跳过"
fi

echo "==> 4/9 安装 VA-API 硬件解码（H.264/H.265 必须用 RPM Fusion freeworld 驱动）"
# Fedora 官方 Mesa 因专利禁用 H.264/H.265 VLD：仅装官方包时 vainfo 只有
# VP9/AV1/JPEG，H.264 全程软解（症状：拖进度条音频超前、画面跟不上）。
# ffmpeg-libs 为 RPM Fusion 完整版（x264/x265/vaapi），会替换 free 栈。
# 注意：--allowerasing 允许 dnf 移除任何与解析结果冲突的已装包，理论上
# 不限于 ffmpeg free 栈（同一事务里的 mesa 驱动替换也走该路径）。
# 若事务异常，回退：sudo dnf swap ffmpeg-libs ffmpeg-free-libs
sudo dnf install -y libva-utils gstreamer1-vaapi
sudo dnf install -y --allowerasing ffmpeg ffmpeg-libs mesa-va-drivers-freeworld

echo "==> 5/9 部署 Firefox VA-API 配置（user.js，免手动 about:config）"
# Firefox profile 目录随安装方式变化：rpm 版在 ~/.mozilla/firefox，
# 本机（及 flatpak / 手动迁移）在 ~/.config/mozilla/firefox。
# 定位优先级：profiles.ini（[Install] 的 Default = 当前使用的 profile，
# 兜底 [Profile*] 的 Default=1）> *.default* glob。
# 遍历全部候选目录，找到有效 profile 才停（避免空目录抢占）。
locate_profile() {
  local moz="$1" rel=""
  [ -d "$moz" ] || return 0
  # 依次尝试 profiles.ini 的 [Install*] Default、[Profile*] Default=1 的 Path；
  # 每个候选都验证拼接后的目录真实存在，无效则继续下一优先级
  # （段名做格式约束：Install 段带十六进制安装 ID（1-16 位，上游不补零），
  #   Profile 段带数字，避免误伤用户自定义的 [InstallFoo] 之类的段）
  rel=$(python3 - "$moz" 2>/dev/null <<'PY' || true
import configparser, os, re, sys
moz = sys.argv[1]
ini = os.path.join(moz, 'profiles.ini')
if not os.path.isfile(ini):
    sys.exit(0)
cp = configparser.ConfigParser()
cp.read(ini)

def resolve(path):
    """ini 的 Path/Default 值 -> 绝对目录；空值或目录不存在返回 None"""
    if not path:
        return None
    full = path if os.path.isabs(path) else os.path.join(moz, path)
    return full if os.path.isdir(full) else None

cands = []
# 1) [Install<十六进制ID>] 段的 Default：Firefox 记录的"当前使用的 profile"。
#    安装 ID 由上游 "%" PRIX64 格式化、不补零，长度 1-16 位不等，
#    故匹配 1-16 位十六进制（过严会漏合法短 hash）
for sec in cp.sections():
    if re.fullmatch(r'Install[0-9A-Fa-f]{1,16}', sec):
        cands.append(cp.get(sec, 'Default', fallback=None))
# 2) [Profile<数字>] 段 Default=1 的 Path：ini 声明的默认 profile
for sec in sorted(cp.sections()):
    if re.fullmatch(r'Profile\d+', sec):
        if cp.get(sec, 'Default', fallback='0') == '1':
            cands.append(cp.get(sec, 'Path', fallback=None))
for c in cands:
    full = resolve(c)
    if full:
        print(full)
        sys.exit(0)
PY
)
  # 3) 最近活动的 profile（prefs.js mtime 最新）。
  #    仅覆盖 MOZ_DIR 直接子目录（Firefox 标准布局），profiles/ 嵌套布局不适用。
  if [ -z "$rel" ]; then
    local prefs newest
    prefs=$(ls -t "$moz"/*/prefs.js 2>/dev/null | head -1 || true)
    if [ -n "$prefs" ]; then
      newest=${prefs#"$moz"/}
      rel="$moz/${newest%%/*}"
    fi
  fi
  # 4) glob 兜底
  if [ -z "$rel" ]; then
    rel=$(find "$moz" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -1 || true)
  fi
  [ -n "$rel" ] || return 0
  case "$rel" in
    /*) printf '%s\n' "$rel" ;;
    *)  printf '%s\n' "$moz/$rel" ;;
  esac
}

PROFILE_DIR=""
for d in ~/.mozilla/firefox ~/.config/mozilla/firefox \
         ~/.var/app/org.mozilla.firefox/.mozilla/firefox; do
  cand=$(locate_profile "$d")
  # 目录确实存在才采用并停止，否则继续下一个候选目录
  if [ -n "$cand" ] && [ -d "$cand" ]; then
    PROFILE_DIR="$cand"
    break
  fi
done

if [ -n "$PROFILE_DIR" ] && [ -d "$PROFILE_DIR" ]; then
  # 覆盖前备份（同名则追加序号，防同秒重复执行覆盖原始备份）
  if [ -f "$PROFILE_DIR/user.js" ]; then
    bak="$PROFILE_DIR/user.js.bak.$(date +%Y%m%d%H%M%S)"
    n=1
    while [ -e "$bak" ]; do
      bak="$PROFILE_DIR/user.js.bak.$(date +%Y%m%d%H%M%S).$n"
      n=$((n + 1))
    done
    cp -f "$PROFILE_DIR/user.js" "$bak"
    echo "    原 user.js 已备份为 $(basename "$bak")"
  fi
  cp -f "$SCRIPT_DIR/firefox/user.js" "$PROFILE_DIR/user.js"
  echo "    已写入 $PROFILE_DIR/user.js"
else
  echo "    未检测到 Firefox profile（候选目录均不存在或无有效 profile）"
  echo "    跳过：先运行一次 Firefox 生成 profile，再重跑 bash system/install.sh"
fi

echo "==> 6/9 安装排障与网络诊断工具"
sudo dnf install -y iperf3 strace ncdu duf yt-dlp

echo "==> 7/9 切换 tuned 到 desktop profile"
sudo tuned-adm profile desktop

echo "==> 8/9 部署 environment.d 环境变量（Mesa 修复 / Firefox Wayland / 代理）"
mkdir -p ~/.config/environment.d
cp -f "$SCRIPT_DIR/environment.d/mesa-fix.conf" ~/.config/environment.d/
cp -f "$SCRIPT_DIR/environment.d/firefox-wayland.conf" ~/.config/environment.d/
cp -f "$SCRIPT_DIR/environment.d/proxy.conf" ~/.config/environment.d/

echo "==> 9/9 禁用不必要服务"
sudo systemctl disable --now ModemManager 2>/dev/null || true
sudo systemctl disable --now avahi-daemon 2>/dev/null || true
sudo systemctl disable --now sssd-kcm 2>/dev/null || true

echo
echo "完成！验证："
echo "  DNS:       $(resolvectl status 2>/dev/null | grep 'Current DNS Server' | head -1)"
echo "  VA-API:    vainfo | grep -c VAProfileH264    # >=3 才算 H.264 硬解就位"
echo "  Firefox:   grep vaapi ~/.mozilla/firefox/*.default*/user.js"
echo "  tuned:     $(tuned-adm active 2>/dev/null)"
echo "  WiFi:      wifi-diag（见 wifi/ 模块）"
