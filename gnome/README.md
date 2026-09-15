# GNOME 桌面配置模块

Fedora 44 GNOME 的桌面个性化（macOS 风格工作流）：键位 / 全屏空间 / Dock / 扩展 / 壁纸。
全部通过 dconf 片段 + 扩展部署还原，不依赖手动点选。

## 内容

| 项 | 说明 |
|---|---|
| 键位交换 | Ctrl ⇄ Win 交换（复制粘贴用空格旁键，Mac 手感）；输入法源 us + rime |
| 全屏切换键 | Ctrl+Super+F（对位 Mac 的 Control+Command+F） |
| Dash to Dock | 底部居中、自动隐藏、小圆点指示器 |
| ScreenToSpace | 全屏窗口自动成为独立工作区（trigger 仅 fullscreen） |
| HideTopBar | 自动隐藏顶栏（含其设置） |
| 扩展启用清单 | dash-to-dock / screentospace / hidetopbar |
| 会话 / 触控板 | 禁用空闲熄屏（idle-delay=0）、双指滚动 |
| 壁纸 | macOS 动态壁纸工具链（fetch.sh 系列） + 轮播 dconf 设置 |
| 扩展收纳 | hidetopbar 扩展本体（~176K，EGO 用户目录扩展、无 dnf 包） |

## dconf 片段（install.sh 按此顺序 load）

| 文件 | 目标路径 |
|---|---|
| `dconf/10-keymap.dconf` | `/org/gnome/desktop/input-sources/` |
| `dconf/20-keybindings.dconf` | `/org/gnome/desktop/wm/keybindings/` |
| `dconf/30-dash-to-dock.dconf` | `/org/gnome/shell/extensions/dash-to-dock/` |
| `dconf/40-screentospace.dconf` | `/org/gnome/shell/extensions/screentospace/` |
| `dconf/45-hidetopbar.dconf` | `/org/gnome/shell/extensions/hidetopbar/` |
| `dconf/50-extensions.dconf` | `/org/gnome/shell/`（⚠️ 覆盖扩展启用清单） |
| `dconf/55-session.dconf` | `/org/gnome/desktop/session/` |
| `dconf/56-touchpad.dconf` | `/org/gnome/desktop/peripherals/touchpad/` |
| `dconf/57-background.dconf` | `/org/gnome/desktop/background/` |

## 壁纸

`backgrounds/` 收纳下载/转换脚本（`fetch.sh`、`fetch_natural.sh`、`lfs_urls.py`、`convert.py`、`status.sh`、`urls.json`）与轮播 `slideshow.xml`；壁纸本体（~900MB）不入库，重装后运行脚本重新下载。

## 注意

- 扩展与键位在**注销重新登录**后生效（Wayland 无法热重载新扩展）
- `50-extensions.dconf` 的 load 会覆盖 `enabled-extensions`，如需保留新装系统的其他扩展请先手动合并

## 卸载

- 扩展：`gnome-extensions disable dash-to-dock@micxgx.gmail.com screentospace@dilzhan.dev hidetopbar@mathieu.bidon.ca`
- 键位交换：`gsettings reset org.gnome.desktop.input-sources xkb-options`
