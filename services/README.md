# 用户级 systemd 服务模块

自建的用户级服务与配套脚本（重装系统后必丢的部分，随本模块恢复）。

## 服务一览

| 服务 | 作用 | 依赖 |
|---|---|---|
| `llama-server.service` | Qwen3.8-27B ROCm llama-server（OpenAI API，:8080） | `~/llama-bin`、`~/models`（模型 gguf 不入库） |
| `steam-llama-guard.service` | 检测到 Steam 游戏运行时暂停 llama-server（避免抢 VRAM） | 无 |
| `ptyxis-theme-sync.service` | Ptyxis 调色板跟随 GNOME 日夜模式（Latte/Mocha） | Ptyxis |
| `clash-profile-reload.service` | Clash Verge 内核启动后安全重载 profile（TUN 原子重载 + profiles.yaml 自愈） | Clash Verge Rev、[`~/clash-configs`](https://github.com/)（订阅不入库） |

## 脚本清单（部署位置）

- `scripts/start-qwen-api.sh` → `~/start-qwen-api.sh`
- `scripts/steam-llama-guard` → `~/.local/bin/`
- `scripts/ptyxis-theme-sync.sh` → `~/.local/bin/`
- `scripts/reload-profile.sh` / `reload-safe.sh` / `restore-profile.sh` / `sync-nolotus-profile.sh` → Clash Verge Rev 数据目录

## 安装

```bash
bash services/install.sh
```

## 备注

- `start-qwen-api.sh` 与 `llama-server.service` 内含 `/home/nolotus/...` 绝对路径（LLAMA_BIN / MODEL / 日志 / PID），换用户名重现时需对应替换
- Clash 的「单 profile 锁定」设计：`reload-profile.sh` 检测到 current 不是 nolotus 会强制改回（多 profile 场景勿启用）
- 模型文件、clash 订阅 profile（含节点信息）一律不入库

## 卸载

```bash
systemctl --user disable --now llama-server steam-llama-guard ptyxis-theme-sync clash-profile-reload
rm ~/.config/systemd/user/{llama-server,steam-llama-guard,ptyxis-theme-sync,clash-profile-reload}.service
```
