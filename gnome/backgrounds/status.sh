#!/usr/bin/env bash
# Show download + install status for the macOS dynamic wallpapers.
cd "$(dirname "$0")"
declare -A EXP=(
  [Mojave.heic]=286984418 [Catalina.heic]=124504568
  [BigSur.heic]=138803942 [Monterey.heic]=98038775)
order=(Mojave.heic Catalina.heic BigSur.heic Monterey.heic)
echo "== macOS dynamic wallpaper status  ($(date +%T)) =="
alive=$(ps -ef | grep -E "fetch.sh|alambic" | grep -v grep | wc -l)
echo "downloader running: $alive process(es)"
for f in "${order[@]}"; do
  cur=$(stat -c%s "$f" 2>/dev/null || echo 0)
  pct=$(python3 -c "print(f'{$cur/${EXP[$f]}*100:.1f}')")
  st="..."; [ "$cur" -eq "${EXP[$f]}" ] && st="DONE"
  printf "  %-12s %6.1f%%  %s\n" "$f" "$pct" "$st"
done
echo "gnome-background-properties entries:"
ls ~/.local/share/gnome-background-properties/mac-*.xml 2>/dev/null | sed 's/^/  /' || echo "  (none yet)"
if [ -f .installed ]; then echo "INSTALL MARKER: present (.installed)"; fi
echo "last log lines:"; tail -3 download.log 2>/dev/null | sed 's/^/  /'
