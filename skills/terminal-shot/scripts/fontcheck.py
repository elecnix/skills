#!/usr/bin/env python3
"""Font check: do block characters render gap-free?

Renders full-block characters through termframe and looks for background
seams inside the filled area. A font that draws blocks shorter than the line
box leaves horizontal bars; a font that draws U+2588 narrower than the cell
leaves vertical ones. Both show up here as a fully-background row or column
inside the block bounding box.

Usage: fontcheck.py [renderer-args...]
Exit: 0 when the blocks tile cleanly, 1 when they do not.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image
import numpy as np

COLS = 12
ROWS = 4
SCREEN = "\n".join(["█" * COLS] * ROWS) + "\n"


def render(extra_args: list[str]) -> Image.Image:
    tmp = Path(tempfile.mkdtemp(prefix="fontcheck-"))
    svg = tmp / "blocks.svg"
    png = tmp / "blocks.png"
    termframe = Path.home() / ".local/bin/termframe"
    result = subprocess.run(
        [str(termframe), "-W", str(COLS + 4), "-H", str(ROWS + 2), *extra_args, "-o", str(svg)],
        input=SCREEN,
        check=True,
        capture_output=True,
        text=True,
    )
    missing = [line for line in result.stderr.splitlines() if "font not found" in line]
    if missing:
        raise SystemExit(
            "FAIL: the configured fonts do not cover every glyph:\n  "
            + "\n  ".join(missing[:5])
        )
    subprocess.run(["rsvg-convert", "-z", "1", "-o", str(png), str(svg)], check=True)
    return Image.open(png).convert("RGB")


def check(img: Image.Image) -> tuple[bool, str]:
    a = np.asarray(img).astype(int)
    # The blocks are drawn in the terminal foreground; find them by contrast
    # against the most common (background) colour in the image.
    flat = a.reshape(-1, 3)
    colours, counts = np.unique(flat, axis=0, return_counts=True)
    bg = colours[counts.argmax()]
    diff = np.abs(a - bg).sum(axis=2)
    filled = diff > 24
    rows = np.where(filled.any(axis=1))[0]
    cols = np.where(filled.any(axis=0))[0]
    if rows.size == 0 or cols.size == 0:
        return False, "no blocks found in the render"
    box = (rows[0], rows[-1], cols[0], cols[-1])
    inside = filled[box[0] : box[1] + 1, box[2] : box[3] + 1]
    empty_rows = int((~inside.any(axis=1)).sum())
    empty_cols = int((~inside.any(axis=0)).sum())
    height = box[1] - box[0] + 1
    width = box[3] - box[2] + 1
    ok = empty_rows == 0 and empty_cols == 0
    detail = (
        f"{width}x{height}px block area, {empty_rows} background row(s), "
        f"{empty_cols} background column(s) inside it"
    )
    return ok, detail


def main() -> int:
    img = render(sys.argv[1:])
    ok, detail = check(img)
    print(("PASS" if ok else "FAIL") + ": " + detail)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
