#!/usr/bin/env python3
"""Convert macOS dynamic .heic wallpapers into GNOME timed-slideshow wallpapers.

For each .heic:
  1. Extract every image item to a high-quality JPEG (downscaled to <= MAXW px wide)
     via pillow-heif (libheif) -- no heif-convert / sudo needed.
  2. Parse the Apple `apple_desktop:h24` (time-of-day) or `apple_desktop:solar`
     schedule from the XMP packet. h24 -> exact 24h schedule; solar/unknown ->
     frames spread evenly across 24h in image-sequence order (a smooth day cycle).
  3. Emit a GNOME background slideshow XML (`<static>`+`<transition>` segments,
     total duration 86400s, starttime at midnight) that GNOME cycles by time of day.
  4. Register the slideshow in ~/.local/share/gnome-background-properties/.

GNOME 50 does not natively parse HEIC solar/h24 metadata, so this conversion is
what makes the macOS dynamic wallpaper actually change with time on GNOME.
"""
import os, sys, base64, plistlib, re, html, time
from pathlib import Path
import pillow_heif
from PIL import Image

pillow_heif.register_heif_opener()

BASE  = Path(os.path.expanduser("~/.local/share/backgrounds/mac"))
PROPS = Path(os.path.expanduser("~/.local/share/gnome-background-properties"))
MAXW  = 3840          # cap frame width to display native (4K)
TRANS = 900.0         # crossfade duration (s) between frames

WALLPAPERS = [
    ("Mojave Desert", "Mojave.heic",   "mojave"),
    ("Catalina",      "Catalina.heic", "catalina"),
    ("Big Sur",       "BigSur.heic",   "big-sur"),
    ("Monterey",      "Monterey.heic", "monterey"),
]

EXP = {"Mojave.heic":286984418, "Catalina.heic":124504568,
       "BigSur.heic":138803942, "Monterey.heic":98038775}


def parse_apple_schedule(xmp_bytes, n_frames):
    """Return (kind, [(start_seconds, image_idx), ...]) sorted by start_seconds."""
    if not xmp_bytes:
        return "even", even(n_frames)
    txt = xmp_bytes.decode("utf-8", "replace") if isinstance(xmp_bytes, bytes) else xmp_bytes
    kind, b64 = None, None
    for k in ("h24", "solar"):
        m = re.search(rf"apple_desktop:{k}=\"([A-Za-z0-9+/=]+)\"", txt)
        if m:
            kind, b64 = k, m.group(1); break
    if not b64:
        return "even", even(n_frames)
    try:
        pl = plistlib.loads(base64.b64decode(b64))
    except Exception as e:
        print(f"    plist decode failed ({e}); using even schedule"); return "even", even(n_frames)
    if kind == "h24" and "ti" in pl:
        ti = sorted(pl["ti"], key=lambda e: e["t"])
        secs = [(e["t"] * 86400.0, int(e["i"])) for e in ti]
        return "h24", secs
    if kind == "solar" and "si" in pl:
        # solar: list of {i, a (altitude), z (azimuth)}. Order frames by azimuth across the day:
        # azimuth ~0/360 == noon-ish isn't reliable, so use image-sequence order (already a day cycle).
        return "solar", even(n_frames)
    return kind or "even", even(n_frames)


def even(n):
    return [(i * 86400.0 / n, i) for i in range(n)]


def build_slideshow_xml(frames, schedule, out_xml):
    segs = sorted(schedule, key=lambda s: s[0])
    n = len(segs)
    L = ['<?xml version="1.0"?>', '<background>',
         '  <starttime><year>2026</year><month>1</month><day>1</day>'
         '<hour>0</hour><minute>0</minute><second>0</second></starttime>']
    for k, (t0, idx) in enumerate(segs):
        t1 = segs[(k + 1) % n][0] if k < n - 1 else 86400.0
        dur = max(t1 - t0 - TRANS, 60.0)
        nxt = segs[(k + 1) % n][1]
        L += ['  <static>', f'    <duration>{dur:.1f}</duration>',
              f'    <file>{html.escape(frames[idx])}</file>', '  </static>']
        L += ['  <transition>', f'    <duration>{TRANS:.1f}</duration>',
              f'    <from>{html.escape(frames[idx])}</from>',
              f'    <to>{html.escape(frames[nxt])}</to>', '  </transition>']
    L += ['</background>']
    out_xml.write_text("\n".join(L) + "\n")


def process(name, heic, slug):
    src = BASE / heic
    exp = EXP.get(heic)
    ready = src.exists() and (exp is None or src.stat().st_size == exp)
    if not ready:
        print(f"[skip] {name}: {heic} not ready "
              f"({src.stat().st_size if src.exists() else 0}/{exp or 0}B)")
        return False
    return _convert(name, src, slug)


def process_one(name, heic, slug, expected=None):
    """Public entry: convert a single .heic (path relative to BASE).
    If expected bytes given, verify file size matches before converting."""
    src = BASE / heic
    if expected is not None:
        if not src.exists() or src.stat().st_size != expected:
            print(f"[skip] {name}: {heic} not ready "
                  f"({src.stat().st_size if src.exists() else 0}/{expected}B)")
            return False
    return process(name, heic, slug)


def _convert(name, src, slug):
    outdir = BASE / slug
    outdir.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    print(f"[convert] {name}  <- {src.name} ({src.stat().st_size}B)")
    h = pillow_heif.open_heif(str(src))
    n = len(h)
    print(f"  frames: {n}")
    frames = []
    for i, img in enumerate(h):
        pil = img.to_pillow()
        if pil.mode != "RGB":
            pil = pil.convert("RGB")
        if pil.width > MAXW:
            pil = pil.resize((MAXW, int(pil.height * MAXW / pil.width)), Image.LANCZOS)
        p = outdir / f"frame_{i:02d}.jpg"
        pil.save(p, "JPEG", quality=88, optimize=True)
        frames.append(str(p))
    print(f"  extracted {n} frames in {time.time()-t0:.1f}s")
    kind, sched = parse_apple_schedule(h[0].info.get("xmp", b""), n)
    print(f"  schedule: {kind} ({len(sched)} points)")
    xml = outdir / "slideshow.xml"
    build_slideshow_xml(frames, sched, xml)
    print(f"  slideshow: {xml}")
    prop = PROPS / f"mac-{slug}.xml"
    prop.write_text(
        '<?xml version="1.0"?>\n'
        '<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">\n'
        '<wallpapers>\n'
        '  <wallpaper deleted="false">\n'
        f'    <name>{name} (macOS Dynamic)</name>\n'
        f'    <filename>{xml}</filename>\n'
        f'    <filename-dark>{xml}</filename-dark>\n'
        '    <options>zoom</options>\n'
        '    <shade_type>solid</shade_type>\n'
        '    <pcolor>#000000</pcolor>\n'
        '    <scolor>#000000</scolor>\n'
        '  </wallpaper>\n'
        '</wallpapers>\n')
    print(f"  registered: {prop}")
    return True


def main():
    PROPS.mkdir(parents=True, exist_ok=True)
    if "--test" in sys.argv:
        # validate with the small Mountain Lion file copied into BASE
        src = Path("/tmp/ml.heic")
        if src.exists():
            (BASE / "MountainLion.heic").write_bytes(src.read_bytes())
            process("Mountain Lion (test)", "MountainLion.heic", "mountain-lion-test")
            return
    ok = sum(process(n, h, s) for n, h, s in WALLPAPERS)
    print(f"\nInstalled {ok}/{len(WALLPAPERS)} wallpapers.")
    if ok:
        print("Settings -> Background will list them; they cycle by time of day.")


if __name__ == "__main__":
    main()
