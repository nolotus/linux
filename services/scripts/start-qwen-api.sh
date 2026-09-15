#!/bin/bash
# Qwen3.8-27B OpenAI API - ROCm 7.2.1 Native MTP + Ngram (Extreme Perf & Zero Crash)
# Hardware: AMD Radeon RX 7900 XT (20GB VRAM)
# Context: 96K (98304 tokens) | VRAM: ~18.1GB | RAM Safe: --cache-ram 0
set -euo pipefail

LLAMA_BIN="/home/nolotus/llama-bin/llama-dflash2"
HIP721="/home/nolotus/llama-bin/llama-b8407-ubuntu-24.04-rocm-7.2.1-gfx110X-gfx115X-gfx120X-x64"
LLAMA="$LLAMA_BIN/llama-server"
MODEL="${MODEL:-/home/nolotus/models/Huihui-Qwen3.8-27B-abliterated-UD-Q3_K_XL.gguf}"
CTX_SIZE="${CTX_SIZE:-98304}"
NGL="${NGL:-99}"
PORT="${PORT:-8080}"
LOG="${LOG:-/home/nolotus/llama-server.log}"
PIDFILE="${PIDFILE:-/home/nolotus/llama-server.pid}"
MODE="${1:-start}"

export LD_LIBRARY_PATH="$LLAMA_BIN:$HIP721:${LD_LIBRARY_PATH:-}"
export HIP_VISIBLE_DEVICES=0
export HSA_OVERRIDE_GFX_VERSION=11.0.0
export HSA_ENABLE_SDMA=0
export GPU_MAX_HW_QUEUES=8
export HIP_FORCE_DEV_KERNARG=1
export AMD_LOG_LEVEL=0
export ROCBLAS_USE_HIPBLASLT=1

ARGS=(
  -m "$MODEL"
  -ngl "$NGL"
  -t 6
  -np 1
  --fit off
  -fa on
  -b 2048
  -ub 512
  --cache-type-k q4_0
  --cache-type-v q4_0
  -c "$CTX_SIZE"
  --cache-ram 0
  --spec-type "draft-mtp,ngram-cache"
  --spec-draft-n-max 4
  --spec-draft-p-min 0.60
  --alias "Qwen3.8-27B"
  --host 0.0.0.0
  --port "$PORT"
)

if [[ ! -f "$MODEL" ]]; then
  echo "模型不存在: $MODEL" >&2
  exit 1
fi

case "$MODE" in
  start)
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "已在运行 PID $(cat "$PIDFILE")"
      exit 0
    fi

    if [[ -f "$PIDFILE" ]]; then
      kill "$(cat "$PIDFILE")" 2>/dev/null || true
      sleep 1
      rm -f "$PIDFILE"
    fi

    : > "$LOG"
    nohup "$LLAMA" "${ARGS[@]}" >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    echo "started PID $(cat "$PIDFILE") - Qwen3.8-27B (96K Context + Native MTP) 正在运行，查看 $LOG"
    ;;

  foreground)
    : > "$LOG"
    echo $$ > "$PIDFILE"
    exec "$LLAMA" "${ARGS[@]}" >> "$LOG" 2>&1
    ;;

  stop)
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      kill "$(cat "$PIDFILE")"
      rm -f "$PIDFILE"
      echo "stopped"
    else
      killall -9 llama-server 2>/dev/null || true
      rm -f "$PIDFILE"
      echo "stopped all"
    fi
    ;;

  status)
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "running PID $(cat "$PIDFILE")"
    else
      echo "not running"
      exit 1
    fi
    ;;

  *)
    echo "用法: $0 [start|foreground|stop|status]" >&2
    exit 2
    ;;
esac
