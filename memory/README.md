# memory —— 16GB 机器的内存策略

## 为什么需要

2026-10-11 一次真实事故（证据全部来自 journal）：

- Firefox 的一个站点隔离内容进程在 **56 秒内从 78 MB 涨到 10.1 GiB**（16:29:39 → 16:30:35，`anon-rss`）
- 内核触发全局 OOM（`global_oom`）杀掉它；该进程当时**位于 gnome-shell 的 cgroup**（Firefox 的 scope 建晚了 4 分钟，此前 fork 出的内容进程落在了 shell 的 cgroup）
- 由于 systemd 默认 `OOMPolicy=stop`，**整个 `org.gnome.Shell@user.service` 被停掉** → 桌面消失（黑屏），只能强制断电
- 同一条机制也解释了「Firefox 又挂了」：杀掉一个标签页进程后，整个 Firefox scope 被停掉

**结论：关键不是省内存，而是让失控止步于容器边界，并让桌面永不连坐停机。**

## 策略

1. **容器硬上限** —— Firefox scope `MemoryHigh=6G` / `MemoryMax=7G` / `MemorySwapMax=2G`；测试跑在 `heavy.slice`（`MemoryMax=6G` / swap 1G）；`systemd-run` 直连的 transient 单元由 `run-.service.d` / `run-.scope.d` 兜住（6G / 1G）
2. **不连坐** —— gnome-shell、Firefox、ghostty 的 scope 全部 `OOMPolicy=continue`
3. **回收保护** —— `session.slice MemoryLow=1G`，压力下优先回收别处，不把桌面一起回收（表现为卡顿）
4. **兜底** —— systemd-oomd 恢复 swap 监控（`SwapUsedLimit=80%`）、用户会话压力阈值 70% / 20s；zram `min(ram/2, 8192)`（本机实测 7.8 GiB）+ zstd

> 范围说明：`CPUWeight=500` / `IOWeight=500` / `MemoryMin=250M` / `MemoryLow=0` 是既有的 `systemctl set-property` 残留（落在 `/etc/systemd/system.control/user@uid.service.d/`，数值与 `/etc/uresourced.conf` 默认值相同），本模块不重复管理、也不在回滚段清理。本模块自己设置的是 **`session.slice MemoryLow=1G`**（见策略 3）。

> oomd 阈值必须写在**用户级** `~/.config/systemd/user/-.slice.d/50-oomd.conf`：用户管理器把根 slice 报给 oomd，而 `/usr/lib/systemd/user/slice.d/10-oomd-per-slice-defaults.conf` 给的是 80%，只改系统侧 `user@UID.service` 会被它盖住（实测踩过）。

## 为什么没有磁盘 swap

本机 btrfs 由两个设备组成（`nvme0n1p1` + `nvme0n1p4`，各约 461G / 467G，同一 UUID），内核直接拒绝：

```
BTRFS warning (device nvme0n1p4): swapfile must be on one device
```

**btrfs 的 swapfile 只支持单设备文件系统**，没有办法绕过（loop 设备方案会造成「换页 IO 依赖文件系统、文件系统依赖内存」的循环，不做）。`/boot` 是 ext4 但只有 1.2G 可用，磁盘也没有未分配空间。所以只能靠 zram。

## 取值理由

- **zram `min(ram / 2, 8192)` + zstd**：4 GiB 太紧；12 GiB 已实测「装满时吃掉约 10.4 GB 物理内存、压缩比只有 1.15（高熵数据压不动）」。折中取 `ram/2`（本机 MemTotal 15.53 GiB → `ram/2 ≈ 7.75 GiB` 是绑定项，实测 `disksize = 7.76 GiB`），8192 只是上限
- **`vm.swappiness=180`、`vm.page-cluster=0`**：zram 是随机访问设备，这是 zram 场景的推荐值（`swappiness=10` 是给磁盘 swap 的，对本机反而有害）
- **`watermark_scale_factor=125`、`watermark_boost_factor=0`**：Fedora zram 场景推荐，让回收更早动手
- **三处 `MemoryHigh` 一律设 `infinity`**：限流产生的 stall 会累加进 PSI，反而触发 oomd 误杀（实测 62 MB 的 Clash Verge 被误杀过）
- **`SwapUsedLimit=80%`**：触发条件是**内存与 swap 使用率同时超过 80%**，然后挑 swap 占用最多的 cgroup 杀；系统默认 90% 在 7.8 GiB zram 下约 7.0 GiB 才动手，偏晚
- **`MemorySwapMax` 必须设**：zram 占用的物理内存不计入任何 cgroup，只设 `MemoryMax` 会被绕过
- **浏览器侧设置救不了失控页**：`browser.tabs.unloadOnLowMemory` 只管后台标签，前台页面失控时无效

## 一键应用

```bash
bash memory/install.sh
```

> 脚本会重建 zram 设备（隐含一次 `swapoff`）。内存吃紧时先关掉大程序再跑，避免这次隐式换出本身触发压力。

## 验证（三条路径均已实测）

```bash
swapon --show                                    # zram0 约 7.8G，prio 100
cat /sys/block/zram0/comp_algorithm              # 括号里应为 [zstd]
oomctl | grep -A3 "user@$(id -u).service"        # Memory Pressure Limit: 70.00%
oomctl | grep -A2 'Swap Monitored'               # 应有 Path: /
systemctl --user show org.gnome.Shell@user.service -p OOMPolicy          # continue
systemctl --user show session.slice -p MemoryLow                         # 1G
C=$(systemctl --user show -p ControlGroup --value 'app-gnome-org.mozilla.firefox-*.scope')
awk '{print $1/1073741824" GiB"}' /sys/fs/cgroup$C/memory.max            # 7 GiB
```

演练（脚本在 `probes/`，2026-10-11 全部通过）：

| 路径 | 命令 | 实测证据 |
|---|---|---|
| 内核 memcg OOM | `systemd-run --user --unit oomprobe-final -p MemoryMax=1G -p MemorySwapMax=0 --wait python3 probes/oomprobe.py` | `oom-kill:constraint=CONSTRAINT_MEMCG, oom_memcg=.../oomprobe-final.service`，`Memory cgroup out of memory: Killed process (python3) anon-rss:1046404kB`，桌面无感 |
| oomd 压力杀 | `systemd-run --user --unit oomd-drill2 -p MemoryHigh=300M -p MemorySwapMax=64M -p ManagedOOMMemoryPressure=kill -p ManagedOOMMemoryPressureLimit=20% -p ManagedOOMMemoryPressureDurationSec=5s --wait python3 probes/oomprobe.py` | `systemd-oomd: Killed .../oomd-drill2.service due to memory pressure ... being 34.73% > 20.00% for > 5s`，单元 `Result=oom-kill`，桌面无感 |
| slice 级上限 | `systemd-run --user --slice=heavy.slice --unit heavy-drill --wait python3 probes/oomprobe-big.py` | `oom_memcg=.../heavy.slice`、`task_memcg=.../heavy.slice/heavy-drill.service`，`anon-rss 5730664kB`，桌面无感 |
| transient 兜底 | `systemd-run --user --unit run-probe-verify /bin/sleep 10` | 单元实测 `MemoryMax=6G`、`MemorySwapMax=1G`，drop-in `run-.service.d/50-mem.conf` 已加载 |

## 失效模式

- **ghostty 的每个 surface scope 自带 `ManagedOOMMemoryPressure=kill`，阈值默认 60%**（Ghostty 自己设的）。它比 app.slice 的 80% 更早触发，**一杀就是整个终端标签页连同里面的 agent / 测试**（`OOMPolicy=continue` 管不了 oomd 的整 cgroup 杀）。若遇到，在 `~/.config/systemd/user/app-ghostty-surface-transient-.scope.d/` 加 `ManagedOOMMemoryPressureLimit=80%`，或干脆去掉 kill。
- **Firefox 从终端或其它启动器启动**时 scope 名会变（`app-firefox-*.scope` / `app-org.mozilla.firefox-*.scope`），drop-in 匹配不上，上限不生效（但 Shell 有 `OOMPolicy=continue`，最坏只丢会话）
- **`ManagedOOMPreference=avoid` 的采纳依赖 xattr 写入**，未逐一验证；真正可靠的是 `OOMPolicy=continue`
- **zram 自身占用不算在任何 cgroup 里**（满载约 2G），cgroup 上限管不到它
- **卡顿但不触发 kill**：压力始终达不到 oomd 阈值时会长时间卡顿，`session.slice MemoryLow=1G` 只能缓解
- 唯一仍会死桌面的路径：gnome-shell 自身失控 —— 但它 `OOMScoreAdjust=-1000`，概率极低

## 回滚

```bash
sudo rm /etc/systemd/zram-generator.conf /etc/sysctl.d/99-zram-tuning.conf \
        /etc/systemd/oomd.conf.d/50-local.conf "/etc/systemd/system/-.slice.d/50-oomd-swap.conf"
rm -rf ~/.config/systemd/user/org.gnome.Shell@user.service.d \
       ~/.config/systemd/user/app-gnome-org.mozilla.firefox-.scope.d \
       ~/.config/systemd/user/app-ghostty-surface-transient-.scope.d \
       ~/.config/systemd/user/-.slice.d \
       ~/.config/systemd/user/run-.service.d ~/.config/systemd/user/run-.scope.d
sudo systemctl set-property user@$(id -u).service MemoryHigh=12G \
     ManagedOOMMemoryPressureLimit=60% ManagedOOMMemoryPressureDurationSec=15s
systemctl --user set-property app.slice MemoryHigh=12G
systemctl --user set-property heavy.slice MemoryHigh=4G MemoryMax=6G MemorySwapMax=2G
systemctl --user set-property session.slice MemoryLow=0
sudo systemctl daemon-reload && systemctl --user daemon-reload
```

## 相关但不属于本模块

排查中同时发现：测试运行器反复执行 `systemd-run ... /usr/bin/true`，而 `/usr/bin/true` 在 systemd 把它搬进 cgroup 之前就退出，累积 `Failed with result 'resources'` 的失败单元，最终把用户管理器的作业队列堵死（`systemd-run` 客户端永久挂起，连 `/bin/echo hi` 都起不来）。这是**项目代码的竞态**（bun-nolo 仓库），与内存策略无关，需要另行修复；修法：探针改成 `systemd-run --user --scope true` 或加 `--wait` 跑 `sleep 0.2`。
