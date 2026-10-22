"""Renders Android adaptive-icon layers and Google Play listing graphics
from the same drawing as the app icon (generate_icon.py).

    python3 assets/icon/generate_store_assets.py

Writes:
  android/app/src/main/res/mipmap-*/ic_launcher_{background,foreground,monochrome}.png
  store/google-play/icon-512.png               (32-bit PNG, Play listing icon)
  store/google-play/feature-graphic-1024x500.png (24-bit PNG, no alpha)
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generate_icon import N, background, draw_sprout, sprout_mask  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
STORE = os.path.join(ROOT, "store", "google-play")
FONTS = os.path.join(ROOT, "assets", "fonts")

# Adaptive icons are 108dp; launchers may crop to a 66dp circle, so the
# sprout stays inside a radius of 0.29 of the canvas (0.306 is the limit).
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
SAFE_RADIUS = 0.29


def mark_geometry(mask):
    """Centre of the sprout's bounding box and its farthest point from it."""
    small = mask.resize((256, 256), Image.BILINEAR)
    x0, y0, x1, y1 = small.getbbox()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    px = small.load()
    r = max(
        math.hypot(x - cx, y - cy)
        for y in range(y0, y1)
        for x in range(x0, x1)
        if px[x, y] > 8
    )
    k = N / 256
    return cx * k, cy * k, r * k


def centred(img, mask, radius):
    """`img` scaled and moved so the sprout is centred within `radius`·N."""
    cx, cy, r = mark_geometry(mask)
    scale = radius * N / r
    size = round(N * scale)
    scaled = img.resize((size, size), Image.LANCZOS)
    out = Image.new(img.mode, (N, N), (0, 0, 0, 0) if img.mode == "RGBA" else 0)
    out.paste(scaled, (round(N / 2 - cx * scale), round(N / 2 - cy * scale)))
    return out


def save(img, path, size, mode=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = img.resize((size, size), Image.LANCZOS)
    if mode:
        out = out.convert(mode)
    out.save(path, optimize=True)


def adaptive_layers():
    mask = sprout_mask()
    clear = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    foreground = centred(draw_sprout(clear, mask), mask, SAFE_RADIUS)
    # Android tints the monochrome layer for themed icons (Android 13+).
    white = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    white.putalpha(mask)
    monochrome = centred(white, mask, SAFE_RADIUS)
    bg = background()
    for density, px in DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        save(bg, os.path.join(folder, "ic_launcher_background.png"), px, "RGB")
        save(foreground, os.path.join(folder, "ic_launcher_foreground.png"), px)
        save(monochrome, os.path.join(folder, "ic_launcher_monochrome.png"), px)


def play_icon():
    # Play applies its own corner mask; the icon is full-bleed and opaque.
    icon = draw_sprout(background(), sprout_mask())
    save(icon, os.path.join(STORE, "icon-512.png"), 512, "RGBA")


def font(path, size):
    return ImageFont.truetype(os.path.join(FONTS, path), size)


def feature_graphic():
    w, h = 1024, 500
    bg = background().resize((w, w), Image.LANCZOS).crop((0, 262, w, 262 + h))
    canvas = bg.convert("RGBA")

    mask = sprout_mask()
    clear = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mark = centred(draw_sprout(clear, mask), mask, 0.45).resize((380, 380), Image.LANCZOS)
    canvas.alpha_composite(mark, (24, 60))

    draw = ImageDraw.Draw(canvas)
    left, right = 404, w - 40

    def fitted(path, size, text):
        while draw.textlength(text, font=font(path, size)) > right - left:
            size -= 1
        return font(path, size)

    title = "Flourish"
    draw.text((left - 4, 140), title, font=fitted("space_grotesk/SpaceGrotesk-Bold.ttf", 104, title), fill=(236, 246, 241, 255))
    lines = [
        ("Track spending, budgets and net worth.", (196, 214, 206, 255)),
        ("Your records stay on your phone.", (124, 245, 194, 255)),
    ]
    size = min(fitted("manrope/Manrope-Medium.ttf", 32, t).size for t, _ in lines)
    body = font("manrope/Manrope-Medium.ttf", size)
    for i, (text, colour) in enumerate(lines):
        draw.text((left, 280 + i * (size + 14)), text, font=body, fill=colour)
    os.makedirs(STORE, exist_ok=True)
    canvas.convert("RGB").save(os.path.join(STORE, "feature-graphic-1024x500.png"), optimize=True)


if __name__ == "__main__":
    adaptive_layers()
    play_icon()
    feature_graphic()
