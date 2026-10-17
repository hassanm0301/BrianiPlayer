#!/usr/bin/env python3
"""Renders every logo derivative from the master logo.

The master, docs/brand/briani-logo.png, is the supplied artwork (pot over the
"Briani Player" wordmark) on a transparent background. This script splits it
into the full lockup and the pot mark, then writes the in-app assets, the
platform launcher icons, the Android TV banner and the download page images.
Rerun it after replacing the master. Requires Pillow; zopflipng is used to
shrink the PNGs when it is installed.

    python3 tools/brand/render_brand_assets.py
"""

from __future__ import annotations

import base64
import io
import re
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
MASTER = ROOT / "docs" / "brand" / "briani-logo.png"
CLIENT = ROOT / "client"
ANDROID_RES = CLIENT / "android" / "app" / "src" / "main" / "res"
MACOS_ICONS = CLIENT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WINDOWS_ICON = CLIENT / "windows" / "runner" / "resources" / "app_icon.ico"
DOWNLOAD_PAGE = ROOT / "infra" / "downloads" / "page.html"

# Launcher tiles sit on white, the background the logo was supplied on.
TILE = (255, 255, 255, 255)

# Android adaptive icons are 108 dp; launchers may crop to a 66 dp circle.
ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
ADAPTIVE_DP = 108
ADAPTIVE_SAFE_RADIUS_DP = 31


def trim(image: Image.Image) -> Image.Image:
    return image.crop(image.getchannel("A").getbbox())


def split(master: Image.Image) -> tuple[Image.Image, Image.Image]:
    """Returns (lockup, mark): the whole logo and the pot above the wordmark."""
    lockup = trim(master)
    alpha = lockup.getchannel("A")
    width, height = lockup.size
    rows = [alpha.crop((0, y, width, y + 1)).getbbox() is not None for y in range(height)]
    # The wordmark starts after the first fully transparent band below the
    # pot. Search from a third of the way down so gaps in the artwork above
    # the pot's rim are never mistaken for it.
    gap = next(y for y in range(height // 3, height) if not rows[y])
    return lockup, trim(lockup.crop((0, 0, width, gap)))


def scaled(image: Image.Image, width: float | None = None, height: float | None = None) -> Image.Image:
    """Resizes keeping the aspect ratio; Pillow premultiplies alpha for this."""
    w, h = image.size
    factor = min(x for x in (width / w if width else None, height / h if height else None) if x)
    return image.resize((max(1, round(w * factor)), max(1, round(h * factor))), Image.LANCZOS)


def centered(image: Image.Image, size: tuple[int, int], background=(0, 0, 0, 0)) -> Image.Image:
    canvas = Image.new("RGBA", size, background)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    layer.paste(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return Image.alpha_composite(canvas, layer)


def enclosing_radius(image: Image.Image) -> float:
    """Distance from the image center to its farthest visible pixel."""
    alpha = image.getchannel("A").point(lambda v: 255 if v >= 32 else 0)
    cx, cy = image.width / 2, image.height / 2
    radius = 0.0
    pixels = alpha.load()
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x, y]:
                radius = max(radius, ((x + .5 - cx) ** 2 + (y + .5 - cy) ** 2) ** .5)
    return radius


def silhouette(mark: Image.Image) -> Image.Image:
    """One-colour mark for themed icons: the cream play glyph and rice are cut out."""
    r, g, b, a = mark.split()
    cream = ImageChops.multiply(
        ImageChops.multiply(r.point(lambda v: 255 if v > 215 else 0), g.point(lambda v: 255 if v > 195 else 0)),
        b.point(lambda v: 255 if v > 140 else 0),
    )
    alpha = ImageChops.subtract(a, cream)
    white = Image.new("L", mark.size, 255)
    return Image.merge("RGBA", (white, white, white, alpha))


def square_icon(mark: Image.Image, size: int, fill: float = .94) -> Image.Image:
    return centered(scaled(mark, width=size * fill), (size, size))


def macos_icon(mark: Image.Image) -> Image.Image:
    # Apple's 1024 px grid: an 824 px rounded tile with a soft drop shadow.
    size, tile, radius = 1024, 824, 185
    inset = (size - tile) // 2
    shape = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shape).rounded_rectangle((inset, inset, inset + tile - 1, inset + tile - 1), radius, fill=255)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow.putalpha(ImageChops.offset(shape, 0, 10).point(lambda v: v * 0.3).filter(ImageFilter.GaussianBlur(14)))
    plate = Image.new("RGBA", (size, size), TILE)
    plate.putalpha(shape)
    icon = Image.alpha_composite(shadow, plate)
    return Image.alpha_composite(icon, centered(scaled(mark, width=tile * .8), (size, size)))


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    if shutil.which("zopflipng"):
        subprocess.run(["zopflipng", "-y", "--lossy_transparent", str(path), str(path)],
                       check=True, stdout=subprocess.DEVNULL)


def png_data_uri(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def render_flutter(lockup: Image.Image, mark: Image.Image) -> None:
    brand = CLIENT / "assets" / "brand"
    save_png(scaled(lockup, width=900), brand / "logo.png")
    save_png(scaled(mark, width=384), brand / "mark.png")
    # Linux window icon; the runner loads it from the bundled assets.
    save_png(square_icon(mark, 256), brand / "app_icon.png")


def render_android(lockup: Image.Image, mark: Image.Image) -> None:
    radius = enclosing_radius(mark)
    mono = silhouette(mark)
    for bucket, density in ANDROID_DENSITIES.items():
        canvas = round(ADAPTIVE_DP * density)
        factor = ADAPTIVE_SAFE_RADIUS_DP * density / radius
        width = mark.width * factor
        folder = ANDROID_RES / f"mipmap-{bucket}"
        save_png(centered(scaled(mark, width=width), (canvas, canvas)), folder / "ic_launcher_foreground.png")
        save_png(centered(scaled(mono, width=width), (canvas, canvas)), folder / "ic_launcher_monochrome.png")
    # Android TV home banner: 320 x 180 dp, supplied at xhdpi.
    banner = centered(scaled(lockup, height=360 * .84), (640, 360), TILE)
    save_png(banner.convert("RGB"), ANDROID_RES / "drawable-xhdpi" / "tv_banner.png")


def render_desktop(mark: Image.Image) -> None:
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save_png(scaled(macos_icon(mark), width=size), MACOS_ICONS / f"app_icon_{size}.png")
    master = square_icon(mark, 256)
    master.save(WINDOWS_ICON, sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 256)])


def render_download_page(mark: Image.Image) -> None:
    page = DOWNLOAD_PAGE.read_text()
    favicon = png_data_uri(square_icon(mark, 64))
    header = png_data_uri(scaled(mark, width=144))
    page, icons = re.subn(r'(<link rel="icon" type="image/png" href=")[^"]*(")', rf"\g<1>{favicon}\g<2>", page)
    page, marks = re.subn(r'(<img class="mark" src=")[^"]*(")', rf"\g<1>{header}\g<2>", page)
    if (icons, marks) != (1, 1):
        raise SystemExit(f"{DOWNLOAD_PAGE}: expected one favicon and one header mark, found {icons} and {marks}")
    DOWNLOAD_PAGE.write_text(page)


def main() -> None:
    lockup, mark = split(Image.open(MASTER).convert("RGBA"))
    render_flutter(lockup, mark)
    render_android(lockup, mark)
    render_desktop(mark)
    render_download_page(mark)
    print(f"lockup {lockup.size}, mark {mark.size}")


if __name__ == "__main__":
    main()
