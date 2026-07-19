# 系统级优化

系统：Fedora 44 (GNOME) / AMD Ryzen 5600 + RX 7900 XT

## 优化项

| 项目 | 优化前 | 优化后 |
|---|---|---|
| DNF 镜像 | 默认 metalink（慢） | 清华 mirrors.tuna.tsinghua.edu.cn |
| DNF 配置 | 默认串行 | fastestmirror + 10 并行 + deltarpm |
| DNS | 路由器 192.168.31.1 | 阿里 223.5.5.5 + 腾讯 119.29.29.29 |
| VA-API 硬件解码 | 未启用 | mesa Gallium + AV1/H.264/H.265/VP9 全格式 |
| tuned profile | throughput-performance | desktop（更平衡） |
| 不必要服务 | ModemManager/avahi/sssd-kcm 运行 | 禁用 |

## 一键应用

```bash
bash install.sh
```

## DNS 配置说明

⚠️ **不要启用 DNSOverTLS**，在国内会导致部分域名解析失败、网络变慢甚至崩溃。

当前配置（`/etc/systemd/resolved.conf.d/dns.conf`）：
```ini
[Resolve]
DNS=223.5.5.5 2400:3200::1
FallbackDNS=119.29.29.29 8.8.8.8
```

NetworkManager 连接配置（避免被路由器 DNS 覆盖）：
```bash
nmcli connection modify "有线连接 1" \
  ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes \
  ipv4.dns "223.5.5.5 119.29.29.29" ipv6.dns "2400:3200::1"
nmcli connection up "有线连接 1"
```

## DNF 镜像说明

`fedora.repo` 和 `fedora-updates.repo` 把 metalink 改成清华 baseurl。
已禁用 metalink（注释保留），启用 baseurl。

`dnf.conf` 启用：
- `fastestmirror=True`：从镜像列表选最快
- `max_parallel_downloads=10`：10 路并行
- `deltarpm=True`：增量包，省带宽

## VA-API 硬件解码

```bash
sudo dnf install -y libva-utils gstreamer1-vaapi ffmpeg
vainfo  # 验证，应显示 radeonsi + 各种 profile
```

Firefox 启用硬件加速（about:config）：
- `media.ffmpeg.vaapi.enabled` = true
- `media.hardware-video-decoding.force-enabled` = true
- `gfx.webrender.all` = true

MPV 自动启用，无需额外配置。

## tuned profile

```bash
tuned-adm profile desktop      # 桌面用，平衡响应与省电
tuned-adm active               # 查看当前
```

替代选项：
- `throughput-performance`：吞吐优先（服务器风格）
- `accelerator-performance`：禁用 C-states，最低延迟
- `balanced`：通用

## 禁用不必要服务

```bash
# ModemManager：3G/4G 模块管理，桌面用不到
sudo systemctl disable --now ModemManager

# avahi：mDNS 服务发现，除非用局域网打印机共享
sudo systemctl disable --now avahi-daemon

# sssd-kcm：Kerberos 缓存，除非加入 AD 域
sudo systemctl disable --now sssd-kcm
```

## 卸载

```bash
# 恢复 metalink
sudo cp /etc/yum.repos.d/fedora.repo.bak.* /etc/yum.repos.d/fedora.repo
# 恢复 DNS
sudo rm /etc/systemd/resolved.conf.d/dns.conf
nmcli connection modify "有线连接 1" ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no ipv4.dns "" ipv6.dns ""
# 恢复 profile
sudo tuned-adm profile throughput-performance
```
