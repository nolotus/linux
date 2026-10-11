#!/usr/bin/env bash
# 内存策略一键应用：zram min(ram/2,8G)/zstd + oomd swap 兜底 + cgroup 硬上限 + 桌面不连坐
# 适用：Fedora 44 (GNOME)；背景、取值理由与验证方法见同目录 README.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_UNIT_DIR="$HOME/.config/systemd/user"
USER_MGR="user@$(id -u).service"
FILES="$SCRIPT_DIR/files"
U_SRC="$FILES/home/.config/systemd/user"

echo "==> 1/7 部署系统级配置（需 sudo）"
sudo install -Dm644 "$FILES/etc/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$FILES/etc/sysctl.d/99-zram-tuning.conf" /etc/sysctl.d/99-zram-tuning.conf
sudo install -Dm644 "$FILES/etc/systemd/oomd.conf.d/50-local.conf" /etc/systemd/oomd.conf.d/50-local.conf
sudo install -Dm644 "$FILES/etc/systemd/system/-.slice.d/50-oomd-swap.conf" "/etc/systemd/system/-.slice.d/50-oomd-swap.conf"

echo "==> 2/7 部署用户级 drop-in（桌面 / Firefox / 终端 / oomd 阈值 / systemd-run 兜底）"
install -Dm644 "$U_SRC/org.gnome.Shell@user.service.d/50-oom.conf" \
  "$USER_UNIT_DIR/org.gnome.Shell@user.service.d/50-oom.conf"
install -Dm644 "$U_SRC/app-gnome-org.mozilla.firefox-.scope.d/50-mem.conf" \
  "$USER_UNIT_DIR/app-gnome-org.mozilla.firefox-.scope.d/50-mem.conf"
install -Dm644 "$U_SRC/app-ghostty-surface-transient-.scope.d/50-oom.conf" \
  "$USER_UNIT_DIR/app-ghostty-surface-transient-.scope.d/50-oom.conf"
# 用户管理器根 slice 的 oomd 阈值：不写这里，systemd 的 slice.d 默认值(80%)会盖住系统侧设置
install -Dm644 "$U_SRC/-.slice.d/50-oomd.conf" "$USER_UNIT_DIR/-.slice.d/50-oomd.conf"
# 兜住绕过 heavy.slice 的 systemd-run transient 单元（测试运行器大量使用）
install -Dm644 "$U_SRC/run-.service.d/50-mem.conf" "$USER_UNIT_DIR/run-.service.d/50-mem.conf"
install -Dm644 "$U_SRC/run-.scope.d/50-mem.conf" "$USER_UNIT_DIR/run-.scope.d/50-mem.conf"

echo "==> 3/7 应用 sysctl（zram 专用：swappiness / page-cluster / 回收水位）"
sudo sysctl --system >/dev/null
sysctl vm.swappiness vm.page-cluster vm.watermark_scale_factor vm.watermark_boost_factor

echo "==> 4/7 重建 zram 设备（min(ram/2,8G) / zstd / prio 100）"
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service

echo "==> 5/7 恢复 systemd-oomd 的 swap 监控并重启"
sudo systemctl restart systemd-oomd

echo "==> 6/7 解除人为内存压力，保留硬上限，并给会话加回收保护"
sudo systemctl set-property "$USER_MGR" MemoryHigh=infinity \
  ManagedOOMMemoryPressure=kill ManagedOOMMemoryPressureLimit=70% \
  ManagedOOMMemoryPressureDurationSec=20s ManagedOOMSwap=auto
systemctl --user set-property app.slice MemoryHigh=infinity
systemctl --user set-property heavy.slice MemoryHigh=infinity MemoryMax=6G MemorySwapMax=1G
# 压力下优先回收别处，别把桌面一起回收（表现为卡顿）
systemctl --user set-property session.slice MemoryLow=1G
systemctl --user daemon-reload

echo "==> 7/7 状态"
echo "-- swap --"
swapon --show
echo "-- zram 算法 --"
cat /sys/block/zram0/comp_algorithm
echo "-- 内存 --"
free -h | head -3
echo "-- 桌面保护 --"
systemctl --user show org.gnome.Shell@user.service -p OOMPolicy -p ManagedOOMPreference
echo "-- oomd（会话阈值应为 70%，Swap Monitored 应为 /）--"
oomctl 2>/dev/null | grep -E "Swap Used Limit|Swap Monitored|user@$(id -u).service" -A3 || true
echo "-- 会话回收保护 --"
systemctl --user show session.slice -p MemoryLow
echo
echo "提示："
echo "  * Firefox / ghostty 的 drop-in 对**新启动**的 scope 生效（重启 Firefox / 终端即可）"
echo "  * gnome-shell 的 OOMPolicy 在**重新登录**后 100% 确认"
echo "  * 本机 btrfs 为双设备，磁盘 swapfile 在内核层不可用，故只用 zram"
echo "  * 验证演练脚本见 probes/（详见 README）"
