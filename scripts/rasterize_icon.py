#!/usr/bin/env python3
"""Turn a designer SVG icon into the app's raster icon set.

Renders the SVG at 128 px through headless Chrome (no cairo/rsvg needed on a
Mac), then writes the same alpha mask in each colour variant the app picks
from (see AppAssetIcon): white base, ink, accent, muted and profile.

  python3 scripts/rasterize_icon.py path/to/solar_x.svg settings_x
  python3 scripts/rasterize_icon.py path/to/solar_x.svg settings_x --keep-colour

--keep-colour writes only the base file with the SVG's own colours (for icons
the design colours on purpose, like the red «log out» mark).

Needs Google Chrome and Pillow (`pip install pillow`).
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SIZE = 128
ROOT = Path(__file__).resolve().parents[1] / "assets/icons"
VARIANTS = {
    "": (255, 255, 255),
    "ink": (23, 23, 25),
    "accent": (47, 111, 208),
    "muted": (119, 121, 125),
    "profile": (207, 209, 210),
}


def render(svg: Path, out: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "icon.html"
        page.write_text(
            '<html><body style="margin:0;background:transparent">'
            f'<img src="file://{svg.resolve()}" '
            f'style="width:{SIZE}px;height:{SIZE}px;display:block"></body></html>'
        )
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--allow-file-access-from-files",
                "--default-background-color=00000000",
                "--force-device-scale-factor=1",
                f"--window-size={SIZE},{SIZE}",
                f"--screenshot={out}",
                f"file://{page}",
            ],
            check=True,
            capture_output=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("svg", type=Path)
    parser.add_argument("name", help="file name without extension, e.g. settings_about")
    parser.add_argument("--keep-colour", action="store_true")
    args = parser.parse_args()

    source_dir = ROOT / "source" / ("settings" if args.name.startswith("settings_") else "")
    source_dir.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.svg, source_dir / f"{args.name}.svg")

    with tempfile.TemporaryDirectory() as tmp:
        rendered = Path(tmp) / "rendered.png"
        render(args.svg, rendered)
        image = Image.open(rendered).convert("RGBA")
        if args.keep_colour:
            image.save(ROOT / "raster" / f"{args.name}.png")
            return
        alpha = image.getchannel("A")
        for folder, colour in VARIANTS.items():
            target = ROOT / "raster" / folder / f"{args.name}.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            tinted = Image.new("RGBA", image.size, (*colour, 0))
            tinted.putalpha(alpha)
            tinted.save(target)


if __name__ == "__main__":
    main()
