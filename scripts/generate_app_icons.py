#!/usr/bin/env python3
"""Render the launcher icons (iOS app icon sets, Android mipmaps, previews).

The castle comes from assets/icons/source/app_icon_castle.svg and is placed
to match the owner's reference: the rock runs off the left and bottom
edges, the tower sits in the upper half. Everything is rendered once at 1024 px through headless Chrome and
downsampled, so every size stays crisp.

  python3 scripts/generate_app_icons.py            # write every icon
  python3 scripts/generate_app_icons.py --preview  # only preview PNGs in /tmp

Needs Google Chrome and Pillow.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
ROOT = Path(__file__).resolve().parents[1]
CASTLE = ROOT / "assets/icons/source/app_icon_castle.svg"
SIZE = 1024

# Castle placement in the 1024 frame, fitted to the owner's reference by
# overlap of the castle silhouette (96% IoU): the rock's left side lands on
# the left edge and its foot on the bottom one.
SCALE = 5.35
SHIFT = (-175.1, 80.9)
# The rock's straight left side and flat bottom in raw units, extended past
# the frame so no sliver of background shows under the cliff.
ROCK_LEFT_X, ROCK_LEFT_TOP = 32.4, 124.2
ROCK_BOTTOM_Y, ROCK_RIGHT_X = 175.0, 182.8

# (start colour, end colour, x2, y2) of each variant's linear gradient.
VARIANTS = {
    # Fitted to the reference: light sky at the top left to blue bottom right.
    "default": ("#98DEEA", "#4563FE", 1216, 681),
    "sea": ("#1FC5DA", "#1B6EC9", SIZE, 0),
    "night": ("#2A3965", "#0F1224", SIZE, 0),
    "sunset": ("#FE883F", "#E6407A", SIZE, 0),
}


def svg_for(start: str, end: str, x2: float, y2: float) -> str:
    castle = CASTLE.read_text()
    paths = "\n".join(re.findall(r"<path[^>]*/>", castle, re.S))
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}"
 viewBox="0 0 {SIZE} {SIZE}">
<defs><linearGradient id="bg" gradientUnits="userSpaceOnUse" x1="0" y1="0"
 x2="{x2}" y2="{y2}"><stop offset="0" stop-color="{start}"/>
<stop offset="1" stop-color="{end}"/></linearGradient></defs>
<rect width="{SIZE}" height="{SIZE}" fill="url(#bg)"/>
<g fill="#fff" transform="translate({SHIFT[0]} {SHIFT[1]}) scale({SCALE})">
{paths}
<rect x="-40" y="{ROCK_LEFT_TOP}" width="{ROCK_LEFT_X + 40.3}" height="80"/>
<rect x="-40" y="{ROCK_BOTTOM_Y}" width="{ROCK_RIGHT_X + 40}" height="80"/>
</g>
</svg>"""


def render(svg: str, out: Path) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "icon.html"
        (Path(tmp) / "icon.svg").write_text(svg)
        page.write_text(
            '<html><body style="margin:0">'
            f'<img src="icon.svg" width="{SIZE}" height="{SIZE}"></body></html>'
        )
        shot = Path(tmp) / "shot.png"
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                f"--screenshot={shot}",
                f"--window-size={SIZE},{SIZE}",
                page.as_uri(),
            ],
            check=True,
            capture_output=True,
        )
        image = Image.open(shot).convert("RGB").crop((0, 0, SIZE, SIZE))
    image.save(out)
    return image


def sized(master: Image.Image, px: int) -> Image.Image:
    return master.resize((px, px), Image.Resampling.LANCZOS)


def write_ios(master: Image.Image, iconset: Path) -> None:
    import json

    contents = json.loads((iconset / "Contents.json").read_text())
    for item in contents["images"]:
        name = item.get("filename")
        if not name:
            continue
        points = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        sized(master, round(points * scale)).save(iconset / name)


def write_android(master: Image.Image, suffix: str) -> None:
    res = ROOT / "android/app/src/main/res"
    for folder, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        sized(master, px).save(res / f"mipmap-{folder}/ic_launcher{suffix}.png")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", action="store_true")
    args = parser.parse_args()
    xcassets = ROOT / "ios/Runner/Assets.xcassets"
    for name, (start, end, x2, y2) in VARIANTS.items():
        out = (
            Path(tempfile.gettempdir()) / f"app_icon_{name}.png"
            if args.preview
            else ROOT / f"assets/icons/app/{name}.png"
        )
        master = render(svg_for(start, end, x2, y2), out)
        if args.preview:
            print(out)
            continue
        # The in-app picker shows 192 px previews.
        sized(master, 192).save(out)
        write_ios(master, xcassets / ("AppIcon" if name == "default" else name).__add__(".appiconset"))
        write_android(master, "" if name == "default" else f"_{name}")


if __name__ == "__main__":
    main()
