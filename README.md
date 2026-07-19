# Linux 系统优化配置

Fedora 44 (GNOME) 的系统优化与配置备份。重装系统后跑一次 `bootstrap.sh` 即可恢复全部优化。

## 模块

| 模块 | 说明 | 关键内容 |
|---|---|---|
| [`system/`](system/) | 系统级优化 | DNF 清华镜像、阿里 DNS、VA-API 硬件解码、tuned desktop、禁用冗余服务 |
| [`shell/`](shell/) | Shell 与终端 | zsh + starship + fzf/rg/fd/eza/bat/zoxide/git-delta/btop + git 全局配置 |
| [`fonts/`](fonts/) | 字体配置 | Noto CJK SC 中文 + JetBrainsMono Nerd Font 终端，fontconfig 映射 Windows 字体名 |
| [`ibus-rime/`](ibus-rime/) | 输入法 | IBus + Rime + 雾凇拼音（现代词库）+ 八股文语法模型（长句准确） |
| [`gaming/`](gaming/) | 游戏优化 | AMD 开源 Mesa 驱动 + Vulkan + gamemode + mangohud + gamescope + GPU 性能模式切换 |

## 一键恢复（重装系统后）

```bash
# 1. 克隆仓库（国内用 gh-proxy 加速）
git clone https://gh-proxy.com/https://github.com/nolotus/linux.git ~/linux
cd ~/linux

# 2. 一键应用全部模块
bash bootstrap.sh
```

`bootstrap.sh` 按顺序执行各模块的 `install.sh`：system → shell → fonts → ibus-rime → gaming。
顺序敏感（先配镜像加速后面下载，再装工具链，再字体，输入法，最后游戏）。

完成后**注销重新登录**让 zsh/starship/fontconfig 生效。

## 单模块应用

只想应用某个模块：

```bash
cd ~/linux
bash system/install.sh     # 系统优化
bash shell/install.sh      # Shell 环境
bash fonts/install.sh      # 字体
bash ibus-rime/install.sh  # 输入法
```

## 仓库结构

```
linux/
├── bootstrap.sh              # 顶层一键恢复脚本
├── system/
│   ├── install.sh
│   ├── fedora.repo           # 清华镜像
│   ├── fedora-updates.repo
│   ├── dnf.conf              # fastestmirror + 并行下载
│   ├── resolved-dns.conf     # 阿里/腾讯 DNS（无 DoH）
│   └── README.md
├── shell/
│   ├── install.sh
│   ├── zshrc                # zsh 配置（历史/补全/工具集成）
│   ├── starship.toml         # gruvbox_dark 主题
│   ├── gitconfig             # git 全局配置 + delta + alias
│   └── README.md
├── fonts/
│   ├── install.sh
│   ├── fonts.conf            # fontconfig 映射
│   └── README.md
└── ibus-rime/
    ├── install.sh
    ├── rime_ice.custom.yaml  # 关闭拼音提示 + 启用语法模型
    ├── default.custom.yaml   # 精简方案 + 候选词 9
    ├── others/
    │   └── wanxiang-config.yaml  # 万象模型替代配置
    └── README.md
```
## 安全说明

- **密钥不入库**：`OPENCODE_API_KEY` 等敏感信息放 `~/.config/environment.d/*.conf`（chmod 600），由 systemd 自动加载。
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
