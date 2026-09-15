# 字体配置

系统：Fedora 44 (GNOME)
目标：中英文统一清晰显示，终端/编辑器用 Nerd Font（带图标）。

## 一键安装

```bash
bash install.sh
```

脚本会：安装 Noto CJK 字体包（生僻字兜底）→ 检查 MiSans（缺失给出官方下载指引）→ 下载 JetBrainsMono Nerd Font → 应用 fontconfig 配置 → 刷新字体缓存。

## 字体选择

| 用途 | 字体 | 说明 |
|---|---|---|
| 中文 sans-serif | MiSans | 界面主字体，较 Noto 更圆润（官方渠道下载，见 install.sh） |
| 中文 sans-serif 兜底 | Noto Sans CJK SC | Fedora 自带，生僻字覆盖 |
| 中文 serif | Noto Serif CJK SC | Fedora 自带，宋体类 |
| 中文 monospace | Noto Sans Mono CJK SC | Fedora 自带，等宽中文 |
| 英文/终端 mono | JetBrainsMono Nerd Font | 用户已装在 `~/.local/share/fonts/` |
| 西文前置 | Adwaita Sans | 防止 CJK 字体的拉丁字形抢占西文 |

> 终端字体已装在 `~/.local/share/fonts/JetBrainsMono/`，如重装系统需要重新下载，见 install.sh。

## 配置说明

### fonts.conf

放在 `~/.config/fontconfig/fonts.conf`，并用 `~/.config/fontconfig/conf.d/99-user-fonts.conf` 软链启用。

要点：
- `sans-serif` **前置 `Adwaita Sans`**：Fedora 的 google-noto-sans-cjk-vf 会把 CJK 排到 sans-serif 最前，导致英文也被渲染成 CJK 拉丁字形
- 中文回退：`MiSans` 优先（较 Noto 更圆润），`Noto Sans CJK SC` 兜底生僻字
- `monospace` 优先 `JetBrainsMono Nerd Font`（终端、编辑器自动受益）
- `Droid Sans Fallback` → `MiSans` + `Noto Sans CJK SC`
- `宋体`/`SimSun` → `Noto Serif CJK SC`
- `黑体`/`SimHei`/`微软雅黑`/`Microsoft YaHei` → `MiSans` + `Noto Sans CJK SC`
  （很多网页/CrossOver 应用请求这些 Windows 字体名，统一映射到 MiSans）

## 验证

```bash
fc-match sans-serif        # Adwaita Sans（西文优先）
fc-match serif             # Noto Serif CJK SC
fc-match monospace         # JetBrainsMono Nerd Font
fc-match 'sans-serif:lang=zh'   # MiSans
fc-match 'monospace:lang=zh'    # JetBrainsMono Nerd Font
fc-match 'Droid Sans Fallback'  # MiSans（已被替换）
```

## 终端/编辑器手动设置

GNOME Terminal / 其他基于 GTK 的终端：
- 字体设为 `JetBrainsMono Nerd Font` 或 `JetBrainsMono Nerd Font Mono`
  （`Mono` 版本把 Nerd Font 图标放在双宽单元，终端更整齐；`Propo` 比例版用于编辑器）

VS Code：`settings.json` 加
```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font",
"editor.fontFamily": "JetBrainsMono Nerd Font, 'Noto Sans Mono CJK SC'"
```

## 卸载

```bash
rm ~/.config/fontconfig/conf.d/99-user-fonts.conf ~/.config/fontconfig/fonts.conf
fc-cache -f
```
