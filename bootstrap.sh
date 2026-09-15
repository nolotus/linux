#!/usr/bin/env bash
# Linux 系统一键恢复脚本
# 适用：Fedora 44 (GNOME) 重装后快速恢复全部优化配置
#
# 用法：
#   git clone https://gh-proxy.com/https://github.com/nolotus/linux.git ~/linux
#   cd ~/linux && bash bootstrap.sh
#
# 该脚本依次执行各模块的 install.sh，顺序敏感：
#   system -> shell -> fonts -> ibus-rime -> gaming -> gnome -> input-remapper -> services
#   (先配镜像/DNS/工具链，再字体、输入法、游戏，最后桌面/鼠标/服务)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log() { echo -e "${GREEN}==> $1${NC}"; }
warn() { echo -e "${YELLOW}!! $1${NC}"; }
err() { echo -e "${RED}!! $1${NC}"; }

# 0. 前置检查
log "0/9 前置检查"
[ "$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')" = "Fedora Linux" ] || { err "非 Fedora 系统，脚本中止"; exit 1; }
command -v dnf >/dev/null || { err "无 dnf，中止"; exit 1; }
[ "$(id -u)" = 0 ] && { err "请不要用 root 运行，脚本会用 sudo/pkexec 提权"; exit 1; }
log "当前用户：$USER，系统：$(rpm -E %{fedora})"

# 1. 系统级优化（DNF 镜像 + DNS + VA-API + tuned + environment.d）
log "1/9 系统级优化"
[ -f system/install.sh ] && bash system/install.sh || warn "system/install.sh 不存在，跳过"

# 2. Shell 与现代工具链（含 Ghostty 配置）
log "2/9 Shell 与现代工具链"
[ -f shell/install.sh ] && bash shell/install.sh || warn "shell/install.sh 不存在，跳过"

# 3. 字体
log "3/9 字体配置"
[ -f fonts/install.sh ] && bash fonts/install.sh || warn "fonts/install.sh 不存在，跳过"

# 4. 输入法
log "4/9 输入法（IBus + Rime + 雾凇拼音）"
[ -f ibus-rime/install.sh ] && bash ibus-rime/install.sh || warn "ibus-rime/install.sh 不存在，跳过"

# 5. 游戏优化
log "5/9 游戏优化（AMD GPU + Vulkan 工具）"
[ -f gaming/install.sh ] && bash gaming/install.sh || warn "gaming/install.sh 不存在，跳过"

# 6. GNOME 桌面（键位交换 / Dock / 全屏空间 / 扩展 / 壁纸）
log "6/9 GNOME 桌面配置"
[ -f gnome/install.sh ] && bash gnome/install.sh || warn "gnome/install.sh 不存在，跳过"

# 7. 鼠标侧键映射（input-remapper）
log "7/9 鼠标侧键映射"
[ -f input-remapper/install.sh ] && bash input-remapper/install.sh || warn "input-remapper/install.sh 不存在，跳过"

# 8. 用户级 systemd 服务
log "8/9 用户级服务（llama-server / 游戏守护 / 主题同步 / Clash 重载）"
[ -f services/install.sh ] && bash services/install.sh || warn "services/install.sh 不存在，跳过"

# 9. 总结
log "9/9 完成"
echo
echo "─────────────────────────────"
echo " 全部模块应用完成"
echo "─────────────────────────────"
echo
echo "下一步："
echo "  1. 注销重新登录（zsh/starship/fontconfig/扩展/键位/鼠标侧键全部在重登后生效）"
echo "  2. Super+Space 切换到 Rime 输入法"
echo "  3. Firefox about:config 启用 VA-API 硬件解码"
echo
echo "验证命令："
echo "  echo \$SHELL                       # 应为 /usr/bin/zsh"
echo "  fc-match sans-serif                # Adwaita Sans（西文优先修复）"
echo "  fc-match monospace                 # JetBrainsMono Nerd Font"
echo "  fc-match 'sans-serif:lang=zh'      # MiSans"
echo "  resolvectl status | grep 'Current DNS'   # 223.5.5.5"
echo "  vainfo 2>&1 | grep -c Entrypoint   # >5"
echo "  gsettings get org.gnome.desktop.input-sources xkb-options   # 键位交换"
echo "  gnome-extensions list --enabled    # dash-to-dock / screentospace / hidetopbar"
echo "  grep grammar ~/.config/ibus/rime/build/rime_ice.schema.yaml  # 语法模型"
echo
