# 游戏优化（AMD GPU）

系统：Fedora 44 / AMD Ryzen 5 5600 + RX 7900 XT

## 驱动选择

**用开源 Mesa 即可，不要装 amdgpu-pro。**

- Mesa 26.1.4 已支持 RDNA3 (Navi 31) 全部特性
- amdgpu-pro 闭源驱动在 Fedora 上维护差、与内核易冲突、性能无明显优势
- AMD 开源驱动是 Linux 游戏首选，Valve/Steam Deck 同款

## 已装工具

| 工具 | 作用 |
|---|---|
| mesa-dri-drivers 26.1.4 | OpenGL/Vulkan 开源驱动 |
| mesa-vulkan-drivers | Vulkan 1.4 支持 |
| vulkan-tools | vulkaninfo 验证 |
| gamemode | 游戏时自动调优 CPU 调度/内核参数 |
| mangohud | 游戏内显示 FPS/CPU/GPU/温度叠加层 |
| gamescope | Valve 微合成器，可强制分辨率/HDR |

## GPU 性能

7900 XT 默认功耗上限 265W 已是 PP 表最大值，**无需任何手动操作**——AMD 开源驱动默认满血，游戏时自动升频到 2075MHz SCLK / 1249MHz MCLK。

如想确认频率跑满，用 mangohud 看叠加层即可。

## Steam / Proton 配置

Steam 启动游戏时加参数：
- `mangohud %command%` - 显示帧率叠加层
- `gamemoderun %command%` - 启用 gamemode 优化
- `gamescope -W 2560 -H 1440 -r 144 %command%` - 强制分辨率/刷新率

Steam → 设置 → 兼容性 → 勾选"为所有其他产品启用 Steam Play" → 选 Proton Experimental。

## 内核参数

当前 `/etc/default/grub` 或 `/boot/loader/entries/`：
```
amdgpu.gpu_recovery=1
```

可选追加（解锁更多 PP 功能，但可能影响稳定性）：
```
amdgpu.ppfeaturemask=0xffffffff
```

## 验证

```bash
# Vulkan 工作
vulkaninfo --summary | head -5

# OpenGL
glxinfo | grep "OpenGL version"   # 4.6 Mesa 26.1.4

# VA-API 硬件解码
vainfo | grep -c Entrypoint       # >5

# GPU 状态
sudo gpu-profile.sh status
```

## 常见问题

**风扇 0 RPM**：正常，7900 XT 待机被动散热，温度上来后自动转。

**游戏帧率低**：
1. `sudo gpu-profile.sh performance`
2. 检查 `mangohud` 显示的 GPU 频率是否跑满
3. Steam 用 Proton Experimental，别用旧版本

**Proton 游戏崩溃**：装 32 位库
```bash
sudo dnf install -y mesa-dri-drivers.i686 mesa-vulkan-drivers.i686
```

## 卸载

```bash
sudo dnf remove -y vulkan-tools mangohud gamescope
```
