# IBus + Rime + 雾凇拼音 安装与配置

系统：Fedora 44 (GNOME, Wayland)
目标：替代默认的 libpinyin，获得现代词库 + 长句语法模型，提升长句准确度。

## 一键安装

```bash
bash install.sh
```

脚本会完成：安装软件包 → 下载词库与语法模型 → 写入配置 → 重新部署。

## 手动步骤

### 1. 安装软件包

```bash
sudo dnf install -y ibus-rime librime-octagram
```

- `ibus-rime`：Rime 输入法引擎
- `librime-octagram`：八股文语法模型插件（长句准确度提升的关键）

### 2. 下载雾凇拼音词库

国内访问 github 慢，用 gh-proxy 镜像。

```bash
mkdir -p ~/.config/ibus/rime
curl -L -o /tmp/rime-ice.zip https://gh-proxy.com/https://github.com/iDvel/rime-ice/archive/refs/heads/main.zip
cd /tmp && unzip -q rime-ice.zip
cp -r rime-ice-main/. ~/.config/ibus/rime/
rm -rf ~/.config/ibus/rime/.github ~/.config/ibus/rime/.gitignore ~/.config/ibus/rime/AGENTS.md ~/.config/ibus/rime/.gitattributes
```

### 3. 下载语法模型（40MB，八股文）

```bash
curl -L -o ~/.config/ibus/rime/zh-hans-t-essay-bgw.gram \
  https://gh-proxy.com/https://github.com/lotem/rime-octagram-data/raw/hans/zh-hans-t-essay-bgw.gram
```

> 也可选万象模型（420MB，与雾凇词库紧耦合，更准但下载慢）：
> `https://gh-proxy.com/https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram`
> 对应配置见 `others/wanxiang-config.yaml`。

### 4. 写入配置

把 `rime_ice.custom.yaml` 和 `default.custom.yaml` 复制到 `~/.config/ibus/rime/`：

```bash
cp rime_ice.custom.yaml default.custom.yaml ~/.config/ibus/rime/
```

### 5. 配置输入源（移除 libpinyin，只留 Rime）

```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'rime')]"
gsettings set org.gnome.desktop.input-sources mru-sources "[('ibus', 'rime'), ('xkb', 'us')]"
```

### 6. 重新部署

```bash
rm -rf ~/.config/ibus/rime/build
systemctl --user restart org.freedesktop.IBus.session.GNOME.service
```

用 `Super+Space` 切换到 Rime，首次切换时自动部署。

## 配置说明

### rime_ice.custom.yaml

- 关闭候选字旁的 `［拼音］` 提示（雾凇默认为 corrector.lua 开启，较吵）
- 启用八股文语法模型 `zh-hans-t-essay-bgw`
- 启用 `contextual_suggestions`（上下文建议，长句更准）

### default.custom.yaml

- 方案列表只留 `rime_ice`（默认有 9 个双拼方案，用不到会拖慢部署）
- 候选词数量 5 → 9（减少翻页）

## 更新词库

雾凇拼音更新很活跃（每周都有词库更新），定期重跑第 2 步覆盖即可：

```bash
curl -L -o /tmp/rime-ice.zip https://gh-proxy.com/https://github.com/iDvel/rime-ice/archive/refs/heads/main.zip
cd /tmp && rm -rf rime-ice-main && unzip -q rime-ice.zip
cp -r rime-ice-main/. ~/.config/ibus/rime/
rm -rf ~/.config/ibus/rime/build
systemctl --user restart org.freedesktop.IBus.session.GNOME.service
```

注意：`.custom.yaml` 是 patch 文件，不会被覆盖，配置保留。

## 验证

部署完成后检查：

```bash
# 语法模型是否生效
grep "grammar" ~/.config/ibus/rime/build/rime_ice.schema.yaml
# 应输出：language: "zh-hans-t-essay-bgw"

# 候选词数量
grep page_size ~/.config/ibus/rime/build/default.yaml
# 应输出：page_size: 9
```

## 卸载

```bash
sudo dnf remove -y ibus-rime librime-octagram
rm -rf ~/.config/ibus/rime
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us')]"
```
