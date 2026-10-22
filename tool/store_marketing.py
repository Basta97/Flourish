"""Marketing screenshots and a 15-second motion ad for Flourish, built from
real captures of the 1.2.0 release build (store/source/) and the app icon
drawing.

    python3 tool/store_marketing.py screenshots
    python3 tool/store_marketing.py video
    python3 tool/store_marketing.py all

Writes:
  store/google-play/marketing/   1080x1920 (9:16), 24-bit PNG
  store/app-store/iphone-6.9/    1320x2868, 24-bit PNG
  store/app-store/iphone-6.5/    1284x2778, 24-bit PNG
  store/video/flourish-ad-15s.mp4  1080x1920, 30 fps, H.264, 15 s, silent
  store/video/flourish-ad-poster.png

Every phone screen is a capture of the app with invented demo data
(tool/store_demo_backup.dart). Only the system status bar and gesture
handle are repainted, so the shots read the same on Android and iOS.
"""
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "assets", "icon"))
from generate_icon import N, draw_sprout, sprout_mask  # noqa: E402

FONTS = os.path.join(ROOT, "assets", "fonts")
SOURCE = os.path.join(ROOT, "store", "source")
STORE = os.path.join(ROOT, "store")

INK_TOP, INK_BOTTOM = (21, 27, 36), (7, 9, 13)
JADE_LIGHT, JADE_MID, JADE_DEEP = (124, 245, 194), (61, 220, 151), (11, 138, 95)
INDIGO = (99, 102, 241)
TEXT, TEXT_SOFT = (238, 247, 242), (178, 199, 190)

# Captures are 1080x2340 phone screens.
CAP_W, CAP_H = 1080, 2340
STATUS_H = 92


def font(name, size):
    path = {
        "display": "space_grotesk/SpaceGrotesk-Bold.ttf",
        "semibold": "manrope/Manrope-SemiBold.ttf",
        "medium": "manrope/Manrope-Medium.ttf",
        "bold": "manrope/Manrope-Bold.ttf",
    }[name]
    return ImageFont.truetype(os.path.join(FONTS, path), round(size))


def ease_out_cubic(t):
    t = min(max(t, 0.0), 1.0)
    return 1 - (1 - t) ** 3


def ease_in_out(t):
    t = min(max(t, 0.0), 1.0)
    return 3 * t * t - 2 * t * t * t


def ease_out_back(t, s=1.4):
    t = min(max(t, 0.0), 1.0) - 1
    return t * t * ((s + 1) * t + s) + 1


def span(t, start, end):
    """0 before `start`, 1 after `end`, linear between."""
    if end <= start:
        return 1.0 if t >= end else 0.0
    return min(max((t - start) / (end - start), 0.0), 1.0)


# ---------------------------------------------------------------- background

def brand_background(w, h, drift=0.0):
    """Ink gradient with soft jade and indigo aurora, as an RGB image."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((x / w) * 0.35 + (y / h) * 0.65, 0, 1)[..., None]
    img = np.array(INK_TOP, np.float32) * (1 - t) + np.array(INK_BOTTOM, np.float32) * t

    def glow(cx, cy, radius, colour, strength):
        d2 = ((x - cx) ** 2 + (y - cy) ** 2) / (radius ** 2)
        a = (np.exp(-d2) * strength)[..., None]
        return a * (np.array(colour, np.float32) - img)

    s = max(w, h)
    img += glow(w * (0.80 + 0.04 * math.sin(drift)), h * (0.16 + 0.03 * math.cos(drift * 0.8)),
                s * 0.42, JADE_MID, 0.30)
    img += glow(w * (0.05 + 0.05 * math.cos(drift * 0.7)), h * (0.92 - 0.03 * math.sin(drift)),
                s * 0.40, INDIGO, 0.22)
    img += glow(w * 0.5, h * 0.62, s * 0.55, JADE_DEEP, 0.10)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


# --------------------------------------------------------------------- brand

_SPROUT = None


def sprout(size):
    """The app's sprout mark on transparency, `size` px square."""
    global _SPROUT
    if _SPROUT is None:
        mask = sprout_mask()
        art = draw_sprout(Image.new("RGBA", (N, N), (0, 0, 0, 0)), mask)
        _SPROUT = art.crop(art.getbbox())
    w, h = _SPROUT.size
    scale = size / max(w, h)
    return _SPROUT.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)


# ------------------------------------------------------------- phone screens

def clean_screen(img):
    """Repaints the system status bar (clock, icons) and gesture handle of a
    1080x2340 capture with a neutral bar, leaving the app untouched."""
    img = img.convert("RGB").copy()
    px = np.array(img)
    px[:STATUS_H] = px[STATUS_H + 6, 8]
    # The handle sits on a vertical gradient that is uniform across a row.
    for y in range(2270, CAP_H):
        px[y, 380:700] = px[y, 360]
    img = Image.fromarray(px)
    d = ImageDraw.Draw(img)
    ink = (28, 30, 36)
    d.text((64, 46), "9:41", font=font("semibold", 40), fill=ink, anchor="lm")
    # Signal, Wi-Fi and battery, drawn platform-neutral.
    x = 862
    for i in range(4):
        hgt = 10 + i * 6
        d.rounded_rectangle([x + i * 11, 58 - hgt, x + i * 11 + 7, 58], 2, fill=ink)
    cx, cy = 938, 58
    for r, wdt in ((26, 5), (17, 5)):
        d.arc([cx - r, cy - r, cx + r, cy + r], 225, 315, fill=ink, width=wdt)
    d.ellipse([cx - 4, cy - 8, cx + 4, cy], fill=ink)
    d.rounded_rectangle([968, 33, 1018, 59], 7, outline=ink, width=3)
    d.rounded_rectangle([973, 38, 1013, 54], 4, fill=ink)
    d.rounded_rectangle([1020, 41, 1025, 51], 2, fill=ink)
    return img


class Phone:
    """A neutral, borderless phone body that frames a screen image."""

    def __init__(self, width):
        self.width = width
        self.bezel = round(width * 0.028)
        self.screen_w = width - 2 * self.bezel
        self.screen_h = round(self.screen_w * CAP_H / CAP_W)
        self.height = self.screen_h + 2 * self.bezel
        self.radius = round(width * 0.135)
        sr = self.radius - self.bezel
        w, h = self.width, self.height
        body = Image.new("RGBA", (w + 12, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(body)
        # Side buttons, then the body and a fine rim highlight.
        d.rounded_rectangle([w + 2, round(h * 0.20), w + 9, round(h * 0.27)], 3, fill=(36, 41, 50, 255))
        d.rounded_rectangle([w + 2, round(h * 0.30), w + 9, round(h * 0.40)], 3, fill=(36, 41, 50, 255))
        d.rounded_rectangle([0, 0, w - 1, h - 1], self.radius, fill=(13, 16, 21, 255))
        d.rounded_rectangle([1, 1, w - 2, h - 2], self.radius - 1, outline=(70, 80, 94, 255), width=2)
        self.body = body
        self.mask = Image.new("L", (self.screen_w, self.screen_h), 0)
        ImageDraw.Draw(self.mask).rounded_rectangle(
            [0, 0, self.screen_w - 1, self.screen_h - 1], sr, fill=255
        )

    def render(self, screen):
        """`screen` is a cleaned capture at any size; returns RGBA."""
        if screen.size != (self.screen_w, self.screen_h):
            screen = screen.resize((self.screen_w, self.screen_h), Image.LANCZOS)
        out = self.body.copy()
        out.paste(screen, (self.bezel, self.bezel), self.mask)
        return out


def shadow_for(size, blur, opacity=150, colour=(0, 0, 0)):
    w, h = size
    pad = blur * 3
    sh = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [pad, pad, pad + w, pad + h], round(w * 0.14), fill=colour + (opacity,)
    )
    return sh.filter(ImageFilter.GaussianBlur(blur)), pad


# --------------------------------------------------------------- typography

def wrap(text, fnt, width, draw):
    words, lines, line = text.split(), [], ""
    for word in words:
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=fnt) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def spaced(draw, xy, text, fnt, fill, tracking):
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking


# --------------------------------------------------------------- screenshots

SHOTS = [
    ("01-home", "home", "FLOURISH", "Your money,\nat a glance",
     "Accounts, spending and savings in one view."),
    ("02-payment-alerts", "inbox", "PAYMENT ALERTS", "Bank alerts become\npayments",
     "Turn bank SMS and alerts into payments you review and approve."),
    ("03-reports", "reports", "REPORTS", "See where\nit all goes",
     "Spending by category, month after month."),
    ("04-budgets", "budgets", "BUDGETS", "Budgets that keep\nyou on track",
     "Set a limit per category and watch it fill."),
    ("05-privacy", "tools_security", "PRIVATE BY DESIGN", "Your records stay\non your phone",
     "No sign-up, no ads. Daily backups are encrypted on your phone."),
]

SIZES = {
    "google-play/marketing": (1080, 1920),
    "app-store/iphone-6.9": (1320, 2868),
    "app-store/iphone-6.5": (1284, 2778),
}


def screenshot(w, h, still, eyebrow, headline, sub):
    canvas = brand_background(w, h).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    margin = round(w * 0.08)
    y = round(w * 0.11)

    ef = font("bold", w * 0.030)
    spaced(d, (margin, y), eyebrow, ef, JADE_LIGHT, w * 0.006)
    y += round(w * 0.062)

    hf = font("display", w * 0.088)
    for line in headline.split("\n"):
        d.text((margin - round(w * 0.004), y), line, font=hf, fill=TEXT)
        y += round(w * 0.098)

    y += round(w * 0.012)
    sf = font("medium", w * 0.036)
    sub_top = y
    for line in wrap(sub, sf, w - 2 * margin, d):
        d.text((margin, y), line, font=sf, fill=TEXT_SOFT)
        y += round(w * 0.050)
    # Two lines are reserved so every phone in the set sits at one height.
    y = max(y, sub_top + 2 * round(w * 0.050))

    # Taller canvases (iPhone) fit a wider phone; it runs off the bottom
    # edge either way.
    phone = Phone(round(w * (0.74 if h / w < 2 else 0.80)))
    px = (w - phone.width) // 2
    py = y + round(w * 0.065)
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [px - w * 0.10, py + phone.height * 0.05, px + phone.width + w * 0.10, py + phone.height * 0.75],
        fill=JADE_MID + (60,),
    )
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(w * 0.09)))
    sh, pad = shadow_for((phone.width, phone.height), round(w * 0.03), 170)
    canvas.alpha_composite(sh, (px - pad, py - pad + round(w * 0.02)))
    canvas.alpha_composite(phone.render(clean_screen(still)), (px, py))
    return canvas.convert("RGB")


def make_screenshots():
    stills = {
        name: Image.open(os.path.join(SOURCE, "stills", f"{name}.png"))
        for name in {s[1] for s in SHOTS}
    }
    for folder, (w, h) in SIZES.items():
        out = os.path.join(STORE, folder)
        os.makedirs(out, exist_ok=True)
        for file, still, eyebrow, headline, sub in SHOTS:
            screenshot(w, h, stills[still], eyebrow, headline, sub).save(
                os.path.join(out, f"{file}.png"), optimize=True
            )
            print("wrote", os.path.join(folder, f"{file}.png"))


# --------------------------------------------------------------------- video

FPS, DURATION = 30, 15.0
VW, VH = 1080, 1920

# (clip, first second used, scene start, scene end, caption, sub-caption)
SCENES = [
    ("home", 2.15, 2.0, 5.0, "Your money,\nat a glance", "Accounts, spending and savings"),
    ("inbox", 2.0, 5.0, 8.4, "Bank alerts become\npayments", "You review and approve each one"),
    ("reports", 0.45, 8.4, 10.9, "See where\nit all goes", "Spending by category"),
    ("budgets", 0.95, 10.9, 12.7, "Stay on budget", "Limits per category"),
]


def clip_frames(name, start, count, size):
    """`count` frames at 30 fps from `start`, scaled to `size`, cleaned."""
    w, h = size
    cmd = [
        "ffmpeg", "-v", "error", "-ss", f"{start:.3f}", "-i",
        os.path.join(SOURCE, "clips", f"{name}.mp4"),
        "-vf", f"fps={FPS},scale={CAP_W}:{CAP_H}:flags=lanczos",
        "-frames:v", str(count), "-f", "rawvideo", "-pix_fmt", "rgb24", "-",
    ]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (CAP_W * CAP_H * 3)
    frames = []
    for i in range(n):
        arr = np.frombuffer(raw, np.uint8, CAP_W * CAP_H * 3, i * CAP_W * CAP_H * 3)
        img = Image.fromarray(arr.reshape(CAP_H, CAP_W, 3))
        frames.append(clean_screen(img).resize((w, h), Image.LANCZOS))
    # Short clips hold on their last frame.
    while len(frames) < count:
        frames.append(frames[-1])
    return frames


class Text:
    """Pre-rendered text block that can be faded and moved cheaply."""

    def __init__(self, lines, fnt, fill, line_h, width=VW, align="center"):
        d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        self.h = round(line_h * len(lines) + fnt.size * 0.4)
        self.img = Image.new("RGBA", (width, self.h), (0, 0, 0, 0))
        dd = ImageDraw.Draw(self.img)
        for i, line in enumerate(lines):
            tw = d.textlength(line, font=fnt)
            x = (width - tw) / 2 if align == "center" else 0
            dd.text((x, i * line_h), line, font=fnt, fill=fill)

    def draw(self, canvas, x, y, alpha):
        if alpha <= 0.01:
            return
        im = self.img
        if alpha < 0.999:
            im = im.copy()
            im.putalpha(im.getchannel("A").point(lambda v: round(v * alpha)))
        canvas.alpha_composite(im, (round(x), round(y)))


def chip(text):
    f = font("semibold", 38)
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    tw = d.textlength(text, font=f)
    w, h = round(tw + 120), 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(img)
    dd.rounded_rectangle([0, 0, w - 1, h - 1], h // 2, fill=(255, 255, 255, 24), outline=JADE_MID + (150,), width=2)
    cx, cy = 52, h // 2
    dd.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], fill=JADE_MID + (255,))
    dd.line([(cx - 9, cy + 1), (cx - 2, cy + 8), (cx + 10, cy - 7)], fill=(7, 30, 22, 255), width=5, joint="curve")
    dd.text((88, cy), text, font=f, fill=TEXT + (255,), anchor="lm")
    return img


def with_alpha(img, alpha):
    if alpha >= 0.999:
        return img
    out = img.copy()
    out.putalpha(out.getchannel("A").point(lambda v: round(v * alpha)))
    return out


def make_video():
    out_dir = os.path.join(STORE, "video")
    os.makedirs(out_dir, exist_ok=True)
    phone = Phone(round(VW * 0.64))
    screen_size = (phone.screen_w, phone.screen_h)
    phone_x = (VW - phone.width) // 2
    phone_y = 505
    shadow, pad = shadow_for((phone.width, phone.height), 34, 180)

    print("decoding clips…")
    clips = []
    for name, start, s0, s1, *_ in SCENES:
        count = round((s1 - s0) * FPS) + 12  # spare frames for transitions
        clips.append(clip_frames(name, start, count, screen_size))

    print("preparing graphics…")
    bg_big = brand_background(VW + 160, VH + 240)
    big_mark = sprout(300)
    small_mark = sprout(62)
    wordmark = Text(["Flourish"], font("display", 132), TEXT, 140)
    tagline = Text(["Budget. Track. Flourish."], font("medium", 44), TEXT_SOFT, 52)
    brand_small = Text(["Flourish"], font("display", 46), TEXT, 50, width=400, align="left")
    captions = [
        (Text(c.split("\n"), font("display", 82), TEXT, 90),
         Text([sub], font("medium", 40), JADE_LIGHT, 48))
        for *_, c, sub in SCENES
    ]
    chips = [chip("No sign-up"), chip("No ads"), chip("Your records stay on your phone")]
    end_tag = Text(["Private budgeting, on your phone."], font("medium", 46), TEXT_SOFT, 54)
    glow = Image.new("RGBA", (VW, VH), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        [phone_x - 140, phone_y + 120, phone_x + phone.width + 140, phone_y + phone.height - 200],
        fill=JADE_MID + (70,),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(110))

    ffmpeg = subprocess.Popen(
        [
            "ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
            "-s", f"{VW}x{VH}", "-r", str(FPS), "-i", "-",
            "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-profile:v", "high",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart",
            os.path.join(out_dir, "flourish-ad-15s.mp4"),
        ],
        stdin=subprocess.PIPE,
    )

    total = round(DURATION * FPS)
    poster = None
    for f in range(total):
        t = f / FPS
        # Slow drifting background.
        ox = 80 + 60 * math.sin(t * 0.35)
        oy = 120 + 90 * math.sin(t * 0.22)
        canvas = bg_big.crop((round(ox), round(oy), round(ox) + VW, round(oy) + VH)).convert("RGBA")

        # Intro: mark grows, wordmark and tagline rise in, then lift away.
        if t < 2.4:
            out = ease_in_out(span(t, 1.55, 2.2))
            a = span(t, 0.0, 0.5) * (1 - out)
            s = 0.55 + 0.45 * ease_out_back(span(t, 0.0, 0.75))
            mark = big_mark.resize((max(1, round(big_mark.width * s)), max(1, round(big_mark.height * s))), Image.LANCZOS)
            cy = 760 - 260 * out
            canvas.alpha_composite(with_alpha(mark, a), (VW // 2 - mark.width // 2, round(cy - mark.height / 2)))
            wa = span(t, 0.45, 1.0) * (1 - out)
            wordmark.draw(canvas, 0, 960 + 40 * (1 - ease_out_cubic(span(t, 0.45, 1.0))) - 260 * out, wa)
            ta = span(t, 0.85, 1.35) * (1 - out)
            tagline.draw(canvas, 0, 1125 + 30 * (1 - ease_out_cubic(span(t, 0.85, 1.35))) - 260 * out, ta)

        # Small brand lockup while the phone is on screen.
        ba = span(t, 2.0, 2.5) * (1 - span(t, 12.5, 12.9))
        if ba > 0:
            canvas.alpha_composite(with_alpha(small_mark, ba), (74, 92))
            brand_small.draw(canvas, 148, 96, ba)

        # Phone: rises at 2.0 s, gently floats, drops away at 12.7 s.
        rise = ease_out_cubic(span(t, 1.95, 2.6))
        fall = ease_in_out(span(t, 12.65, 13.15))
        if rise > 0 and fall < 1:
            scene = max(i for i, sc in enumerate(SCENES) if t >= sc[2] or i == 0)
            name, start, s0, s1, *_ = SCENES[scene]
            local = round((t - s0) * FPS)
            screen = clips[scene][min(max(local, 0), len(clips[scene]) - 1)]
            # Push transition between scenes inside the screen.
            if scene > 0 and t - s0 < 0.35:
                p = ease_in_out((t - s0) / 0.35)
                prev = clips[scene - 1]
                prev_frame = prev[min(round((t - SCENES[scene - 1][2]) * FPS), len(prev) - 1)]
                comp = Image.new("RGB", screen_size)
                dx = round(screen_size[0] * p)
                comp.paste(prev_frame, (-dx, 0))
                comp.paste(screen, (screen_size[0] - dx, 0))
                screen = comp
            float_y = 10 * math.sin(t * 1.6)
            y = phone_y + (1 - rise) * 1200 + fall * 1400 + float_y
            pa = min(rise * 1.4, 1.0) * (1 - fall)
            canvas = Image.alpha_composite(canvas, with_alpha(glow, pa))
            canvas.alpha_composite(with_alpha(shadow, pa), (phone_x - pad, round(y) - pad + 26))
            canvas.alpha_composite(with_alpha(phone.render(screen), pa), (phone_x - 6 // 2, round(y)))

            # Captions crossfade per scene.
            for i, (title, sub) in enumerate(captions):
                _, _, c0, c1, *_ = SCENES[i]
                ain = ease_out_cubic(span(t, c0 + 0.15, c0 + 0.55))
                aout = 1 - span(t, c1 - 0.25, c1 + 0.05)
                if i == len(SCENES) - 1:
                    aout = 1 - span(t, 12.55, 12.9)
                a = ain * aout
                if a <= 0:
                    continue
                dy = 26 * (1 - ain)
                title.draw(canvas, 0, 168 + dy, a)
                sub.draw(canvas, 0, 168 + title.h + 2 + dy, a)

        # End card: privacy chips, then the brand.
        if t >= 12.8:
            for i, img in enumerate(chips):
                st = 12.85 + i * 0.18
                a = ease_out_cubic(span(t, st, st + 0.35))
                if a <= 0:
                    continue
                s = 0.85 + 0.15 * ease_out_back(span(t, st, st + 0.45))
                im = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
                y = 1240 + i * 118 + 30 * (1 - a)
                canvas.alpha_composite(with_alpha(im, a), (VW // 2 - im.width // 2, round(y)))
            la = ease_out_cubic(span(t, 13.0, 13.55))
            s = 0.7 + 0.3 * ease_out_back(span(t, 13.0, 13.6))
            mark = big_mark.resize((round(big_mark.width * s * 0.8), round(big_mark.height * s * 0.8)), Image.LANCZOS)
            canvas.alpha_composite(with_alpha(mark, la), (VW // 2 - mark.width // 2, round(600 - mark.height / 2)))
            wordmark.draw(canvas, 0, 760 + 30 * (1 - la), la)
            end_tag.draw(canvas, 0, 920 + 20 * (1 - la), ease_out_cubic(span(t, 13.3, 13.8)))

        # Fade from and to ink at the very ends.
        edge = min(span(t, 0.0, 0.25), 1 - span(t, DURATION - 0.2, DURATION))
        frame = canvas.convert("RGB")
        if edge < 1:
            frame = Image.blend(Image.new("RGB", frame.size, INK_BOTTOM), frame, edge)
        if abs(t - 9.9) < 1 / (2 * FPS):
            poster = frame
        ffmpeg.stdin.write(frame.tobytes())
        if f % 30 == 0:
            print(f"  {t:4.1f}s")
    ffmpeg.stdin.close()
    if ffmpeg.wait() != 0:
        raise SystemExit("ffmpeg failed")
    if poster is not None:
        poster.save(os.path.join(out_dir, "flourish-ad-poster.png"), optimize=True)
    print("wrote store/video/flourish-ad-15s.mp4")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("screenshots", "all"):
        make_screenshots()
    if what in ("video", "all"):
        make_video()
