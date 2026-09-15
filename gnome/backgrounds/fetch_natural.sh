#!/usr/bin/env bash
# Download the 10 natural-theme macOS dynamic wallpapers via GitHub LFS,
# then convert each to a GNOME timed slideshow as it completes.
# Resumable (-C -) with retries; refreshes signed URLs each round.
# Run: nohup ./fetch_natural.sh >/dev/null 2>&1 &
set -u
cd "$(dirname "$0")/natural"
LOG=../download_natural.log
: > "$LOG"

# name|expected_bytes
ITEMS=(
  "BigSurMountains|13560081"
  "BigSurNightGrass|17055682"
  "BigSurSucculents|9792846"
  "TheDesert|74285625"
  "TheLake|81427359"
  "Tree|29985989"
  "Valley|33063576"
  "TheCliffs|78365495"
  "Sonoma|20362274"
  "SolarGradients|80850306"
)
# display name|heic filename|slug  (used by the converter)
META=(
  "Big Sur Mountains|BigSurMountains.heic|big-sur-mountains"
  "Big Sur Night Grass|BigSurNightGrass.heic|big-sur-night-grass"
  "Big Sur Succulents|BigSurSucculents.heic|big-sur-succulents"
  "The Desert|TheDesert.heic|the-desert"
  "The Lake|TheLake.heic|the-lake"
  "Tree|Tree.heic|tree"
  "Valley|Valley.heic|valley"
  "The Cliffs|TheCliffs.heic|the-cliffs"
  "Sonoma|Sonoma.heic|sonoma"
  "Solar Gradients|SolarGradients.heic|solar-gradients"
)

declare -A EXP
for line in "${ITEMS[@]}"; do IFS='|' read -r n s <<< "$line"; EXP["$n.heic"]=$s; done
complete() { local f=$1 s; s=$(stat -c%s "$f" 2>/dev/null || echo 0); [ "$s" -eq "${EXP[$f]}" ]; }

# regenerate urls.json from /tmp/natural_urls.json (already has name->url/size)
cp /tmp/natural_urls.json urls.json 2>/dev/null || true

round=0
while true; do
  pending=()
  for line in "${META[@]}"; do
    IFS='|' read -r _ heic _ <<< "$line"
    complete "$heic" || pending+=("$heic")
  done
  if [ ${#pending[@]} -eq 0 ]; then echo "[$(date +%T)] ALL COMPLETE" >> "$LOG"; break; fi
  round=$((round+1))
  echo "[$(date +%T)] round $round: ${#pending[@]} pending -> ${pending[*]}" >> "$LOG"

  for line in "${META[@]}"; do
    IFS='|' read -r disp heic slug <<< "$line"
    complete "$heic" && continue
    url=$(python3 -c "import json;d=json.load(open('urls.json'));print(d['$disp']['url'])" 2>/dev/null)
    [ -z "$url" ] && { echo "[$(date +%T)] no url for $disp" >> "$LOG"; continue; }
    echo "[$(date +%T)] resume $heic (have $(stat -c%s "$heic" 2>/dev/null || echo 0)B)" >> "$LOG"
    curl -sL --retry 8 --retry-delay 5 --retry-all-errors --max-time 1800 -C - "$url" -o "$heic" \
      -w "[$(date +%T)] curl $heic http=%{http_code} got=%{size_download}B time=%{time_total}s\n" >> "$LOG" 2>&1 &
  done
  wait

  # convert any freshly-completed wallpaper immediately
  for line in "${META[@]}"; do
    IFS='|' read -r disp heic slug <<< "$line"
    if complete "$heic"; then
      if [ ! -f "../$slug/slideshow.xml" ]; then
        echo "[$(date +%T)] convert $disp" >> "$LOG"
        exp=$(python3 -c "import json;d=json.load(open('urls.json'));print(d['$disp']['size'])" 2>/dev/null)
        python3 -c "
import sys; sys.path.insert(0,'..')
from convert import process_one
process_one('$disp', '$heic', '$slug', expected=$exp)
" >> "$LOG" 2>&1 && echo "[$(date +%T)] OK $disp" >> "$LOG"
      fi
    fi
  done
  sleep 5
done
touch ../.natural-installed
echo "[$(date +%T)] NATURAL ALL DONE" >> "$LOG"
