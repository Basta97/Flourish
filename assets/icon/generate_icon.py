"""Renders the Flourish app icon (1024×1024 master) with Pillow.

A jade sprout on an ink-navy field with the same soft aurora glow as the
Home net-worth card. Drawn at 4× and downsampled for clean edges.

    python3 assets/icon/generate_icon.py [out.png]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling factor
N = 1024 * S


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(round(lerp(a, b, t)) for a, b in zip(c1, c2))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


# The sprout is drawn in 1024 space, then scaled about its visual centre so
# it holds its own next to system icons at small sizes.
MARK_SCALE = 1.15
MARK_CENTER = (525, 555)


def place(p):
    cx, cy = MARK_CENTER
    return (cx + (p[0] - cx) * MARK_SCALE, cy + (p[1] - cy) * MARK_SCALE)


def cubic(p0, p1, p2, p3, steps=160):
    p0, p1, p2, p3 = place(p0), place(p1), place(p2), place(p3)
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x * S, y * S))
    return pts


def vertical_gradient(top, bottom, box):
    """RGBA image filling `box` with a top→bottom gradient."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    grad = Image.new("RGBA", (1, max(h, 1)))
    for y in range(max(h, 1)):
        grad.putpixel((0, y), mix(top, bottom, y / max(h - 1, 1)) + (255,))
    img.paste(grad.resize((max(w, 1), max(h, 1))), (x0, y0))
    return img


def leaf(base, tip, bulge, lean=0.0):
    """Closed leaf outline from base to tip, two mirrored cubic edges."""
    bx, by = base
    tx, ty = tip
    dx, dy = tx - bx, ty - by
    length = math.hypot(dx, dy)
    nx, ny = -dy / length, dx / length  # unit normal
    def off(t, k):
        return (bx + dx * t + nx * k, by + dy * t + ny * k)
    a1 = off(0.30, bulge * (1 + lean))
    a2 = off(0.78, bulge * 0.62 * (1 + lean))
    b1 = off(0.30, -bulge * (1 - lean))
    b2 = off(0.78, -bulge * 0.62 * (1 - lean))
    return cubic(base, a1, a2, tip) + cubic(tip, b2, b1, base)[1:]


INK_TOP, INK_BOTTOM = hex_rgb("151B24"), hex_rgb("07090D")
JADE_LIGHT, JADE_MID, JADE_DEEP = hex_rgb("7CF5C2"), hex_rgb("3DDC97"), hex_rgb("0B8A5F")


def background():
    """Ink field with the jade and indigo aurora, RGBA at N×N."""
    # Background: diagonal ink gradient.
    small = Image.new("RGB", (256, 256))
    sp = small.load()
    for y in range(256):
        for x in range(256):
            t = (x * 0.35 + y * 0.65) / 255
            sp[x, y] = mix(INK_TOP, INK_BOTTOM, min(t, 1))
    bg = small.resize((N, N), Image.BICUBIC).convert("RGBA")

    # Aurora: jade glow behind the sprout, faint indigo low-left.
    glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([int(N * 0.18), int(N * 0.10), int(N * 0.92), int(N * 0.84)], fill=JADE_MID + (70,))
    gd.ellipse([int(-N * 0.20), int(N * 0.62), int(N * 0.45), int(N * 1.20)], fill=hex_rgb("6366F1") + (55,))
    glow = glow.filter(ImageFilter.GaussianBlur(N * 0.12))
    return Image.alpha_composite(bg, glow)


def sprout_mask():
    """The sprout's silhouette (L mode, N×N)."""
    # Sprout geometry (in 1024 space).
    # The stem ends inside the big leaf's base so no stub shows above it.
    stem = cubic((508, 832), (500, 730), (504, 630), (532, 562), 200)
    right = leaf((520, 560), (800, 268), 120, lean=0.15)
    left = leaf((508, 650), (250, 470), 82, lean=-0.1)

    # Shapes mask.
    mask = Image.new("L", (N, N), 0)
    md = ImageDraw.Draw(mask)
    md.polygon(right, fill=255)
    md.polygon(left, fill=255)
    # Tapered stem: thick at the soil, thin where it flows into the leaf.
    for i, (x, y) in enumerate(stem):
        r = lerp(32, 13, i / (len(stem) - 1)) * S * MARK_SCALE
        md.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return mask


def draw_sprout(bg, mask):
    """Composites the sprout's glow, jade fill and sheen onto `bg` (RGBA)."""
    # Soft drop glow under the mark.
    shadow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    shadow.paste(JADE_MID + (120,), (0, 0), mask.filter(ImageFilter.GaussianBlur(28 * S)))
    bg = Image.alpha_composite(bg, shadow)

    # Jade gradient fill through the mask.
    fill = vertical_gradient(JADE_LIGHT, JADE_DEEP, (0, int(N * 0.24), N, int(N * 0.86)))
    top_pad = Image.new("RGBA", (N, int(N * 0.24)), JADE_LIGHT + (255,))
    fill.paste(top_pad, (0, 0))
    bottom_pad = Image.new("RGBA", (N, N - int(N * 0.86)), JADE_DEEP + (255,))
    fill.paste(bottom_pad, (0, int(N * 0.86)))
    mark = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    mark.paste(fill, (0, 0), mask)
    bg = Image.alpha_composite(bg, mark)

    # Top-edge sheen on the big leaf.
    sheen = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.polygon(leaf((560, 520), (790, 280), 46, lean=0.6), fill=(255, 255, 255, 55))
    sheen = sheen.filter(ImageFilter.GaussianBlur(10 * S))
    clipped = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    clipped.paste(sheen, (0, 0), mask)
    return Image.alpha_composite(bg, clipped)


def main(out):
    bg = draw_sprout(background(), sprout_mask())
    # iOS icons must be opaque.
    bg.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(out, optimize=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/icon/app_icon.png")
