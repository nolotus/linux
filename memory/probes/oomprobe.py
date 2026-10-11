#!/usr/bin/env python3
"""内存演练探针：每 64 MiB 分配一块并打印进度。

用法（在受控 cgroup 内运行，上限会先拦住它）：
    systemd-run --user --unit oomprobe -p MemoryMax=1G -p MemorySwapMax=0 \
        --wait python3 probes/oomprobe.py

预期：进程在容器上限处被 memcg OOM 杀掉（内核日志 constraint=CONSTRAINT_MEMCG），
      桌面与其它应用无感。
"""
chunks = []
for i in range(64):                      # 最多 4 GiB
    chunks.append(bytearray(64 * 1024 * 1024))
    print("alloc", (i + 1) * 64, "MiB", flush=True)
print("survived", len(chunks) * 64, "MiB")
