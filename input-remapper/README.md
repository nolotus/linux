# input-remapper 鼠标侧键模块

把 Rapoo 游戏鼠标的侧键（设备固件宏 `Ctrl+←` / `Ctrl+→`）映射为 `Super+Alt+←/→`（GNOME 切工作区）。
映射按**设备隔离**：仅拦截 Rapoo 鼠标发出的事件，真实键盘的 Ctrl+←/→（按词移动）不受影响。

## 背景

- Rapoo 鼠标侧键不是标准 BTN_SIDE/BTN_EXTRA，而是鼠标「Keyboard 接口」发出的键盘宏 `Ctrl+← / Ctrl+→`（码 29+105 / 29+106）
- preset 据此把这两个组合映射为 `Super+Alt+←/→`，命中 GNOME 的 `switch-to-workspace` 绑定；与 `gnome/` 模块的全屏空间联动 = 鼠标侧键切换空间
- 代价：该鼠标侧键不再有「前进/后退」语义（本来就没有——固件宏是 Ctrl+方向键）

## 文件

- `presets/Rapoo Rapoo Gaming Device/mac-workspaces.json` —— 映射本体（Ctrl+←/→ → Super+Alt+←/→）
- `config.json` —— autoload（登录后自动加载该 preset）
- `autostart/input-remapper-autoload.desktop` —— 登录自启项（执行 `input-remapper-control --command autoload`）

## 安装

```bash
bash input-remapper/install.sh   # 含 dnf 安装、服务启用、配置部署、加入 input 组
```

之后**注销重新登录**：input 组生效 + 自启接管。

## 更换鼠标时

设备 key 会不同（用 `input-remapper-control --list-devices` 查看），需改 preset 目录名与 `config.json` 的 autoload key；或直接用 GUI（`input-remapper-gtk`）新建。

## 卸载

```bash
input-remapper-control --command stop --device "Rapoo Rapoo Gaming Device"
sudo dnf remove input-remapper
rm -rf ~/.config/input-remapper-2 ~/.config/autostart/input-remapper-autoload.desktop
sudo gpasswd -d "$USER" input
