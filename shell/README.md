# Shell 与终端环境

系统：Fedora 44 (GNOME)
目标：zsh + starship + 现代工具链，替代默认 bash 的简陋体验。

## 工具清单

| 工具 | 替代 | 说明 |
|---|---|---|
| zsh | bash | 更强的补全、历史、glob |
| starship | 默认 PS1 | 跨 shell 现代提示符，显示 git/语言版本/时间 |
| fzf | - | 模糊搜索（Ctrl+R 历史、Ctrl+T 文件） |
| ripgrep (rg) | grep | 速度更快的递归搜索 |
| fd-find (fd) | find | 更人性化的查找 |
| eza | ls | 带图标、git 状态的 ls |
| bat | cat | 带语法高亮的 cat |
| zoxide (z) | cd | 基于频率的智能跳转 |
| git-delta | git diff | 美化 diff/blkame 输出 |
| btop | top/htop | 现代系统监控 |
| ghostty | GNOME Terminal | GPU 加速终端（配置/主题随仓库部署，含剪贴板兼容设置） |

## 一键安装

```bash
bash install.sh
```

脚本会：安装 dnf 包 → 下载 starship → 写入 zshrc/starship.toml → 部署 Ghostty 配置 → 切换默认 shell 到 zsh。

## 手动步骤

### 1. 安装 dnf 包

```bash
sudo dnf install -y zsh fzf ripgrep fd-find zoxide eza btop git-delta bat tmux
```

### 2. 安装 starship（不在 dnf 仓库）

```bash
mkdir -p ~/.local/bin
curl -fsSL -o /tmp/starship.tar.gz \
  https://gh-proxy.com/https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz
tar -xzf /tmp/starship.tar.gz -C ~/.local/bin
```

### 3. 写入配置

```bash
cp zshrc ~/.zshrc
cp starship.toml ~/.config/starship.toml
```

### 4. 切换默认 shell

```bash
chsh -s /usr/bin/zsh
```

重新登录后生效。

### 5. 部署 Ghostty 终端配置

```bash
cp -rf ghostty/config ~/.config/ghostty/config
cp -rf ghostty/themes ~/.config/ghostty/themes
```

- 主题跟随 GNOME 日夜模式（`light:GitHub Light Default,dark:GitHub Dark Dimmed`）
- 剪贴板兼容层：`copy-on-select`；Ctrl+C（有选区复制、无选区透传 SIGINT）；`Super+C/V` 跨应用复制粘贴别名（详见 `ghostty/config` 内注释）
- 未安装 ghostty 时：`sudo dnf copr enable agriffis/ghostty-nightly && sudo dnf install -y ghostty`

## 常用快捷键

| 键 | 作用 |
|---|---|
| `Ctrl+R` | fzf 模糊搜索历史命令 |
| `Ctrl+T` | fzf 选择文件插入命令行 |
| `Alt+C` | fzf 模糊 cd |
| `z <关键词>` | zoxide 智能跳转（如 `z linux` 跳到 linux 目录） |
| `Ctrl+P` / `Ctrl+N` | 历史上一条/下一条 |

## 别名速记

```
ls   -> eza (带图标+git)
ll   -> eza -lh
la   -> eza -lah
lt   -> eza --tree (树状)
cat  -> bat
grep -> rg
find -> fd
top  -> btop
gs/gl/gd/gp/gpl -> git 系列
.. / ... / .... -> 上级目录
```

## API key 安全

`.zshrc` 不再硬编码密钥。把密钥放到：

```bash
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/opencode.conf << 'EOF'
OPENCODE_API_KEY=your_key_here
EOF
chmod 600 ~/.config/environment.d/opencode.conf
```

systemd 用户会话会自动加载到所有进程的环境变量，zshrc 末尾也会再 source 一次。**这个目录不要提交到 git**。

## 卸载

```bash
chsh -s /bin/bash
sudo dnf remove -y zsh fzf ripgrep fd-find zoxide eza btop git-delta
rm ~/.local/bin/starship ~/.zshrc ~/.config/starship.toml
rm -rf ~/.config/ghostty
```
