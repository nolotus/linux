# input-remapper 鼠标侧键模块

把 Rapoo 游戏鼠标的侧键（设备固件宏 `Ctrl+←` / `Ctrl+→`）映射为 `Ctrl+Alt+←/→`（GNOME 切工作区）。
映射按**设备隔离**：仅拦截 Rapoo 鼠标发出的事件，真实键盘的 Ctrl+←/→（按词移动）不受影响。

## 背景

- Rapoo 鼠标侧键不是标准 BTN_SIDE/BTN_EXTRA，而是鼠标「Keyboard 接口」发出的键盘宏 `Ctrl+← / Ctrl+→`（码 29+105 / 29+106；该接口只发这三个码，preset 按方向键单码 105/106 拦截即可）
- preset 据此把方向键码映射为 `Ctrl+Alt+←/→`，命中 GNOME 的 `switch-to-workspace` 绑定；与 `gnome/` 模块的全屏空间联动 = 鼠标侧键切换空间
- 代价：该鼠标侧键不再有「前进/后退」语义（本来就没有——固件宏是 Ctrl+方向键）

## 文件

- `presets/Rapoo Rapoo Gaming Device/WorkspaceSwitch.json` —— 映射本体（Ctrl+←/→ → Ctrl+Alt+←/→）
- `config.json` —— autoload（登录后自动加载该 preset）
- `autostart/input-remapper-autoload.desktop` —— 登录自启项（执行 `input-remapper-control --command autoload`）
- `healthcheck.sh` —— 注入健康检查脚本（见下节）
- `units/input-remapper-healthcheck.service` / `.timer` —— 每 60 秒跑一次健康检查的 system 级单元

## 注入自愈（软掉线兜底）

登录自启与 input-remapper 自带的 udev 规则（`99-input-remapper.rules`）只覆盖两种场景：**登录时**、**真实 USB 重新枚举时**。

覆盖不到的是设备「**软掉线**」：内核 fd 断裂但 USB 未重新枚举，udev 不产生 `add` 事件。此时 daemon 的注入循环停掉、进程却还活着，注入从此失效且不会自愈。

实测证据（2026-11-06 00:25）：

```
input-remapper-service: ERROR: fd broke, was the device unplugged?
input-remapper-service: read loop for /dev/input/event19 stopped
# 之后 journalctl -u systemd-udevd：零条 input 事件 → udev 规则没机会运行
```

`input-remapper-healthcheck.timer` 周期性检查，判据是 **input-remapper-service 是否持有该事件节点的 fd**（用 `lsof` 读，无侵入、不 grab 设备、不干扰正常注入）。注入丢失则自动 `autoload`；service 本身不在则先重启服务。

检查间隔是 `OnUnitActiveSec=60s` 配 `AccuracySec=5s`：**通常约一分钟恢复，不是严格上界**（定时器允许延后，执行与调度也会叠加延迟）。依赖缺失（如没有 `lsof`）时脚本显式失败退出，不会把"查不到"当成"无 fd"去误触发恢复。

手动验证自愈链路：

```bash
DEV=$(readlink -f /dev/input/by-id/usb-Rapoo_Rapoo_Gaming_Device_2607-54L-if01-event-kbd)
sudo systemctl start input-remapper-healthcheck.service
sudo lsof -n "$DEV"                    # 应看到新的 input-remapper fd
journalctl -t input-remapper-hc -n 5   # 应看到"注入丢失…触发 autoload"
```

## 安装

```bash
bash input-remapper/install.sh   # 含 dnf 安装、服务启用、配置部署、加入 input 组、健康检查 timer
```

之后**注销重新登录**：input 组生效 + 自启接管。

## 更换鼠标时

设备 key 会不同（用 `input-remapper-control --list-devices` 查看），需改 preset 目录名与 `config.json` 的 autoload key；或直接用 GUI（`input-remapper-gtk`）新建。

另外 `healthcheck.sh` 里的 `DEV_ID`（by-id 路径含设备序列号 `2607-54L`）与 `preset` 目录名都要同步更新，否则自愈会失效（脚本对设备不存在的情况会静默退出）。

## 卸载

```bash
input-remapper-control --command stop --device "Rapoo Rapoo Gaming Device"
sudo systemctl disable --now input-remapper-healthcheck.timer
sudo rm -f /etc/systemd/system/input-remapper-healthcheck.service \
           /etc/systemd/system/input-remapper-healthcheck.timer \
           /usr/local/sbin/input-remapper-healthcheck
sudo systemctl daemon-reload
sudo dnf remove input-remapper
rm -rf ~/.config/input-remapper-2 ~/.config/autostart/input-remapper-autoload.desktop
sudo gpasswd -d "$USER" input
```
