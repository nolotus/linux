#!/usr/bin/env bash
# Resumable downloader for 4 macOS dynamic wallpapers from a GitHub LFS repo.
# - Refreshes signed URLs (1h expiry) each round via lfs_urls.py; on refresh
#   failure, falls back to existing urls.json (valid until its X-Amz-Expires).
# - Resumes with curl -C -; verifies final byte size per file.
# - Re-runs until all 4 complete; safe to re-invoke.
# Logs to download.log. Run: nohup ./fetch.sh >/dev/null 2>&1 &
set -u
cd "$(dirname "$0")"
LOG=download.log
declare -A EXP=(
  [Mojave.heic]=286984418
  [Catalina.heic]=124504568
  [BigSur.heic]=138803942
  [Monterey.heic]=98038775
)
order=(Mojave.heic Catalina.heic BigSur.heic Monterey.heic)
complete() { local f=$1 s; s=$(stat -c%s "$f" 2>/dev/null || echo 0); [ "$s" -eq "${EXP[$f]}" ]; }

round=0
while true; do
  pending=()
  for f in "${order[@]}"; do complete "$f" || pending+=("$f"); done
  if [ ${#pending[@]} -eq 0 ]; then echo "[$(date +%T)] ALL COMPLETE" >> "$LOG"; break; fi
  round=$((round+1))
  echo "[$(date +%T)] round $round: ${#pending[@]} pending -> ${pending[*]}" >> "$LOG"
  if python3 lfs_urls.py >> "$LOG" 2>&1; then
    echo "[$(date +%T)] urls refreshed" >> "$LOG"
  else
    echo "[$(date +%T)] urls refresh failed -> reuse existing urls.json" >> "$LOG"
  fi
  for f in "${pending[@]}"; do
    name="${f%.heic}"
    url=$(python3 -c "import json;print(json.load(open('urls.json'))['$name'])" 2>/dev/null)
    [ -z "$url" ] && continue
    echo "[$(date +%T)] resume $f (have $(stat -c%s "$f" 2>/dev/null || echo 0)B)" >> "$LOG"
    curl -sL --retry 8 --retry-delay 5 --retry-all-errors --max-time 3000 -C - "$url" -o "$f" \
      -w "[$(date +%T)] curl $f http=%{http_code} got=%{size_download}B time=%{time_total}s\n" >> "$LOG" 2>&1 &
  done
  wait
  new_ok=0
  for f in "${pending[@]}"; do
    s=$(stat -c%s "$f" 2>/dev/null || echo 0)
    if complete "$f"; then
      echo "[$(date +%T)] OK   $f = $s B" >> "$LOG"; new_ok=1
    else echo "[$(date +%T)] PART $f = $s / ${EXP[$f]} B" >> "$LOG"; fi
  done
  # Convert any freshly-completed wallpaper immediately (convert is idempotent
  # and skips files that aren't ready yet).
  if [ "$new_ok" = "1" ]; then
    echo "[$(date +%T)] running convert.py ..." >> "$LOG"
    python3 convert.py >> "$LOG" 2>&1
    touch .installed
  fi
  sleep 5
done
  sleep 5
done

echo "[$(date +%T)] running convert.py ..." >> "$LOG"
if python3 convert.py >> "$LOG" 2>&1; then
  echo "[$(date +%T)] CONVERT OK -> dynamic wallpapers installed" >> "$LOG"
else
  echo "[$(date +%T)] CONVERT FAILED (see log)" >> "$LOG"
fi
