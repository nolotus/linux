#!/usr/bin/env python3
"""Regenerate GitHub LFS signed download URLs into urls.json when they expire.
Robust: retries on network errors; never clobbers existing urls.json on failure."""
import json, time, urllib.request, urllib.error
REPO = "Deeeeeeeeeeeeeeeeeeeee/macOS-Wallpapers"
OBJS = [
    ("Mojave",   "892bfd3fc43ca5dc2240993c2134ae8d77ac987ce9ca98d34d92aab4577350f7", 286984418),
    ("Catalina", "c4b5701343ad010652307807586a7b1a2d9be0bf5724ac4eaf0a1f7e195a3a3e", 124504568),
    ("BigSur",   "8c147037ba6f629b60258970fbda5bec91629ef6c25a0ee8531062f990162561", 138803942),
    ("Monterey", "436b0e5140048a1307fc48f328a97c6879c2a7882661b0965e5e95790023446d",  98038775),
]
body = json.dumps({"operation":"download","transfers":["basic"],
                   "objects":[{"oid":o,"size":s} for _,o,s in OBJS]}).encode()
last = None
for attempt in range(6):
    try:
        req = urllib.request.Request(
            f"https://github.com/{REPO}.git/info/lfs/objects/batch",
            data=body, headers={"Accept":"application/vnd.git-lfs+json",
                                "Content-Type":"application/vnd.git-lfs+json"})
        r = json.load(urllib.request.urlopen(req, timeout=40))
        urls = {name: obj["actions"]["download"]["href"] for (name,_,_),obj in zip(OBJS, r["objects"])}
        json.dump(urls, open("urls.json","w"), indent=2)
        print("refreshed", len(urls), "urls"); break
    except Exception as e:
        last = e; time.sleep(10)
else:
    print("refresh FAILED:", last); raise SystemExit(1)
