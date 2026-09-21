"""Cut the four static Rubik weights out of the variable font.

Why static cuts: Flutter on iOS renders variable-font weights as a synthetic
bold (FRONTEND-33), so pubspec lists one real file per weight.

The first cuts were subset too tightly and lacked «/», «», dashes, the
ellipsis and «№», so those fell back to the system font (FRONTEND-35). This
keeps the full Latin and Cyrillic ranges and the punctuation, quotes,
currency and arrow blocks the app can show.

Usage (needs fontTools, not a project dependency):
    python3 -m venv /tmp/fontvenv && /tmp/fontvenv/bin/pip install fonttools
    /tmp/fontvenv/bin/python scripts/build_rubik_static.py
"""

from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FONTS = Path(__file__).resolve().parent.parent / "assets" / "fonts"
SOURCE = FONTS / "Rubik-VariableFont_wght.ttf"

WEIGHTS = {"Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700}

# Basic Latin, Latin-1, Latin Extended-A, Cyrillic (+ supplement), general
# punctuation, currency, letterlike («№», «™»), arrows, math signs.
UNICODES = (
    list(range(0x0020, 0x007F))
    + list(range(0x00A0, 0x0180))
    + list(range(0x0400, 0x0530))
    + list(range(0x2010, 0x2028))
    + list(range(0x2030, 0x205F))
    + list(range(0x20A0, 0x20C1))
    + [0x2116, 0x2122]
    + list(range(0x2190, 0x2194))
    + [0x2212, 0x2248, 0x2260, 0x2264, 0x2265, 0x25CF, 0x2022]
)


def build(style: str, weight: int) -> Path:
    font = TTFont(SOURCE)
    static = instancer.instantiateVariableFont(
        font, {"wght": weight}, updateFontNames=True
    )
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.glyph_names = False
    options.hinting = False
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=UNICODES)
    subsetter.subset(static)
    out = FONTS / f"Rubik-{style}.ttf"
    static.save(out)
    return out


if __name__ == "__main__":
    for style, weight in WEIGHTS.items():
        path = build(style, weight)
        print(path.name, path.stat().st_size, "bytes")
