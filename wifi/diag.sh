#!/usr/bin/env bash
# WiFi 链路一键诊断
# 用法：wifi-diag [接口名，默认 wlp35s0]
# 依赖：iw / nmcli（NetworkManager）/ iperf3（测速另跑）
set -euo pipefail

IFACE="${1:-wlp35s0}"

echo "== 当前链路 =="
iw dev "$IFACE" link 2>/dev/null | grep -E "SSID:|freq:|signal:|bitrate" || { echo "未连接到 $IFACE"; exit 1; }
echo

echo "== 网卡配置 =="
printf "power_save: "; iw dev "$IFACE" get power_save 2>/dev/null
CONN=$(nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | awk -F: -v i="$IFACE" '$2==i{print $1}' | head -1)
if [ -n "$CONN" ]; then
  nmcli -f connection.id,802-11-wireless.powersave connection show "$CONN" 2>/dev/null
fi
echo

echo "== 30 秒链路质量采样 =="
python3 - "$IFACE" <<'PY'
import subprocess, time, re, sys
iface = sys.argv[1]

def station():
    """返回 (tx_packets, tx_retries)；命令失败或字段缺失返回 None（采样无效）"""
    r = subprocess.run(['iw', 'dev', iface, 'station', 'dump'],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None
    txp = re.search(r'tx packets:\s+(\d+)', r.stdout)
    txr = re.search(r'tx retries:\s+(\d+)', r.stdout)
    if not txp or not txr:
        return None
    return (int(txp.group(1)), int(txr.group(1)))

start = station()
if start is None:
    print("!! 起始采样失败（接口未连接或 iw 执行失败），跳过重传率统计")

sigs = []
for i in range(30):
    r = subprocess.run(['iw', 'dev', iface, 'link'], capture_output=True, text=True)
    o = r.stdout if r.returncode == 0 else ''
    s = re.search(r'signal:\s*(-?\d+)', o)
    nss = re.search(r'HE-NSS (\d+)', o)
    if s:
        sigs.append(int(s.group(1)))
        if i % 10 == 0:
            print(f"  t={i:02d}s signal={s.group(1)}dBm NSS={nss.group(1) if nss else '?'}")
    time.sleep(1)
end = station()

if sigs:
    n = len(sigs)
    print(f"\n信号: min={min(sigs)} max={max(sigs)} avg={sum(sigs)/n:.1f} dBm"
          f"（-60 以内佳，-70 以外偏弱；有效样本 {n}/30）")
    print(f"深度衰落(<-75dBm): {sum(1 for s in sigs if s < -75)}/{n}")
else:
    print("\n!! 30 秒内未采到任何信号样本，链路可能已断开")

if start is None or end is None:
    print("重传率：采样失败，无数据")
else:
    dp, dr = end[0] - start[0], end[1] - start[1]
    if dp > 0 and dr >= 0:
        rate = dr / dp
        print(f"30s 新增 tx 包 {dp}，重传 {dr} -> 重传率 {rate*100:.2f}%")
        if rate > 0.05:
            print("!! 重传率 >5%：信道拥挤，按 README 换信道")
        else:
            print("重传率健康（<5%）")
    else:
        print("!! tx 计数器无增长或出现回退（重连/计数器重置），本次采样无效")
PY
echo

echo "== 周边 AP（NetworkManager 扫描，找最干净的信道）=="
nmcli -f IN-USE,SSID,CHAN,SIGNAL device wifi list --rescan yes 2>/dev/null | head -15
echo
echo "判断：优先选 5G 信道里邻居最少的；当前常用干净信道：149 / 157（避开 52-64 的 DFS 信道）"
