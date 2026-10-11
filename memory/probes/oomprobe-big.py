#!/usr/bin/env python3
"""内存演练探针（大）：最多 10 GiB，用于验证 slice 级上限。

用法（验证 heavy.slice 的 6G 硬上限）：
    systemd-run --user --slice=heavy.slice --unit heavy-drill --wait \
        python3 probes/oomprobe-big.py

预期：内核日志出现 oom_memcg=.../heavy.slice，桌面无感。
"""
chunks = []
for i in range(160):                     # 最多 10 GiB
    chunks.append(bytearray(64 * 1024 * 1024))
    print("alloc", (i + 1) * 64, "MiB", flush=True)
print("survived", len(chunks) * 64, "MiB")
