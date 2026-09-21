# Linux 系统优化配置

Fedora 44 (GNOME) 的系统优化与配置备份。重装系统后跑一次 `bootstrap.sh` 即可恢复全部优化。

## 模块

| 模块 | 说明 | 关键内容 |
|---|---|---|
| [`system/`](system/) | 系统级优化 | DNF 清华镜像、阿里 DNS、VA-API 硬件解码、tuned desktop、environment.d 环境变量、禁用冗余服务 |
| [`shell/`](shell/) | Shell 与终端 | zsh + starship + fzf/rg/fd/eza/bat/zoxide/git-delta/btop + git 全局配置 + Ghostty 终端配置 |
| [`fonts/`](fonts/) | 字体配置 | Inter 西文主字体 + MiSans 中文主字体（Noto 兜底生僻字）+ JetBrainsMono Nerd Font + subpixel 抗锯齿 + fontconfig 映射 Windows 字体名 |
| [`ibus-rime/`](ibus-rime/) | 输入法 | IBus + Rime + 雾凇拼音（现代词库）+ 八股文语法模型（长句准确） |
| [`gaming/`](gaming/) | 游戏优化 | AMD 开源 Mesa 驱动 + Vulkan + gamemode + mangohud + gamescope |
| [`gnome/`](gnome/) | 桌面（macOS 风格） | 键位交换 Ctrl⇄Win、全屏=独立空间、Dash to Dock、HideTopBar、界面字体 Inter Medium 11.5 + subpixel 抗锯齿、mac 壁纸工具链 |
| [`input-remapper/`](input-remapper/) | 鼠标侧键 | Rapoo 侧键 → 切换工作区（设备隔离，不影响键盘） |
| [`services/`](services/) | 用户级 systemd 服务 | llama-server、steam-llama-guard、ptyxis-theme-sync、clash-profile-reload |

## 一键恢复（重装系统后）

```bash
# 1. 克隆仓库（国内用 gh-proxy 加速）
git clone https://gh-proxy.com/https://github.com/nolotus/linux.git ~/linux
cd ~/linux

# 2. 一键应用全部模块
bash bootstrap.sh
```

`bootstrap.sh` 按顺序执行各模块的 `install.sh`：system → shell → fonts → ibus-rime → gaming → gnome → input-remapper → services。
顺序敏感（先配镜像加速后面下载，再工具链、字体、输入法、游戏，最后桌面 / 鼠标 / 服务）。

完成后**注销重新登录**让 zsh/starship/fontconfig/扩展/键位/鼠标侧键生效。

## 单模块应用

```bash
cd ~/linux
bash system/install.sh          # 系统优化
bash shell/install.sh           # Shell 环境 + Ghostty
bash fonts/install.sh           # 字体
bash ibus-rime/install.sh       # 输入法
bash gnome/install.sh           # GNOME 桌面（mac 风格）
bash input-remapper/install.sh  # 鼠标侧键
bash services/install.sh        # 用户级服务
```

## 仓库结构

```
linux/
├── bootstrap.sh              # 顶层一键恢复脚本
├── system/
│   ├── install.sh
│   ├── fedora.repo / fedora-updates.repo / dnf.conf
│   ├── resolved-dns.conf     # 阿里/腾讯 DNS（无 DoH）
│   ├── environment.d/        # Mesa 修复 / Firefox Wayland / 代理变量
│   └── README.md
├── shell/
│   ├── install.sh
│   ├── zshrc / starship.toml / gitconfig
│   ├── ghostty/              # Ghostty 终端配置 + 主题
│   └── README.md
├── fonts/
│   ├── install.sh
│   ├── fonts.conf            # Inter 西文 + MiSans 中文 + Noto 兜底 + subpixel 渲染
│   └── README.md
├── ibus-rime/
│   ├── install.sh
│   ├── rime_ice.custom.yaml / default.custom.yaml
│   ├── others/wanxiang-config.yaml
│   └── README.md
├── gaming/
│   ├── install.sh
│   └── README.md
├── gnome/
│   ├── install.sh
│   ├── dconf/                # 9 个 dconf 片段（键位/Dock/全屏空间/扩展…）
│   ├── extensions/           # hidetopbar 扩展本体（EGO 无包）
│   ├── backgrounds/          # mac 壁纸下载/转换工具链（本体不入库）
│   └── README.md
├── input-remapper/
│   ├── install.sh
│   ├── config.json
│   ├── presets/Rapoo Rapoo Gaming Device/mac-workspaces.json
│   ├── autostart/input-remapper-autoload.desktop
│   └── README.md
└── services/
    ├── install.sh
    ├── units/                # 4 个用户级服务
    ├── scripts/              # 服务配套脚本（含 Clash 工具链）
    └── README.md
```

## 安全说明

- **密钥不入库**：`OPENCODE_API_KEY` 等敏感信息放 `~/.config/environment.d/*.conf`（chmod 600），由 systemd 自动加载；clash 订阅 profile、`~/.nolo` 凭据同样不入库。
- **体积资产不入库**：MiSans 字体（78MB）、mac 壁纸（~900MB）、llama 模型 gguf 由脚本或手动下载。
- **`install.sh` 中的备份**：修改系统文件前会备份原文件（`.bak.<timestamp>`）。
- **DNS 不要开 DoH**：在国内会导致部分域名解析失败、网络变慢甚至崩溃（已踩坑）。

## 卸载单个模块

各模块 README.md 末尾均有卸载步骤。

## 硬件参考

- AMD Ryzen 5 5600 + RX 7900 XT + 16G + 1T NVMe
- VA-API 硬件解码支持 AV1/H.264/H.265/VP9
- tuned desktop profile（平衡响应与省电）

## 更新

仓库随系统优化持续更新。本地修改后：

```bash
cd ~/linux
git add -A
git commit -m "update: <描述>"
git push
```
