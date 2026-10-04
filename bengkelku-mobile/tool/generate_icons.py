#!/usr/bin/env python3
"""Buat ikon Android/iOS/web dari assets/logo/app_icon_1024.png (RGB, tanpa alpha)."""
import json, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
sq = Image.open("assets/logo/app_icon_1024.png").convert("RGB")
for d, s in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    sq.resize((s, s), Image.LANCZOS).save(f"android/app/src/main/res/mipmap-{d}/ic_launcher.png")
iconset = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
if os.path.isdir(iconset):
    c = json.load(open(f"{iconset}/Contents.json"))
    for img in c["images"]:
        size = float(img["size"].split("x")[0]); sc = int(img["scale"][0])
        fn = img.get("filename") or f"Icon-{img['size']}@{sc}x.png"
        img["filename"] = fn
        px = int(round(size * sc))
        sq.resize((px, px), Image.LANCZOS).save(f"{iconset}/{fn}")
    json.dump(c, open(f"{iconset}/Contents.json", "w"), indent=2)
for s, fn in [(192, "web/icons/Icon-192.png"), (512, "web/icons/Icon-512.png"),
              (192, "web/icons/Icon-maskable-192.png"), (512, "web/icons/Icon-maskable-512.png"),
              (32, "web/favicon.png")]:
    sq.resize((s, s), Image.LANCZOS).save(fn)
print("icons generated")
